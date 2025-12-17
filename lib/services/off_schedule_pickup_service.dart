import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/token_storage.dart';
import '../models/off_schedule_pickup.dart';

class OffSchedulePickupService {
  final String baseUrl = ApiConfig.baseUrl;

  /// Get active/pending request for a specific service account
  /// Returns the most recent active request (sent, processing, pending status)
  Future<OffSchedulePickup?> getActiveRequestByServiceAccount(int serviceAccountId) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      // Get all requests and filter by service account
      final url = Uri.parse('$baseUrl/mobile/resident/off-schedule-pickups?per_page=50&page=1');
      
      print('[SEARCH] [getActiveRequest] Fetching pickups for serviceAccountId: $serviceAccountId');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('[SEARCH] [getActiveRequest] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> pickupsJson = data['data'];
        
        print('[SEARCH] [getActiveRequest] Total pickups found: ${pickupsJson.length}');
        
        // Find active request for this service account
        // Active status: sent, processing, pending, completed, paid (exclude rejected only)
        final activeStatuses = ['sent', 'processing', 'pending', 'completed', 'paid'];
        
        for (final json in pickupsJson) {
          // Get service account ID from either nested object or direct field
          int pickupServiceAccountId = 0;
          if (json['service_account'] != null && json['service_account']['id'] != null) {
            final saId = json['service_account']['id'];
            pickupServiceAccountId = saId is int ? saId : int.tryParse(saId.toString()) ?? 0;
          } else if (json['service_account_id'] != null) {
            final saId = json['service_account_id'];
            pickupServiceAccountId = saId is int ? saId : int.tryParse(saId.toString()) ?? 0;
          }
          
          final requestStatus = json['request_status'] ?? '';
          final pickupId = json['id'] ?? 0;
          
          print('[SEARCH] [getActiveRequest] Checking pickup $pickupId: serviceAccountId=$pickupServiceAccountId, status=$requestStatus');
          
          if (pickupServiceAccountId == serviceAccountId && 
              activeStatuses.contains(requestStatus)) {
            print('[OK] [getActiveRequest] Found active request: $pickupId with status $requestStatus');
            return OffSchedulePickup.fromJson(json);
          }
        }
        print('[ERROR] [getActiveRequest] No active request found for serviceAccountId: $serviceAccountId');
        return null;
      } else {
        print('[ERROR] [getActiveRequest] API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('[ERROR] [getActiveRequest] Error: $e');
      return null;
    }
  }

  /// Get pricing info for off-schedule pickups
  Future<Map<String, dynamic>> getPricingInfo() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final url = Uri.parse('$baseUrl/mobile/resident/off-schedule-pickups/pricing-info');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('data')) {
          return Map<String, dynamic>.from(data['data']);
        }
        return {};
      } else {
        throw Exception('Failed to fetch pricing info: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Preview scheduled pickups that will be skipped
  Future<Map<String, dynamic>> previewSkipScheduled({
    required int serviceAccountId,
    required String requestedPickupDate,
  }) async {
    try {
      final token = await TokenStorage.getToken();
      
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final url = Uri.parse('$baseUrl/mobile/resident/off-schedule-pickups/preview-skip');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'service_account_id': serviceAccountId,
          'requested_pickup_date': requestedPickupDate,
        }),
      );

      print('[SEARCH] [PreviewSkip] Response status: ${response.statusCode}');
      print('[SEARCH] [PreviewSkip] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? {};
      } else if (response.statusCode == 422) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Validation error');
      } else {
        throw Exception('Failed to preview skip: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Create off-schedule pickup request with optional skip next scheduled
  Future<Map<String, dynamic>> createRequest({
    required int serviceAccountId,
    required String requestedPickupDate,
    String? requestedPickupTime,
    String? note,
    bool skipNextScheduled = false,
  }) async {
    try {
      final token = await TokenStorage.getToken();
      
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final url = Uri.parse('$baseUrl/mobile/resident/off-schedule-pickups');
      
      final requestBody = {
        'service_account_id': serviceAccountId,
        'requested_pickup_date': requestedPickupDate,
        if (requestedPickupTime != null) 'requested_pickup_time': requestedPickupTime,
        if (note != null) 'resident_note': note,
        'skip_next_scheduled': skipNextScheduled,
      };

      print('[SEND] [CreateRequest] Request body: ${jsonEncode(requestBody)}');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      print('[NET] [CreateRequest] Response status: ${response.statusCode}');
      print('[NET] [CreateRequest] Response body: ${response.body}');


      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        // Return full response including message and skipped_pickups
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'Request berhasil dibuat',
          'data': data['data'],
          'skipped_pickups': data['skipped_pickups'] ?? [],
        };
      } else if (response.statusCode == 422) {
        final error = jsonDecode(response.body);
        // Handle the new error format: {errors: {message: "...", details: {...}}}
        final errors = error['errors'] as Map<String, dynamic>?;
        if (errors != null) {
          // Check for detailed validation errors first
          final details = errors['details'] as Map<String, dynamic>?;
          if (details != null && details.isNotEmpty) {
            // Get the first validation error message from details
            final firstField = details.values.first;
            if (firstField is List && firstField.isNotEmpty) {
              throw Exception(firstField.first.toString());
            }
          }
          // Fallback to general error message
          if (errors['message'] != null) {
            throw Exception(errors['message'].toString());
          }
          // Legacy format: errors directly contains field errors
          final firstError = errors.values.first;
          final errorMessage = firstError is List ? firstError.first : firstError.toString();
          throw Exception(errorMessage);
        }
        throw Exception(error['message'] ?? 'Validation error');
      } else {
        throw Exception('Failed to create pickup request: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// List own requests
  Future<List<OffSchedulePickup>> listRequests({
    String? status,
    int perPage = 15,
    int page = 1,
  }) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      var url = '$baseUrl/mobile/resident/off-schedule-pickups?per_page=$perPage&page=$page';
      if (status != null) {
        url += '&status=$status';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> pickupsJson = data['data'];
        return pickupsJson.map((json) => OffSchedulePickup.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load pickup requests: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get request detail
  Future<OffSchedulePickup> getRequestDetail(int id) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final url = Uri.parse('$baseUrl/mobile/resident/off-schedule-pickups/$id');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return OffSchedulePickup.fromJson(data['data']);
      } else {
        throw Exception('Failed to load pickup detail: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Confirm completed pickup by resident
  /// PUT /mobile/resident/off-schedule-pickups/{id}/confirm
  Future<OffSchedulePickup> confirmPickup(int id) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final url = Uri.parse('$baseUrl/mobile/resident/off-schedule-pickups/$id/confirm');
      
      print('[NET] [OffSchedulePickupService] PUT $url');
      
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('[NET] [OffSchedulePickupService] Confirm response: ${response.statusCode}');
      print('[DATA] [OffSchedulePickupService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          print('[OK] [OffSchedulePickupService] Pickup #$id confirmed successfully');
          return OffSchedulePickup.fromJson(data['data']);
        } else {
          final msg = data['message']?.toString() ?? 'Gagal mengkonfirmasi pengambilan';
          throw Exception(msg);
        }
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        final msg = data['message']?.toString() ?? 'Pengambilan tidak dapat dikonfirmasi';
        throw Exception(msg);
      } else if (response.statusCode == 404) {
        throw Exception('Pengambilan tidak ditemukan');
      } else {
        throw Exception('Gagal mengkonfirmasi: ${response.statusCode}');
      }
    } catch (e) {
      print('[ERROR] [OffSchedulePickupService] Confirm pickup failed: $e');
      rethrow;
    }
  }



  /// Get off-schedule pickups for collector (today's assigned tasks)
  /// This will be called by collector to see their assigned off-schedule pickups
  /// Endpoint: /mobile/collector/off-schedule-pickups/
  Future<List<OffSchedulePickup>> getCollectorTodayPickups() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        print('[ERROR] [OffSchedulePickupService] No authentication token found');
        throw Exception('No authentication token found');
      }

      print('[SEARCH] [OffSchedulePickupService] Fetching assigned pickups for collector...');
      print('[KEY] [OffSchedulePickupService] Token: ${token.substring(0, 20)}...');
      
      // ✅ ENDPOINT sesuai dokumentasi API (tanpa trailing slash)
      final url = Uri.parse('$baseUrl/mobile/collector/off-schedule-pickups');
      
      print('[NET] [OffSchedulePickupService] API URL: $url');
      print('[SEND] [OffSchedulePickupService] Request headers:');
      print('   - Content-Type: application/json');
      print('   - Accept: application/json');
      print('   - Authorization: Bearer ${token.substring(0, 20)}...');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('[NET] [OffSchedulePickupService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[DATA] [OffSchedulePickupService] Response structure: ${data.keys.toList()}');
        
        // Sesuai dokumentasi API: {"success": true, "data": [...]}
        if (data['success'] == true && data['data'] is List) {
          final List<dynamic> pickupsJson = data['data'];
          print('[STATS] [OffSchedulePickupService] Total pickups from API: ${pickupsJson.length}');
          
          if (pickupsJson.isNotEmpty) {
            print('[LIST] [OffSchedulePickupService] Sample pickup:');
            print('   ID: ${pickupsJson.first['id']}');
            print('   Request Status: ${pickupsJson.first['request_status']}');
            print('   Requested Date: ${pickupsJson.first['requested_pickup_date']}');
            print('   Service Account: ${pickupsJson.first['service_account']}');
          }
          
          // Parse semua pickups dari API
          final allPickups = pickupsJson
              .map((json) => OffSchedulePickup.fromJson(json))
              .toList();
          
          print('[DATA] [OffSchedulePickupService] Parsed ${allPickups.length} total pickups');
          
          // ✅ FILTER: Hanya tampilkan request dengan status aktif
          // - request_status: 'processing' (sudah ditugaskan ke collector)
          // - EXCLUDE: 'sent' (belum ditugaskan), 'rejected' (ditolak), 
          //            'completed' (selesai), 'paid' (lunas), 'pending' (menunggu konfirmasi)
          final activePickups = allPickups.where((pickup) {
            final isProcessing = pickup.requestStatus == 'processing';
            final notCancelled = pickup.status != 'cancelled';
            
            if (!isProcessing || !notCancelled) {
              print('   [SKIP] Filtered out Pickup #${pickup.id}: request_status=${pickup.requestStatus}, status=${pickup.status}');
            }
            
            return isProcessing && notCancelled;
          }).toList();
          
          print('[OK] [OffSchedulePickupService] Active pickups: ${activePickups.length} (filtered from ${allPickups.length})');
          return activePickups;
        } else {
          print('[WARN] [OffSchedulePickupService] Unexpected response format');
          return [];
        }
      } else {
        print('[ERROR] [OffSchedulePickupService] Failed: ${response.statusCode}');
        print('[PAGE] [OffSchedulePickupService] Response body: ${response.body}');
        
        if (response.statusCode == 401) {
          print('[AUTH] [OffSchedulePickupService] Authentication failed - token may be invalid');
          print('[TIP] [OffSchedulePickupService] Ensure the endpoint has auth:sanctum middleware');
        }
        
        return [];
      }
    } catch (e, stackTrace) {
      print('[CRASH] [OffSchedulePickupService] Error: $e');
      print('   Stack trace:');
      print(stackTrace);
      
      // Return empty list untuk menghindari crash
      return [];
    }
  }

  /// Start/confirm off-schedule pickup for collector
  /// This changes status from pending/scheduled to on_progress
  /// Endpoint: /mobile/collector/off-schedule-pickups/{id}/start
  static Future<(bool success, String? message)> startPickup(int id) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/mobile/collector/off-schedule-pickups/$id/start');
      
      print('[SEARCH] [OffSchedulePickupService] Starting pickup ID: $id');
      print('[NET] [OffSchedulePickupService] API URL: $url');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('[NET] [OffSchedulePickupService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[OK] [OffSchedulePickupService] Start pickup SUCCESS');
        
        if (data['success'] == true) {
          return (true, null);
        } else {
          final msg = data['errors']?['message']?.toString() ?? 'Gagal memulai pengambilan';
          return (false, msg);
        }
      } else {
        print('[ERROR] [OffSchedulePickupService] Failed: ${response.statusCode}');
        print('[PAGE] [OffSchedulePickupService] Response: ${response.body}');
        
        final data = jsonDecode(response.body);
        final msg = data['errors']?['message']?.toString() ?? 'Gagal memulai pengambilan';
        return (false, msg);
      }
    } catch (e) {
      print('[CRASH] [OffSchedulePickupService] Error: $e');
      return (false, 'Terjadi kesalahan: $e');
    }
  }

  /// ✅ Get ALL off-schedule pickups for collector (including completed for history)
  /// Returns all pickups without filtering by status - used for history display
  Future<List<OffSchedulePickup>> getCollectorAllPickups() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }
      
      // ✅ ENDPOINT sesuai dokumentasi API (tanpa trailing slash)
      final url = Uri.parse('$baseUrl/mobile/collector/off-schedule-pickups');
      
      print('[NET] [OffSchedulePickupService] getAllPickups API URL: $url');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('[NET] [OffSchedulePickupService] getAllPickups Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Sesuai dokumentasi API: {"success": true, "data": [...]}
        if (data['success'] == true && data['data'] is List) {
          final List<dynamic> pickupsJson = data['data'];
          print('[STATS] [OffSchedulePickupService] Total pickups (all): ${pickupsJson.length}');
          
          // DEBUG: Log sample pickup data to see waste_items structure
          if (pickupsJson.isNotEmpty) {
            final samplePickup = pickupsJson.first as Map<String, dynamic>;
            print('[DEBUG] Sample pickup keys: ${samplePickup.keys.toList()}');
            if (samplePickup['waste_items'] != null) {
              print('[DEBUG] waste_items found: ${samplePickup['waste_items']}');
            } else {
              print('[DEBUG] waste_items is NULL in API response');
            }
            // Check if there's delivery or items under different key
            if (samplePickup['delivery'] != null) {
              print('[DEBUG] delivery found: ${samplePickup['delivery']}');
            }
            if (samplePickup['items'] != null) {
              print('[DEBUG] items found: ${samplePickup['items']}');
            }
            if (samplePickup['invoice'] != null) {
              print('[DEBUG] invoice found: ${samplePickup['invoice']}');
            }
          }
          
          // Parse semua pickups dari API TANPA FILTER
          final allPickups = pickupsJson
              .map((json) => OffSchedulePickup.fromJson(json))
              .toList();
          
          print('[OK] [OffSchedulePickupService] Successfully loaded ${allPickups.length} all pickups');
          return allPickups;
        } else {
          print('[WARN] [OffSchedulePickupService] Unexpected response format');
          return [];
        }
      } else {
        print('[ERROR] [OffSchedulePickupService] Failed: ${response.statusCode}');
        return [];
      }
    } catch (e, stackTrace) {
      print('[CRASH] [OffSchedulePickupService] Error: $e');
      print('   Stack trace:');
      print(stackTrace);
      return [];
    }
  }
}
