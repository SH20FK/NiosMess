#pragma once
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <stdexcept>
#include <vector>

// Same bounded GATT framing as Android's BleFrameCodec.
class BleFrameCodec {
 public:
  static constexpr size_t maximum = 25600;
  std::vector<uint8_t> Accept(const std::vector<uint8_t>& data) {
    using namespace std::chrono;
    const auto now = steady_clock::now();
    if (open_ && now - started_ > seconds(60)) Reset();
    if (data.empty() || data.size() > 512) throw std::runtime_error("frame");
    if (data[0] == 1) {
      if (data.size() != 3) throw std::runtime_error("start");
      expected_ = (size_t(data[1]) << 8) | data[2];
      if (!expected_ || expected_ > maximum) throw std::runtime_error("size");
      buffer_.clear(); buffer_.reserve(expected_); index_ = 0; started_ = now; open_ = true;
    } else if (data[0] == 2) {
      if (!open_ || data.size() < 4 || ((size_t(data[1]) << 8) | data[2]) != index_ ||
          buffer_.size() + data.size() - 3 > expected_) throw std::runtime_error("sequence");
      ++index_; buffer_.insert(buffer_.end(), data.begin() + 3, data.end());
    } else if (data[0] == 3) {
      if (!open_ || data.size() != 1 || buffer_.size() != expected_) throw std::runtime_error("end");
      auto result = std::move(buffer_); Reset(); return result;
    } else throw std::runtime_error("type");
    return {};
  }
  void Reset() { buffer_.clear(); open_ = false; expected_ = index_ = 0; }
  static std::vector<std::vector<uint8_t>> Encode(const std::vector<uint8_t>& value, size_t capacity) {
    if (value.empty() || value.size() > maximum || capacity < 20 || capacity > 512) throw std::runtime_error("size");
    std::vector<std::vector<uint8_t>> chunks{{1, uint8_t(value.size() >> 8), uint8_t(value.size())}};
    size_t index = 0;
    for (size_t offset = 0; offset < value.size();) {
      size_t count = std::min(capacity - 3, value.size() - offset);
      std::vector<uint8_t> part{2, uint8_t(index >> 8), uint8_t(index)};
      part.insert(part.end(), value.begin() + offset, value.begin() + offset + count);
      chunks.push_back(std::move(part)); offset += count; ++index;
    }
    chunks.push_back({3}); return chunks;
  }
 private:
  std::vector<uint8_t> buffer_;
  size_t expected_ = 0, index_ = 0;
  bool open_ = false;
  std::chrono::steady_clock::time_point started_;
};
