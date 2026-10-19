import 'dart:typed_data';
import 'package:http/testing.dart';
import 'package:pulse_flutter/services/public_media_upload_service.dart';
export 'package:pulse_flutter/services/public_media_upload_service.dart';

class FakePublicMediaUpload extends PublicMediaUploadService {
  FakePublicMediaUpload() : super(MockClient((_) async {
    throw StateError('Unexpected HTTP call');
  }), () => 'synthetic-token');

  Uint8List? uploaded;
  String? uploadedFilename;
  @override
  Future<String> upload(Uint8List bytes, {required String filename}) async {
    uploaded = bytes;
    uploadedFilename = filename;
    return '0123456789abcdef0123456789abcdef';
  }
}
