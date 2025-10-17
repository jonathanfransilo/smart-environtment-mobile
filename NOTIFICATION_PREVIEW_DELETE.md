# Fitur Preview dan Hapus Notifikasi

## Overview
Dokumentasi ini menjelaskan fitur preview detail notifikasi dan penghapusan notifikasi yang telah ditambahkan ke aplikasi Smart Environment Mobile.

## Fitur yang Ditambahkan

### 1. 📱 Preview Detail Notifikasi

#### Cara Menggunakan:
- **Tap** pada notifikasi di list untuk membuka detail lengkap

#### Komponen UI:
- **Modal Bottom Sheet** dengan desain modern
- **Draggable** - bisa di-drag ke atas/bawah
- **Handle Bar** di bagian atas untuk indikasi draggable
- **Icon Besar** dengan background warna sesuai tipe notifikasi
- **Title** dengan font besar dan bold
- **Full Message** dalam container dengan background abu-abu
- **Timestamp** dengan icon clock
- **Action Buttons**:
  - Tombol "Hapus" (merah) - menghapus notifikasi
  - Tombol "Tutup" (teal) - menutup modal

#### Konfigurasi:
```dart
DraggableScrollableSheet(
  initialChildSize: 0.6,  // 60% tinggi layar
  minChildSize: 0.4,       // minimal 40%
  maxChildSize: 0.9,       // maksimal 90%
  expand: false,
)
```

#### Behavior:
- Saat dibuka, notifikasi otomatis ditandai sebagai **sudah dibaca**
- Badge dot hilang setelah dibaca
- Background berubah dari putih ke abu-abu muda
- Icon berubah dari warna penuh ke abu-abu

### 2. 🗑️ Hapus Notifikasi Per Item

#### Cara Menggunakan:
1. **Dari List**: Tap icon delete (🗑️) di sebelah kanan notifikasi
2. **Dari Detail**: Tap tombol "Hapus" di modal bottom sheet

#### Konfirmasi Dialog:
- Title: "Hapus Notifikasi"
- Pesan: "Apakah Anda yakin ingin menghapus notifikasi ini?"
- Buttons:
  - "Batal" (abu-abu) - membatalkan penghapusan
  - "Hapus" (merah) - konfirmasi hapus

#### Feedback:
Setelah berhasil dihapus, muncul **SnackBar**:
```
"Notifikasi berhasil dihapus"
```
dengan background warna teal.

### 3. 🗑️ Hapus Semua Notifikasi

#### Cara Menggunakan:
1. Tap icon menu (⋮) di AppBar
2. Pilih "Hapus semua"

#### Konfirmasi Dialog:
- Title: "Hapus Semua Notifikasi"
- Pesan: "Apakah Anda yakin ingin menghapus semua notifikasi? Tindakan ini tidak dapat dibatalkan."
- Buttons:
  - "Batal" - membatalkan
  - "Hapus Semua" (merah) - konfirmasi

#### Feedback:
Setelah berhasil:
```
"Semua notifikasi berhasil dihapus"
```

### 4. ✅ Tandai Semua Dibaca

#### Cara Menggunakan:
1. Tap icon menu (⋮) di AppBar
2. Pilih "Tandai semua dibaca"

#### Behavior:
- Semua notifikasi langsung ditandai sebagai dibaca
- Badge dot hilang dari semua item
- Background berubah ke abu-abu muda
- Icon berubah ke abu-abu

#### Feedback:
```
"Semua notifikasi ditandai sudah dibaca"
```

## UI/UX Details

### List Item Layout

```
┌─────────────────────────────────────────────┐
│ [Icon] Title                    [Badge] [🗑️] │
│        Message (max 2 lines)...             │
│        ⏰ 2 jam yang lalu                    │
└─────────────────────────────────────────────┘
```

**Read State:**
- Background: `Colors.grey.shade50`
- Icon Color: `Colors.grey`
- Text Color: `Colors.black54`
- No Badge

**Unread State:**
- Background: `Colors.white`
- Icon Color: Sesuai tipe (hijau/orange/biru/dll)
- Text Color: `Colors.black87`
- Badge dot dengan warna icon

### Detail Modal Layout

```
┌─────────────────────────────────────────────┐
│              ─────                           │
│                                             │
│           [  Icon  ]                        │
│                                             │
│         Title Text Bold                     │
│                                             │
│  ┌───────────────────────────────────────┐ │
│  │ Full message text with all details    │ │
│  │ in a nice container with gray bg      │ │
│  └───────────────────────────────────────┘ │
│                                             │
│        ⏰ 2 jam yang lalu                   │
│                                             │
│  [  Hapus  ]  [      Tutup      ]          │
│                                             │
└─────────────────────────────────────────────┘
```

### AppBar Menu

```
┌─────────────────────────────┐
│ ✓ Tandai semua dibaca       │
│ 🗑️ Hapus semua (red)         │
└─────────────────────────────┘
```

## API Methods

### NotificationService

```dart
// Hapus satu notifikasi
static Future<void> deleteNotification(String id)

// Hapus semua notifikasi
static Future<void> clearAll()

// Tandai semua sebagai dibaca
static Future<void> markAllAsRead()
```

### NotificationScreen (Private Methods)

```dart
// Hapus notifikasi dan refresh list
Future<void> _deleteNotification(String id)

// Tampilkan detail notifikasi
void _showNotificationDetail(Map<String, dynamic> notif)
```

## Workflow

### Preview Notifikasi:
```
User tap notifikasi
    ↓
Mark as read (jika belum dibaca)
    ↓
Tampilkan modal bottom sheet
    ↓
User lihat detail lengkap
    ↓
User pilih aksi:
    - Tutup → kembali ke list
    - Hapus → konfirmasi → hapus → kembali ke list
```

### Hapus dari List:
```
User tap icon delete
    ↓
Tampilkan konfirmasi dialog
    ↓
User konfirmasi:
    - Batal → tutup dialog
    - Hapus → hapus notifikasi → refresh list → snackbar
```

### Hapus Semua:
```
User tap menu ⋮
    ↓
User pilih "Hapus semua"
    ↓
Tampilkan konfirmasi dialog
    ↓
User konfirmasi:
    - Batal → tutup dialog
    - Hapus Semua → clear all → refresh list → snackbar → empty state
```

## Best Practices

### 1. Konfirmasi Sebelum Hapus
Selalu tampilkan dialog konfirmasi untuk aksi destructive (hapus):
```dart
final confirm = await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Hapus Notifikasi'),
    content: Text('Apakah Anda yakin?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text('Batal'),
      ),
      ElevatedButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text('Hapus'),
      ),
    ],
  ),
);

if (confirm == true) {
  // Lakukan penghapusan
}
```

### 2. Feedback Setelah Aksi
Selalu berikan feedback dengan SnackBar:
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Notifikasi berhasil dihapus'),
    backgroundColor: Colors.teal,
  ),
);
```

### 3. Auto Mark as Read
Saat user membuka detail, otomatis tandai sebagai dibaca:
```dart
onTap: () async {
  if (!isRead) {
    await _markAsRead(notif['id']);
  }
  _showNotificationDetail(notif);
}
```

### 4. Refresh After Action
Selalu refresh list setelah perubahan:
```dart
await _deleteNotification(notif['id']);
await _loadNotifications(); // refresh
```

## Color Scheme

| Tipe Notifikasi | Icon | Warna | Hex Code |
|----------------|------|-------|----------|
| Jadwal Pickup | 🚛 | Hijau | #4CAF50 |
| Tagihan Baru | 💰 | Orange | #F57C00 |
| Pembayaran Sukses | ✅ | Biru | #2196F3 |
| Artikel Baru | 📰 | Ungu | #9C27B0 |
| Laporan Terkirim | 📝 | Pink | #E91E63 |
| Akun Dibuat | 🎉 | Teal | #159189 |

## Responsive Design

### Modal Bottom Sheet
- **Mobile**: 60% tinggi layar (initialChildSize: 0.6)
- **Draggable**: User bisa drag untuk resize
- **Min**: 40% tinggi layar
- **Max**: 90% tinggi layar

### List Item
- **Padding**: horizontal 8, vertical 4
- **Elevation**: 2 (unread), 0 (read)
- **Icon Size**: 24px
- **Title Font**: 14px
- **Message Font**: 13px (dengan title), 14px (tanpa title)
- **Time Font**: 12px

### Buttons
- **Delete Icon**: 20px
- **Action Buttons**: vertical padding 12px
- **Border Radius**: 10px

## Testing Scenarios

### 1. Preview Notifikasi
- [ ] Tap notifikasi membuka detail
- [ ] Modal draggable bekerja
- [ ] Icon dan warna sesuai tipe
- [ ] Full message terlihat
- [ ] Timestamp akurat
- [ ] Otomatis mark as read
- [ ] Badge hilang setelah dibaca

### 2. Hapus Per Item
- [ ] Icon delete terlihat di trailing
- [ ] Tap delete tampilkan konfirmasi
- [ ] Batal tidak menghapus
- [ ] Konfirmasi menghapus notifikasi
- [ ] List refresh otomatis
- [ ] SnackBar muncul
- [ ] Empty state jika semua dihapus

### 3. Hapus dari Detail
- [ ] Tombol hapus di modal bekerja
- [ ] Konfirmasi dialog muncul
- [ ] Penghapusan berhasil
- [ ] Modal tertutup setelah hapus
- [ ] SnackBar muncul

### 4. Hapus Semua
- [ ] Menu muncul di AppBar
- [ ] "Hapus semua" tampilkan konfirmasi
- [ ] Semua notifikasi terhapus
- [ ] Empty state muncul
- [ ] SnackBar konfirmasi

### 5. Tandai Semua Dibaca
- [ ] Menu muncul di AppBar
- [ ] Semua badge hilang
- [ ] Semua background berubah
- [ ] SnackBar konfirmasi

## Troubleshooting

### Modal tidak muncul?
- Pastikan `showModalBottomSheet` dipanggil dengan context yang benar
- Check bahwa `_showNotificationDetail` dipanggil di `onTap`

### Delete tidak bekerja?
- Verify `NotificationService.deleteNotification()` implemented
- Check ID notifikasi valid
- Pastikan `_loadNotifications()` dipanggil setelah delete

### Konfirmasi tidak muncul?
- Pastikan `showDialog` return `bool?`
- Check kondisi `if (confirm == true)`

### SnackBar tidak muncul?
- Pastikan ada `Scaffold` di widget tree
- Check `mounted` sebelum memanggil `ScaffoldMessenger`
- Verify context masih valid

## Future Improvements

1. **Swipe to Delete**: Gestur swipe untuk hapus tanpa tap icon
2. **Undo Delete**: Opsi undo setelah hapus dengan timeout
3. **Batch Select**: Multiple selection untuk hapus beberapa sekaligus
4. **Archive**: Arsip notifikasi lama alih-alih hapus
5. **Filter by Type**: Filter notifikasi berdasarkan tipe
6. **Search**: Cari notifikasi berdasarkan keyword
7. **Export**: Export riwayat notifikasi ke PDF
8. **Notification Actions**: Quick action di notifikasi (bayar, lihat detail, dll)

## Version History

### v1.1.0 (Current)
- ✅ Preview detail dengan modal bottom sheet
- ✅ Hapus per notifikasi dengan konfirmasi
- ✅ Hapus semua notifikasi
- ✅ Tandai semua dibaca
- ✅ Menu di AppBar

### v1.0.0
- ✅ Basic notification list
- ✅ Mark as read per item
- ✅ Different icons per type
- ✅ Relative time format
