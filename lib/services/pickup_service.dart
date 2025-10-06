import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PickupService {
  static const String _keyPengambilan = 'pengambilan_terakhir';

  // Simpan data pengambilan baru
  static Future<void> savePickupData({
    required String userName,
    required String address,
    required String idPengambilan,
    required List<Map<String, dynamic>> selectedItems,
    required double totalPrice,
    required String imagePath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing data
    List<Map<String, dynamic>> existingData = await getPickupHistory();
    
    // Create new pickup entry
    final newPickup = {
      'name': userName,
      'address': address,
      'idPengambilan': idPengambilan,
      'items': selectedItems,
      'totalPrice': totalPrice,
      'image': imagePath,
      'timestamp': DateTime.now().toIso8601String(),
      'date': _formatDate(DateTime.now()),
    };
    
    // Add to beginning of list (most recent first)
    existingData.insert(0, newPickup);
    
    // Keep only last 10 entries
    if (existingData.length > 10) {
      existingData = existingData.sublist(0, 10);
    }
    
    // Save to SharedPreferences
    final String jsonData = json.encode(existingData);
    await prefs.setString(_keyPengambilan, jsonData);
  }
  
  // Ambil semua data pengambilan
  static Future<List<Map<String, dynamic>>> getPickupHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonData = prefs.getString(_keyPengambilan);
    
    if (jsonData != null) {
      final List<dynamic> decoded = json.decode(jsonData);
      return decoded.cast<Map<String, dynamic>>();
    }
    
    return [];
  }
  
  // Format tanggal ke string yang readable
  static String _formatDate(DateTime date) {
    const List<String> days = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
    ];
    const List<String> months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    
    String dayName = days[date.weekday - 1];
    String monthName = months[date.month - 1];
    
    return '$dayName, ${date.day} $monthName ${date.year} ${date.hour.toString().padLeft(2, '0')}.${date.minute.toString().padLeft(2, '0')}';
  }
}