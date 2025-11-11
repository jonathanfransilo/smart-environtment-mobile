import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'token_storage.dart';
import '../utils/file.dart'; // Conditional import for File class

class ComplaintService {
  static const String baseUrl =
      'https://smart-environment-web.citiasiainc.id/api/v1/mobile/resident/complaints';

  /// Get list of complaints
  /// Returns: (success, message, data)
  static Future<(bool, String, List<Map<String, dynamic>>?)> getComplaints({
    String? status, // 'open', 'in_progress', 'resolved', 'cancelled'
    int? limit,
    int? offset,
  }) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        return (false, 'Token tidak ditemukan. Silakan login kembali.', null);
      }

      // Build query parameters
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();

      final uri = Uri.parse(
        baseUrl,
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      print('📋 Get Complaints Response: ${response.statusCode}');
      print('📋 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          // Handle nested structure: {success: true, data: {complaints: [...], meta: {...}}}
          final dataWrapper = jsonResponse['data'];

          if (dataWrapper is Map<String, dynamic> &&
              dataWrapper.containsKey('complaints')) {
            // Complaints are in data.complaints
            final List<dynamic> complaintsData =
                dataWrapper['complaints'] ?? [];
            final List<Map<String, dynamic>> complaints = complaintsData
                .map((item) => item as Map<String, dynamic>)
                .toList();

            return (true, 'Berhasil memuat daftar keluhan', complaints);
          } else if (dataWrapper is List) {
            // Direct array (old format)
            final List<Map<String, dynamic>> complaints = dataWrapper
                .map((item) => item as Map<String, dynamic>)
                .toList();

            return (true, 'Berhasil memuat daftar keluhan', complaints);
          } else {
            return (false, 'Format respons tidak valid', null);
          }
        } else {
          final String message =
              jsonResponse['message']?.toString() ?? 'Gagal memuat keluhan';
          return (false, message, null);
        }
      } else if (response.statusCode == 401) {
        return (false, 'Sesi telah berakhir. Silakan login kembali.', null);
      } else {
        final errorData = json.decode(response.body);
        final String message =
            errorData['message']?.toString() ?? 'Gagal memuat keluhan';
        return (false, message, null);
      }
    } on SocketException {
      return (false, 'Tidak ada koneksi internet', null);
    } on http.ClientException {
      return (false, 'Koneksi ke server gagal', null);
    } catch (e) {
      print('❌ Error get complaints: $e');
      return (false, 'Terjadi kesalahan: $e', null);
    }
  }

  /// Create new complaint
  /// Returns: (success, message, data)
  static Future<(bool, String, Map<String, dynamic>?)> createComplaint({
    required String
    type, // Jenis keluhan (illegal_dumping, uncollected_waste, damaged_facility, other)
    required String description,
    required String location, // Lokasi kejadian
    String? serviceAccountId, // ID service account (opsional)
    File? image,
  }) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        return (false, 'Token tidak ditemukan. Silakan login kembali.', null);
      }

      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));
      request.headers['Authorization'] = 'Bearer $token';

      // Add text fields
      request.fields['type'] = type;
      request.fields['description'] = description;
      request.fields['address'] = location; // API menggunakan field 'address'

      if (serviceAccountId != null) {
        request.fields['service_account_id'] = serviceAccountId;
      }

      // Add image file if provided (sesuai dokumentasi: evidence_photos[])
      if (image != null) {
        if (kIsWeb) {
          // Untuk web, gunakan fromBytes
          final bytes = await image.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'evidence_photos[]', // Array field name sesuai API docs
              bytes,
              filename: 'complaint_image.jpg',
            ),
          );
        } else {
          // Untuk mobile, gunakan fromPath
          request.files.add(
            await http.MultipartFile.fromPath('evidence_photos[]', image.path),
          );
        }
      }

      print('📤 Creating complaint:');
      print('  Type: $type');
      print(
        '  Description: ${description.substring(0, description.length > 50 ? 50 : description.length)}...',
      );
      print('  Location: $location');
      print('  Service Account ID: ${serviceAccountId ?? 'null'}');
      print('  Has image: ${image != null}');

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamedResponse);

      print('📋 Create Complaint Response: ${response.statusCode}');
      print('📋 Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        print('📋 JSON Response: $jsonResponse');

        if (jsonResponse['success'] == true) {
          final dataWrapper = jsonResponse['data'];

          // Handle nested structure: {success: true, data: {complaint: {...}}}
          if (dataWrapper is Map<String, dynamic>) {
            // Check if data contains 'complaint' key
            if (dataWrapper.containsKey('complaint')) {
              final complaintData =
                  dataWrapper['complaint'] as Map<String, dynamic>;
              return (true, 'Keluhan berhasil dikirim', complaintData);
            }
            // Data is directly the complaint
            return (true, 'Keluhan berhasil dikirim', dataWrapper);
          } else {
            return (false, 'Format respons tidak valid', null);
          }
        } else {
          final String message =
              jsonResponse['message']?.toString() ?? 'Gagal mengirim keluhan';
          return (false, message, null);
        }
      } else if (response.statusCode == 401) {
        return (false, 'Sesi telah berakhir. Silakan login kembali.', null);
      } else {
        print('❌ Error status: ${response.statusCode}');
        print('❌ Error body: ${response.body}');

        try {
          final errorData = json.decode(response.body);
          final String message =
              errorData['message']?.toString() ?? 'Gagal mengirim keluhan';

          // Check for validation errors
          if (errorData.containsKey('errors')) {
            final errors = errorData['errors'];
            print('❌ Validation errors: $errors');
            return (false, 'Validasi gagal: $message', null);
          }

          return (false, message, null);
        } catch (e) {
          print('❌ Error parsing response: $e');
          return (
            false,
            'Gagal mengirim keluhan (Status: ${response.statusCode})',
            null,
          );
        }
      }
    } on SocketException {
      return (false, 'Tidak ada koneksi internet', null);
    } on http.ClientException {
      return (false, 'Koneksi ke server gagal', null);
    } catch (e) {
      print('❌ Error create complaint: $e');
      return (false, 'Terjadi kesalahan: $e', null);
    }
  }

  /// Get complaint statistics
  /// Returns: (success, message, data)
  static Future<(bool, String, Map<String, dynamic>?)> getStatistics() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        return (false, 'Token tidak ditemukan. Silakan login kembali.', null);
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/statistics'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      print('📊 Get Statistics Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          final dataWrapper = jsonResponse['data'];

          // Handle nested or direct structure
          if (dataWrapper is Map<String, dynamic>) {
            // Check if data contains 'statistics' key
            if (dataWrapper.containsKey('statistics')) {
              final stats = dataWrapper['statistics'] as Map<String, dynamic>;
              return (true, 'Berhasil memuat statistik', stats);
            }
            // Data is directly the stats
            return (true, 'Berhasil memuat statistik', dataWrapper);
          } else {
            return (false, 'Format respons tidak valid', null);
          }
        } else {
          final String message =
              jsonResponse['message']?.toString() ?? 'Gagal memuat statistik';
          return (false, message, null);
        }
      } else if (response.statusCode == 401) {
        return (false, 'Sesi telah berakhir. Silakan login kembali.', null);
      } else {
        return (false, 'Gagal memuat statistik', null);
      }
    } catch (e) {
      print('❌ Error get statistics: $e');
      return (false, 'Terjadi kesalahan: $e', null);
    }
  }

  /// Get complaint detail by ID
  /// Returns: (success, message, data)
  static Future<(bool, String, Map<String, dynamic>?)> getComplaintDetail(
    String id,
  ) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        return (false, 'Token tidak ditemukan. Silakan login kembali.', null);
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/$id'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      print('📋 Get Complaint Detail Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          final dataWrapper = jsonResponse['data'];

          // Handle nested structure: {success: true, data: {complaint: {...}}}
          if (dataWrapper is Map<String, dynamic>) {
            // Check if data contains 'complaint' key
            if (dataWrapper.containsKey('complaint')) {
              final complaint =
                  dataWrapper['complaint'] as Map<String, dynamic>;
              return (true, 'Berhasil memuat detail keluhan', complaint);
            }
            // Data is directly the complaint
            return (true, 'Berhasil memuat detail keluhan', dataWrapper);
          } else {
            return (false, 'Format respons tidak valid', null);
          }
        } else {
          final String message =
              jsonResponse['message']?.toString() ??
              'Gagal memuat detail keluhan';
          return (false, message, null);
        }
      } else if (response.statusCode == 401) {
        return (false, 'Sesi telah berakhir. Silakan login kembali.', null);
      } else if (response.statusCode == 404) {
        return (false, 'Keluhan tidak ditemukan', null);
      } else {
        return (false, 'Gagal memuat detail keluhan', null);
      }
    } catch (e) {
      print('❌ Error get complaint detail: $e');
      return (false, 'Terjadi kesalahan: $e', null);
    }
  }

  /// Update complaint (only for status 'open')
  /// Returns: (success, message, data)
  static Future<(bool, String, Map<String, dynamic>?)> updateComplaint({
    required String id,
    String? category,
    String? description,
    String? location,
    File? image,
  }) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        return (false, 'Token tidak ditemukan. Silakan login kembali.', null);
      }

      var request = http.MultipartRequest('PUT', Uri.parse('$baseUrl/$id'));
      request.headers['Authorization'] = 'Bearer $token';

      // Add text fields only if provided
      if (category != null) request.fields['category'] = category;
      if (description != null) request.fields['description'] = description;
      if (location != null)
        request.fields['address'] = location; // API menggunakan field 'address'

      // Add image file if provided
      if (image != null) {
        if (kIsWeb) {
          // Untuk web, gunakan fromBytes
          final bytes = await image.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'image',
              bytes,
              filename: 'complaint_image.jpg',
            ),
          );
        } else {
          // Untuk mobile, gunakan fromPath
          request.files.add(
            await http.MultipartFile.fromPath('image', image.path),
          );
        }
      }

      print('📤 Updating complaint: $id');

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamedResponse);

      print('📋 Update Complaint Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          final dataWrapper = jsonResponse['data'];

          // Handle nested structure: {success: true, data: {complaint: {...}}}
          if (dataWrapper is Map<String, dynamic>) {
            // Check if data contains 'complaint' key
            if (dataWrapper.containsKey('complaint')) {
              final complaintData =
                  dataWrapper['complaint'] as Map<String, dynamic>;
              return (true, 'Keluhan berhasil diperbarui', complaintData);
            }
            // Data is directly the complaint
            return (true, 'Keluhan berhasil diperbarui', dataWrapper);
          } else {
            return (false, 'Format respons tidak valid', null);
          }
        } else {
          final String message =
              jsonResponse['message']?.toString() ??
              'Gagal memperbarui keluhan';
          return (false, message, null);
        }
      } else if (response.statusCode == 401) {
        return (false, 'Sesi telah berakhir. Silakan login kembali.', null);
      } else if (response.statusCode == 403) {
        return (false, 'Keluhan tidak dapat diubah', null);
      } else if (response.statusCode == 404) {
        return (false, 'Keluhan tidak ditemukan', null);
      } else {
        final errorData = json.decode(response.body);
        final String message =
            errorData['message']?.toString() ?? 'Gagal memperbarui keluhan';
        return (false, message, null);
      }
    } catch (e) {
      print('❌ Error update complaint: $e');
      return (false, 'Terjadi kesalahan: $e', null);
    }
  }

  /// Cancel complaint
  /// Returns: (success, message, data)
  static Future<(bool, String, Map<String, dynamic>?)> cancelComplaint(
    String id,
  ) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        return (false, 'Token tidak ditemukan. Silakan login kembali.', null);
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/$id/cancel'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      print('📋 Cancel Complaint Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          final dataWrapper = jsonResponse['data'];

          // Handle nested structure: {success: true, data: {complaint: {...}}}
          if (dataWrapper is Map<String, dynamic>) {
            // Check if data contains 'complaint' key
            if (dataWrapper.containsKey('complaint')) {
              final complaintData =
                  dataWrapper['complaint'] as Map<String, dynamic>;
              return (true, 'Keluhan berhasil dibatalkan', complaintData);
            }
            // Data is directly the complaint
            return (true, 'Keluhan berhasil dibatalkan', dataWrapper);
          } else {
            return (false, 'Format respons tidak valid', null);
          }
        } else {
          final String message =
              jsonResponse['message']?.toString() ??
              'Gagal membatalkan keluhan';
          return (false, message, null);
        }
      } else if (response.statusCode == 401) {
        return (false, 'Sesi telah berakhir. Silakan login kembali.', null);
      } else if (response.statusCode == 403) {
        return (false, 'Keluhan tidak dapat dibatalkan', null);
      } else if (response.statusCode == 404) {
        return (false, 'Keluhan tidak ditemukan', null);
      } else {
        final errorData = json.decode(response.body);
        final String message =
            errorData['message']?.toString() ?? 'Gagal membatalkan keluhan';
        return (false, message, null);
      }
    } catch (e) {
      print('❌ Error cancel complaint: $e');
      return (false, 'Terjadi kesalahan: $e', null);
    }
  }
}
