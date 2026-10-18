import 'package:nios_lab/nios_lab.dart';
import 'package:test/test.dart';

void main() {
  test(
    'all five modules interoperate with real native crypto and network IO',
    () async {
      final result = await runNiosProtocolLab();
      expect(result['status'], 'passed');
      expect(result['modules'], 5);
      expect(result['transport'], 'native_iroh_quic');
      expect(result['shard_servers_stopped'], 2);
      expect(result['duplicate_applications'], 0);
      expect(result['device_signed_acknowledgements'], true);
      expect(result['transport_keys_account_authorized'], true);
      expect(result['group_key_forgery_rejected'], true);
      expect(result['lost_ack_recovered_after_restart'], true);
      expect(result['link_ciphertext_restart'], true);
      expect(result['keyless_repair'], true);
      expect(result['removed_member_rejected'], true);
      expect(result.toString(), isNot(contains('fileKey')));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
