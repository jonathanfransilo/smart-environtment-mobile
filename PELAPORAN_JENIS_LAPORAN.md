# Dokumentasi: Fitur Jenis Laporan (Pelaporan & Pengaduan)

## 📋 Overview
Fitur baru yang menambahkan pilihan **Jenis Laporan** pada tampilan pelaporan:
- **Pelaporan (Public)**: Laporan bersifat publik dan bisa dilihat oleh user lain
- **Pengaduan (Private)**: Pengaduan bersifat privat dan hanya bisa dilihat oleh user yang membuatnya

## 🎯 Perubahan yang Dilakukan

### 1. **Model Data (`Laporan` class)**
#### Perubahan:
```dart
class Laporan {
  final String id;
  final String kota;
  final String jenisLaporan; // ✅ BARU: 'pelaporan' atau 'pengaduan'
  final String kategori;
  final String lokasi;
  // ... fields lainnya
  
  // ✅ BARU: Helper property untuk cek public/private
  bool get isPublic => jenisLaporan == 'pelaporan';
}
```

#### Penjelasan:
- Ditambahkan field `jenisLaporan` untuk menyimpan jenis ('pelaporan' atau 'pengaduan')
- Ditambahkan getter `isPublic` untuk kemudahan pengecekan

---

### 2. **BuatLaporanScreen**
#### Perubahan:
```dart
class BuatLaporanScreen extends StatefulWidget {
  final File? imageFile;
  final bool isAsset;
  final String jenisLaporan; // ✅ BARU: Parameter wajib

  const BuatLaporanScreen({
    super.key,
    required this.imageFile,
    required this.isAsset,
    required this.jenisLaporan, // ✅ BARU: Required parameter
  });
}
```

#### UI Baru:
Ditambahkan tampilan jenis laporan di bawah Kota Jakarta:

```dart
// JENIS LAPORAN (Read-only display)
Container(
  decoration: BoxDecoration(
    color: widget.jenisLaporan == 'pelaporan' 
        ? Colors.blue.shade50    // Biru untuk Pelaporan
        : Colors.orange.shade50, // Orange untuk Pengaduan
  ),
  child: Row(
    children: [
      Icon(
        widget.jenisLaporan == 'pelaporan' 
            ? Icons.public           // 🌐 Icon untuk Public
            : Icons.lock_outline,    // 🔒 Icon untuk Private
        color: // Warna sesuai jenis
      ),
      Text('Pelaporan (Public)' atau 'Pengaduan (Private)'),
      Badge('Publik' atau 'Privat'), // Badge pill
    ],
  ),
)
```

**Tampilan Visual:**
- **Pelaporan**: Background biru muda, icon 🌐 public, badge "Publik" biru
- **Pengaduan**: Background orange muda, icon 🔒 lock, badge "Privat" orange

---

### 3. **PelaporanScreen - Dialog Pemilihan**
#### Fitur Baru: `_showJenisLaporanDialog()`

Sebelum navigasi ke form, user harus memilih jenis laporan terlebih dahulu:

```dart
void _showJenisLaporanDialog() {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: "Pilih Jenis Laporan",
      content: Column(
        children: [
          // Opsi 1: Pelaporan (Public)
          InkWell(
            onTap: () => _navigateToBuatLaporan('pelaporan'),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue.shade300),
                color: Colors.blue.shade50,
              ),
              child: Row(
                children: [
                  Icon(Icons.public, color: Colors.blue),
                  Column(
                    children: [
                      Text("Pelaporan"),
                      Text("Laporan bersifat publik, bisa dilihat oleh user lain"),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Opsi 2: Pengaduan (Private)
          InkWell(
            onTap: () => _navigateToBuatLaporan('pengaduan'),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange.shade300),
                color: Colors.orange.shade50,
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.orange),
                  Column(
                    children: [
                      Text("Pengaduan"),
                      Text("Pengaduan bersifat privat, hanya bisa dilihat oleh Anda"),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
```

**Flow Navigasi Baru:**
1. User klik FAB (+) atau (✓)
2. Jika sudah ada foto → Tampilkan dialog pemilihan jenis
3. User pilih "Pelaporan" atau "Pengaduan"
4. Navigate ke `BuatLaporanScreen` dengan parameter `jenisLaporan`

---

### 4. **DetailLaporanScreen - Tampilan Detail**
#### Perubahan:
Ditambahkan tampilan jenis laporan di detail:

```dart
// Di antara Kota dan Kategori
Padding(
  child: Column(
    children: [
      Text("Jenis Laporan", style: label),
      Row(
        children: [
          Icon(isPublic ? Icons.public : Icons.lock_outline),
          Text(isPublic ? 'Pelaporan (Public)' : 'Pengaduan (Private)'),
          Badge(isPublic ? 'Publik' : 'Privat'),
        ],
      ),
    ],
  ),
)
```

---

### 5. **DetailLaporanTerkirimScreen**
#### Perubahan:
Sama seperti `DetailLaporanScreen`, ditambahkan tampilan jenis laporan menggunakan `laporan.isPublic` helper.

---

## 🎨 Design Specifications

### Color Scheme:
| Jenis | Background | Icon/Text Color | Badge Background | Badge Text |
|-------|-----------|----------------|-----------------|-----------|
| **Pelaporan (Public)** | `Colors.blue.shade50` | `Colors.blue.shade700` | `Colors.blue.shade100` | `Colors.blue.shade700` |
| **Pengaduan (Private)** | `Colors.orange.shade50` | `Colors.orange.shade700` | `Colors.orange.shade100` | `Colors.orange.shade700` |

### Icons:
- **Pelaporan (Public)**: `Icons.public` (🌐)
- **Pengaduan (Private)**: `Icons.lock_outline` (🔒)

### Typography:
- **Label**: 12px, grey.shade600, Poppins Regular
- **Value**: 16px, black87/color coded, Poppins Medium (w500)
- **Badge**: 10px, color coded, Poppins SemiBold (w600)

---

## 🔄 User Flow

### Flow Sebelum:
```
📸 Pilih Foto → 📝 Isi Form → ✅ Konfirmasi → ✔️ Selesai
```

### Flow Sesudah (NEW):
```
📸 Pilih Foto → 🎯 Pilih Jenis Laporan → 📝 Isi Form → ✅ Konfirmasi → ✔️ Selesai
                     ↓
            [Pelaporan (Public) atau Pengaduan (Private)]
```

---

## 📱 Screenshot Referensi (Deskripsi)

### 1. Dialog Pemilihan Jenis Laporan
```
┌─────────────────────────────────┐
│  Pilih Jenis Laporan           │
├─────────────────────────────────┤
│                                 │
│  ┌───────────────────────────┐ │
│  │ 🌐  Pelaporan             │ │
│  │     Laporan bersifat      │ │
│  │     publik, bisa dilihat  │ │
│  │     oleh user lain        │ │
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │ 🔒  Pengaduan             │ │
│  │     Pengaduan bersifat    │ │
│  │     privat, hanya bisa    │ │
│  │     dilihat oleh Anda     │ │
│  └───────────────────────────┘ │
│                                 │
│                    [BATAL]      │
└─────────────────────────────────┘
```

### 2. Form dengan Jenis Laporan (setelah Kota)
```
┌─────────────────────────────────┐
│ Kota                            │
│ ✓ Jakarta                       │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ 🌐 Jenis               [Publik] │
│    Pelaporan (Public)           │
└─────────────────────────────────┘
    (atau)
┌─────────────────────────────────┐
│ 🔒 Jenis              [Privat]  │
│    Pengaduan (Private)          │
└─────────────────────────────────┘
```

---

## 🧪 Testing Checklist

### Functional Testing:
- [ ] Dialog jenis laporan muncul setelah foto dipilih
- [ ] Klik "Pelaporan" → navigasi ke form dengan jenis 'pelaporan'
- [ ] Klik "Pengaduan" → navigasi ke form dengan jenis 'pengaduan'
- [ ] Form menampilkan jenis laporan yang benar (icon, warna, text)
- [ ] Detail laporan menampilkan jenis laporan dengan benar
- [ ] Laporan terkirim menyimpan jenis laporan dengan benar
- [ ] Badge "Publik"/"Privat" ditampilkan dengan benar

### UI/UX Testing:
- [ ] Warna sesuai design (biru untuk pelaporan, orange untuk pengaduan)
- [ ] Icon sesuai (🌐 untuk public, 🔒 untuk private)
- [ ] Badge pill terlihat jelas
- [ ] Text readable pada semua ukuran layar
- [ ] Dialog responsive di berbagai device
- [ ] Animasi smooth saat navigasi

### Edge Cases:
- [ ] Klik "BATAL" di dialog → kembali ke screen sebelumnya
- [ ] Back button saat di form → kembali tanpa simpan
- [ ] Multiple submit → tidak buat duplikat laporan

---

## 🚀 Implementasi Backend (TODO)

Ketika mengintegrasikan dengan backend:

### API Request:
```json
POST /api/reports
{
  "kota": "Jakarta",
  "jenis_laporan": "pelaporan", // atau "pengaduan"
  "kategori": "Sampah Liar",
  "lokasi": "Jl. Sudirman No. 123",
  "waktu_pelanggaran": "23 Oktober 2025 pukul 14:30",
  "ciri_ciri": "Sampah menumpuk di trotoar",
  "image": "base64_string_or_url"
}
```

### Database Schema (Suggestion):
```sql
CREATE TABLE reports (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  kota VARCHAR(100),
  jenis_laporan ENUM('pelaporan', 'pengaduan') NOT NULL,
  kategori VARCHAR(100),
  lokasi TEXT,
  waktu_pelanggaran TIMESTAMP,
  ciri_ciri TEXT,
  image_url TEXT,
  is_public BOOLEAN GENERATED ALWAYS AS (jenis_laporan = 'pelaporan'),
  created_at TIMESTAMP DEFAULT NOW(),
  
  INDEX idx_jenis_laporan (jenis_laporan),
  INDEX idx_is_public (is_public),
  INDEX idx_user_id_jenis (user_id, jenis_laporan)
);
```

### Query Logic:
```sql
-- Untuk menampilkan laporan public (semua user bisa lihat)
SELECT * FROM reports 
WHERE jenis_laporan = 'pelaporan' 
ORDER BY created_at DESC;

-- Untuk menampilkan pengaduan pribadi (hanya user sendiri)
SELECT * FROM reports 
WHERE jenis_laporan = 'pengaduan' 
AND user_id = :current_user_id 
ORDER BY created_at DESC;
```

---

## 📝 Notes

1. **Privacy**: Pastikan backend menerapkan authorization yang benar:
   - Pengaduan (private) hanya bisa diakses oleh user yang membuatnya
   - Pelaporan (public) bisa diakses oleh semua user

2. **Filter**: Bisa ditambahkan filter di list untuk menampilkan:
   - Semua laporan public
   - Hanya pengaduan saya
   - Kombinasi keduanya

3. **Notifikasi**: 
   - Pelaporan (public) → bisa notify admin dan user lain di area yang sama
   - Pengaduan (private) → hanya notify admin/petugas yang ditugaskan

4. **Analytics**:
   - Track berapa banyak laporan public vs private
   - Monitor response time untuk pengaduan private (SLA)

---

## 🔗 Related Files
- `lib/screens/user/pelaporan_screen.dart` - Main file yang dimodifikasi
- `lib/utils/responsive.dart` - Responsive helper (untuk future responsive implementation)
- `PELAPORAN_JENIS_LAPORAN.md` - Dokumentasi ini

---

**Created**: 2025-10-23  
**Version**: 1.0  
**Author**: GitHub Copilot
