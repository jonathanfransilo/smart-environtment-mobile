import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/complaint.dart';
import 'token_storage.dart';

class CollectorComplaintService {
  static const String baseUrl =
      'https://smart-environment-web.citiasiainc.id/api/v1/mobile/collector';

  /// Get assigned complaints for the collector
  Future<List<Complaint>> getAssignedComplaints({String? status}) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      String url = '$baseUrl/complaints';
      if (status != null && status.isNotEmpty) {
        url += '?status=$status';
      }

      print('🌐 [ComplaintService] Fetching complaints from: $url');
      print('🔑 [ComplaintService] Token: ${token.substring(0, 20)}...');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - server tidak merespon');
        },
      );

      print('📡 [ComplaintService] Response status: ${response.statusCode}');
      print('📦 [ComplaintService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        print('🔍 [ComplaintService] Parsed data keys: ${data.keys}');
        
        // Handle jika data kosong atau null
        if (data['data'] == null) {
          print('⚠️ [ComplaintService] data[\'data\'] is NULL');
          return [];
        }
        
        dynamic complaintsData;
        
        // ✅ PERBAIKAN: Handle nested structure {"data": {"complaints": [...]}}
        if (data['data'] is Map && data['data']['complaints'] != null) {
          complaintsData = data['data']['complaints'];
          print('🔍 [ComplaintService] Found nested complaints array with ${complaintsData.length} items');
        }
        // Handle jika data adalah List langsung
        else if (data['data'] is List) {
          complaintsData = data['data'];
          print('🔍 [ComplaintService] Found direct complaints array with ${complaintsData.length} items');
        }
        // Handle jika data adalah Map (single object)
        else if (data['data'] is Map) {
          complaintsData = [data['data']];
          print('🔍 [ComplaintService] Found single complaint object, wrapped in array');
        }
        else {
          print('⚠️ [ComplaintService] Unknown data format, returning empty list');
          return [];
        }
        
        print('✅ [ComplaintService] Parsing ${complaintsData.length} complaints');
        
        final complaints = (complaintsData as List<dynamic>)
            .map((json) => Complaint.fromJson(json as Map<String, dynamic>))
            .toList();
            
        // Debug: print each complaint
        for (var complaint in complaints) {
          print('   📋 Complaint #${complaint.id}: ${complaint.type}, Status: ${complaint.status}');
        }
        
        return complaints;
      } else {
        print('❌ [ComplaintService] Error response: ${response.statusCode}');
        print('   Body: ${response.body}');
        throw Exception('Gagal mengambil data pelaporan: ${response.body}');
      }
    } catch (e) {
      print('❌ [CollectorComplaintService] Error in getAssignedComplaints: $e');
      throw Exception('Error: $e');
    }
  }

  /// Get complaint detail by ID
  Future<Complaint> getComplaintDetail(String complaintId) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/complaints/$complaintId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Complaint.fromJson(data['data'] as Map<String, dynamic>);
      } else {
        throw Exception('Gagal mengambil detail pelaporan: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  /// Update complaint status
  Future<void> updateComplaintStatus({
    required String complaintId,
    required String status,
    String? notes,
    File? photo,
  }) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/complaints/$complaintId/update-status'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['status'] = status;
      if (notes != null && notes.isNotEmpty) {
        request.fields['notes'] = notes;
      }

      if (photo != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'photo',
            photo.path,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Gagal update status: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  /// Get collector statistics
  Future<Map<String, dynamic>> getCollectorStatistics() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/complaints/statistics'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception('Gagal mengambil statistik: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
