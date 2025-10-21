import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../services/api_client.dart';

class RiwayatPembayaranService {
  static const String _keyRiwayatPembayaran = 'riwayat_pembayaran';
  final Dio _dio = ApiClient.instance.dio;

  /// Get payment history from API
  Future<List<Map<String, dynamic>>> getPaymentHistory({int page = 1, int perPage = 15}) async {
    try {
      final response = await _dio.get(
        '/mobile/resident/payments',
        queryParameters: {
          'page': page,
          'per_page': perPage,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'];
        return data.map((item) => item as Map<String, dynamic>).toList();
      }

      throw Exception('Failed to load payment history');
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response!.data['message'] ?? 'Failed to load payment history');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error loading payment history: $e');
    }
  }

  /// Model data untuk riwayat pembayaran (legacy - untuk sampah)
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