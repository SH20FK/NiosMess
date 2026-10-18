import 'dart:async';

import 'package:nios_sdk/stream.dart';
import 'package:universal_io/io.dart';

/// Child process intentionally killed by the publication crash test.
Future<void> main(List<String> arguments) async {
  final server = await CiphertextBlobServer.bind(
    directory: arguments.single,
    bearerToken: 'loopback-test-token-not-a-production-credential',
  );
  stdout.writeln(server.baseUri);
  await Completer<void>().future;
}
