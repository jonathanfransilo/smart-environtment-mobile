import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _key = 'auth_token';
  static const _storage = FlutterSecureStorage();

  static Future<void> saveToken(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, token);
    } else if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      await _storage.write(key: _key, value: token);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, token);
    }
  }

  static Future<String?> getToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key);
    } else if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return _storage.read(key: _key);
    } else {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key);
    }
  }

  static Future<void> clearToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } else if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      await _storage.delete(key: _key);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    }
  }
}
