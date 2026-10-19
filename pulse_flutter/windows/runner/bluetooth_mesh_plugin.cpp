#include "bluetooth_mesh_plugin.h"
#include "ble_frame_codec.h"
#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Devices.Radios.h>
#include <winrt/Windows.Devices.Bluetooth.Advertisement.h>
#include <winrt/Windows.Devices.Bluetooth.GenericAttributeProfile.h>
#include <algorithm>
#include <atomic>
#include <condition_variable>
#include <deque>
#include <functional>
#include <map>
#include <mutex>
#include <thread>

namespace {
using namespace winrt;
using namespace Windows::Foundation;
using namespace Windows::Devices::Bluetooth;
using namespace Windows::Devices::Bluetooth::Advertisement;
using namespace Windows::Devices::Bluetooth::GenericAttributeProfile;
using namespace Windows::Storage::Streams;
using V = flutter::EncodableValue;
using M = flutter::EncodableMap;
const guid service_id{"c358e1b0-bf5c-48ec-9f05-241f97d4a06a"};
const guid char_id{"c358e1b1-bf5c-48ec-9f05-241f97d4a06a"};
std::string Text(const M& map, const char* key) {
  auto i = map.find(V(key));
  return i != map.end() && std::holds_alternative<std::string>(i->second) ? std::get<std::string>(i->second) : "";
}
IBuffer MakeBuffer(const std::vector<uint8_t>& value) {
  DataWriter writer; writer.WriteBytes(value); return writer.DetachBuffer();
}
std::vector<uint8_t> Bytes(IBuffer const& value) {
  if (!value || value.Length() > 512) throw std::runtime_error("size");
  std::vector<uint8_t> result(value.Length()); DataReader::FromBuffer(value).ReadBytes(result); return result;
}
}

// All radio objects and peers are owned by one MTA worker. Flutter channels are
// touched only on the window thread. Window messages carry no external pointer.
struct BluetoothMeshPlugin::Impl : std::enable_shared_from_this<Impl> {
  struct Peer {
    std::string id;
    hstring key;
    BluetoothLEDevice device{nullptr};
    GattDeviceService service{nullptr};
    GattSession session{nullptr};
    GattCharacteristic remote{nullptr};
    GattSubscribedClient subscriber{nullptr};
    event_token value_token{}, disconnected_token{};
    BleFrameCodec decoder;
    size_t capacity = 20;
    std::chrono::steady_clock::time_point touched = std::chrono::steady_clock::now();
  };
  HWND window;
  std::atomic<bool> closing{false};
  std::mutex mutex;
  std::condition_variable cv;
  std::deque<std::function<void()>> work, ui;
  std::thread worker;
  std::unique_ptr<flutter::MethodChannel<V>> methods;
  std::unique_ptr<flutter::EventChannel<V>> events;
  std::unique_ptr<flutter::EventSink<V>> sink;
  std::string lease, state = "stopped";
  bool running = false;
  unsigned next_peer = 0;
  BluetoothLEAdvertisementWatcher watcher{nullptr};
  GattServiceProvider provider{nullptr};
  GattLocalCharacteristic local{nullptr};
  event_token received_token{}, stopped_token{}, write_token{}, subscribers_token{};
  std::map<std::string, std::shared_ptr<Peer>> peers;
  std::map<uint64_t, std::chrono::steady_clock::time_point> visited;
  explicit Impl(HWND hwnd) : window(hwnd) {}
  bool Post(std::function<void()> task) {
    std::lock_guard<std::mutex> lock(mutex);
    if (closing || work.size() >= 256) return false;
    work.push_back(std::move(task)); cv.notify_one(); return true;
  }
  void UI(std::function<void()> task) {
    std::lock_guard<std::mutex> lock(mutex);
    if (closing || ui.size() >= 512) return;
    ui.push_back(std::move(task)); PostMessage(window, BluetoothMeshPlugin::message, 0, 0);
  }
  void Emit(M map) {
    map[V("lease")] = V(lease);
    auto self = shared_from_this();
    UI([self, map = std::move(map)] { if (self->sink) self->sink->Success(V(map)); });
  }
  void State(const std::string& value) { state = value; Emit({{V("type"), V("status")}, {V("state"), V(value)}}); }
  void Connected(const std::shared_ptr<Peer>& peer, bool value) {
    Emit({{V("type"), V("peer")}, {V("peer"), V(peer->id)}, {V("connected"), V(value)}});
  }
  void Close(const std::string& id) {
    auto found = peers.find(id); if (found == peers.end()) return;
    auto p = found->second; peers.erase(found);
    try { if (p->remote) p->remote.ValueChanged(p->value_token); } catch (...) {}
    try { if (p->device) { p->device.ConnectionStatusChanged(p->disconnected_token); p->device.Close(); } } catch (...) {}
    try { if (p->session) p->session.Close(); if (p->service) p->service.Close(); } catch (...) {}
    Connected(p, false);
  }
  void Stop() {
    running = false;
    try { if (watcher) { watcher.Received(received_token); watcher.Stopped(stopped_token); watcher.Stop(); } } catch (...) {}
    watcher = nullptr;
    try { if (provider) provider.StopAdvertising(); } catch (...) {}
    try { if (local) { local.WriteRequested(write_token); local.SubscribedClientsChanged(subscribers_token); } } catch (...) {}
    local = nullptr; provider = nullptr;
    while (!peers.empty()) Close(peers.begin()->first);
    visited.clear(); State("stopped");
  }
  void Frame(const std::shared_ptr<Peer>& peer, const std::vector<uint8_t>& bytes) {
    try {
      auto frame = peer->decoder.Accept(bytes); peer->touched = std::chrono::steady_clock::now();
      if (!frame.empty()) Emit({{V("type"), V("frame")}, {V("peer"), V(peer->id)}, {V("data"), V(frame)}});
    } catch (...) { peer->decoder.Reset(); Close(peer->id); }
  }
  void Subscribed(const std::string& generation) {
    if (!running || generation != lease || !local) return;
    std::vector<std::string> removed;
    auto clients = local.SubscribedClients();
    for (const auto& item : peers) {
      if (!item.second->subscriber) continue;
      bool found = false;
      for (auto c : clients) if (c.Session().DeviceId().Id() == item.second->key) found = true;
      if (!found) removed.push_back(item.first);
    }
    for (const auto& id : removed) Close(id);
    for (auto client : clients) {
      auto key = client.Session().DeviceId().Id(); bool found = false;
      for (const auto& item : peers) if (item.second->key == key) found = true;
      if (found || peers.size() >= 4) continue;
      auto peer = std::make_shared<Peer>(); peer->id = "p" + std::to_string(++next_peer);
      peer->key = key; peer->subscriber = client;
      peer->capacity = std::clamp<size_t>(client.MaxNotificationSize(), 20, 244);
      peers[peer->id] = peer; Connected(peer, true);
    }
  }
  void Peripheral(const std::string& generation) {
    auto result = GattServiceProvider::CreateAsync(service_id).get();
    if (result.Error() != BluetoothError::Success) return;
    provider = result.ServiceProvider();
    GattLocalCharacteristicParameters params;
    params.CharacteristicProperties(GattCharacteristicProperties::Write | GattCharacteristicProperties::Indicate);
    params.WriteProtectionLevel(GattProtectionLevel::Plain);
    auto created = provider.Service().CreateCharacteristicAsync(char_id, params).get();
    if (created.Error() != BluetoothError::Success) { provider = nullptr; return; }
    local = created.Characteristic(); auto weak = weak_from_this();
    write_token = local.WriteRequested([weak, generation](auto const&, GattWriteRequestedEventArgs const& args) {
      auto deferral = args.GetDeferral();
      if (auto self = weak.lock()) { if (!self->Post([self, generation, args, deferral] {
        try {
          auto request = args.GetRequestAsync().get();
          if (request) {
            std::shared_ptr<Peer> peer;
            if (self->running && self->lease == generation) {
              auto key = args.Session().DeviceId().Id();
              for (const auto& item : self->peers) if (item.second->key == key) peer = item.second;
            }
            if (!peer || request.Offset() != 0 || request.Option() != GattWriteOption::WriteWithResponse)
              request.RespondWithProtocolError(0x03);
            else { self->Frame(peer, Bytes(request.Value())); request.Respond(); }
          }
        } catch (...) {}
        deferral.Complete();
      })) deferral.Complete(); } else deferral.Complete();
    });
    subscribers_token = local.SubscribedClientsChanged([weak, generation](auto const&, auto const&) {
      if (auto self = weak.lock()) self->Post([self, generation] { self->Subscribed(generation); });
    });
    GattServiceProviderAdvertisingParameters advertising;
    advertising.IsConnectable(true); advertising.IsDiscoverable(true);
    provider.StartAdvertising(advertising);
  }
  void Connect(uint64_t address, const std::string& generation) {
    if (!running || lease != generation || peers.size() >= 4) return;
    auto now = std::chrono::steady_clock::now();
    auto last = visited.find(address);
    if (last != visited.end() && now - last->second < std::chrono::seconds(45)) return;
    visited[address] = now; if (visited.size() > 64) visited.erase(visited.begin());
    auto peer = std::make_shared<Peer>(); peer->id = "p" + std::to_string(++next_peer);
    try {
      peer->device = BluetoothLEDevice::FromBluetoothAddressAsync(address).get();
      if (!peer->device) return;
      peer->key = peer->device.BluetoothDeviceId().Id();
      for (const auto& item : peers) if (item.second->key == peer->key) { peer->device.Close(); return; }
      auto services = peer->device.GetGattServicesForUuidAsync(service_id, BluetoothCacheMode::Uncached).get();
      if (services.Status() != GattCommunicationStatus::Success || !services.Services().Size()) { peer->device.Close(); return; }
      peer->service = services.Services().GetAt(0);
      auto chars = peer->service.GetCharacteristicsForUuidAsync(char_id, BluetoothCacheMode::Uncached).get();
      if (chars.Status() != GattCommunicationStatus::Success || !chars.Characteristics().Size()) { peer->service.Close(); peer->device.Close(); return; }
      peer->remote = chars.Characteristics().GetAt(0);
      peer->session = GattSession::FromDeviceIdAsync(peer->device.BluetoothDeviceId()).get();
      if (peer->session) peer->capacity = std::clamp<size_t>(peer->session.MaxPduSize() - 3, 20, 244);
      auto weak = weak_from_this(); auto id = peer->id;
      peer->value_token = peer->remote.ValueChanged([weak, generation, id](auto const&, GattValueChangedEventArgs const& args) {
        try {
          auto data = Bytes(args.CharacteristicValue());
          if (auto self = weak.lock()) self->Post([self, generation, id, data = std::move(data)] {
            auto found = self->peers.find(id);
            if (self->lease == generation && found != self->peers.end()) self->Frame(found->second, data);
          });
        } catch (...) {}
      });
      auto status = peer->remote.WriteClientCharacteristicConfigurationDescriptorAsync(GattClientCharacteristicConfigurationDescriptorValue::Indicate).get();
      if (status != GattCommunicationStatus::Success) { peer->remote.ValueChanged(peer->value_token); peer->device.Close(); return; }
      peer->disconnected_token = peer->device.ConnectionStatusChanged([weak, generation, id](BluetoothLEDevice const& source, auto const&) {
        if (source.ConnectionStatus() == BluetoothConnectionStatus::Disconnected)
          if (auto self = weak.lock()) self->Post([self, generation, id] { if (self->lease == generation) self->Close(id); });
      });
      peers[id] = peer; Connected(peer, true);
    } catch (...) { try { if (peer->device) peer->device.Close(); } catch (...) {} }
  }
  void Start(const std::string& requested) {
    if (lease != requested) { Stop(); lease = requested; }
    if (running) return;
    auto adapter = BluetoothAdapter::GetDefaultAsync().get();
    if (!adapter || !adapter.IsLowEnergySupported()) { State("unsupported"); return; }
    auto radio=adapter.GetRadioAsync().get();
    if(radio && radio.State()!=Windows::Devices::Radios::RadioState::On) { State("bluetooth_off"); return; }
    running = true;
    if (adapter.IsPeripheralRoleSupported()) { try { Peripheral(requested); } catch (...) {} }
    watcher = BluetoothLEAdvertisementWatcher(); watcher.ScanningMode(BluetoothLEScanningMode::Passive);
    watcher.AdvertisementFilter().Advertisement().ServiceUuids().Append(service_id);
    auto weak = weak_from_this();
    received_token = watcher.Received([weak, requested](auto const&, BluetoothLEAdvertisementReceivedEventArgs const& args) {
      if (auto self = weak.lock()) { auto address = args.BluetoothAddress(); self->Post([self, requested, address] { self->Connect(address, requested); }); }
    });
    stopped_token=watcher.Stopped([weak,requested](auto const&,BluetoothLEAdvertisementWatcherStoppedEventArgs const& args) {
      if(auto self=weak.lock()) { auto error=args.Error(); self->Post([self,requested,error] {
        if(self->lease!=requested || !self->running) return;
        self->Stop(); self->State(error==BluetoothError::RadioNotAvailable || error==BluetoothError::DisabledByUser ? "bluetooth_off" : "unavailable");
      }); }
    });
    watcher.Start(); State(local ? "active" : "unsupported_peripheral");
  }
  void Send(const std::string& id, const std::vector<uint8_t>& data) {
    auto found = peers.find(id); if (!running || found == peers.end()) return;
    auto peer = found->second;
    try {
      for (const auto& part : BleFrameCodec::Encode(data, peer->capacity)) {
        if (closing) return;
        if (peer->remote) {
          auto result = peer->remote.WriteValueWithResultAsync(MakeBuffer(part), GattWriteOption::WriteWithResponse).get();
          if (result.Status() != GattCommunicationStatus::Success) throw std::runtime_error("write");
        } else if (local && peer->subscriber) {
          auto result = local.NotifyValueAsync(MakeBuffer(part), peer->subscriber).get();
          if (result.Status() != GattCommunicationStatus::Success) throw std::runtime_error("indicate");
        } else throw std::runtime_error("peer");
      }
      peer->touched = std::chrono::steady_clock::now();
    } catch (...) { Close(id); }
  }
};

BluetoothMeshPlugin::BluetoothMeshPlugin(flutter::BinaryMessenger* messenger, HWND window) {
  auto self = impl_ = std::make_shared<Impl>(window);
  self->worker = std::thread([self] {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
    for (;;) {
      std::function<void()> task;
      {
        std::unique_lock<std::mutex> lock(self->mutex);
        self->cv.wait_for(lock, std::chrono::seconds(30), [&] { return self->closing || !self->work.empty(); });
        if (self->closing) break;
        if (!self->work.empty()) { task = std::move(self->work.front()); self->work.pop_front(); }
      }
      if (task) { try { task(); } catch (...) { self->State("unavailable"); } }
      std::vector<std::string> idle;
      for (const auto& p : self->peers) if (std::chrono::steady_clock::now() - p.second->touched > std::chrono::minutes(3)) idle.push_back(p.first);
      for (const auto& id : idle) self->Close(id);
    }
    self->Stop(); winrt::uninit_apartment();
  });
  self->methods = std::make_unique<flutter::MethodChannel<V>>(messenger, "app.niosmess/bluetooth_mesh", &flutter::StandardMethodCodec::GetInstance());
  self->events = std::make_unique<flutter::EventChannel<V>>(messenger, "app.niosmess/bluetooth_mesh/events", &flutter::StandardMethodCodec::GetInstance());
  std::weak_ptr<Impl> weak = self;
  self->events->SetStreamHandler(std::make_unique<flutter::StreamHandlerFunctions<V>>(
    [weak](const V*, std::unique_ptr<flutter::EventSink<V>>&& sink) -> std::unique_ptr<flutter::StreamHandlerError<V>> {
      if (auto p = weak.lock()) p->sink = std::move(sink); return nullptr;
    }, [weak](const V*) -> std::unique_ptr<flutter::StreamHandlerError<V>> {
      if (auto p = weak.lock()) p->sink.reset(); return nullptr;
    }));
  self->methods->SetMethodCallHandler([weak](const flutter::MethodCall<V>& call, std::unique_ptr<flutter::MethodResult<V>> result) {
    auto p = weak.lock();
    if (!p || !call.arguments() || !std::holds_alternative<M>(*call.arguments())) { result->Error("INVALID", "Invalid arguments"); return; }
    auto args = std::get<M>(*call.arguments()); auto lease = Text(args, "lease");
    if (lease.empty() || lease.size() > 64) { result->Error("INVALID", "Invalid lease"); return; }
    if (call.method_name() == "start") {
      auto reply = std::shared_ptr<flutter::MethodResult<V>>(std::move(result));
      if(!p->Post([p, lease, reply] {
        try { p->Start(lease); } catch (...) { p->State("unavailable"); }
        auto state = p->state; p->UI([reply, state] { reply->Success(V(M{{V("state"), V(state)}})); });
      })) reply->Error("BUSY","Bluetooth is busy");
    } else if (call.method_name() == "stop") {
      p->Post([p, lease] { if (p->lease == lease) p->Stop(); }); result->Success();
    } else if (call.method_name() == "send") {
      auto item = args.find(V("data")); auto peer = Text(args, "peer");
      if (item == args.end() || !std::holds_alternative<std::vector<uint8_t>>(item->second)) { result->Error("INVALID", "Invalid frame"); return; }
      auto data = std::get<std::vector<uint8_t>>(item->second);
      if (data.empty() || data.size() > BleFrameCodec::maximum) { result->Error("INVALID", "Frame size"); return; }
      p->Post([p, lease, peer, data = std::move(data)] { if (p->lease == lease) p->Send(peer, data); });
      result->Success();
    } else result->NotImplemented();
  });
}
void BluetoothMeshPlugin::Dispatch() {
  auto self = impl_; std::deque<std::function<void()>> tasks;
  { std::lock_guard<std::mutex> lock(self->mutex); tasks.swap(self->ui); }
  for (auto& task : tasks) if (!self->closing) task();
}
BluetoothMeshPlugin::~BluetoothMeshPlugin() {
  auto self = impl_; self->methods->SetMethodCallHandler(nullptr); self->events->SetStreamHandler(nullptr); self->sink.reset(); self->methods.reset(); self->events.reset();
  { std::lock_guard<std::mutex> lock(self->mutex); self->closing = true; self->work.clear(); self->ui.clear(); }
  self->cv.notify_one();
  // A pending Windows GATT operation may take seconds. Never block Flutter's UI
  // on teardown; the worker owns no engine objects after this point.
  self->worker.detach();
}
