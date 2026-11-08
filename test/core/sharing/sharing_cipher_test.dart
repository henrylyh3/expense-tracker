import 'package:expense_tracker/core/sharing/sharing_cipher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'authenticated encryption rejects changed content, key and direction',
    () async {
      final cipher = SharingCipher();
      final key = await cipher.newKey();
      final packet = await cipher.seal(
        {'amount': '12.50'},
        key,
        'request:trip',
      );
      expect(
        (await cipher.open(
          Map<String, dynamic>.from(packet),
          key,
          'request:trip',
        ))['amount'],
        '12.50',
      );
      await expectLater(
        cipher.open(
          Map<String, dynamic>.from(packet),
          await cipher.newKey(),
          'request:trip',
        ),
        throwsException,
      );
      await expectLater(
        cipher.open(Map<String, dynamic>.from(packet), key, 'response:trip'),
        throwsException,
      );
    },
  );
}
