import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/token_storage.dart';
import '../models/off_schedule_pickup.dart';

class OffSchedulePickupService {
  final String baseUrl = ApiConfig.baseUrl;

  /// Create off-schedule pickup request
  Future<OffSchedulePickup> createRequest({
    required int serviceAccountId,
    required String requestedPickupDate,
    String? requestedPickupTime,
    required int bagCount,
    String? residentNote,
  }) async {
    try {
      print('🔍 [OffSchedulePickup] Getting token from TokenStorage...');
      final token = await TokenStorage.getToken();
      print('🔑 [OffSchedulePickup] Token: ${token != null ? "Found (${token.substring(0, 20)}...)" : "NOT FOUND"}');
      
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final url = Uri.parse('$baseUrl/mobile/resident/off-schedule-pickups');
      
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
          if (requestedPickupTime != null) 'requested_pickup_time': requestedPickupTime,
          'bag_count': bagCount,
          if (residentNote != null) 'resident_note': residentNote,
        }),
      );

      print('📤 [OffSchedulePickup] Create request - Status: ${response.statusCode}');
      print('📤 [OffSchedulePickup] Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return OffSchedulePickup.fromJson(data['data']);
      } else if (response.statusCode == 422) {
        final error = jsonDecode(response.body);
        final errors = error['errors']['details'] as Map<String, dynamic>?;
        final firstError = errors?.values.first;
        final errorMessage = firstError is List ? firstError.first : firstError.toString();
        throw Exception(errorMessage);
      } else {
        throw Exception('Failed to create pickup request: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [OffSchedulePickup] Error creating request: $e');
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

      print('📥 [OffSchedulePickup] List requests - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> pickupsJson = data['data'];
        return pickupsJson.map((json) => OffSchedulePickup.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load pickup requests: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [OffSchedulePickup] Error listing requests: $e');
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

      print('📥 [OffSchedulePickup] Get detail - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return OffSchedulePickup.fromJson(data['data']);
      } else {
        throw Exception('Failed to load pickup detail: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [OffSchedulePickup] Error getting detail: $e');
      rethrow;
    }
  }

  /// Confirm completed pickup
  Future<OffSchedulePickup> confirmPickup(int id) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final url = Uri.parse('$baseUrl/mobile/resident/off-schedule-pickups/$id/confirm');
      
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('✅ [OffSchedulePickup] Confirm pickup - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return OffSchedulePickup.fromJson(data['data']);
      } else {
        throw Exception('Failed to confirm pickup: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [OffSchedulePickup] Error confirming pickup: $e');
      rethrow;
    }
  }
}
