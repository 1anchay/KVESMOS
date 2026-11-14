import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'progress_transfer.dart';

/// Versioned binary file: signature, version, 16-byte salt, 12-byte nonce,
/// 16-byte authentication tag, then ciphertext. Parameters are fixed by version.
abstract final class ProgressEncryption {
  static const _signature = [0x4b, 0x56, 0x45, 0x53, 0x42, 0x4b, 0x50];
  static const _version = 1;
  static const _headerSize = 52;

  static bool isEncrypted(Uint8List bytes) =>
      bytes.length >= _signature.length &&
      Iterable<int>.generate(
        _signature.length,
      ).every((index) => bytes[index] == _signature[index]);

  static Future<SecretKey> _key(String password, List<int> salt) =>
      Pbkdf2.hmacSha256(
        iterations: 600000,
        bits: 256,
      ).deriveKeyFromPassword(password: password, nonce: salt);

  static Future<Uint8List> encrypt(Uint8List bytes, String password) async {
    if (bytes.length > progressTransferMaxBytes) {
      throw const FormatException('Файл превышает 32 МБ.');
    }
    return Isolate.run(() async {
      final random = Random.secure();
      final salt = List.generate(16, (_) => random.nextInt(256));
      final cipher = AesGcm.with256bits();
      final nonce = cipher.newNonce();
      final prefix = [..._signature, _version, ...salt, ...nonce];
      final key = await _key(password, salt);
      try {
        final box = await cipher.encrypt(
          bytes,
          secretKey: key,
          nonce: nonce,
          aad: prefix,
        );
        return (BytesBuilder(copy: false)
              ..add(prefix)
              ..add(box.mac.bytes)
              ..add(box.cipherText))
            .takeBytes();
      } finally {
        key.destroy();
      }
    });
  }

  static Future<Uint8List> decrypt(Uint8List bytes, String password) async {
    if (!isEncrypted(bytes) ||
        bytes.length <= _headerSize ||
        bytes.length > progressTransferMaxBytes + _headerSize ||
        bytes[_signature.length] != _version) {
      throw const FormatException('Формат защищённой копии не поддерживается.');
    }
    return Isolate.run(() async {
      final key = await _key(password, Uint8List.sublistView(bytes, 8, 24));
      try {
        final restored = await AesGcm.with256bits().decrypt(
          SecretBox(
            Uint8List.sublistView(bytes, _headerSize),
            nonce: Uint8List.sublistView(bytes, 24, 36),
            mac: Mac(Uint8List.sublistView(bytes, 36, _headerSize)),
          ),
          secretKey: key,
          aad: Uint8List.sublistView(bytes, 0, 36),
        );
        return restored is Uint8List ? restored : Uint8List.fromList(restored);
      } on SecretBoxAuthenticationError {
        throw const FormatException('Пароль неверен или файл повреждён.');
      } finally {
        key.destroy();
      }
    });
  }
}
