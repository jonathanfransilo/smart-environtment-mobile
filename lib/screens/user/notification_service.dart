import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static const _key = 'notifications';
  static const _kolektorKey = 'notifications_kolektor';

  /// Ambil semua notifikasi
  /// [isKolektor] - true jika untuk kolektor, false untuk user/resident
  static Future<List<Map<String, dynamic>>> getNotifications({bool isKolektor = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = isKolektor ? _kolektorKey : _key;
    final data = prefs.getStringList(storageKey) ?? [];
    return data.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  /// Tambah notifikasi baru
  /// [isKolektor] - true jika untuk kolektor, false untuk user/resident
  static Future<void> addNotification(String message, {bool isKolektor = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = isKolektor ? _kolektorKey : _key;
    final data = prefs.getStringList(storageKey) ?? [];
    final list = data.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

    final notif = {
      "id": DateTime.now().millisecondsSinceEpoch.toString(),
      "message": message,
      "time": DateTime.now().toIso8601String(),
      "isRead": false,
    };

    list.insert(0, notif); // tambah di awal biar notif terbaru di atas
    await prefs.setStringList(
      storageKey,
      list.map((e) => jsonEncode(e)).toList(),
    );
  }

  /// Tandai notifikasi sudah dibaca per-item
  /// [isKolektor] - true jika untuk kolektor, false untuk user/resident
  static Future<void> markAsRead(String id, {bool isKolektor = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = isKolektor ? _kolektorKey : _key;
    final data = prefs.getStringList(storageKey) ?? [];
    final list = data.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

    for (var n in list) {
      if (n['id'] == id) {
        n['isRead'] = true;
        break;
      }
    }

    await prefs.setStringList(
      storageKey,
      list.map((e) => jsonEncode(e)).toList(),
    );
  }

  /// Tandai semua sudah dibaca (optional)
  /// [isKolektor] - true jika untuk kolektor, false untuk user/resident
  static Future<void> markAllAsRead({bool isKolektor = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = isKolektor ? _kolektorKey : _key;
    final data = prefs.getStringList(storageKey) ?? [];
    final list = data.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

    for (var n in list) {
      n['isRead'] = true;
    }

    await prefs.setStringList(
      storageKey,
      list.map((e) => jsonEncode(e)).toList(),
    );
  }

  /// Hapus satu notifikasi berdasarkan ID
  /// [isKolektor] - true jika untuk kolektor, false untuk user/resident
  static Future<void> deleteNotification(String id, {bool isKolektor = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = isKolektor ? _kolektorKey : _key;
    final data = prefs.getStringList(storageKey) ?? [];
    final list = data.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

    // Hapus notifikasi dengan ID yang sesuai
    list.removeWhere((n) => n['id'] == id);

    await prefs.setStringList(
      storageKey,
      list.map((e) => jsonEncode(e)).toList(),
    );
  }

  /// Hapus semua notifikasi (opsional)
  /// [isKolektor] - true jika untuk kolektor, false untuk user/resident
  static Future<void> clearAll({bool isKolektor = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = isKolektor ? _kolektorKey : _key;
    await prefs.remove(storageKey);
  }

  /// Tambah notifikasi khusus pembayaran
  /// [isKolektor] - true jika untuk kolektor, false untuk user/resident
  static Future<void> addPaymentNotification(String title, String message, {bool isKolektor = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = isKolektor ? _kolektorKey : _key;
    final data = prefs.getStringList(storageKey) ?? [];
    final list = data.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

    final notif = {
      "id": DateTime.now().millisecondsSinceEpoch.toString(),
      "title": title,
      "message": message,
      "time": DateTime.now().toIso8601String(),
      "isRead": false,
      "type": "payment",
    };

    list.insert(0, notif); // tambah di awal biar notif terbaru di atas
    await prefs.setStringList(
      storageKey,
      list.map((e) => jsonEncode(e)).toList(),
    );
  }

  /// Tambah notifikasi dengan tipe tertentu
  /// Types: pickup_schedule, invoice_new, invoice_reminder, article_new, 
  ///        report_created, payment_success, service_account_created
  /// [isKolektor] - true jika untuk kolektor, false untuk user/resident
  static Future<void> addNotificationWithType({
    required String type,
    required String title,
    required String message,
    bool isKolektor = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = isKolektor ? _kolektorKey : _key;
    final data = prefs.getStringList(storageKey) ?? [];
    final list = data.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

    final notif = {
      "id": DateTime.now().millisecondsSinceEpoch.toString(),
      "title": title,
      "message": message,
      "time": DateTime.now().toIso8601String(),
      "isRead": false,
      "type": type,
    };

    list.insert(0, notif); // tambah di awal biar notif terbaru di atas
    await prefs.setStringList(
      storageKey,
      list.map((e) => jsonEncode(e)).toList(),
    );
  }

  /// Dapatkan jumlah notifikasi yang belum dibaca
  /// [isKolektor] - true jika untuk kolektor, false untuk user/resident
  static Future<int> getUnreadCount({bool isKolektor = false}) async {
    final notifications = await getNotifications(isKolektor: isKolektor);
    return notifications.where((n) => n['isRead'] == false).length;
  }
}
