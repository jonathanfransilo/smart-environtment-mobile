import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/collector_off_schedule_pickup_service.dart';

class CollectorOffScheduleDetailScreen extends StatefulWidget {
  final int pickupId;

  const CollectorOffScheduleDetailScreen({
    super.key,
    required this.pickupId,
  });

  @override
  State<CollectorOffScheduleDetailScreen> createState() => _CollectorOffScheduleDetailScreenState();
}

class _CollectorOffScheduleDetailScreenState extends State<CollectorOffScheduleDetailScreen> {
  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  Map<String, dynamic>? _pickup;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      final service = CollectorOffSchedulePickupService();
      final pickup = await service.getPickupDetail(widget.pickupId);
      
      if (!mounted) return;
      setState(() {
        _pickup = pickup;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memuat detail: ${e.toString().replaceAll('Exception: ', '')}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInfoRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
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
          'Detail Request',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _pickup == null
              ? Center(
                  child: Text(
                    'Data tidak ditemukan',
                    style: GoogleFonts.poppins(color: Colors.grey.shade600),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.orange.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 48,
                              color: Colors.orange,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Request Luar Jadwal',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: #${_pickup!['id']}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Resident Info
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Informasi Warga',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              'Nama',
                              _pickup!['service_account']?['name'] ?? '',
                              icon: Icons.person_outline,
                            ),
                            _buildInfoRow(
                              'Alamat',
                              _pickup!['service_account']?['address'] ?? '',
                              icon: Icons.location_on_outlined,
                            ),
                            if (_pickup!['service_account']?['contact_phone'] != null)
                              _buildInfoRow(
                                'Telepon',
                                _pickup!['service_account']?['contact_phone'] ?? '',
                                icon: Icons.phone_outlined,
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Pickup Info
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jadwal Pengambilan',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              'Tanggal',
                              DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(
                                DateTime.parse(_pickup!['requested_pickup_date']),
                              ),
                              icon: Icons.calendar_today_outlined,
                            ),
                            if (_pickup!['requested_pickup_time'] != null)
                              _buildInfoRow(
                                'Waktu',
                                _pickup!['requested_pickup_time'],
                                icon: Icons.access_time_outlined,
                              ),
                            if (_pickup!['resident_note'] != null && _pickup!['resident_note'].toString().isNotEmpty)
                              _buildInfoRow(
                                'Catatan Warga',
                                _pickup!['resident_note'],
                                icon: Icons.note_outlined,
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Waste Pricing Info
                      if (_pickup!['waste_pricing'] != null) ...[
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Informasi Harga',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.payments_outlined, size: 18, color: Colors.orange.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Biaya Tambahan: ',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    Text(
                                      'Rp ${(_pickup!['off_schedule_surcharge'] ?? 0).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Daftar Harga Sampah:',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...(_pickup!['waste_pricing'] as List).map((pricing) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${pricing['waste_name']} (${pricing['pocket_size_name']})',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Rp ${pricing['price'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      const SizedBox(height: 80), // Space for button
                    ],
                  ),
                ),
      bottomNavigationBar: _pickup != null && _pickup!['status'] == 'pending'
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // TODO: Implement skip/reject
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Fitur tolak akan segera hadir',
                                style: GoogleFonts.poppins(),
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.red.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Tolak',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: Navigate to complete pickup screen
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Fitur ambil sampah akan segera hadir',
                                style: GoogleFonts.poppins(),
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Ambil Sampah',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
