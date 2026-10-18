import 'package:nios_lab/nios_lab.dart';
import 'package:test/test.dart';

void main() {
  test(
    'all four modules interoperate with real native crypto and network IO',
    () async {
      final result = await runNiosProtocolLab();
      expect(result['status'], 'passed');
      expect(result['modules'], 4);
      expect(result['transport'], 'native_iroh_quic');
      expect(result['duplicate_applications'], 0);
      expect(result['device_signed_acknowledgements'], true);
      expect(result['transport_keys_account_authorized'], true);
      expect(result['group_key_forgery_rejected'], true);
      expect(result['lost_ack_recovered_after_restart'], true);
      expect(result['link_ciphertext_restart'], true);
      expect(result['plaintext_verified'], true);
      expect(result['cache_reused_after_restart'], true);
      expect(result['removed_member_rejected'], true);
      expect(result.toString(), isNot(contains('fileKey')));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
