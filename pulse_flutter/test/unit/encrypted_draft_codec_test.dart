import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_codec.dart';

void main() {
  test('drafts authenticate account, chat and key epoch', () async {
    final own = OrdinaryKeys.create(1);
    final packet = await OrdinaryCodec.sealDraft(own, 10, 'личный черновик');
    expect(packet, isNot(contains('личный')));
    expect(await OrdinaryCodec.openDraft(own, 10, packet), 'личный черновик');
    await expectLater(
      OrdinaryCodec.openDraft(own, 11, packet),
      throwsA(anything),
    );
    await expectLater(
      OrdinaryCodec.openDraft(OrdinaryKeys.create(1), 10, packet),
      throwsA(anything),
    );
    await expectLater(
      OrdinaryCodec.openDraft(
        OrdinaryKeys(2, own.epoch, own.dhSeed, own.edSeed),
        10,
        packet,
      ),
      throwsA(anything),
    );
  });
}
