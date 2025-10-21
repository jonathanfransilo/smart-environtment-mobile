import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/payment_transaction.dart';

class PaymentService {
  final Dio _dio = ApiClient.instance.dio;

  /// Create new payment transaction
  /// 
  /// Parameters:
  /// - invoiceIds: List of invoice IDs to pay
  /// - paymentType: 'virtual_account', 'qris', or 'ewallet'
  /// - paymentChannel: Specific channel (e.g., 'bca', 'gopay', 'shopeepay')
  Future<PaymentTransaction> createPayment({
    required List<int> invoiceIds,
    required String paymentType,
    String? paymentChannel,
  }) async {
    try {
      final response = await _dio.post(
        '/mobile/resident/payments/create',
        data: {
          'invoice_ids': invoiceIds,
          'payment_type': paymentType,
          if (paymentChannel != null) 'payment_channel': paymentChannel,
        },
      );

      if ((response.statusCode == 200 || response.statusCode == 201) && 
          response.data['success'] == true) {
        // Backend returns payment data directly in 'payment' key
        final paymentData = response.data['payment'];
        return PaymentTransaction.fromJson(paymentData);
      }

      throw Exception(response.data['message'] ?? 'Failed to create payment');
    } on DioException catch (e) {
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final data = e.response!.data;
        
        // Handle authentication error
        if (statusCode == 401) {
          throw Exception('Sesi Anda telah berakhir. Silakan login kembali.');
        }
        
        // Handle validation errors
        if (statusCode == 422 && data is Map) {
          final errors = data['errors'] as Map?;
          if (errors != null && errors.isNotEmpty) {
            final firstError = errors.values.first;
            throw Exception(firstError is List ? firstError.first : firstError.toString());
          }
        }
        
        // Handle other errors
        final message = data is Map ? (data['message'] ?? 'Payment creation failed') : 'Payment creation failed';
        throw Exception(message);
      }
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error creating payment: $e');
    }
  }

  /// Check payment status
  Future<PaymentTransaction> checkPaymentStatus(String orderId) async {
    try {
      final response = await _dio.get(
        '/mobile/resident/payments/$orderId/status',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return PaymentTransaction.fromJson(response.data['payment']);
      }

      throw Exception('Failed to check payment status');
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response!.data['message'] ?? 'Status check failed');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error checking payment status: $e');
    }
  }

  /// Get payment detail
  Future<PaymentTransaction> getPaymentDetail(int paymentId) async {
    try {
      final response = await _dio.get(
        '/mobile/resident/payments/$paymentId',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return PaymentTransaction.fromJson(response.data['data']['payment']);
      }

      throw Exception('Failed to get payment detail');
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response!.data['message'] ?? 'Failed to load payment');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error getting payment detail: $e');
    }
  }

  /// Get available payment methods
  /// This returns static list for now, but can be made dynamic from API
  List<PaymentMethod> getAvailablePaymentMethods() {
    return [
      PaymentMethod(
        id: 'va',
        name: 'Virtual Account',
        type: 'va',
        channels: [
          PaymentChannel(
            id: 'bca',
            name: 'BCA Virtual Account',
            description: 'Transfer via ATM/Mobile Banking BCA',
          ),
          PaymentChannel(
            id: 'bni',
            name: 'BNI Virtual Account',
            description: 'Transfer via ATM/Mobile Banking BNI',
          ),
          PaymentChannel(
            id: 'bri',
            name: 'BRI Virtual Account',
            description: 'Transfer via ATM/Mobile Banking BRI',
          ),
          PaymentChannel(
            id: 'permata',
            name: 'Permata Virtual Account',
            description: 'Transfer via ATM/Mobile Banking Permata',
          ),
        ],
      ),
      PaymentMethod(
        id: 'qris',
        name: 'QRIS',
        type: 'qris',
      ),
      PaymentMethod(
        id: 'ewallet',
        name: 'E-Wallet',
        type: 'ewallet',
        channels: [
          PaymentChannel(
            id: 'gopay',
            name: 'GoPay',
            description: 'Bayar dengan GoPay',
          ),
          PaymentChannel(
            id: 'shopeepay',
            name: 'ShopeePay',
            description: 'Bayar dengan ShopeePay',
          ),
        ],
      ),
    ];
  }

  /// Cancel payment
  Future<bool> cancelPayment(String orderId) async {
    try {
      final response = await _dio.post(
        '/mobile/resident/payments/$orderId/cancel',
      );

      if ((response.statusCode == 200 || response.statusCode == 201) && 
          response.data['success'] == true) {
        return true;
      }

      throw Exception(response.data['message'] ?? 'Failed to cancel payment');
    } on DioException catch (e) {
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final data = e.response!.data;
        
        // Handle specific errors
        if (statusCode == 400) {
          throw Exception(data['message'] ?? 'Payment cannot be cancelled');
        }
        
        final message = data is Map ? (data['message'] ?? 'Failed to cancel payment') : 'Failed to cancel payment';
        throw Exception(message);
      }
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error cancelling payment: $e');
    }
  }
}
