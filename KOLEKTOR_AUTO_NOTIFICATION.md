# 🔔 Sistem Notifikasi Otomatis Kolektor - Dokumentasi

**Versi:** 1.0.0  
**Tanggal:** 18 Oktober 2025  
**Status:** ✅ Production Ready

---

## 📋 Daftar Isi
- [Overview](#overview)
- [Features](#features)
- [Implementation](#implementation)
- [Notification Types](#notification-types)
- [Architecture](#architecture)
- [Usage](#usage)
- [Testing](#testing)

---

## 🎯 Overview

Sistem notifikasi otomatis untuk kolektor yang secara real-time memberikan update tentang:
1. **Jadwal Pengambilan Sampah Baru** - Notifikasi saat ada pickup dijadwalkan
2. **Aktivitas Terbaru** - Notifikasi saat ada pengambilan selesai
3. **Reminder Harian** - Notifikasi pagi hari untuk pickup hari ini
4. **Badge Counter** - Indikator visual jumlah notifikasi belum dibaca

---

## ✨ Features

### 1. **Notifikasi Jadwal Pickup Baru** 📅
- **Trigger:** Saat ada pickup baru dengan status `scheduled` atau `pending`
- **Timing:** Otomatis saat home screen dimuat atau data refresh
- **Content:** Nama warga, alamat, dan ID pickup
- **Icon:** 📅 (Green)

**Contoh:**
```
📅 Jadwal Pickup Baru
Anda memiliki jadwal pengambilan sampah dari Budi Santoso 
di Jl. Sudirman No. 123. Tap untuk detail.
```

### 2. **Notifikasi Aktivitas Selesai** ✅
- **Trigger:** Saat ada pickup dengan status `completed` atau `collected`
- **Timing:** Otomatis saat history data dimuat
- **Content:** Nama warga dan total harga
- **Icon:** ✅ (Green)

**Contoh:**
```
✅ Pengambilan Selesai
Pengambilan sampah dari Budi Santoso telah selesai. 
Total: Rp 50,000
```

### 3. **Notifikasi Pickup Dalam Proses** 🚚
- **Trigger:** Saat ada pickup dengan status `on_progress`
- **Timing:** Otomatis saat history data dimuat
- **Content:** Nama warga
- **Icon:** 🚚 (Orange)

**Contoh:**
```
🚚 Pickup Sedang Berlangsung
Pengambilan sampah dari Budi Santoso sedang dalam proses.
```

### 4. **Reminder Harian** ☀️
- **Trigger:** Setiap pagi (8:00 - 10:00) jika ada pickup pending
- **Timing:** Otomatis saat home screen dimuat di pagi hari
- **Content:** Jumlah pickup hari ini
- **Icon:** ☀️ (Blue)

**Contoh:**
```
☀️ Selamat Pagi!
Anda memiliki 3 tugas pengambilan sampah hari ini. 
Selamat bekerja!
```

### 5. **Badge Counter** 🔴
- **Display:** Red badge pada icon notification bell
- **Update:** Real-time setiap kali notifikasi baru atau dibaca
- **Format:** Angka (1-9) atau "9+" jika lebih dari 9

---

## 🔧 Implementation

### File Structure

```
lib/
├── services/
│   └── kolektor_notification_service.dart  ← NEW SERVICE
├── screens/
│   ├── kolektor/
│   │   └── home_screens_kolektor.dart      ← MODIFIED
│   └── user/
│       ├── notification_screen.dart         ← REUSED
│       └── notification_service.dart        ← REUSED
```

### 1. **KolektorNotificationService** (New)

Service khusus untuk menangani notifikasi kolektor dengan fitur:

#### Main Methods

```dart
// Check dan trigger notifikasi otomatis
static Future<void> checkAndTriggerNotifications({
  List<Map<String, dynamic>>? todayPickups,
  List<Map<String, dynamic>>? recentHistory,
})

// Check jadwal pickup hari ini
static Future<void> _checkTodayPickupSchedule(
  List<Map<String, dynamic>> todayPickups,
)

// Check aktivitas terbaru
static Future<void> _checkRecentActivity(
  List<Map<String, dynamic>> recentHistory,
)

// Send daily reminders (pagi hari)
static Future<void> sendDailyReminders(
  List<Map<String, dynamic>> todayPickups,
)
```

#### Helper Methods

```dart
// Manual notification triggers
static Future<void> notifyPickupAssigned({...})
static Future<void> notifyPickupReminder({...})
static Future<void> notifyPaymentReceived({...})
static Future<void> notifyPickupCancelled({...})
static Future<void> notifyPickupRescheduled({...})

// Statistics
static Future<Map<String, int>> getNotificationStats()

// Reset/Clear
static Future<void> resetProcessedPickups()
static Future<void> resetProcessedHistory()
static Future<void> resetAll()
```

#### Storage Keys

```dart
'kolektor_last_notification_check'  // Timestamp pemeriksaan terakhir
'kolektor_processed_pickups'        // List ID pickup yang sudah diproses
'kolektor_processed_history'        // List ID aktivitas yang sudah diproses
```

### 2. **HomeScreensKolektor** (Modified)

#### New State Variables

```dart
int _unreadNotifCount = 0;  // Counter untuk badge
```

#### New Methods

```dart
// Initialize semua data dan trigger notifikasi
Future<void> _initializeData() async {
  await _loadTodayPickups();
  await _loadPengambilanData();
  await _loadProfileImage();
  await _checkAndTriggerNotifications();
  await _loadUnreadNotifCount();
}

// Check dan trigger notifikasi otomatis
Future<void> _checkAndTriggerNotifications() async {
  await KolektorNotificationService.checkAndTriggerNotifications(
    todayPickups: todayPickups,
    recentHistory: pengambilanList,
  );
  await KolektorNotificationService.sendDailyReminders(todayPickups);
  await _loadUnreadNotifCount();
}

// Load unread notification count untuk badge
Future<void> _loadUnreadNotifCount() async {
  final count = await NotificationService.getUnreadCount();
  setState(() {
    _unreadNotifCount = count;
  });
}
```

#### Modified Widget - Notification Button dengan Badge

```dart
Stack(
  children: [
    IconButton(
      onPressed: () async {
        await Navigator.push(...);
        await _loadUnreadNotifCount(); // Refresh badge
      },
      icon: const Icon(Icons.notifications_outlined),
    ),
    // Badge merah untuk unread count
    if (_unreadNotifCount > 0)
      Positioned(
        right: 8,
        top: 8,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Text(
            _unreadNotifCount > 9 ? '9+' : _unreadNotifCount.toString(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
  ],
)
```

---

## 📱 Notification Types

### Notification Type Schema

```dart
{
  "id": "unique_timestamp_id",
  "type": "notification_type",
  "title": "Notification Title",
  "message": "Notification Message",
  "time": "2025-10-18T10:30:00.000Z",
  "isRead": false
}
```

### Available Types for Kolektor

| Type | Icon | Color | Usage |
|------|------|-------|-------|
| `pickup_schedule` | 🚚 | Green | Jadwal pickup baru |
| `pickup_reminder` | 🔔 | Orange | Reminder pickup hari ini |
| `pickup_completed` | ✅ | Green | Pickup selesai |
| `pickup_in_progress` | 🚚 | Orange | Pickup sedang berlangsung |
| `payment_success` | 💰 | Blue | Pembayaran diterima |
| `pickup_cancelled` | ❌ | Red | Pickup dibatalkan |
| `pickup_rescheduled` | 📅 | Blue | Jadwal diubah |
| `daily_reminder` | ☀️ | Blue | Reminder pagi hari |

---

## 🏗️ Architecture

### Data Flow

```
1. Home Screen Loaded
   ↓
2. _initializeData() called
   ↓
3. Load Today Pickups & History
   ↓
4. _checkAndTriggerNotifications()
   ↓
5. KolektorNotificationService.checkAndTriggerNotifications()
   ↓
6. Check for new pickups (not in processed list)
   ↓
7. Create notifications for new items
   ↓
8. Save IDs to processed list
   ↓
9. sendDailyReminders() if morning
   ↓
10. _loadUnreadNotifCount()
    ↓
11. Update badge UI
```

### Prevention of Duplicate Notifications

**Problem:** Setiap kali home screen dimuat, akan check pickups → bisa trigger notifikasi duplikat

**Solution:** Menggunakan "processed list" di SharedPreferences

```dart
// Simpan ID yang sudah diproses
List<String> processedPickupIds = ['123', '456', '789'];

// Check apakah pickup sudah pernah diproses
if (processedPickupIds.contains(pickupId)) {
  continue; // Skip, sudah ada notifikasinya
}

// Jika belum, buat notifikasi dan tambah ke list
createNotification(pickup);
processedPickupIds.add(pickupId);
```

### Timing Logic

#### Daily Reminder
```dart
final now = DateTime.now();
final hour = now.hour;

// Hanya kirim reminder di pagi hari (8-10 AM)
if (hour >= 8 && hour <= 10) {
  sendDailyReminder();
}
```

#### Pickup Check
```dart
// Trigger saat:
1. initState() → First load
2. _loadTodayPickups() → Data refresh
3. _loadPengambilanData() → History refresh
4. Return from PengambilanSampahScreen → After pickup
```

---

## 📖 Usage

### For Developers

#### 1. Automatic Notifications (Default)

Notifikasi otomatis sudah berjalan tanpa kode tambahan:

```dart
// Di home_screens_kolektor.dart
@override
void initState() {
  super.initState();
  _initializeData(); // ← Otomatis trigger notifikasi
}
```

#### 2. Manual Notification Trigger

Jika perlu trigger notifikasi manual (misal dari API callback):

```dart
// Notifikasi pickup baru
await KolektorNotificationService.notifyPickupAssigned(
  residentName: 'Budi Santoso',
  address: 'Jl. Sudirman No. 123',
  pickupId: '456',
);

// Notifikasi reminder
await KolektorNotificationService.notifyPickupReminder(
  residentName: 'Budi Santoso',
  address: 'Jl. Sudirman No. 123',
);

// Notifikasi payment
await KolektorNotificationService.notifyPaymentReceived(
  residentName: 'Budi Santoso',
  amount: 50000,
);

// Notifikasi cancelled
await KolektorNotificationService.notifyPickupCancelled(
  residentName: 'Budi Santoso',
  reason: 'User tidak tersedia',
);

// Notifikasi rescheduled
await KolektorNotificationService.notifyPickupRescheduled(
  residentName: 'Budi Santoso',
  newDate: '20 Oktober 2025',
);
```

#### 3. Get Notification Statistics

```dart
final stats = await KolektorNotificationService.getNotificationStats();
print('Total: ${stats['total']}');
print('Unread: ${stats['unread']}');
print('Pickup Schedule: ${stats['pickup_schedule']}');
print('Completed: ${stats['pickup_completed']}');
print('Payment: ${stats['payment']}');
```

#### 4. Reset Processed Lists (Testing)

```dart
// Reset pickup list
await KolektorNotificationService.resetProcessedPickups();

// Reset history list
await KolektorNotificationService.resetProcessedHistory();

// Reset semua
await KolektorNotificationService.resetAll();
```

### For Users (Kolektor)

#### View Notifications

1. Buka app → Home Screen Kolektor
2. Lihat badge merah di icon lonceng 🔔
3. Tap icon lonceng
4. Lihat list notifikasi (newest first)
5. Tap notifikasi untuk detail
6. Badge akan update otomatis

#### Notification Actions

- **Mark as Read:** Tap notifikasi → otomatis marked
- **Delete:** Tap delete button atau swipe
- **Close:** Tap back atau swipe down modal

---

## 🧪 Testing

### Test Scenarios

#### ✅ Test 1: New Pickup Notification
```
1. Buka Home Screen Kolektor
2. Ensure ada pickup baru dengan status 'scheduled'
3. Check notifikasi → Should see "📅 Jadwal Pickup Baru"
4. Reload app → Should NOT create duplicate notification
```

#### ✅ Test 2: Completed Pickup Notification
```
1. Complete a pickup
2. Return to Home Screen
3. Check notifikasi → Should see "✅ Pengambilan Selesai"
4. Reload app → Should NOT create duplicate
```

#### ✅ Test 3: Daily Reminder
```
1. Set device time to 9:00 AM
2. Ensure ada pickup pending hari ini
3. Load Home Screen
4. Check notifikasi → Should see "☀️ Selamat Pagi!"
5. Reload at 11:00 AM → Should NOT send reminder
```

#### ✅ Test 4: Badge Counter
```
1. Create 3 new notifications
2. Check badge → Should show "3"
3. Tap notification bell
4. Mark 1 as read
5. Return to home → Badge should show "2"
6. Delete 1 notification
7. Badge should show "1"
```

#### ✅ Test 5: No Duplicate Notifications
```
1. Load Home Screen (create notification)
2. Navigate away
3. Return to Home Screen
4. Check notifikasi → Should see 1, not 2
```

#### ✅ Test 6: Multiple Pickups
```
1. Ensure ada 5 pickup baru
2. Load Home Screen
3. Check notifikasi → Should see 5 notifications
4. Reload → Should NOT create 5 more
```

#### ✅ Test 7: Badge Update After Read
```
1. Badge shows "5"
2. Open notification screen
3. Tap 1 notification
4. Return to home
5. Badge should show "4" (auto refresh)
```

### Manual Testing Checklist

- [ ] Notification created for new pickup
- [ ] Notification created for completed pickup
- [ ] No duplicate notifications on reload
- [ ] Badge shows correct count
- [ ] Badge updates after marking read
- [ ] Badge updates after delete
- [ ] Daily reminder only sends in morning
- [ ] No reminder for 0 pending pickups
- [ ] Notification navigation works
- [ ] Mark as read updates instantly
- [ ] Delete removes from list
- [ ] Empty state shows when no notifications
- [ ] Processed lists persist after app restart

### Edge Cases

- [ ] Works with 0 pickups (no error)
- [ ] Works with 100+ pickups (performance OK)
- [ ] Works offline (uses cached data)
- [ ] Works after clear app data (fresh start)
- [ ] Badge never shows negative number
- [ ] Badge max at "9+" for large numbers
- [ ] Notification time format correct
- [ ] Icons and colors correct per type

---

## 🎨 Visual Design

### Badge Specification

```dart
Container(
  padding: EdgeInsets.all(4),
  decoration: BoxDecoration(
    color: Colors.red,           // Red badge
    shape: BoxShape.circle,      // Circular
    border: Border.all(
      color: Colors.white,       // White border
      width: 1.5,                // 1.5px border
    ),
  ),
  constraints: BoxConstraints(
    minWidth: 18,                // Min 18x18px
    minHeight: 18,
  ),
  child: Text(
    _unreadNotifCount > 9 
      ? '9+' 
      : _unreadNotifCount.toString(),
    style: GoogleFonts.poppins(
      color: Colors.white,       // White text
      fontSize: 10,              // 10px font
      fontWeight: FontWeight.bold,
    ),
  ),
)
```

### Badge Position

```
┌─────────────────────────┐
│  [Profile]         🔔®  │  ← Badge di pojok kanan atas bell
│                         │
│  Tugas Hari Ini         │
│  18 Oktober 2025        │
└─────────────────────────┘

® = Red badge with count
```

---

## 📊 Performance Considerations

### Optimization Strategies

1. **Lazy Loading:** Notifikasi hanya di-check saat home screen dimuat
2. **Caching:** Processed IDs disimpan di SharedPreferences
3. **Debouncing:** Tidak check ulang jika sudah diproses
4. **Batch Processing:** Check semua pickup sekaligus, bukan satu-satu
5. **Async Operations:** Semua operasi async untuk tidak block UI

### Memory Usage

```
Processed Pickup IDs: ~100 IDs × 10 chars = 1 KB
Processed History IDs: ~50 IDs × 10 chars = 500 bytes
Notifications: ~100 notif × 200 chars = 20 KB
Total: ~21.5 KB (negligible)
```

---

## 🚀 Future Enhancements

### Priority 1 (High)
- [ ] **Push Notifications:** FCM untuk instant alerts
- [ ] **Sound & Vibration:** Alert suara saat notifikasi baru
- [ ] **Background Service:** Check notifikasi di background
- [ ] **Real-time Updates:** WebSocket untuk real-time sync

### Priority 2 (Medium)
- [ ] **Notification Grouping:** Group by type atau date
- [ ] **Smart Reminders:** AI-based reminder timing
- [ ] **Custom Notification Sounds:** Beda suara per tipe
- [ ] **Notification History Archive:** Archive notifikasi lama

### Priority 3 (Low)
- [ ] **Notification Analytics:** Track open rate, response time
- [ ] **Smart Filters:** Filter by priority, location, etc.
- [ ] **Quick Actions:** Action buttons di notification
- [ ] **Notification Templates:** Custom templates per kolektor

---

## 🐛 Known Issues & Limitations

### Current Limitations

1. **No Real-time Updates:** Notifikasi hanya di-check saat app dibuka
2. **No Push Notifications:** Belum ada FCM integration
3. **Local Storage Only:** Tidak sync ke server
4. **Manual Refresh:** Perlu reload untuk check notifikasi baru
5. **No Notification History:** Old notifications terhapus permanen

### Workarounds

- **For Real-time:** Pull down to refresh home screen
- **For Push:** Akan ditambahkan di versi berikutnya
- **For Sync:** Data local sudah cukup untuk v1
- **For History:** Export notifikasi penting ke notes

---

## 📝 Code Analysis Result

```
flutter analyze lib/screens/kolektor/home_screens_kolektor.dart 
              lib/services/kolektor_notification_service.dart

✅ 0 errors
⚠️ 8 info warnings (deprecation & style warnings - non-critical)

Status: Production Ready
```

---

## 📚 Related Documentation

- `KOLEKTOR_NOTIFICATION_BUTTON.md` - Notification button fix
- `SISTEM_NOTIFIKASI_OTOMATIS.md` - User notification system
- `NOTIFICATION_PREVIEW_DELETE.md` - Notification preview & delete

---

## 📞 Support & Troubleshooting

### Issue: Notifikasi tidak muncul
**Solution:**
1. Check `todayPickups` dan `recentHistory` ada data
2. Verify `KolektorNotificationService.checkAndTriggerNotifications()` dipanggil
3. Check console untuk error logs
4. Reset processed lists dengan `resetAll()`

### Issue: Duplicate notifications
**Solution:**
1. Verify processed IDs tersimpan di SharedPreferences
2. Check key: `kolektor_processed_pickups`
3. Ensure IDs match antara pickup dan processed list

### Issue: Badge tidak update
**Solution:**
1. Check `_loadUnreadNotifCount()` dipanggil
2. Verify `setState()` dipanggil setelah load
3. Check `NotificationService.getUnreadCount()` return benar

### Issue: Reminder tidak muncul
**Solution:**
1. Check device time (8-10 AM)
2. Verify ada pickup pending
3. Check `sendDailyReminders()` dipanggil
4. Console log untuk debug timing

---

**Dokumentasi dibuat:** 18 Oktober 2025  
**Last Updated:** 18 Oktober 2025  
**Version:** 1.0.0  
**Status:** ✅ Production Ready  
**Author:** Smart Environment Team
