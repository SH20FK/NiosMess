import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/services/system/device_hardware_service.dart';

final deviceHardwareProvider = FutureProvider<DeviceHardwareInfo>((ref) async {
  return DeviceHardwareService.getHardwareInfo();
});
