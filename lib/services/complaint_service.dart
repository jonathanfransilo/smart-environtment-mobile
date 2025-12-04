import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'token_storage.dart';
import '../config/api_config.dart';
import '../utils/file.dart'; // Conditional import for File class

class ComplaintService {
  // ✅ FIX: Gunakan format URL yang konsisten dengan API lainnya
  static String get baseUrl => '${ApiConfig.baseUrl}/mobile/resident/complaints';
  static Future<(bool, String, List<Map<String, dynamic>>?)> getComplaints({
    String? status,
    String? type,
    int? serviceAccountId,
    int? perPage,
  }) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        return (false, 'Token tidak ditemukan. Silakan login kembali.', null);
      }

      // Build query parameters
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;
      if (type != null) queryParams['type'] = type;
      if (serviceAccountId != null) queryParams['service_account_id'] = serviceAccountId.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();

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

  static Future<(bool, String, Map<String, dynamic>?)> createComplaint({
    required String type,
    required String description,
    String? location,
    double? latitude,
    double? longitude,
    int? serviceAccountId,
    File? image, 
    List<File>? images, 
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
      if (location != null && location.isNotEmpty) {
        request.fields['address'] = location;
      }
      if (latitude != null) {
        request.fields['latitude'] = latitude.toString();
      }
      if (longitude != null) {
        request.fields['longitude'] = longitude.toString();
      }

      if (serviceAccountId != null) {
        request.fields['service_account_id'] = serviceAccountId.toString();
      }

      // Add images - support both single and multiple
      final filesToUpload = <File>[];
      if (images != null && images.isNotEmpty) {
        filesToUpload.addAll(images);
      } else if (image != null) {
        filesToUpload.add(image);
      }

      // Add all image files (sesuai dokumentasi: evidence_photos[])
      for (var file in filesToUpload) {
        if (kIsWeb) {
          // Untuk web, gunakan fromBytes
          final bytes = await file.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'evidence_photos[]', // Array field name sesuai API docs
              bytes,
              filename:
                  'complaint_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          );
        } else {
          // Untuk mobile, gunakan fromPath
          request.files.add(
            await http.MultipartFile.fromPath('evidence_photos[]', file.path),
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
      print('  Number of images: ${filesToUpload.length}');

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
      if (location != null) {
        request.fields['address'] = location; // API menggunakan field 'address'
      }

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

  /// Konfirmasi Penyelesaian Pengaduan
  /// Hanya berlaku untuk pengaduan dengan status 'pending_confirmation'
  /// (khususnya tipe 'sampah_tidak_diangkut')
  /// 
  /// Parameters:
  /// - id: ID pengaduan
  /// - confirmed: true untuk konfirmasi selesai, false untuk menolak
  /// - rejectionNote: Alasan penolakan (wajib jika confirmed=false, max: 500 karakter)
  /// 
  /// Returns: (success, message, data)
  static Future<(bool, String, Map<String, dynamic>?)> confirmResolution({
    required String id,
    required bool confirmed,
    String? rejectionNote,
  }) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        return (false, 'Token tidak ditemukan. Silakan login kembali.', null);
      }

      // Build request body
      final body = <String, dynamic>{
        'confirmed': confirmed,
      };
      
      // Add rejection note if rejecting
      if (!confirmed && rejectionNote != null && rejectionNote.isNotEmpty) {
        body['rejection_note'] = rejectionNote;
      }

      print('📤 Confirming resolution for complaint: $id');
      print('   Confirmed: $confirmed');
      if (!confirmed) print('   Rejection Note: $rejectionNote');

      final response = await http
          .post(
            Uri.parse('$baseUrl/$id/confirm-resolution'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      print('📋 Confirm Resolution Response: ${response.statusCode}');
      print('📋 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          final String successMessage = jsonResponse['message']?.toString() ?? 
              (confirmed 
                  ? 'Terima kasih! Pengaduan telah dikonfirmasi selesai.'
                  : 'Pengaduan dikembalikan ke status dalam proses.');
          
          final dataWrapper = jsonResponse['data'];

          // Handle response structure
          if (dataWrapper is Map<String, dynamic>) {
            return (true, successMessage, dataWrapper);
          } else {
            return (true, successMessage, null);
          }
        } else {
          final String message =
              jsonResponse['message']?.toString() ??
              'Gagal mengkonfirmasi penyelesaian';
          return (false, message, null);
        }
      } else if (response.statusCode == 400) {
        final errorData = json.decode(response.body);
        final String message =
            errorData['message']?.toString() ??
            'Pengaduan ini tidak dalam status menunggu konfirmasi.';
        return (false, message, null);
      } else if (response.statusCode == 401) {
        return (false, 'Sesi telah berakhir. Silakan login kembali.', null);
      } else if (response.statusCode == 404) {
        return (false, 'Keluhan tidak ditemukan', null);
      } else if (response.statusCode == 422) {
        final errorData = json.decode(response.body);
        final String message =
            errorData['message']?.toString() ?? 'Validasi gagal';
        return (false, message, null);
      } else {
        final errorData = json.decode(response.body);
        final String message =
            errorData['message']?.toString() ??
            'Gagal mengkonfirmasi penyelesaian';
        return (false, message, null);
      }
    } on SocketException {
      return (false, 'Tidak ada koneksi internet', null);
    } on http.ClientException {
      return (false, 'Koneksi ke server gagal', null);
    } catch (e) {
      print('❌ Error confirm resolution: $e');
      return (false, 'Terjadi kesalahan: $e', null);
    }
  }
}
