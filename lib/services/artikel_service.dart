import 'package:dio/dio.dart';
import '../models/artikel_model.dart';
import 'api_client.dart';
import 'dart:developer' as developer;

class ArtikelService {
  final Dio _dio = ApiClient.instance.dio;

  /// Get list of articles with pagination, search, sorting, and filter
  ///
  /// Parameters:
  /// - [page]: Page number (default: 1)
  /// - [perPage]: Items per page (default: 10)
  /// - [search]: Search query for title/content
  /// - [sortBy]: Field to sort by (e.g., 'created_at', 'title', 'view_count')
  /// - [sortOrder]: Sort order ('asc' or 'desc')
  /// - [isFeatured]: Filter by featured status
  Future<ArtikelListResponse> getArticles({
    int page = 1,
    int perPage = 10,
    String? search,
    String? sortBy,
    String? sortOrder,
    bool? isFeatured,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };

      if (search != null && search.isNotEmpty) {
        queryParameters['search'] = search;
      }
      if (sortBy != null && sortBy.isNotEmpty) {
        queryParameters['sort_by'] = sortBy;
      }
      if (sortOrder != null && sortOrder.isNotEmpty) {
        queryParameters['sort_order'] = sortOrder;
      }
      if (isFeatured != null) {
        queryParameters['is_featured'] = isFeatured;
      }

      final response = await _dio.get(
        '/mobile/resident/articles',
        queryParameters: queryParameters,
      );

      if (response.statusCode == 200) {
        developer.log('Raw response: ${response.data}', name: 'ArtikelService');
        developer.log(
          'Response type: ${response.data.runtimeType}',
          name: 'ArtikelService',
        );

        // Handle different response formats
        try {
          // If response is already the expected format
          if (response.data is Map<String, dynamic>) {
            final responseMap = response.data as Map<String, dynamic>;

            // Handle Laravel API response format with success wrapper
            // Response: {success: true, data: {articles: [...], meta: {...}}}
            if (responseMap.containsKey('success') &&
                responseMap.containsKey('data')) {
              final dataWrapper = responseMap['data'] as Map<String, dynamic>;

              // Articles are in data.articles
              if (dataWrapper.containsKey('articles')) {
                developer.log(
                  'Found articles in nested structure',
                  name: 'ArtikelService',
                );
                return ArtikelListResponse(
                  data: (dataWrapper['articles'] as List)
                      .map((item) => ArtikelModel.fromJson(item))
                      .toList(),
                  meta: PaginationMeta.fromJson(dataWrapper['meta'] ?? {}),
                );
              }
            }

            // Standard format without success wrapper
            return ArtikelListResponse.fromJson(responseMap);
          }
          // If response is directly a list (without 'data' wrapper)
          else if (response.data is List) {
            return ArtikelListResponse(
              data: (response.data as List)
                  .map((item) => ArtikelModel.fromJson(item))
                  .toList(),
              meta: PaginationMeta(
                currentPage: page,
                lastPage: 1,
                perPage: perPage,
                total: (response.data as List).length,
                from: 1,
                to: (response.data as List).length,
              ),
            );
          } else {
            throw Exception(
              'Unexpected response format: ${response.data.runtimeType}',
            );
          }
        } catch (e) {
          developer.log('Error parsing response: $e', name: 'ArtikelService');
          rethrow;
        }
      } else {
        throw Exception('Failed to load articles: ${response.statusCode}');
      }
    } on DioException catch (e) {
      developer.log(
        'Error fetching articles: ${e.message}',
        name: 'ArtikelService',
      );
      if (e.response != null) {
        developer.log(
          'Response data: ${e.response?.data}',
          name: 'ArtikelService',
        );
        developer.log(
          'Response status: ${e.response?.statusCode}',
          name: 'ArtikelService',
        );

        final message = e.response?.data is Map
            ? (e.response?.data['message'] ??
                  e.response?.data['error'] ??
                  'Server error')
            : e.message ?? 'Unknown error';

        throw Exception('Gagal memuat artikel: $message');
      } else {
        throw Exception('Koneksi gagal. Periksa internet Anda.');
      }
    } catch (e) {
      developer.log('Unexpected error: $e', name: 'ArtikelService');
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  /// Get article detail by ID or slug
  ///
  /// Parameters:
  /// - [identifier]: Article ID (int) or slug (string)
  Future<ArtikelModel> getArticleDetail(dynamic identifier) async {
    try {
      final response = await _dio.get('/mobile/resident/articles/$identifier');

      if (response.statusCode == 200) {
        developer.log(
          'Detail response: ${response.data}',
          name: 'ArtikelService',
        );

        // Handle Laravel API response format with success wrapper
        if (response.data is Map<String, dynamic>) {
          final responseMap = response.data as Map<String, dynamic>;

          // Check for success wrapper: {success: true, data: {...}}
          if (responseMap.containsKey('success') &&
              responseMap.containsKey('data')) {
            final articleData = responseMap['data'];

            // If data contains 'article' key
            if (articleData is Map && articleData.containsKey('article')) {
              return ArtikelModel.fromJson(articleData['article']);
            }
            // Data is directly the article
            return ArtikelModel.fromJson(articleData);
          }

          // Standard format: {data: {...}}
          final data = responseMap['data'] ?? responseMap;
          return ArtikelModel.fromJson(data);
        }

        throw Exception('Invalid response format');
      } else {
        throw Exception(
          'Failed to load article detail: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      developer.log(
        'Error fetching article detail: ${e.message}',
        name: 'ArtikelService',
      );
      if (e.response != null) {
        developer.log(
          'Response data: ${e.response?.data}',
          name: 'ArtikelService',
        );

        final message = e.response?.data is Map
            ? (e.response?.data['message'] ??
                  e.response?.data['error'] ??
                  'Server error')
            : e.message ?? 'Unknown error';

        throw Exception('Gagal memuat detail artikel: $message');
      } else {
        throw Exception('Koneksi gagal. Periksa internet Anda.');
      }
    } catch (e) {
      developer.log('Unexpected error: $e', name: 'ArtikelService');
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  /// Get featured/latest articles for homepage/dashboard
  ///
  /// Parameters:
  /// - [limit]: Number of articles to fetch (default: 5)
  Future<List<ArtikelModel>> getFeaturedArticles({int limit = 5}) async {
    try {
      final response = await _dio.get(
        '/mobile/resident/articles/featured',
        queryParameters: {'limit': limit},
      );

      if (response.statusCode == 200) {
        developer.log(
          'Featured response: ${response.data}',
          name: 'ArtikelService',
        );

        // Handle Laravel API response format with success wrapper
        if (response.data is Map<String, dynamic>) {
          final responseMap = response.data as Map<String, dynamic>;

          // Check for success wrapper: {success: true, data: {...}}
          if (responseMap.containsKey('success') &&
              responseMap.containsKey('data')) {
            final dataWrapper = responseMap['data'];

            // If data contains 'articles' key
            if (dataWrapper is Map && dataWrapper.containsKey('articles')) {
              final articles = dataWrapper['articles'];
              if (articles is List) {
                return articles
                    .map((item) => ArtikelModel.fromJson(item))
                    .toList();
              }
            }
            // Data is directly array of articles
            else if (dataWrapper is List) {
              return dataWrapper
                  .map((item) => ArtikelModel.fromJson(item))
                  .toList();
            }
          }

          // Standard format: {data: [...]}
          final data = responseMap['data'];
          if (data is List) {
            return data.map((item) => ArtikelModel.fromJson(item)).toList();
          }
        }
        // Direct array response
        else if (response.data is List) {
          return (response.data as List)
              .map((item) => ArtikelModel.fromJson(item))
              .toList();
        }

        throw Exception('Invalid response format');
      } else {
        throw Exception(
          'Failed to load featured articles: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      developer.log(
        'Error fetching featured articles: ${e.message}',
        name: 'ArtikelService',
      );
      if (e.response != null) {
        developer.log(
          'Response data: ${e.response?.data}',
          name: 'ArtikelService',
        );

        final message = e.response?.data is Map
            ? (e.response?.data['message'] ??
                  e.response?.data['error'] ??
                  'Server error')
            : e.message ?? 'Unknown error';

        throw Exception('Gagal memuat artikel unggulan: $message');
      } else {
        throw Exception('Koneksi gagal. Periksa internet Anda.');
      }
    } catch (e) {
      developer.log('Unexpected error: $e', name: 'ArtikelService');
      throw Exception('Terjadi kesalahan: $e');
    }
  }
}
