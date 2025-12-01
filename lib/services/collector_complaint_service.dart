import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
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
      final previewToken = token.length > 20 ? '${token.substring(0, 20)}...' : token;
      print('🔑 [ComplaintService] Token: $previewToken');

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
        final Map<String, dynamic> responseData = json.decode(response.body) as Map<String, dynamic>;

        // ✅ Sesuai dokumentasi API: {"success": true, "data": {"complaints": [...]}}
        if (!responseData.containsKey('success') || responseData['success'] != true) {
          print('⚠️ [ComplaintService] API returned success=false');
          return <Complaint>[];
        }

        final data = responseData['data'];
        if (data == null) {
          print('⚠️ [ComplaintService] data is NULL');
          return <Complaint>[];
        }

        // ✅ Parse struktur: {"data": {"complaints": [...], "meta": {...}}}
        List<dynamic> complaintsData;
        
        if (data is Map && data.containsKey('complaints') && data['complaints'] is List) {
          complaintsData = data['complaints'] as List<dynamic>;
          print('🔍 [ComplaintService] Found complaints array: ${complaintsData.length} items');
          
          // Log pagination metadata jika ada
          if (data.containsKey('meta')) {
            final meta = data['meta'];
            print('📄 [ComplaintService] Pagination: page ${meta['current_page']} of ${meta['last_page']} (total: ${meta['total']})');
          }
        } else if (data is List) {
          // Fallback: jika data langsung array
          complaintsData = data;
          print('🔍 [ComplaintService] Found direct array: ${complaintsData.length} items');
        } else {
          print('⚠️ [ComplaintService] Unknown data format');
          return <Complaint>[];
        }

        print('✅ [ComplaintService] Parsing ${complaintsData.length} complaints');

        final complaints = complaintsData
            .map((j) => Complaint.fromJson(j as Map<String, dynamic>))
            .toList(growable: false);

        for (final complaint in complaints) {
          print('   📋 Complaint #${complaint.id}: ${complaint.type}, Status: ${complaint.status}');
        }

        return complaints;
      }
      print('❌ [ComplaintService] Error response: ${response.statusCode}');
      print('   Body: ${response.body}');
      throw Exception('Gagal mengambil data pelaporan: ${response.body}');
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

      print('🔍 [ComplaintService] Getting detail for complaint #$complaintId');

      final response = await http.get(
        Uri.parse('$baseUrl/complaints/$complaintId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 [ComplaintService] Detail response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body) as Map<String, dynamic>;
        
        // ✅ DEBUG: Print full response
        print('📦 [ComplaintService] FULL RESPONSE BODY:');
        print(json.encode(responseData));
        print('=====================================');
        
        // ✅ Sesuai dokumentasi: {"success": true, "data": {"complaint": {...}}}
        if (responseData['success'] != true) {
          throw Exception('API returned success=false');
        }
        
        final data = responseData['data'];
        if (data == null) {
          throw Exception('Data is null');
        }
        
        // Parse complaint object (bisa langsung atau nested dalam 'complaint')
        final complaintData = data.containsKey('complaint') ? data['complaint'] : data;
        
        print('📋 [ComplaintService] Parsing complaint data:');
        print('   - Has service_account: ${complaintData.containsKey('service_account')}');
        print('   - service_account_id: ${complaintData['service_account_id']}');
        if (complaintData.containsKey('service_account')) {
          print('   - service_account data: ${complaintData['service_account']}');
        }
        
        return Complaint.fromJson(complaintData as Map<String, dynamic>);
      } else {
        throw Exception('Gagal mengambil detail pelaporan: ${response.body}');
      }
    } catch (e) {
      print('❌ [ComplaintService] Error getting detail: $e');
      throw Exception('Error: $e');
    }
  }

  /// Update complaint status
  Future<Map<String, dynamic>> updateComplaintStatus({
    required String complaintId,
    required String status,
    String? notes,
    XFile? photo,
  }) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      print('🔄 [ComplaintService] Updating complaint #$complaintId to status: $status');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/complaints/$complaintId/update-status'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['status'] = status;
      
      if (notes != null && notes.isNotEmpty) {
        request.fields['notes'] = notes;
      }

      // ✅ Sesuai dokumentasi: resolution_photo wajib jika status=resolved
      if (photo != null) {
        print('📸 [ComplaintService] Adding resolution_photo');
        request.files.add(
          await http.MultipartFile.fromPath(
            'resolution_photo', // ✅ Field name sesuai API documentation
            photo.path,
          ),
        );
      } else if (status == 'resolved') {
        print('⚠️ [ComplaintService] WARNING: No photo provided for resolved status');
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📡 [ComplaintService] Update response: ${response.statusCode}');
      print('📦 [ComplaintService] Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Gagal update status: ${response.body}');
      }
      
      // ✅ Parse response sesuai dokumentasi: {"success": true, "message": "...", "data": {...}}
      final Map<String, dynamic> responseData = json.decode(response.body) as Map<String, dynamic>;
      
      if (responseData['success'] != true) {
        throw Exception(responseData['message'] ?? 'Update failed');
      }
      
      print('✅ [ComplaintService] ${responseData['message']}');
      
      return responseData['data'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      print('❌ [ComplaintService] Error updating status: $e');
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
        final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception('Gagal mengambil statistik: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
