import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  SecurityService._();
  static final instance = SecurityService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _pinSaltKey = 'dgzone_pin_salt';
  static const _pinHashKey = 'dgzone_pin_hash';
  static const _pinLengthKey = 'dgzone_pin_length';
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> get hasPin async =>
      (await _storage.read(key: _pinHashKey))?.isNotEmpty == true;

  Future<int?> get pinLength async =>
      int.tryParse(await _storage.read(key: _pinLengthKey) ?? '');

  Future<void> setPin(String pin) async {
    final random = Random.secure();
    final salt = base64UrlEncode(
      List<int>.generate(24, (_) => random.nextInt(256)),
    );
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: _derive(pin, salt));
    await _storage.write(key: _pinLengthKey, value: pin.length.toString());
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _pinSaltKey);
    final expected = await _storage.read(key: _pinHashKey);
    if (salt == null || expected == null) return false;
    final actual = _derive(pin, salt);
    if (actual.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < actual.length; i++) {
      difference |= actual.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    return difference == 0;
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _pinSaltKey);
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinLengthKey);
  }

  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.isDeviceSupported() &&
          (await _localAuth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      if (!await canUseBiometrics()) return false;
      return await _localAuth.authenticate(
        localizedReason: 'DGzone Money ကို ဖွင့်ရန် အတည်ပြုပါ',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  String _derive(String pin, String salt) {
    List<int> bytes = utf8.encode('$salt:$pin');
    final saltBytes = utf8.encode(salt);
    for (var round = 0; round < 12000; round++) {
      bytes = sha256.convert([...bytes, ...saltBytes]).bytes;
    }
    return base64UrlEncode(bytes);
  }
}
