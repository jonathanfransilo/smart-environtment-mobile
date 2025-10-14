import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserStorage {
  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserRoles = 'user_roles';

  /// Simpan data user ke SharedPreferences
  static Future<void> saveUser({
    required int id,
    required String name,
    required String email,
    List<String>? roles,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, id);
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserEmail, email);
    
    if (roles != null && roles.isNotEmpty) {
      await prefs.setString(_keyUserRoles, jsonEncode(roles));
    } else {
      await prefs.remove(_keyUserRoles);
    }
  }

  /// Ambil ID user
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserId);
  }

  /// Ambil nama user
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  /// Ambil email user
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  /// Ambil roles user
  static Future<List<String>> getUserRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final rolesJson = prefs.getString(_keyUserRoles);
    
    if (rolesJson == null || rolesJson.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(rolesJson);
      return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Check apakah user memiliki role tertentu
  static Future<bool> hasRole(String roleName) async {
    final roles = await getUserRoles();
    return roles.contains(roleName);
  }

  /// Check apakah user adalah collector
  static Future<bool> isCollector() async {
    try {
      return await hasRole('collector') || await hasRole('kolektor');
    } catch (e) {
      print('❌ [UserStorage] Error checking isCollector: $e');
      return false; // Default to false jika error
    }
  }

  /// Check apakah user adalah warga
  static Future<bool> isWarga() async {
    return await hasRole('warga') || await hasRole('user');
  }

  /// Ambil semua data user
  static Future<Map<String, dynamic>?> getUser() async {
    final id = await getUserId();
    final name = await getUserName();
    final email = await getUserEmail();
    final roles = await getUserRoles();

    if (id == null || name == null || email == null) {
      return null;
    }

    return {
      'id': id,
      'name': name,
      'email': email,
      'roles': roles,
    };
  }

  /// Hapus semua data user
  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserRoles);
  }
}
