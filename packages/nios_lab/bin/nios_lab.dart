import 'dart:convert';
import 'package:nios_lab/nios_lab.dart';
import 'package:universal_io/io.dart';

Future<void> main() async {
  try {
    final result = await runNiosProtocolLab();
    stdout.writeln(jsonEncode(result));
  } catch (_) {
    // CLI diagnostics intentionally contain no exception strings, keys, tokens
    // or message bodies. Tests retain structured failure context separately.
    stderr.writeln(
      jsonEncode({'status': 'failed', 'code': 'lab_verification_failed'}),
    );
    exitCode = 1;
  }
  // Native FRB receive ports may keep the CLI isolate alive after all endpoint
  // and database handles have closed. Only this process-owned entry point exits;
  // the reusable library never shuts down a host application's runtime.
  await stdout.flush();
  await stderr.flush();
  exit(exitCode);
}
