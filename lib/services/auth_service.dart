import 'package:dio/dio.dart' show Options, Response; 
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:talking_plants/services/api.dart';

class AuthService {
  /* ───────────────── CONFIG ─────────────────────────── */
  static const _storage = FlutterSecureStorage();
  static const _baseUrl = 'http://57.182.33.61:3000';

  String get baseUrl => _baseUrl;
  Future<String?> getJwt() => _jwt;
  Future<bool> hasJwt() async => (await _jwt) != null;

  Exception _dioError(Response r) =>
      Exception('[${r.statusCode}] ${r.data}');

  /* ── token helpers ─────────────────────────────────── */
  Future<String?> get _jwt async => _storage.read(key: 'jwt');
  Future<void> _saveJwt(String t) => _storage.write(key: 'jwt', value: t);

  Future<void> logout() => _storage.deleteAll(); // JWT + currentDevice

  /* ───────────────── PUBLIC CALLS ───────────────────── */
  Future<bool> emailExists(String email) async {
    final r = await dio.get('/auth/email-exists',
        queryParameters: {'email': email});
    if (r.statusCode != 200) throw _dioError(r);
    return r.data['exists'] as bool;
  }

  Future<void> register(String email, String pw) async {
    final r =
        await dio.post('/register', data: {'email': email, 'password': pw});
    if (r.statusCode != 201) throw _dioError(r);
    await login(email, pw);          // fetch JWT
    await _refreshDeviceId();        // cache device if already linked
  }

  Future<void> login(String email, String pw) async {
    final r =
        await dio.post('/login', data: {'email': email, 'password': pw});
    if (r.statusCode != 200) throw _dioError(r);
    await _saveJwt(r.data['token']);
    await _refreshDeviceId();        // repopulate cache after deleteAll()
  }

  Future<bool> isDeviceSynced() async {
    final token = await _jwt;
    if (token == null) return false;

    final r = await dio.get('/api/user/status',
        options: Options(headers: {'Authorization': 'Bearer $token'}));
    if (r.statusCode != 200) throw _dioError(r);

    return (r.data['devices'] as int) > 0;
  }
  /// Returns `{ step: String, device_id: String? }` describing the user's
  /// onboarding progress. Caches the device_id when present.
  Future<Map<String, dynamic>> onboardingStatus() async {
    final token = await _jwt;
    if (token == null) {
      return {'step': 'claim', 'device_id': null};
    }

    final r = await dio.get(
      '/api/user/onboarding',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode != 200) throw _dioError(r);

    final step = r.data['step'] as String;
    final deviceId = r.data['device_id'] as String?;
    if (deviceId != null) {
      await _storage.write(key: 'currentDevice', value: deviceId);
    }
    return {'step': step, 'device_id': deviceId};
  }

  /* ───────────────── DEVICE CLAIM FLOW ─────────────── */
  Future<void> claimPendingDevice() async {
    final pending = await _storage.read(key: 'pendingDevice');
    if (pending == null) {
      debugPrint('ℹ️  no pendingDevice');
      return;
    }

    final parts = pending.split(',');
    if (parts.length != 2) {
      debugPrint('⚠️  malformed pendingDevice $pending');
      await _storage.delete(key: 'pendingDevice');
      return;
    }

    final deviceId = parts[0];
    final token    = parts[1];

    final r = await dio.post(
      '/devices/claim',
      data: {'device_id': deviceId, 'token': token},
      options: Options(headers: {'Authorization': 'Bearer ${await _jwt}'}),
    );

    if (r.statusCode == 201) {
      await _storage.write(key: 'currentDevice', value: deviceId);
      await _storage.write(key: 'deviceForWiFi', value: '$deviceId,$token');
      debugPrint('✅ claimed $deviceId');
    } else {
      debugPrint('❌ claim failed $deviceId  -> ${r.statusCode}');
      throw _dioError(r);
    }
    await _storage.delete(key: 'pendingDevice');
  }

  /* ───────────────── CURRENT DEVICE ─────────────────── */
  /// Returns cached device_id, or fetches from backend and caches it.
  Future<String?> currentDeviceId() async {
    // ① local cache
    final cached = await _storage.read(key: 'currentDevice');
    if (cached != null) return cached;

    // ② fallback to backend
    return _refreshDeviceId();
  }

  /// Helper: hit /api/devices and cache the first device_id.
  Future<String?> _refreshDeviceId() async {
    final token = await _jwt;
    if (token == null) return null;

    try {
      final r = await dio.get(
        '/api/devices',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (r.statusCode == 200 && (r.data as List).isNotEmpty) {
        final deviceId = r.data[0]['device_id'] as String;
        await _storage.write(key: 'currentDevice', value: deviceId);
        return deviceId;
      }
    } catch (_) {
      // network / auth error → ignore, return null below
    }
    return null;
  }
}
