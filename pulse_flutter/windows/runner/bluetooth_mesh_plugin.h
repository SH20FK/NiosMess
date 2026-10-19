#pragma once
#include <windows.h>
#include <flutter/binary_messenger.h>
#include <memory>

class BluetoothMeshPlugin {
 public:
  static constexpr UINT message = WM_APP + 0x467;
  BluetoothMeshPlugin(flutter::BinaryMessenger* messenger, HWND window);
  ~BluetoothMeshPlugin();
  void Dispatch();
 private:
  struct Impl;
  std::shared_ptr<Impl> impl_;
};
