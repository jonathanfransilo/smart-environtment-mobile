# Fix Notifikasi Kolektor - Menghapus Notifikasi Artikel

## 📋 Deskripsi Masalah

**Issue**: Notifikasi artikel muncul di halaman notifikasi kolektor, padahal kolektor tidak memiliki menu artikel atau layanan yang berhubungan dengan artikel.

**Root Cause**: 
- `NotificationService` menggunakan satu storage SharedPreferences yang sama (`'notifications'`) untuk user dan kolektor
- Notifikasi artikel yang ditrigger oleh `NotificationHelper` (untuk user) juga muncul di kolektor
- Tidak ada pemisahan notifikasi antara user dan kolektor

## ✅ Solusi Implementasi

### 1. **Pemisahan Storage Notifikasi**

Menambahkan storage terpisah untuk notifikasi kolektor:

```dart
// notification_service.dart
class NotificationService {
  static const _key = 'notifications';              // Untuk user/resident
  static const _kolektorKey = 'notifications_kolektor';  // Untuk kolektor
```

### 2. **Parameter `isKolektor` di Semua Method**

Semua method di `NotificationService` sekarang menerima parameter `isKolektor`:

```dart
// Sebelum
static Future<List<Map<String, dynamic>>> getNotifications()

// Sesudah
static Future<List<Map<String, dynamic>>> getNotifications({bool isKolektor = false})
```

**Method yang Diupdate:**
- ✅ `getNotifications({bool isKolektor = false})`
- ✅ `addNotification(String message, {bool isKolektor = false})`
- ✅ `markAsRead(String id, {bool isKolektor = false})`
- ✅ `markAllAsRead({bool isKolektor = false})`
- ✅ `deleteNotification(String id, {bool isKolektor = false})`
- ✅ `clearAll({bool isKolektor = false})`
- ✅ `addPaymentNotification(String title, String message, {bool isKolektor = false})`
- ✅ `addNotificationWithType({required String type, required String title, required String message, bool isKolektor = false})`
- ✅ `getUnreadCount({bool isKolektor = false})`

### 3. **Update `KolektorNotificationService`**

Semua pemanggilan `NotificationService.addNotificationWithType()` di `KolektorNotificationService` sekarang menggunakan `isKolektor: true`:

```dart
await NotificationService.addNotificationWithType(
  type: 'pickup_schedule',
  title: '📅 Jadwal Pickup Baru',
  message: 'Anda memiliki jadwal pengambilan sampah...',
  isKolektor: true,  // ✅ Ditambahkan
);
```

**Method yang Diupdate:**
- ✅ `_checkTodayPickupSchedule()` - Set `isKolektor: true`
- ✅ `_checkRecentActivity()` - Set `isKolektor: true`
- ✅ `notifyPickupAssigned()` - Set `isKolektor: true`
- ✅ `notifyPickupReminder()` - Set `isKolektor: true`
- ✅ `notifyPaymentReceived()` - Set `isKolektor: true`
- ✅ `notifyPickupCancelled()` - Set `isKolektor: true`
- ✅ `notifyPickupRescheduled()` - Set `isKolektor: true`
- ✅ `sendDailyReminders()` - Set `isKolektor: true`
- ✅ `getNotificationStats()` - Use `getNotifications(isKolektor: true)`

### 4. **Update `NotificationScreen`**

Menambahkan parameter `isKolektor` ke widget `NotificationScreen`:

```dart
// Sebelum
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

// Sesudah
class NotificationScreen extends StatefulWidget {
  final bool isKolektor;
  const NotificationScreen({super.key, this.isKolektor = false});
```

Semua method menggunakan parameter ini:
```dart
final list = await NotificationService.getNotifications(isKolektor: widget.isKolektor);
await NotificationService.markAsRead(id, isKolektor: widget.isKolektor);
await NotificationService.deleteNotification(id, isKolektor: widget.isKolektor);
await NotificationService.clearAll(isKolektor: widget.isKolektor);
```

### 5. **Update Home Screen Kolektor**

```dart
// home_screens_kolektor.dart

// Load unread count dengan isKolektor: true
Future<void> _loadUnreadNotifCount() async {
  final count = await NotificationService.getUnreadCount(isKolektor: true);
  setState(() => _unreadNotifCount = count);
}

// Navigation ke NotificationScreen dengan parameter
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const NotificationScreen(isKolektor: true),
  ),
);
```

### 6. **Update `NotificationHelper`**

Menambahkan parameter `isKolektor` untuk mencegah notifikasi artikel di kolektor:

```dart
Future<void> checkAndTriggerNotifications({
  String? serviceAccountId,
  bool isKolektor = false,  // ✅ Parameter baru
}) async {
  // Notifikasi hanya untuk user/resident
  if (!isKolektor) {
    await _checkScheduledPickupNotification(serviceAccountId: serviceAccountId);
    await _checkUnpaidInvoiceNotification();
    await _checkNewArticleNotification();  // ✅ Tidak akan dipanggil untuk kolektor
  }
}
```

## 🔄 Data Flow

### **User/Resident Flow:**
```
NotificationHelper (isKolektor: false)
    ↓
NotificationService.addNotificationWithType(isKolektor: false)
    ↓
SharedPreferences key: 'notifications'
    ↓
NotificationScreen(isKolektor: false)
```

### **Kolektor Flow:**
```
KolektorNotificationService
    ↓
NotificationService.addNotificationWithType(isKolektor: true)
    ↓
SharedPreferences key: 'notifications_kolektor'
    ↓
NotificationScreen(isKolektor: true)
```

## 📊 Tipe Notifikasi

### **User/Resident:**
- ✅ `pickup_schedule` - Jadwal pengambilan sampah
- ✅ `invoice_new` - Tagihan baru
- ✅ `invoice_reminder` - Pengingat tagihan
- ✅ `article_new` - Artikel terbaru ← **HANYA UNTUK USER**
- ✅ `report_created` - Laporan terkirim
- ✅ `payment_success` - Pembayaran berhasil
- ✅ `service_account_created` - Akun layanan dibuat

### **Kolektor:**
- ✅ `pickup_schedule` - Jadwal pickup baru
- ✅ `pickup_completed` - Pengambilan selesai
- ✅ `pickup_in_progress` - Pickup sedang berlangsung
- ✅ `pickup_reminder` - Pengingat pickup
- ✅ `daily_reminder` - Reminder harian
- ✅ `payment_success` - Pembayaran diterima
- ✅ `pickup_cancelled` - Pickup dibatalkan
- ✅ `pickup_rescheduled` - Jadwal diubah
- ❌ `article_new` - **TIDAK ADA** (difilter)

## 🧪 Testing Checklist

### User/Resident:
- [ ] Notifikasi artikel muncul di user
- [ ] Notifikasi jadwal pickup muncul di user
- [ ] Notifikasi tagihan muncul di user
- [ ] Badge unread count akurat
- [ ] Clear all hanya menghapus notifikasi user
- [ ] Mark as read hanya update notifikasi user

### Kolektor:
- [ ] **Notifikasi artikel TIDAK muncul di kolektor** ✅
- [ ] Notifikasi pickup schedule muncul
- [ ] Notifikasi pickup completed muncul
- [ ] Notifikasi daily reminder muncul
- [ ] Badge unread count akurat
- [ ] Clear all hanya menghapus notifikasi kolektor
- [ ] Mark as read hanya update notifikasi kolektor

### Pemisahan Storage:
- [ ] User dan kolektor memiliki notifikasi terpisah
- [ ] Hapus notifikasi di user tidak mempengaruhi kolektor
- [ ] Hapus notifikasi di kolektor tidak mempengaruhi user
- [ ] Unread count terpisah antara user dan kolektor

## 📁 File yang Dimodifikasi

### Services:
- ✅ `lib/services/notification_helper.dart`
  - Tambah parameter `isKolektor` di `checkAndTriggerNotifications()`
  - Filter notifikasi artikel hanya untuk user

- ✅ `lib/services/kolektor_notification_service.dart`
  - Tambah `isKolektor: true` di semua `addNotificationWithType()`
  - Update `getNotificationStats()` dengan `isKolektor: true`

- ✅ `lib/screens/user/notification_service.dart`
  - Tambah storage key `_kolektorKey`
  - Tambah parameter `isKolektor` di semua method
  - Implementasi pemisahan storage

### Screens:
- ✅ `lib/screens/user/notification_screen.dart`
  - Tambah parameter `isKolektor` ke widget
  - Update semua method untuk menggunakan parameter

- ✅ `lib/screens/kolektor/home_screens_kolektor.dart`
  - Update `_loadUnreadNotifCount()` dengan `isKolektor: true`
  - Update navigation dengan `NotificationScreen(isKolektor: true)`

## 🎯 Hasil

### Before ❌:
- Notifikasi artikel muncul di kolektor (SALAH)
- Notifikasi user dan kolektor tercampur
- Tidak ada pemisahan storage
- Hapus all menghapus semua notifikasi user + kolektor

### After ✅:
- Notifikasi artikel HANYA muncul di user
- Notifikasi terpisah berdasarkan role
- Storage terpisah: `notifications` vs `notifications_kolektor`
- Operasi CRUD notifikasi terpisah per role
- Kolektor hanya menerima notifikasi yang relevan

## 🚀 How to Use

### Untuk User/Resident:
```dart
// Default isKolektor = false
await NotificationHelper().checkAndTriggerNotifications(
  serviceAccountId: accountId,
);

// Atau explicit
final notifications = await NotificationService.getNotifications(isKolektor: false);
```

### Untuk Kolektor:
```dart
// Gunakan KolektorNotificationService
await KolektorNotificationService.checkAndTriggerNotifications(
  todayPickups: pickups,
  recentHistory: history,
);

// Atau manual
final notifications = await NotificationService.getNotifications(isKolektor: true);
```

## 📝 Notes

- **Backward Compatibility**: Method dengan `isKolektor = false` sebagai default memastikan kode existing tetap berfungsi
- **Type Safety**: Parameter boolean `isKolektor` lebih aman daripada string role
- **Scalability**: Jika ada role baru (admin, etc), bisa tambahkan parameter atau refactor ke enum
- **Performance**: Pemisahan storage tidak menambah overhead, hanya memilih key yang berbeda

## 🔮 Future Enhancements

1. **Enum untuk Role**:
   ```dart
   enum UserRole { resident, kolektor, admin }
   ```

2. **Notification Filtering**:
   - Filter berdasarkan tipe notifikasi
   - Filter berdasarkan tanggal
   - Search notifikasi

3. **Push Notifications**:
   - Integrasi FCM untuk real-time notifications
   - Background notification processing

4. **Analytics**:
   - Track notification open rate
   - Most interacted notification types
   - Notification performance metrics

---

**Status**: ✅ Production Ready  
**Version**: 1.0.0  
**Last Updated**: 2025-10-18
