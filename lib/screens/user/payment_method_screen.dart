import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/payment_service.dart';
import '../../models/payment_transaction.dart';
import 'payment_process_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  final List<Map<String, dynamic>> invoices;

  const PaymentMethodScreen({
    super.key,
    required this.invoices,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  final PaymentService _paymentService = PaymentService();
  final currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String? _selectedPaymentType;
  String? _selectedChannel;
  bool _isProcessing = false;

  double get _totalAmount {
    return widget.invoices.fold(
      0.0,
      (sum, invoice) => sum + (invoice['total_amount'] ?? 0).toDouble(),
    );
  }

  List<int> get _invoiceIds {
    return widget.invoices
        .map((inv) => inv['id'] as int)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final paymentMethods = _paymentService.getAvailablePaymentMethods();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pilih Metode Pembayaran',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Total amount banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade800],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Pembayaran',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currencyFormat.format(_totalAmount),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.invoices.length} Tagihan',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Payment methods list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: paymentMethods.length,
              itemBuilder: (context, index) {
                final method = paymentMethods[index];
                final isExpanded = _selectedPaymentType == method.type;

                return _buildPaymentMethodCard(method, isExpanded);
              },
            ),
          ),

          // Process button
          if (_selectedPaymentType != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Lanjutkan Pembayaran',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard(PaymentMethod method, bool isExpanded) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isExpanded ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isExpanded ? Colors.blue.shade700 : Colors.grey.shade200,
          width: isExpanded ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () {
              setState(() {
                if (_selectedPaymentType == method.type) {
                  _selectedPaymentType = null;
                  _selectedChannel = null;
                } else {
                  _selectedPaymentType = method.type;
                  _selectedChannel = null;
                }
              });
            },
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isExpanded
                    ? Colors.blue.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getMethodIcon(method.type),
                color: isExpanded ? Colors.blue.shade700 : Colors.grey.shade600,
              ),
            ),
            title: Text(
              method.name,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: isExpanded ? Colors.blue.shade700 : Colors.black87,
              ),
            ),
            trailing: Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: isExpanded ? Colors.blue.shade700 : Colors.grey,
            ),
          ),

          // Channels (untuk VA dan E-Wallet)
          if (isExpanded && method.channels != null)
            ...method.channels!.map((channel) => _buildChannelOption(channel)),

          // Untuk QRIS (langsung tanpa pilihan channel)
          if (isExpanded && method.type == 'qris')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Scan QR Code dengan aplikasi mobile banking atau e-wallet apapun',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedChannel = 'qris';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Pilih QRIS',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChannelOption(PaymentChannel channel) {
    final isSelected = _selectedChannel == channel.id;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedChannel = channel.id;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue.shade700 : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: channel.id,
              groupValue: _selectedChannel,
              onChanged: (value) {
                setState(() {
                  _selectedChannel = value;
                });
              },
              activeColor: Colors.blue.shade700,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.blue.shade700 : Colors.black87,
                    ),
                  ),
                  if (channel.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      channel.description!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMethodIcon(String type) {
    switch (type) {
      case 'virtual_account':
        return Icons.account_balance;
      case 'qris':
        return Icons.qr_code_2;
      case 'ewallet':
        return Icons.account_balance_wallet;
      default:
        return Icons.payment;
    }
  }

  Future<void> _processPayment() async {
    if (_selectedPaymentType == null) {
      _showError('Pilih metode pembayaran');
      return;
    }

    // Untuk VA dan E-Wallet, harus pilih channel
    if (_selectedPaymentType != 'qris' && _selectedChannel == null) {
      _showError('Pilih channel pembayaran');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final payment = await _paymentService.createPayment(
        invoiceIds: _invoiceIds,
        paymentType: _selectedPaymentType!,
        paymentChannel: _selectedChannel,
      );

      if (!mounted) return;

      // Check if this is a continuing payment (not new)
      final isContinuing = payment.createdAt != null && 
          DateTime.now().difference(payment.createdAt!).inMinutes > 1;

      if (isContinuing && mounted) {
        // Show info dialog for continuing payment
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Melanjutkan Pembayaran',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'Anda memiliki pembayaran yang belum diselesaikan untuk tagihan ini. Lanjutkan pembayaran sebelumnya?',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Batal',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                ),
                child: Text(
                  'Lanjutkan',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ),
        );

        if (shouldContinue != true) {
          setState(() {
            _isProcessing = false;
          });
          return;
        }
      }

      if (!mounted) return;

      // Navigate to payment process screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentProcessScreen(
            payment: payment,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }
}
