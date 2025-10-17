import 'package:shared_preferences/shared_preferences.dart';
import '../screens/user/notification_service.dart';

/// Service khusus untuk notifikasi kolektor
/// Menangani notifikasi otomatis untuk jadwal pickup dan aktivitas baru
class KolektorNotificationService {
  static const String _lastCheckKey = 'kolektor_last_notification_check';
  static const String _processedPickupsKey = 'kolektor_processed_pickups';
  static const String _processedHistoryKey = 'kolektor_processed_history';

  /// Check dan trigger notifikasi otomatis untuk kolektor
  /// Dipanggil saat home screen kolektor dimuat
  static Future<void> checkAndTriggerNotifications({
    List<Map<String, dynamic>>? todayPickups,
    List<Map<String, dynamic>>? recentHistory,
  }) async {
    // Check jadwal pickup hari ini
    if (todayPickups != null && todayPickups.isNotEmpty) {
      await _checkTodayPickupSchedule(todayPickups);
    }

    // Check aktivitas/pengambilan terbaru
    if (recentHistory != null && recentHistory.isNotEmpty) {
      await _checkRecentActivity(recentHistory);
    }

    // Update last check timestamp
    await _updateLastCheck();
  }

  /// Check jadwal pickup hari ini dan buat notifikasi jika ada yang baru
  static Future<void> _checkTodayPickupSchedule(
    List<Map<String, dynamic>> todayPickups,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final processedIds = prefs.getStringList(_processedPickupsKey) ?? [];

    for (var pickup in todayPickups) {
      final pickupId = pickup['id']?.toString() ?? '';
      final status = pickup['status']?.toString() ?? '';

      // Skip jika pickup sudah diproses
      if (processedIds.contains(pickupId)) {
        continue;
      }

      // Buat notifikasi untuk pickup baru (status scheduled atau pending)
      if (status == 'scheduled' || status == 'pending') {
        final houseInfo = pickup['house_info'] as Map<String, dynamic>?;
        final residentName = houseInfo?['resident_name']?.toString() ?? 'User';
        final address = houseInfo?['address']?.toString() ?? '';

        await NotificationService.addNotificationWithType(
          type: 'pickup_schedule',
          title: '📅 Jadwal Pickup Baru',
          message:
              'Anda memiliki jadwal pengambilan sampah dari $residentName di $address. Tap untuk detail.',
          isKolektor: true,
        );

        // Tandai pickup ini sudah diproses
        processedIds.add(pickupId);
      }
    }

    // Simpan list pickup yang sudah diproses
    await prefs.setStringList(_processedPickupsKey, processedIds);
  }

  /// Check aktivitas terbaru dan buat notifikasi
  static Future<void> _checkRecentActivity(
    List<Map<String, dynamic>> recentHistory,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final processedIds = prefs.getStringList(_processedHistoryKey) ?? [];

    // Ambil 3 aktivitas terbaru
    final latestActivities = recentHistory.take(3).toList();

    for (var activity in latestActivities) {
      final activityId = activity['id']?.toString() ?? '';

      // Skip jika aktivitas sudah diproses
      if (processedIds.contains(activityId)) {
        continue;
      }

      final name = activity['name']?.toString() ?? 'User';
      final status = activity['status']?.toString() ?? 'completed';
      final totalPrice = (activity['totalPrice'] as num?)?.toInt() ?? 0;

      // Buat notifikasi untuk aktivitas baru
      if (status == 'completed' || status == 'collected') {
        await NotificationService.addNotificationWithType(
          type: 'pickup_completed',
          title: '✅ Pengambilan Selesai',
          message:
              'Pengambilan sampah dari $name telah selesai. Total: Rp $totalPrice',
          isKolektor: true,
        );
      } else if (status == 'on_progress') {
        await NotificationService.addNotificationWithType(
          type: 'pickup_in_progress',
          title: '🚚 Pickup Sedang Berlangsung',
          message: 'Pengambilan sampah dari $name sedang dalam proses.',
          isKolektor: true,
        );
      }

      // Tandai aktivitas ini sudah diproses
      processedIds.add(activityId);
    }

    // Simpan list aktivitas yang sudah diproses
    await prefs.setStringList(_processedHistoryKey, processedIds);
  }

  /// Update timestamp pemeriksaan terakhir
  static Future<void> _updateLastCheck() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastCheckKey,
      DateTime.now().toIso8601String(),
    );
  }

  /// Dapatkan timestamp pemeriksaan terakhir
  static Future<DateTime?> getLastCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getString(_lastCheckKey);
    if (lastCheck != null) {
      return DateTime.parse(lastCheck);
    }
    return null;
  }

  /// Reset processed pickups (untuk testing atau clear cache)
  static Future<void> resetProcessedPickups() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_processedPickupsKey);
  }

  /// Reset processed history (untuk testing atau clear cache)
  static Future<void> resetProcessedHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_processedHistoryKey);
  }

  /// Reset semua data notifikasi kolektor
  static Future<void> resetAll() async {
    await resetProcessedPickups();
    await resetProcessedHistory();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastCheckKey);
  }

  /// Trigger notifikasi manual untuk pickup tertentu
  static Future<void> notifyPickupAssigned({
    required String residentName,
    required String address,
    required String pickupId,
  }) async {
    await NotificationService.addNotificationWithType(
      type: 'pickup_schedule',
      title: '📅 Tugas Baru Ditambahkan',
      message:
          'Anda mendapat tugas pengambilan sampah dari $residentName di $address.',
      isKolektor: true,
    );
  }

  /// Trigger notifikasi manual untuk pickup reminder
  static Future<void> notifyPickupReminder({
    required String residentName,
    required String address,
  }) async {
    await NotificationService.addNotificationWithType(
      type: 'pickup_reminder',
      title: '🔔 Pengingat Pickup',
      message:
          'Jangan lupa! Anda memiliki jadwal pengambilan sampah dari $residentName di $address hari ini.',
      isKolektor: true,
    );
  }

  /// Trigger notifikasi manual untuk payment received
  static Future<void> notifyPaymentReceived({
    required String residentName,
    required int amount,
  }) async {
    await NotificationService.addNotificationWithType(
      type: 'payment_success',
      title: '💰 Pembayaran Diterima',
      message:
          'Pembayaran dari $residentName sebesar Rp $amount telah diterima.',
      isKolektor: true,
    );
  }

  /// Trigger notifikasi manual untuk pickup cancelled
  static Future<void> notifyPickupCancelled({
    required String residentName,
    required String reason,
  }) async {
    await NotificationService.addNotificationWithType(
      type: 'pickup_cancelled',
      title: '❌ Pickup Dibatalkan',
      message: 'Pickup dari $residentName dibatalkan. Alasan: $reason',
      isKolektor: true,
    );
  }

  /// Trigger notifikasi manual untuk pickup rescheduled
  static Future<void> notifyPickupRescheduled({
    required String residentName,
    required String newDate,
  }) async {
    await NotificationService.addNotificationWithType(
      type: 'pickup_rescheduled',
      title: '📅 Jadwal Diubah',
      message:
          'Jadwal pickup dari $residentName telah diubah ke $newDate.',
      isKolektor: true,
    );
  }

  /// Check apakah perlu mengirim reminder untuk pickup hari ini
  /// Dipanggil pada waktu tertentu (misal pagi hari)
  static Future<void> sendDailyReminders(
    List<Map<String, dynamic>> todayPickups,
  ) async {
    final now = DateTime.now();
    final hour = now.hour;

    // Kirim reminder hanya di pagi hari (8-10 AM)
    if (hour < 8 || hour > 10) {
      return;
    }

    // Hitung pickup yang belum selesai
    final pendingPickups = todayPickups.where((p) {
      final status = p['status']?.toString() ?? '';
      return status == 'scheduled' || status == 'pending';
    }).toList();

    if (pendingPickups.isNotEmpty) {
      await NotificationService.addNotificationWithType(
        type: 'daily_reminder',
        title: '☀️ Selamat Pagi!',
        message:
            'Anda memiliki ${pendingPickups.length} tugas pengambilan sampah hari ini. Selamat bekerja!',
        isKolektor: true,
      );
    }
  }

  /// Dapatkan statistik notifikasi kolektor
  static Future<Map<String, int>> getNotificationStats() async {
    final notifications = await NotificationService.getNotifications(isKolektor: true);

    final stats = {
      'total': notifications.length,
      'unread': notifications.where((n) => n['isRead'] == false).length,
      'pickup_schedule': notifications.where((n) => n['type'] == 'pickup_schedule').length,
      'pickup_completed': notifications.where((n) => n['type'] == 'pickup_completed').length,
      'payment': notifications.where((n) => n['type'] == 'payment_success').length,
    };

    return stats;
  }
}
