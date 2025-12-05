import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../config/api_config.dart';
import 'api_client.dart';

class PickupService {
  static const String _keyPengambilan = 'pengambilan_terakhir';
  static final Dio _dio = ApiClient.instance.dio;

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
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const List<String> months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    String dayName = days[date.weekday - 1];
    String monthName = months[date.month - 1];

    return '$dayName, ${date.day} $monthName ${date.year} ${date.hour.toString().padLeft(2, '0')}.${date.minute.toString().padLeft(2, '0')}';
  }

  // ========== API Methods ==========

  /// Ambil daftar waste items dengan pricing dari API
  static Future<
    (bool success, String? message, List<Map<String, dynamic>>? data)
  >
  getWasteItems() async {
    try {
      print('[NET] [PickupService] Calling API: ${ApiConfig.collectorWasteItems}');
      final response = await _dio.get(ApiConfig.collectorWasteItems);

      print('[NET] [PickupService] Response status: ${response.statusCode}');

      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true) {
        final data = body['data'] as List<dynamic>?;
        print('[DATA] [PickupService] Data received: ${data?.length} items');

        if (data != null) {
          final items = data.map((e) => e as Map<String, dynamic>).toList();
          print(
            '[OK] [PickupService] Successfully parsed ${items.length} waste items',
          );
          return (true, null, items);
        }
        return (true, null, <Map<String, dynamic>>[]);
      } else {
        final msg =
            body['errors']?['message']?.toString() ??
            'Gagal mengambil data waste items';
        print('[ERROR] [PickupService] API returned success=false: $msg');
        return (false, msg, null);
      }
    } on DioException catch (e) {
      print('[CRASH] [PickupService] DioException: ${e.type}, ${e.message}');
      print(
        '[CRASH] [PickupService] Response: ${e.response?.statusCode} - ${e.response?.data}',
      );

      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['errors']?['message']?.toString() ?? msg;
      }
      return (false, msg, null);
    } catch (e) {
      print('[CRASH] [PickupService] Exception: $e');
      return (false, 'Error: $e', null);
    }
  }

  /// Ambil daftar pickup hari ini dari API (untuk Collector)
  static Future<
    (bool success, String? message, List<Map<String, dynamic>>? data)
  >
  getTodayPickups() async {
    try {
      print('[SEARCH] [PickupService] ===== FETCHING TODAY PICKUPS =====');
      print(
        '[NET] [PickupService] Calling API: ${ApiConfig.collectorPickupsToday}',
      );
      print(
        '[TIME] [PickupService] Current time: ${DateTime.now().toIso8601String()}',
      );

      // Get logged in collector info - handle both int and string
      final prefs = await SharedPreferences.getInstance();
      final userIdRaw = prefs.get('user_id');
      final userId = userIdRaw?.toString();
      final userName = prefs.getString('user_name');
      final userRole = prefs.getString('user_role');

      print('[TAG] [PickupService] Logged in user:');
      print('   - ID: $userId (type: ${userIdRaw.runtimeType})');
      print('   - Name: $userName');
      print('   - Role: $userRole');

      final response = await _dio.get(ApiConfig.collectorPickupsToday);

      print('[NET] [PickupService] Response status: ${response.statusCode}');

      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true) {
        // API menggunakan key 'items' bukan 'data'
        final items = body['items'] as List<dynamic>?;
        print('[DATA] [PickupService] Received ${items?.length ?? 0} pickup items');

        if (items != null && items.isNotEmpty) {
          // Debug: Print first item structure
          print('[LIST] [PickupService] Sample pickup structure:');
          final firstItem = items.first as Map<String, dynamic>;
          print('   - Keys: ${firstItem.keys.toList()}');
          print('   - Pickup ID: ${firstItem['id']}');
          print('   - Collector ID: ${firstItem['collector_id']}');
          print('   - Status: ${firstItem['status']}');
          print('   - Date: ${firstItem['pickup_date']}');

          if (firstItem.containsKey('service_account')) {
            final sa = firstItem['service_account'] as Map<String, dynamic>?;
            print(
              '   - service_account: ${sa != null ? sa.keys.toList() : "null"}',
            );
            if (sa != null) {
              print('     • name: ${sa['name']}');
              print('     • contact_phone: ${sa['contact_phone']}');
            }
          } else {
            print('   - [WARN] No service_account key found!');
          }
          if (firstItem.containsKey('house_info')) {
            final houseInfo = firstItem['house_info'] as Map<String, dynamic>?;
            print('   - house_info keys: ${houseInfo?.keys.toList()}');
            if (houseInfo != null) {
              print('     • account_number: ${houseInfo['account_number']}');
              print('     • resident_name: ${houseInfo['resident_name']}');
              print('     • address: ${houseInfo['address']}');
            }
          }

          final pickups = items.map((e) => e as Map<String, dynamic>).toList();
          print(
            '[OK] [PickupService] Successfully parsed ${pickups.length} pickups',
          );
          print('═══════════════════════════════════════════════════════');
          return (true, null, pickups);
        }
        print('[WARN] [PickupService] No pickups found for today');
        print('═══════════════════════════════════════════════════════');
        return (true, null, <Map<String, dynamic>>[]);
      } else {
        final msg =
            body['errors']?['message']?.toString() ??
            'Gagal mengambil data pickup';
        print('[ERROR] [PickupService] API returned success=false: $msg');
        print('═══════════════════════════════════════════════════════');
        return (false, msg, null);
      }
    } on DioException catch (e) {
      print('[CRASH] [PickupService] DioException: ${e.type}, ${e.message}');
      print(
        '[CRASH] [PickupService] Response: ${e.response?.statusCode} - ${e.response?.data}',
      );
      print('═══════════════════════════════════════════════════════');
      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['errors']?['message']?.toString() ?? msg;
      }
      return (false, msg, null);
    } catch (e, stackTrace) {
      print('[CRASH] [PickupService] Exception: $e');
      print('Stack trace: $stackTrace');
      print('═══════════════════════════════════════════════════════');
      return (false, 'Error: $e', null);
    }
  }

  /// Ambil riwayat pickup yang sudah completed dari API (untuk Collector)
  static Future<
    (bool success, String? message, List<Map<String, dynamic>>? data)
  >
  getPickupHistoryFromAPI({int? limit}) async {
    try {
      print(
        '[NET] [PickupService] Calling API: ${ApiConfig.collectorPickupsHistory}',
      );

      final queryParams = limit != null ? {'limit': limit} : null;
      final response = await _dio.get(
        ApiConfig.collectorPickupsHistory,
        queryParameters: queryParams,
      );

      print('[NET] [PickupService] Response status: ${response.statusCode}');

      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true) {
        final data = body['data'] as List<dynamic>?;
        print(
          '[DATA] [PickupService] History data received: ${data?.length} items',
        );

        if (data != null) {
          final history = data.map((e) {
            final item = e as Map<String, dynamic>;

            // Transform data untuk UI
            final houseInfo = item['house_info'] as Map<String, dynamic>?;
            final wasteItems = item['waste_items'] as List<dynamic>?;

            // Transform waste items to match UI expectations
            final transformedItems =
                wasteItems?.map((wasteItem) {
                  final wi = wasteItem as Map<String, dynamic>;
                  return {
                    'category': wi['waste_category'] ?? 'Unknown',
                    'name':
                        '${wi['waste_category'] ?? 'Unknown'} ${wi['pocket_size'] ?? ''}',
                    'quantity': wi['quantity'] ?? 0,
                    'price': wi['unit_price'] ?? 0,
                    'totalPrice': wi['total_price'] ?? 0,
                  };
                }).toList() ??
                [];

            return {
              'id': item['id'],
              'idPengambilan': 'no ${item['id']}',
              'name':
                  houseInfo?['account_number'] ??
                  houseInfo?['resident_name'] ??
                  'N/A',
              'address': houseInfo?['address'] ?? 'N/A',
              'totalPrice': item['total_amount'] ?? 0,
              'image': item['photo_url'] ?? 'assets/images/dummy.jpg',
              'date': item['pickup_date'] ?? '',
              'dayName': item['day_name'] ?? '',
              'status': item['status'] ?? '',
              'items': transformedItems, // Use 'items' key for compatibility
              'notes': item['collector_notes'] ?? '',
            };
          }).toList();

          print(
            '[OK] [PickupService] Successfully parsed ${history.length} history items',
          );
          return (true, null, history);
        }
return (true, null, <Map<String, dynamic>>[]);
      } else {
        final msg =
            body['errors']?['message']?.toString() ??
            'Gagal mengambil riwayat pickup';
        print('[ERROR] [PickupService] API returned success=false: $msg');
        return (false, msg, null);
      }
    } on DioException catch (e) {
      print('[CRASH] [PickupService] DioException: ${e.type}, ${e.message}');
      print(
        '[CRASH] [PickupService] Response: ${e.response?.statusCode} - ${e.response?.data}',
      );

      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['errors']?['message']?.toString() ?? msg;
      }
      return (false, msg, null);
    } catch (e) {
      print('[CRASH] [PickupService] Exception: $e');
      return (false, 'Error: $e', null);
    }
  }

  /// Ambil detail pickup berdasarkan ID
  static Future<(bool success, String? message, Map<String, dynamic>? data)>
  getPickupDetail(int id) async {
    try {
      final response = await _dio.get('${ApiConfig.collectorPickupDetail}/$id');

      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>?;
        return (true, null, data);
      } else {
        final msg =
            body['errors']?['message']?.toString() ??
            'Gagal mengambil detail pickup';
        return (false, msg, null);
      }
    } on DioException catch (e) {
      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['errors']?['message']?.toString() ?? msg;
      }
      return (false, msg, null);
    } catch (e) {
      return (false, 'Error: $e', null);
    }
  }

  /// Start pickup (ubah status ke on_progress)
  static Future<(bool success, String? message)> startPickup(int id) async {
    try {
      final response = await _dio.put(
        '${ApiConfig.collectorPickupDetail}/$id/start',
      );

      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true) {
        return (true, null);
      } else {
        final msg =
            body['errors']?['message']?.toString() ?? 'Gagal memulai pickup';
        return (false, msg);
      }
    } on DioException catch (e) {
      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['errors']?['message']?.toString() ?? msg;
      }
      return (false, msg);
    } catch (e) {
      return (false, 'Error: $e');
    }
  }

  /// Complete pickup dengan waste items
  static Future<(bool success, String? message, Map<String, dynamic>? data)>
  completePickup({
    required int id,
    required String photo,
    required List<Map<String, dynamic>> wasteItems,
    String? collectorNotes,
  }) async {
    try {
      final url = '${ApiConfig.collectorPickupDetail}/$id/complete';
      print('[NET] [PickupService] Calling PUT $url');
      print('[DATA] [PickupService] Photo length: ${photo.length} chars');
      print('[DATA] [PickupService] Waste items: ${wasteItems.length} items');

      final response = await _dio.put(
        url,
        data: {
          'photo': photo,
          'waste_items': wasteItems,
          'collector_notes': collectorNotes,
        },
      );

      print('[NET] [PickupService] Response status: ${response.statusCode}');

      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>?;
        print('[OK] [PickupService] Complete pickup SUCCESS');
        return (true, null, data);
      } else {
        final msg =
            body['errors']?['message']?.toString() ??
            'Gagal menyelesaikan pickup';
        print('[ERROR] [PickupService] API returned success=false: $msg');
        return (false, msg, null);
      }
    } on DioException catch (e) {
      print('[CRASH] [PickupService] DioException Type: ${e.type}');
      print('[CRASH] [PickupService] DioException Message: ${e.message}');
      print('[CRASH] [PickupService] Response Status: ${e.response?.statusCode}');
      print('[CRASH] [PickupService] Response Data: ${e.response?.data}');
      print('[CRASH] [PickupService] Request Data: ${e.requestOptions.data}');

      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg =
            body['errors']?['message']?.toString() ??
            body['message']?.toString() ??
            msg;
      }
      return (false, msg, null);
    } catch (e) {
      print('[CRASH] [PickupService] General Exception: $e');
      return (false, 'Error: $e', null);
    }
  }

  /// Skip pickup dengan reason
  static Future<(bool success, String? message)> skipPickup({
    required int id,
    required String reason,
  }) async {
    try {
      final response = await _dio.put(
        '${ApiConfig.collectorPickupDetail}/$id/skip',
        data: {'reason': reason},
      );

      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true) {
        return (true, null);
      } else {
        final msg =
            body['errors']?['message']?.toString() ?? 'Gagal melewati pickup';
        return (false, msg);
      }
    } on DioException catch (e) {
      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['errors']?['message']?.toString() ?? msg;
      }
      return (false, msg);
    } catch (e) {
      return (false, 'Error: $e');
    }
  }
}
