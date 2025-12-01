import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/complaint.dart';
import '../../services/collector_complaint_service.dart';
import 'collector_complaint_detail_screen.dart';

class CollectorComplaintsScreen extends StatefulWidget {
  const CollectorComplaintsScreen({Key? key}) : super(key: key);

  @override
  State<CollectorComplaintsScreen> createState() =>
      _CollectorComplaintsScreenState();
}

class _CollectorComplaintsScreenState extends State<CollectorComplaintsScreen>
    with SingleTickerProviderStateMixin {
  final CollectorComplaintService _complaintService =
      CollectorComplaintService();
  late TabController _tabController;

  List<Complaint> _allComplaints = [];
  List<Complaint> _filteredComplaints = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadComplaints();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _filterComplaints();
    }
  }

  Future<void> _loadComplaints() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final complaints = await _complaintService.getAssignedComplaints();
      
      // Debug: Log semua complaint yang diterima
      debugPrint('📊 [CollectorComplaints] Total complaints received: ${complaints.length}');
      for (var i = 0; i < complaints.length; i++) {
        final c = complaints[i];
        debugPrint('   ${i+1}. ID: ${c.id} | Type: ${c.type} | Status: "${c.status}" | Created: ${c.createdAt}');
      }
      
      setState(() {
        _allComplaints = complaints;
        _filterComplaints();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ [CollectorComplaints] Error loading complaints: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterComplaints() {
    setState(() {
      switch (_tabController.index) {
        case 0: // Semua
          _filteredComplaints = _allComplaints;
          debugPrint('📋 [Filter] Semua: ${_filteredComplaints.length} complaints');
          break;
        case 1: // Diproses
          _filteredComplaints = _allComplaints
              .where((c) {
                final status = c.status.toLowerCase().trim();
                return status == 'in_progress' || status == 'in progress' || status == 'diproses';
              })
              .toList();
          debugPrint('📋 [Filter] Diproses: ${_filteredComplaints.length} complaints');
          break;
        case 2: // Selesai
          _filteredComplaints = _allComplaints
              .where((c) {
                final status = c.status.toLowerCase().trim();
                return status == 'resolved' || status == 'completed' || status == 'done' || status == 'selesai';
              })
              .toList();
          debugPrint('📋 [Filter] Selesai: ${_filteredComplaints.length} complaints');
          for (var c in _filteredComplaints) {
            debugPrint('   ✅ ${c.type} (Status: "${c.status}")');
          }
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Pelaporan Warga',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 21, 145, 137),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          tabs: const [
            Tab(text: 'Semua'),
            Tab(text: 'Diproses'),
            Tab(text: 'Selesai'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadComplaints,
        color: const Color.fromARGB(255, 21, 145, 137),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color.fromARGB(255, 21, 145, 137),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Gagal memuat data',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadComplaints,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 21, 145, 137),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredComplaints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada pelaporan',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _tabController.index == 0
                  ? 'Belum ada pelaporan dari warga'
                  : _tabController.index == 1
                      ? 'Belum ada pelaporan yang sedang diproses'
                      : 'Belum ada pelaporan yang selesai',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredComplaints.length,
      itemBuilder: (context, index) {
        final complaint = _filteredComplaints[index];
        return _ComplaintCard(
          complaint: complaint,
          onTap: () => _navigateToDetail(complaint),
        );
      },
    );
  }

  void _navigateToDetail(Complaint complaint) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CollectorComplaintDetailScreen(complaint: complaint),
      ),
    );

    // Reload if status was updated
    if (result == true) {
      _loadComplaints();
    }
  }
}

class _ComplaintCard extends StatelessWidget {
  final Complaint complaint;
  final VoidCallback onTap;

  const _ComplaintCard({
    Key? key,
    required this.complaint,
    required this.onTap,
  }) : super(key: key);

  Color _getStatusColor() {
    switch (complaint.status.toLowerCase()) {
      case 'open':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reporterName = complaint.reporter?['name']?.toString() ?? 'Warga';
    final reporterAddress =
        complaint.reporter?['address']?.toString() ?? complaint.location;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                complaint.typeText,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    reporterName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            complaint.statusText,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      complaint.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                    if (reporterAddress != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              reporterAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd MMM yyyy, HH:mm')
                              .format(complaint.createdAt),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Red indicator strip on the right
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 6,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
