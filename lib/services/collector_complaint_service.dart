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
        final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;

        // Guard: pastikan struktur data ada
        if (data['data'] == null) {
          print('⚠️ [ComplaintService] data[\'data\'] is NULL');
          return <Complaint>[];
        }

        late final List<dynamic> complaintsData;

        // Handle nested structure {"data": {"complaints": [...]} }
        if (data['data'] is Map && (data['data'] as Map).containsKey('complaints') && data['data']['complaints'] is List) {
          complaintsData = (data['data']['complaints'] as List<dynamic>);
          print('🔍 [ComplaintService] Found nested complaints array with ${complaintsData.length} items');
        }
        // Handle jika data adalah List langsung
        else if (data['data'] is List) {
          complaintsData = (data['data'] as List<dynamic>);
          print('🔍 [ComplaintService] Found direct complaints array with ${complaintsData.length} items');
        }
        // Handle jika data adalah Map (single object)
        else if (data['data'] is Map) {
          complaintsData = <dynamic>[data['data'] as Map<String, dynamic>];
          print('🔍 [ComplaintService] Found single complaint object, wrapped in array');
        } else {
          print('⚠️ [ComplaintService] Unknown data format, returning empty list');
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

      final response = await http.get(
        Uri.parse('$baseUrl/complaints/$complaintId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
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
    XFile? photo,
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
