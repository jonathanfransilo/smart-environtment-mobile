import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/off_schedule_pickup_service.dart';
import '../../models/off_schedule_pickup.dart';
import 'off_schedule_pickup_detail_screen.dart';

class OffSchedulePickupListScreen extends StatefulWidget {
  const OffSchedulePickupListScreen({super.key});

  @override
  State<OffSchedulePickupListScreen> createState() => _OffSchedulePickupListScreenState();
}

class _OffSchedulePickupListScreenState extends State<OffSchedulePickupListScreen> {
  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  List<OffSchedulePickup> _pickups = [];
  bool _isLoading = true;
  String? _selectedStatus;
  
  final List<Map<String, String>> _statusFilters = [
    {'value': '', 'label': 'Semua'},
    {'value': 'pending', 'label': 'Menunggu'},
    {'value': 'collected', 'label': 'Sudah Diambil'},
    {'value': 'completed', 'label': 'Selesai'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPickups();
  }

  Future<void> _loadPickups() async {
    setState(() => _isLoading = true);
    try {
      final service = OffSchedulePickupService();
      final pickups = await service.listRequests(
        status: _selectedStatus?.isEmpty == true ? null : _selectedStatus,
      );
      
      if (!mounted) return;
      setState(() {
        _pickups = pickups;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memuat data: ${e.toString().replaceAll('Exception: ', '')}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'sent':
        return Colors.blue;
      case 'processing':
        return Colors.orange;
      case 'pending':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'paid':
        return Colors.teal;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'sent':
        return Icons.send_outlined;
      case 'processing':
        return Icons.local_shipping_outlined;
      case 'pending':
        return Icons.pending_outlined;
      case 'completed':
        return Icons.check_circle_outline;
      case 'paid':
        return Icons.payment_outlined;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildPickupCard(OffSchedulePickup pickup) {
    final statusColor = _getStatusColor(pickup.requestStatus);
    final statusIcon = _getStatusIcon(pickup.requestStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OffSchedulePickupDetailScreen(pickupId: pickup.id),
            ),
          ).then((_) => _loadPickups()); // Reload after returning
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Status badge + Date
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          pickup.getStatusLabel(),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('dd MMM yyyy').format(DateTime.parse(pickup.requestedPickupDate)),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Address
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined, size: 18, color: primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pickup.serviceAccountName,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pickup.address,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Info row
              Row(
                children: [
                  // Time
                  if (pickup.requestedPickupTime != null) ...[
                    Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      pickup.requestedPickupTime!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  
                  // Extra fee
                  if (pickup.extraFee > 0) ...[
                    Icon(Icons.payments_outlined, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Rp ${pickup.extraFee.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                  
                  const Spacer(),
                  
                  // Arrow
                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Request Pengambilan',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadPickups,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statusFilters.map((filter) {
                  final isSelected = _selectedStatus == filter['value'] ||
                      (_selectedStatus == null && filter['value'] == '');
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter['label']!),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatus = filter['value'];
                        });
                        _loadPickups();
                      },
                      selectedColor: primaryColor.withOpacity(0.2),
                      checkmarkColor: primaryColor,
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? primaryColor : Colors.grey.shade700,
                      ),
                      side: BorderSide(
                        color: isSelected ? primaryColor : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          const Divider(height: 1),
          
          // List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  )
                : _pickups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada request',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Request pengambilan Anda akan muncul di sini',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPickups,
                        color: primaryColor,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _pickups.length,
                          itemBuilder: (context, index) {
                            return _buildPickupCard(_pickups[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
