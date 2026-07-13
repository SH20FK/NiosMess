import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('write test', (tester) async {
    final f = File('test_output.txt');
    f.writeAsBytesSync([72, 101, 108, 108, 111]);
    print('WRITE OK');
  });
}
