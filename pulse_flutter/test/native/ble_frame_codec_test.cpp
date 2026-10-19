#include "../../windows/runner/ble_frame_codec.h"
#include <cassert>
#include <iostream>

int main() {
  for (size_t size : {size_t(1),size_t(19),size_t(1000),BleFrameCodec::maximum}) {
    std::vector<uint8_t> value(size);
    for(size_t i=0;i<size;++i) value[i]=uint8_t(i*31);
    for(size_t mtu : {size_t(20),size_t(244),size_t(512)}) {
      BleFrameCodec decoder;std::vector<uint8_t> result;
      for(const auto& part:BleFrameCodec::Encode(value,mtu)) {
        auto frame=decoder.Accept(part);if(!frame.empty()) result=std::move(frame);
      }
      assert(result==value);
    }
  }
  // Fixed Android-compatible wire: start(3), sequence(0), end.
  BleFrameCodec decoder;
  decoder.Accept({1,0,3});decoder.Accept({2,0,0,65,66,67});assert((decoder.Accept({3})==std::vector<uint8_t>{65,66,67}));
  for(auto bad:std::vector<std::vector<uint8_t>>{{},{3},{1,255,255},{2,0,1,65}}) {
    bool rejected=false;try { BleFrameCodec fresh;fresh.Accept(bad); } catch(...) { rejected=true; }
    assert(rejected);
  }
  bool rejected=false;try { decoder.Accept({1,0,3});decoder.Accept({2,0,1,65}); } catch(...) { rejected=true; }
  assert(rejected);std::cout<<"PASS bounded GATT framing, fixed Android vector, malformed/reordered input\n";
}
