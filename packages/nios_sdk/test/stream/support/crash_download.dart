import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:nios_sdk/stream.dart';
import 'package:universal_io/io.dart';

Future<void> main(List<String> args) async {
  final json =
      jsonDecode(await File(args[0]).readAsString()) as Map<String, dynamic>;
  final manifest = NiosStreamManifest.fromJson(json, expectedHash: args[1]);
  final key = SecretKey(base64Decode(await File(args[2]).readAsString()));
  final download = await NiosStreamDownload.open(
    directory: args[4],
    manifest: manifest,
    key: key,
    sources: [FileCiphertextSource(args[3])],
  );
  await download.fetchSegment(1);
  stdout.writeln('READY');
  await stdout.flush();
  await Completer<void>().future;
}
