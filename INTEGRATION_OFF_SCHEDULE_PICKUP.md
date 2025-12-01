# Integrasi Off-Schedule Pickup ke Home Kolektor

## 📋 Ringkasan
Implementasi fitur untuk menampilkan request pengambilan sampah luar jadwal (off-schedule) yang telah ditugaskan oleh admin ke kolektor pada halaman home kolektor.

## 🔄 Alur Kerja

1. **User membuat request** (Express Request Screen)
   - User mengisi form request pengambilan luar jadwal
   - Request dikirim ke backend dengan status `sent`
   - Data tersimpan di database

2. **Admin menugaskan ke Kolektor** (Web Dashboard)
   - Admin melihat request yang masuk
   - Admin menugaskan request ke kolektor tertentu
   - Status berubah menjadi `processing`
   - `collector_id` terassign

3. **Kolektor menerima tugas** (Home Screen Kolektor)
   - Tugas off-schedule muncul di halaman Home
   - Ditampilkan dengan badge "⚡ Luar Jadwal"
   - Border oranye untuk membedakan dari pickup reguler

## 📝 Perubahan File

### 1. `lib/services/off_schedule_pickup_service.dart`
**Penambahan:**
- Method `getCollectorTodayPickups()` untuk mengambil off-schedule pickups yang ditugaskan ke kolektor

```dart
Future<List<OffSchedulePickup>> getCollectorTodayPickups() async {
  // Mengambil data dari endpoint: /mobile/collector/off-schedule-pickups/today
}
```

### 2. `lib/config/api_config.dart`
**Penambahan:**
- Endpoint baru: `collectorOffSchedulePickupsToday`

### 3. `lib/screens/kolektor/home_screens_kolektor.dart`
**Penambahan State:**
```dart
List<Map<String, dynamic>> offSchedulePickups = [];
bool _isLoadingOffSchedule = false;
```

**Method Baru:**
- `_loadOffSchedulePickups()` - Load off-schedule pickups dari API
- Transform data dari model `OffSchedulePickup` ke format Map untuk UI

**Update Method:**
- `_buildBerandaPage()` - Total tasks include off-schedule pickups
- `_buildPengambilanList()` - Gabungkan regular + off-schedule pickups
- `_taskCard()` - Tambah visual indicator untuk off-schedule (badge + border)
- `didChangeAppLifecycleState()` - Refresh off-schedule saat app resume
- `_initializeData()` - Load off-schedule saat init

## 🎨 UI/UX Features

### Visual Indicator Off-Schedule Pickup:
1. **Badge "⚡ Luar Jadwal"** dengan warna oranye
2. **Border oranye** (2px) di card
3. **ID dengan prefix "LJ#"** (Luar Jadwal)

### Counter di Dashboard:
- Total Tasks = Regular Pickups + Off-Schedule + Complaints
- Completed = Pickup Completed + Off-Schedule Completed + Complaints Resolved
- Pending = Total - Completed

## 🔌 API Endpoint (Backend)

**Required endpoint:**
```
GET /api/v1/mobile/collector/off-schedule-pickups/today
Authorization: Bearer {token}

Response:
{
  "items": [
    {
      "id": 1,
      "service_account_name": "Jonathan",
      "address": "Jl. Taman Bukit Duri...",
      "requested_pickup_date": "2025-12-01",
      "requested_pickup_time": "14:00",
      "status": "pending",
      "request_status": "processing",
      "bag_count": 0,
      "total_amount": 5000,
      "resident_note": "...",
      ...
    }
  ]
}
```

## ✅ Testing Checklist

- [ ] Request dibuat dari user express request screen
- [ ] Admin assign request ke kolektor di web dashboard
- [ ] Off-schedule pickup muncul di home kolektor
- [ ] Badge "Luar Jadwal" tampil dengan benar
- [ ] Border oranye tampil di card
- [ ] Counter total tasks include off-schedule
- [ ] Pull-to-refresh memuat ulang off-schedule pickups
- [ ] App resume memuat ulang data

## 🚀 Cara Testing

1. **Login sebagai User**
   - Buka Express Request Screen
   - Buat request baru dengan tanggal hari ini

2. **Login sebagai Admin (Web)**
   - Lihat request yang masuk
   - Assign ke kolektor tertentu

3. **Login sebagai Kolektor**
   - Buka Home Screen
   - Lihat tugas "Luar Jadwal" muncul
   - Verify badge dan border oranye
   - Pull-to-refresh untuk reload

## 📌 Catatan Penting

- Off-schedule pickups dan regular pickups digabung dalam satu list
- Dibedakan dengan field `pickup_type: 'off-schedule'`
- Status tetap mengikuti status dari backend
- Koordinat (lat/long) default 0.0 jika tidak ada di data

## 🔮 Future Enhancement

- [ ] Tambahkan navigasi ke detail off-schedule pickup
- [ ] Implementasi proses pengambilan off-schedule
- [ ] Integrasi dengan maps untuk off-schedule location
- [ ] Push notification untuk assignment baru
