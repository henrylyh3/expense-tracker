import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class SharingCipher {
  final _cipher = AesGcm.with256bits();

  Future<String> newKey() async =>
      base64UrlEncode(await (await _cipher.newSecretKey()).extractBytes());

  Future<Map<String, Object?>> seal(
    Map<String, Object?> data,
    String key,
    String context,
  ) async {
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(data)),
      secretKey: SecretKey(base64Url.decode(key)),
      nonce: _cipher.newNonce(),
      aad: utf8.encode(context),
    );
    return {
      'nonce': base64UrlEncode(box.nonce),
      'data': base64UrlEncode(box.cipherText),
      'mac': base64UrlEncode(box.mac.bytes),
    };
  }

  Future<Map<String, dynamic>> open(
    Map<String, dynamic> packet,
    String key,
    String context,
  ) async {
    final bytes = await _cipher.decrypt(
      SecretBox(
        base64Url.decode(packet['data'] as String),
        nonce: base64Url.decode(packet['nonce'] as String),
        mac: Mac(base64Url.decode(packet['mac'] as String)),
      ),
      secretKey: SecretKey(base64Url.decode(key)),
      aad: utf8.encode(context),
    );
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }
}
