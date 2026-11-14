import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/data/progress_encryption.dart';

void main() {
  test('encrypted backup authenticates its contents and password', () async {
    const password = 'Пример длинного пароля';
    final original = Uint8List.fromList(utf8.encode('{"name":"Ученик"}'));
    final encrypted = await ProgressEncryption.encrypt(original, password);
    expect(ProgressEncryption.isEncrypted(encrypted), isTrue);
    expect(ProgressEncryption.isEncrypted(original), isFalse);
    expect(await ProgressEncryption.decrypt(encrypted, password), original);
    await expectLater(
      ProgressEncryption.decrypt(encrypted, 'неверный пароль'),
      throwsFormatException,
    );
    final damaged = Uint8List.fromList(encrypted)..[52] ^= 1;
    await expectLater(
      ProgressEncryption.decrypt(damaged, password),
      throwsFormatException,
    );
  });
}
