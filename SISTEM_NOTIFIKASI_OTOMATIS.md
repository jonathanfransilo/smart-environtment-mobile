# Dokumentasi Sistem Notifikasi Otomatis

## Overview
Sistem notifikasi otomatis telah ditambahkan untuk memberikan informasi real-time kepada pengguna tentang berbagai event penting dalam aplikasi Smart Environment Mobile.

## Fitur Notifikasi Otomatis

### 1. **Notifikasi Jadwal Pengambilan Sampah** 🚛
- **Trigger**: Otomatis setiap hari saat aplikasi dibuka
- **Kondisi**: Ada jadwal pengambilan sampah pada hari tersebut
- **Informasi**: 
  - Hari pengambilan
  - Jam pengambilan (jika tersedia)
  - Pengingat untuk menyiapkan sampah
- **Tipe**: `pickup_schedule`
- **Icon**: 🚛 (Truck icon)
- **Warna**: Hijau (#4CAF50)

### 2. **Notifikasi Tagihan Baru** 💰
- **Trigger**: Saat ada tagihan baru yang terbit
- **Kondisi**: Tagihan belum pernah dinotifikasi sebelumnya
- **Informasi**:
  - Periode tagihan
  - Jumlah tagihan
  - Tanggal jatuh tempo
  - Peringatan jika mendekati jatuh tempo (7 hari)
- **Tipe**: `invoice_new`
- **Icon**: 💰 (Receipt icon)
- **Warna**: Orange (#F57C00)

### 3. **Notifikasi Pengingat Tagihan** ⏰
- **Trigger**: 3 hari sebelum jatuh tempo
- **Kondisi**: Tagihan masih belum dibayar
- **Informasi**:
  - Periode tagihan
  - Jumlah tagihan
  - Sisa hari sebelum jatuh tempo
- **Tipe**: `invoice_reminder`
- **Icon**: ⏰ (Receipt icon)
- **Warna**: Orange (#F57C00)

### 4. **Notifikasi Pembayaran Berhasil** ✅
- **Trigger**: Setelah pembayaran berhasil diproses
- **Kondisi**: Pembayaran sukses melalui `payment_detail_screen`
- **Informasi**:
  - Periode yang dibayar
  - Jumlah yang dibayar
  - Konfirmasi pembayaran
- **Tipe**: `payment_success`
- **Icon**: ✅ (Check circle icon)
- **Warna**: Biru (#2196F3)

### 5. **Notifikasi Artikel Terbaru** 📰
- **Trigger**: Saat ada artikel baru ditambahkan
- **Kondisi**: Jumlah artikel bertambah
- **Informasi**:
  - Jumlah artikel baru
  - Ajakan untuk membaca
- **Tipe**: `article_new`
- **Icon**: 📰 (Article icon)
- **Warna**: Ungu (#9C27B0)

### 6. **Notifikasi Pelaporan Terkirim** 📝
- **Trigger**: Setelah laporan berhasil dibuat
- **Kondisi**: User menyelesaikan form pelaporan
- **Informasi**:
  - Kategori pelanggaran
  - Lokasi pelaporan
  - Konfirmasi pengiriman
- **Tipe**: `report_created`
- **Icon**: 📝 (Report icon)
- **Warna**: Pink (#E91E63)

### 7. **Notifikasi Akun Layanan Dibuat** 🎉
- **Trigger**: Setelah akun layanan berhasil dibuat
- **Kondisi**: User menyelesaikan form tambah akun layanan
- **Informasi**:
  - Nama akun layanan
  - Konfirmasi pembuatan
- **Tipe**: `service_account_created`
- **Icon**: 🎉 (Account circle icon)
- **Warna**: Teal (#159189)

## Struktur Kode

### 1. NotificationHelper (`lib/services/notification_helper.dart`)
Helper class yang mengelola semua logika notifikasi otomatis.

**Metode Utama:**
```dart
// Check semua notifikasi otomatis
Future<void> checkAndTriggerNotifications({String? serviceAccountId})

// Notifikasi manual untuk event tertentu
Future<void> notifyPaymentSuccess({required String period, required num amount})
Future<void> notifyReportCreated({required String category, required String location})
Future<void> notifyServiceAccountCreated({required String accountName})
```

**Private Methods:**
- `_checkScheduledPickupNotification()` - Cek jadwal pickup hari ini
- `_checkUnpaidInvoiceNotification()` - Cek tagihan baru/belum dibayar
- `_checkNewArticleNotification()` - Cek artikel baru

### 2. NotificationService (`lib/screens/user/notification_service.dart`)
Service untuk menyimpan dan mengelola notifikasi di local storage (SharedPreferences).

**Metode Baru:**
```dart
// Tambah notifikasi dengan tipe tertentu
static Future<void> addNotificationWithType({
  required String type,
  required String title,
  required String message,
})

// Hapus satu notifikasi berdasarkan ID
static Future<void> deleteNotification(String id)

// Hapus semua notifikasi
static Future<void> clearAll()

// Tandai satu notifikasi sebagai sudah dibaca
static Future<void> markAsRead(String id)

// Tandai semua notifikasi sebagai sudah dibaca
static Future<void> markAllAsRead()

// Get semua notifikasi
static Future<List<Map<String, dynamic>>> getNotifications()

// Get jumlah notifikasi belum dibaca
static Future<int> getUnreadCount()
```

### 3. NotificationScreen (`lib/screens/user/notification_screen.dart`)
UI untuk menampilkan daftar notifikasi dengan icon berbeda berdasarkan tipe.

**Fitur:**
- Icon dinamis berdasarkan tipe notifikasi
- Warna berbeda untuk setiap tipe
- Format waktu relatif (X hari/jam/menit yang lalu)
- Badge untuk notifikasi belum dibaca
- Empty state dengan ilustrasi custom
- **Preview detail notifikasi** dengan modal bottom sheet
- **Tombol hapus per notifikasi** dengan konfirmasi
- **Menu hapus semua** dan tandai semua dibaca di AppBar

**UI Components:**
1. **List Item**:
   - Icon dengan background warna sesuai tipe
   - Title dan message dengan truncate
   - Waktu relatif
   - Badge dot untuk unread
   - Tombol delete di trailing
   - Tap untuk buka detail

2. **Detail Modal** (Bottom Sheet):
   - Icon besar dengan background
   - Title dan full message
   - Timestamp
   - Tombol "Hapus" dan "Tutup"
   - Draggable dengan handle bar

3. **AppBar Menu**:
   - "Tandai semua dibaca" - Mark all as read
   - "Hapus semua" - Clear all notifications (dengan konfirmasi)

## Integrasi

### Home Screen
```dart
// Di initState atau saat app dibuka
Future<void> _checkAutomaticNotifications() async {
  final helper = NotificationHelper();
  await helper.checkAndTriggerNotifications(
    serviceAccountId: _selectedAkun?['id']?.toString(),
  );
  await _loadUnreadNotif();
}
```

### Payment Screen
```dart
// Setelah pembayaran berhasil
final helper = NotificationHelper();
await helper.notifyPaymentSuccess(
  period: invoice['period'] ?? '',
  amount: invoice['amount'] ?? 0,
);
```

### Pelaporan Screen
```dart
// Setelah laporan dibuat
final helper = NotificationHelper();
await helper.notifyReportCreated(
  category: reportData['kategori']!,
  location: reportData['lokasi']!,
);
```

### Tambah Akun Layanan Screen
```dart
// Setelah akun dibuat
final helper = NotificationHelper();
await helper.notifyServiceAccountCreated(
  accountName: account.name,
);
```

## Local Storage Keys

NotificationHelper menggunakan SharedPreferences untuk menyimpan state:

| Key | Deskripsi | Format |
|-----|-----------|--------|
| `last_notification_check_date` | Tanggal terakhir check jadwal pickup | `YYYY-MM-DD` |
| `last_article_count` | Jumlah artikel terakhir | `int` |
| `last_unpaid_invoice_ids` | List ID invoice yang sudah dinotifikasi | `List<String>` |

## Format Data Notifikasi

```json
{
  "id": "1697654400000",
  "type": "pickup_schedule",
  "title": "🚛 Jadwal Pengambilan Sampah",
  "message": "Hari ini (Selasa) ada jadwal pengambilan sampah pukul 08:00 - 10:00...",
  "time": "2024-10-18T08:00:00.000Z",
  "isRead": false
}
```

## Best Practices

1. **Hindari Notifikasi Duplikat**: Sistem sudah dilengkapi dengan mekanisme untuk mencegah notifikasi yang sama muncul berulang kali.

2. **Check Timing**: Notifikasi otomatis hanya di-trigger:
   - Saat aplikasi dibuka (home screen init)
   - Sekali per hari untuk jadwal pickup
   - Saat ada perubahan data (tagihan baru)

3. **User Action Notifications**: Notifikasi untuk aksi user (pembayaran, pelaporan) langsung di-trigger setelah aksi berhasil.

4. **Performance**: Semua check notifikasi berjalan asynchronous untuk tidak memblokir UI.

## Testing

Untuk testing notifikasi, gunakan metode reset:

```dart
final helper = NotificationHelper();
await helper.resetNotificationChecks();
```

Ini akan menghapus semua state check sehingga notifikasi akan muncul lagi.

## Future Improvements

1. **Push Notifications**: Integrasi dengan Firebase Cloud Messaging untuk notifikasi bahkan saat app tertutup
2. **Notification Preferences**: Pengaturan untuk user memilih notifikasi mana yang ingin diterima
3. **Notification History**: Archive notifikasi lama dengan pagination
4. **Rich Notifications**: Tambah action button di notifikasi (bayar sekarang, lihat detail, dll)
5. **Notification Sound**: Audio feedback saat notifikasi muncul
6. **Badge Count**: Update badge count di app icon (iOS/Android)

## Troubleshooting

### Notifikasi tidak muncul?
1. Pastikan `checkAndTriggerNotifications()` dipanggil di home screen
2. Check console log untuk error messages
3. Verify data tersedia (ada jadwal, tagihan, dll)
4. Reset notification checks untuk testing

### Notifikasi muncul terus menerus?
1. Pastikan state persistence bekerja (SharedPreferences)
2. Check implementasi date comparison
3. Verify ID invoice/artikel unique

### Icon tidak sesuai?
1. Check tipe notifikasi di data
2. Pastikan switch case di notification_screen.dart lengkap
3. Verify type string match (case-sensitive)

## Changelog

### Version 1.1.0 (18 Oktober 2024)
- ✅ Tambah preview detail notifikasi dengan modal bottom sheet
- ✅ Tambah tombol hapus per notifikasi dengan konfirmasi
- ✅ Tambah menu "Hapus Semua" di AppBar
- ✅ Tambah menu "Tandai Semua Dibaca" di AppBar
- ✅ Improve UI notification list dengan tombol delete di trailing
- ✅ Tambah metode `deleteNotification()` di NotificationService
- ✅ Auto mark as read saat buka detail notifikasi

### Version 1.0.0 (18 Oktober 2024)
- ✅ Implementasi NotificationHelper
- ✅ Notifikasi jadwal pengambilan sampah otomatis
- ✅ Notifikasi tagihan baru dan reminder
- ✅ Notifikasi pembayaran berhasil
- ✅ Notifikasi artikel baru
- ✅ Notifikasi pelaporan terkirim
- ✅ Notifikasi akun layanan dibuat
- ✅ UI notification screen dengan icon dinamis
- ✅ Format waktu relatif
- ✅ Integrasi ke semua screen terkait
