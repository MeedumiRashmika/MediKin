import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinService {
  PinService._();
  static final instance = PinService._();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String _key(String uid) => 'medifamily_pin_$uid';
  String _lockKey(String uid) => 'medifamily_pin_lock_$uid';
  String _triesKey(String uid) => 'medifamily_pin_tries_$uid';

  Future<bool> hasPin(String uid) async =>
      (await _storage.read(key: _key(uid))) != null;

  Future<void> setPin(String uid, String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError('PIN must contain exactly four digits.');
    }
    final random = Random.secure();
    final salt = List<int>.generate(24, (_) => random.nextInt(256));
    final saltString = base64Encode(salt);
    final digest = sha256.convert(utf8.encode('$saltString:$uid:$pin')).toString();
    await _storage.write(key: _key(uid), value: '$saltString:$digest');
    await _storage.delete(key: _triesKey(uid));
    await _storage.delete(key: _lockKey(uid));
  }

  Future<Duration?> remainingLock(String uid) async {
    final value = await _storage.read(key: _lockKey(uid));
    final until = int.tryParse(value ?? '');
    if (until == null) return null;
    final left = DateTime.fromMillisecondsSinceEpoch(until)
        .difference(DateTime.now());
    if (left <= Duration.zero) {
      await _storage.delete(key: _lockKey(uid));
      return null;
    }
    return left;
  }

  Future<bool> verifyPin(String uid, String pin) async {
    if (await remainingLock(uid) != null) return false;
    final stored = await _storage.read(key: _key(uid));
    if (stored == null || !RegExp(r'^\d{4}$').hasMatch(pin)) return false;
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    final hash = sha256.convert(utf8.encode('${parts[0]}:$uid:$pin')).toString();
    if (hash == parts[1]) {
      await _storage.delete(key: _triesKey(uid));
      return true;
    }
    final tries = (int.tryParse(await _storage.read(key: _triesKey(uid)) ?? '') ?? 0) + 1;
    if (tries >= 5) {
      await _storage.write(key: _lockKey(uid),
          value: DateTime.now().add(const Duration(minutes: 5))
              .millisecondsSinceEpoch.toString());
      await _storage.delete(key: _triesKey(uid));
    } else {
      await _storage.write(key: _triesKey(uid), value: tries.toString());
    }
    return false;
  }

  Future<void> clearForUser(String uid) async {
    await _storage.delete(key: _key(uid));
    await _storage.delete(key: _triesKey(uid));
    await _storage.delete(key: _lockKey(uid));
  }
}
