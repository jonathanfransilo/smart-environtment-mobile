# Dokumentasi Fitur Nonaktifkan Akun Layanan

## Overview
Dokumentasi ini menjelaskan fitur "Nonaktifkan Akun" yang menggantikan fitur "Hapus Akun" dengan validasi tagihan yang belum dibayar.

## Perubahan dari Fitur Sebelumnya

### ❌ Sebelum (Hapus Akun):
- Tombol "Hapus Akun" berwarna merah
- Icon: `Icons.delete`
- Langsung menghapus akun tanpa validasi tagihan
- Konfirmasi simpel: "Apakah Anda yakin?"

### ✅ Sekarang (Nonaktifkan Akun):
- Tombol "Nonaktifkan Akun" berwarna orange
- Icon: `Icons.block`
- **Validasi tagihan** sebelum menonaktifkan
- Konfirmasi dengan penjelasan lengkap
- **Peringatan jika ada tagihan belum lunas**

## Fitur Utama

### 1. 🔍 Validasi Tagihan Otomatis

Sebelum menonaktifkan akun, sistem akan:
1. Menampilkan loading "Memeriksa tagihan..."
2. Mengecek semua tagihan yang belum dibayar
3. Menghitung total tagihan
4. Menentukan apakah akun bisa dinonaktifkan

### 2. ⚠️ Peringatan Tagihan Belum Lunas

Jika ada tagihan yang belum dibayar:

**Dialog Warning:**
```
┌─────────────────────────────────────────┐
│         ⚠️ (Icon Orange)                 │
│                                         │
│    Tidak Dapat Dinonaktifkan           │
│                                         │
│  Akun ini masih memiliki tagihan yang  │
│  belum dibayar. Silakan lunasi tagihan │
│  terlebih dahulu sebelum menonaktifkan │
│  akun.                                  │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ Jumlah Tagihan: 2 tagihan         │ │
│  │ ───────────────────────────────   │ │
│  │ Total Belum Dibayar: Rp 150.000   │ │
│  └───────────────────────────────────┘ │
│                                         │
│      [Tutup]    [Bayar]                │
└─────────────────────────────────────────┘
```

**Komponen:**
- ⚠️ Icon warning berwarna orange
- Title: "Tidak Dapat Dinonaktifkan"
- Pesan penjelasan yang jelas
- **Info Box** dengan:
  - Jumlah tagihan belum dibayar
  - Total nominal yang harus dibayar
  - Format currency: Rp XXX.XXX
  - Background merah muda dengan border merah
- **2 Tombol:**
  - "Tutup" (abu-abu) - menutup dialog
  - "Bayar" (hijau) - redirect ke pembayaran

### ✅ Konfirmasi Nonaktifkan

Jika **tidak ada tagihan** yang belum dibayar:

**Dialog Konfirmasi:**
```
┌─────────────────────────────────────────┐
│  🚫 Nonaktifkan Akun                    │
│                                         │
│  Apakah Anda yakin ingin menonaktifkan │
│  akun layanan ini? Akun yang           │
│  dinonaktifkan dapat diaktifkan        │
│  kembali kapan saja.                   │
│                                         │
│      [Batal]    [Nonaktifkan]          │
└─────────────────────────────────────────┘
```

**Komponen:**
- Icon block (🚫) berwarna orange
- Penjelasan konsekuensi nonaktifkan akun
- **✨ PENTING: Menyatakan akun BISA diaktifkan kembali**
- **2 Tombol:**
  - "Batal" (abu-abu)
  - "Nonaktifkan" (orange)

### 4. 🎉 Success Dialog

Setelah berhasil menonaktifkan:

```
┌─────────────────────────────────────────┐
│         ✓ (Icon Hijau)                  │
│                                         │
│    Akun Berhasil Dinonaktifkan         │
│                                         │
│  Akun layanan telah dinonaktifkan.     │
│  Anda dapat mengaktifkan kembali       │
│  akun ini kapan saja.                  │
│                                         │
│           [OK]                          │
└─────────────────────────────────────────┘
```

**Komponen:**
- ✅ Icon checkmark hijau
- Title: "Akun Berhasil Dinonaktifkan"
- **✨ Message yang jelas: Akun BISA diaktifkan kembali**
- Tombol "OK" (hijau)

## Workflow Lengkap

### Skenario 1: Ada Tagihan Belum Lunas ❌

```
User tap "Nonaktifkan Akun"
    ↓
Tampilkan dialog konfirmasi
    ↓
User tap "Nonaktifkan"
    ↓
Tampilkan loading "Memeriksa tagihan..."
    ↓
Fetch data tagihan dari API
    ↓
Cek: Ada tagihan belum dibayar?
    ↓ (YA)
Tampilkan dialog warning dengan detail tagihan
    ↓
User pilih:
    - Tutup → kembali ke detail akun
    - Bayar → SnackBar "Silakan bayar tagihan di menu Home"
```

### Skenario 2: Tidak Ada Tagihan ✅

```
User tap "Nonaktifkan Akun"
    ↓
Tampilkan dialog konfirmasi
    ↓
User tap "Nonaktifkan"
    ↓
Tampilkan loading "Memeriksa tagihan..."
    ↓
Fetch data tagihan dari API
    ↓
Cek: Ada tagihan belum dibayar?
    ↓ (TIDAK)
Panggil API deleteAccount()
    ↓
Tampilkan success dialog
    ↓
User tap "OK"
    ↓
Kembali ke list akun layanan (dengan refresh)
```

## API Integration

### InvoiceService.getUnpaidInvoices()

**Request:**
```dart
final invoiceData = await _invoiceService.getUnpaidInvoices();
```

**Response Structure:**
```json
{
  "unpaid_invoices": [
    {
      "id": 1,
      "period": "Oktober 2024",
      "amount": 75000,
      "due_date": "2024-10-25"
    },
    {
      "id": 2,
      "period": "November 2024",
      "amount": 75000,
      "due_date": "2024-11-25"
    }
  ],
  "total_amount": 150000
}
```

**Data Extraction:**
```dart
final invoices = invoiceData['unpaid_invoices'] as List<dynamic>?;
final totalAmount = invoiceData['total_amount'] as num? ?? 0;

// Check ada tagihan atau tidak
if (invoices != null && invoices.isNotEmpty) {
  // Ada tagihan → tampilkan warning
  _showTagihanBelumLunasDialog(context, invoices, totalAmount);
} else {
  // Tidak ada tagihan → lanjutkan nonaktifkan
  await _serviceAccountService.deleteAccount(akun.id);
}
```

### ServiceAccountService.deleteAccount()

**Request:**
```dart
await _serviceAccountService.deleteAccount(akun.id);
```

**Purpose:** Menonaktifkan akun layanan di server

## UI/UX Details

### Tombol "Nonaktifkan Akun"

**Styling:**
```dart
ElevatedButton.icon(
  onPressed: () => _konfirmasiNonaktifkan(context),
  icon: const Icon(Icons.block),
  label: const Text("Nonaktifkan Akun"),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.orange,      // Warna orange
    foregroundColor: Colors.white,       // Text putih
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
)
```

**Sebelumnya (Merah):**
```dart
backgroundColor: const Color.fromARGB(255, 220, 61, 61)  // Merah
icon: const Icon(Icons.delete)                            // Delete icon
```

**Sekarang (Orange):**
```dart
backgroundColor: Colors.orange  // Orange
icon: const Icon(Icons.block)   // Block icon
```

### Loading Dialog

**Loading Check Tagihan:**
```dart
showDialog(
  context: context,
  barrierDismissible: false,  // Tidak bisa ditutup dengan tap di luar
  builder: (ctx) => Center(
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Memeriksa tagihan...',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        ],
      ),
    ),
  ),
);
```

### Warning Dialog (Tagihan Belum Lunas)

**Layout:**
- Container dengan padding 16px
- Background: `Colors.red.shade50`
- Border: `Colors.red.shade200`
- Border radius: 12px

**Info Row 1:**
```
Jumlah Tagihan:         2 tagihan
```

**Info Row 2:**
```
Total Belum Dibayar:    Rp 150.000
```

**Currency Format:**
```dart
final currencyFormat = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

Text(currencyFormat.format(totalAmount))
// Output: Rp 150.000
```

### Success Dialog

**Icon:**
- Size: 48px
- Color: White
- Background: Hijau (`Color(0xFF4CAF50)`)
- Shape: Circle dengan padding 16px

**Button OK:**
- Full width
- Padding vertical: 12px
- Background: Hijau
- Text: Bold, 16px, putih

## Error Handling

### 1. Network Error
```dart
catch (error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Gagal menonaktifkan akun: $error'),
      backgroundColor: Colors.redAccent,
    ),
  );
}
```

### 2. API Error
Sama seperti network error, ditampilkan dalam SnackBar merah

### 3. Context Not Mounted
```dart
if (!context.mounted) return;
```
Cek sebelum setiap operasi yang menggunakan context

## Code Structure

### File Modified: `layanan_sampah_screen.dart`

**New Imports:**
```dart
import 'package:intl/intl.dart';
import '../../services/invoice_service.dart';
```

**New Service Instance:**
```dart
static final InvoiceService _invoiceService = InvoiceService();
```

**Methods:**

1. **`_nonaktifkanAkun(BuildContext context)`**
   - Main function untuk nonaktifkan akun
   - Check tagihan
   - Call API delete
   - Show success dialog

2. **`_showTagihanBelumLunasDialog(...)`**
   - Tampilkan warning dialog
   - Display invoice details
   - Show total amount
   - Buttons: Tutup & Bayar

3. **`_konfirmasiNonaktifkan(BuildContext context)`**
   - Konfirmasi dialog
   - Explain consequences
   - Buttons: Batal & Nonaktifkan

**Removed Methods:**
- ❌ `_hapusAkun()` (diganti dengan `_nonaktifkanAkun()`)
- ❌ `_konfirmasiHapus()` (diganti dengan `_konfirmasiNonaktifkan()`)

## Testing Checklist

### Test Case 1: Nonaktifkan dengan Tagihan ❌
- [ ] Tap tombol "Nonaktifkan Akun"
- [ ] Dialog konfirmasi muncul
- [ ] Tap "Nonaktifkan"
- [ ] Loading "Memeriksa tagihan..." muncul
- [ ] Warning dialog muncul (jika ada tagihan)
- [ ] Jumlah tagihan ditampilkan dengan benar
- [ ] Total amount terformat dengan benar (Rp XXX.XXX)
- [ ] Tap "Tutup" → kembali ke detail
- [ ] Tap "Bayar" → SnackBar muncul

### Test Case 2: Nonaktifkan tanpa Tagihan ✅
- [ ] Tap tombol "Nonaktifkan Akun"
- [ ] Dialog konfirmasi muncul
- [ ] Tap "Nonaktifkan"
- [ ] Loading "Memeriksa tagihan..." muncul
- [ ] API dipanggil (deleteAccount)
- [ ] Success dialog muncul
- [ ] Tap "OK" → kembali ke list
- [ ] List akun refresh otomatis

### Test Case 3: Error Handling
- [ ] Disconnect internet → error SnackBar muncul
- [ ] API error → error message ditampilkan
- [ ] Context check bekerja (no crashes)

### Test Case 4: UI/UX
- [ ] Tombol berwarna orange (bukan merah)
- [ ] Icon block (bukan delete)
- [ ] Text "Nonaktifkan Akun" (bukan "Hapus Akun")
- [ ] All dialogs responsive
- [ ] Currency format Indonesia (Rp X.XXX)
- [ ] Font Poppins consistent

## Future Improvements

### 1. **Navigate to Payment** 💳
   - Tombol "Bayar" langsung ke payment screen
   - Pass invoice data sebagai parameter
   
### 2. **Show Invoice List** 📋
   - Detail setiap tagihan di dialog
   - Period, amount, due date
   
### 3. **Email Notification** 📧
   - Send email saat akun dinonaktifkan
   - Include invoice summary jika ada
   
### 4. **Reactivate Account (PRIORITAS TINGGI)** 🔄
   - ✨ **Fitur untuk aktifkan kembali akun yang dinonaktifkan**
   - Tampilkan akun nonaktif di list dengan badge "Nonaktif"
   - Tombol "Aktifkan Kembali" di detail akun nonaktif
   - Konfirmasi dialog sebelum mengaktifkan kembali
   - Success notification setelah akun diaktifkan
   - **Backend API:**
     ```
     PUT /api/service-accounts/{id}/activate
     Response: { "success": true, "message": "Akun berhasil diaktifkan" }
     ```
   - **UI Flow:**
     ```
     List Akun → Akun Nonaktif (dengan badge) 
              → Detail Akun → Tombol "Aktifkan Kembali"
              → Konfirmasi → Success Dialog → Refresh List
     ```
   
### 5. **Archive Instead of Delete** 🗄️
   - Simpan data akun yang dinonaktifkan
   - Bisa restore nanti
   - History tracking

## Security & Validation

### ✅ Implemented:
- Validasi tagihan sebelum nonaktifkan
- Konfirmasi ganda (dialog konfirmasi + check tagihan)
- Error handling yang proper
- Context safety checks

### 🔒 Best Practices:
- Semua aksi destructive harus konfirmasi
- Loading indicator untuk async operations
- Clear error messages untuk user
- Format currency yang benar

## Version History

### v1.1.1 (Current) ✨
- ✅ **Update messaging: Akun yang dinonaktifkan DAPAT diaktifkan kembali**
- ✅ Konfirmasi dialog: "dapat diaktifkan kembali kapan saja"
- ✅ Success dialog: "Anda dapat mengaktifkan kembali akun ini kapan saja"
- ✅ Perubahan UX untuk memberikan informasi yang jelas dan tidak misleading
- ✅ User friendly: Tidak menakut-nakuti user dengan kata "tidak dapat digunakan lagi"

### v1.1.0
- ✅ Ganti "Hapus Akun" menjadi "Nonaktifkan Akun"
- ✅ Tambah validasi tagihan otomatis
- ✅ Tambah warning dialog untuk tagihan belum lunas
- ✅ Tambah success dialog
- ✅ Improve UI/UX dengan warna dan icon yang tepat
- ✅ Tambah currency formatting
- ✅ Improve error handling
- ❌ Messaging misleading: "tidak dapat digunakan lagi"

### v1.0.0 (Previous)
- Basic "Hapus Akun" functionality
- Simple confirmation dialog
- No invoice validation
