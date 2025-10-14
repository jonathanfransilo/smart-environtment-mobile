import 'package:dio/dio.dart';
import 'api_client.dart';

class InvoiceService {
  final Dio _dio = ApiClient.instance.dio;

  /// Get unpaid invoices for current user
  Future<Map<String, dynamic>> getUnpaidInvoices() async {
    try {
      final response = await _dio.get('/mobile/resident/invoices/unpaid');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      throw Exception('Failed to load unpaid invoices');
    } catch (e) {
      throw Exception('Error fetching unpaid invoices: $e');
    }
  }

  /// Get single invoice detail
  Future<Map<String, dynamic>> getInvoiceDetail(int invoiceId) async {
    try {
      final response = await _dio.get('/mobile/resident/invoices/$invoiceId');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data']['invoice'];
      }
      throw Exception('Failed to load invoice detail');
    } catch (e) {
      throw Exception('Error fetching invoice detail: $e');
    }
  }

  /// Dummy pay - marks invoice as paid (for testing)
  Future<Map<String, dynamic>> dummyPay(int invoiceId) async {
    try {
      final response = await _dio.post('/mobile/resident/invoices/$invoiceId/dummy-pay');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      throw Exception('Payment failed');
    } catch (e) {
      throw Exception('Error processing payment: $e');
    }
  }
}
