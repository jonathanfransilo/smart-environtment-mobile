import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static const _key = 'notifications';

  /// Ambil semua notifikasi
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_key) ?? [];
    return data.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  /// Tambah notifikasi baru
  static Future<void> addNotification(String message) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_key) ?? [];
    final list = data.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

    final notif = {
      "id": DateTime.now().millisecondsSinceEpoch.toString(),
      "message": message,
      "time": DateTime.now().toIso8601String(),
      "isRead": false,
    };

    list.insert(0, notif); // tambah di awal biar notif terbaru di atas
    await prefs.setStringList(
      _key,
      list.map((e) => jsonEncode(e)).toList(),
    );
  }

  /// Tandai notifikasi sudah dibaca per-item
  static Future<void> markAsRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_key) ?? [];
    final list = data.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

    for (var n in list) {
      if (n['id'] == id) {
        n['isRead'] = true;
        break;
      }
    }

    await prefs.setStringList(
      _key,
      list.map((e) => jsonEncode(e)).toList(),
    );
  }

  /// Tandai semua sudah dibaca (optional)
  static Future<void> markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_key) ?? [];
    final list = data.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

    for (var n in list) {
      n['isRead'] = true;
    }

    await prefs.setStringList(
      _key,
      list.map((e) => jsonEncode(e)).toList(),
    );
  }

  /// Hapus semua notifikasi (opsional)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
