import 'dart:ffi';

String? currentAndroidAbi() => switch (Abi.current()) {
  Abi.androidArm64 => 'arm64-v8a',
  Abi.androidArm => 'armeabi-v7a',
  Abi.androidX64 => 'x86_64',
  _ => null,
};
