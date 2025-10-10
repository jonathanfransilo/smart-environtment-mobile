import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RiwayatPembayaranService {
  static const String _keyRiwayatPembayaran = 'riwayat_pembayaran';

  /// Model data untuk riwayat pembayaran
  static Map<String, dynamic> createRiwayatPembayaran({
    required String id,
    required String namaKolektor,
    required String alamat,
    required List<Map<String, dynamic>> items,
    required double totalHarga,
    required DateTime tanggalPengambilan,
    String status = 'Selesai',
    String? metodePembayaran,
  }) {
    return {
      'id': id,
      'namaKolektor': namaKolektor,
      'alamat': alamat,
      'items': items,
      'totalHarga': totalHarga,
      'tanggalPengambilan': tanggalPengambilan.toIso8601String(),
      'status': status,
      'metodePembayaran': metodePembayaran ?? 'Tunai',
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  /// Simpan riwayat pembayaran baru
  static Future<void> saveRiwayatPembayaran(Map<String, dynamic> riwayat) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingData = prefs.getStringList(_keyRiwayatPembayaran) ?? [];
      
      // Tambahkan riwayat baru ke awal list
      existingData.insert(0, jsonEncode(riwayat));
      
      await prefs.setStringList(_keyRiwayatPembayaran, existingData);
    } catch (e) {
      throw Exception('Gagal menyimpan riwayat pembayaran: $e');
    }
  }

  /// Ambil semua riwayat pembayaran
  static Future<List<Map<String, dynamic>>> getRiwayatPembayaran() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList(_keyRiwayatPembayaran) ?? [];
      
      return data.map((item) {
        try {
          return Map<String, dynamic>.from(jsonDecode(item));
        } catch (e) {
          return <String, dynamic>{}; // Return empty map for corrupted data
        }
      }).where((item) => item.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  /// Ambil total pembayaran bulan ini
  static Future<double> getTotalPembayaranBulanIni() async {
    try {
      final riwayat = await getRiwayatPembayaran();
      final now = DateTime.now();
      double total = 0;

      for (final item in riwayat) {
        final tanggal = DateTime.parse(item['tanggalPengambilan']);
        if (tanggal.year == now.year && tanggal.month == now.month) {
          total += (item['totalHarga'] as num).toDouble();
        }
      }

      return total;
    } catch (e) {
      return 0;
    }
  }

  /// Ambil jumlah transaksi bulan ini
  static Future<int> getJumlahTransaksiBulanIni() async {
    try {
      final riwayat = await getRiwayatPembayaran();
      final now = DateTime.now();
      int count = 0;

      for (final item in riwayat) {
        final tanggal = DateTime.parse(item['tanggalPengambilan']);
        if (tanggal.year == now.year && tanggal.month == now.month) {
          count++;
        }
      }

      return count;
    } catch (e) {
      return 0;
    }
  }

  /// Hapus riwayat pembayaran berdasarkan ID
  static Future<bool> deleteRiwayatPembayaran(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList(_keyRiwayatPembayaran) ?? [];
      
      final filteredData = data.where((item) {
        try {
          final decoded = jsonDecode(item);
          return decoded['id'] != id;
        } catch (e) {
          return false;
        }
      }).toList();

      await prefs.setStringList(_keyRiwayatPembayaran, filteredData);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Format currency Indonesia
  static String formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  /// Format tanggal Indonesia
  static String formatDate(DateTime date) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ===== SISTEM TAGIHAN BULANAN =====

  /// Ambil tagihan yang belum dibayar (status: Menunggu Pembayaran)
  static Future<List<Map<String, dynamic>>> getTagihanPending() async {
    try {
      final allRiwayat = await getRiwayatPembayaran();
      return allRiwayat.where((item) => item['status'] == 'Menunggu Pembayaran').toList();
    } catch (e) {
      return [];
    }
  }

  /// Ambil total tagihan yang belum dibayar bulan ini
  static Future<double> getTotalTagihanPendingBulanIni() async {
    try {
      final tagihan = await getTagihanPending();
      final now = DateTime.now();
      double total = 0;

      for (final item in tagihan) {
        final tanggal = DateTime.parse(item['tanggalPengambilan']);
        if (tanggal.year == now.year && tanggal.month == now.month) {
          total += (item['totalHarga'] as num).toDouble();
        }
      }

      return total;
    } catch (e) {
      return 0;
    }
  }

  /// Bayar semua tagihan bulan ini sekaligus
  static Future<bool> bayarSemuaTagihanBulanIni() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList(_keyRiwayatPembayaran) ?? [];
      final now = DateTime.now();
      
      List<String> updatedData = [];
      bool adaPembayaran = false;

      for (final itemStr in data) {
        try {
          final item = jsonDecode(itemStr) as Map<String, dynamic>;
          final tanggal = DateTime.parse(item['tanggalPengambilan']);
          
          // Jika tagihan bulan ini dan status pending
          if (tanggal.year == now.year && 
              tanggal.month == now.month && 
              item['status'] == 'Menunggu Pembayaran') {
            
            // Update status menjadi Lunas
            item['status'] = 'Lunas';
            item['metodePembayaran'] = 'Transfer Bank';
            item['tanggalPembayaran'] = DateTime.now().toIso8601String();
            adaPembayaran = true;
          }
          
          updatedData.add(jsonEncode(item));
        } catch (e) {
          // Keep original if decode fails
          updatedData.add(itemStr);
        }
      }

      if (adaPembayaran) {
        await prefs.setStringList(_keyRiwayatPembayaran, updatedData);
      }

      return adaPembayaran;
    } catch (e) {
      return false;
    }
  }

  /// Hitung jumlah tagihan pending bulan ini
  static Future<int> getJumlahTagihanPendingBulanIni() async {
    try {
      final tagihan = await getTagihanPending();
      final now = DateTime.now();
      int count = 0;

      for (final item in tagihan) {
        final tanggal = DateTime.parse(item['tanggalPengambilan']);
        if (tanggal.year == now.year && tanggal.month == now.month) {
          count++;
        }
      }

      return count;
    } catch (e) {
      return 0;
    }
  }
}