import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/complaint.dart';
import '../../services/collector_complaint_service.dart';

class CollectorComplaintDetailScreen extends StatefulWidget {
  final Complaint complaint;

  const CollectorComplaintDetailScreen({
    Key? key,
    required this.complaint,
  }) : super(key: key);

  @override
  State<CollectorComplaintDetailScreen> createState() =>
      _CollectorComplaintDetailScreenState();
}

class _CollectorComplaintDetailScreenState
    extends State<CollectorComplaintDetailScreen> {
  final CollectorComplaintService _complaintService =
      CollectorComplaintService();
  final TextEditingController _notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  bool _isUpdating = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    switch (widget.complaint.status.toLowerCase()) {
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

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Gagal mengambil foto: $e');
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    // Validation
    if (newStatus == 'resolved' && _selectedImage == null) {
      _showErrorSnackBar('Foto bukti wajib untuk menyelesaikan pelaporan');
      return;
    }

    final confirm = await _showConfirmDialog(
      'Update Status',
      'Apakah Anda yakin ingin mengubah status menjadi ${_getStatusText(newStatus)}?',
    );

    if (!confirm) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      await _complaintService.updateComplaintStatus(
        complaintId: widget.complaint.id,
        status: newStatus,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        photo: _selectedImage,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Status berhasil diupdate',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate update
      }
    } catch (e) {
      _showErrorSnackBar('Gagal update status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return 'Menunggu';
      case 'in_progress':
        return 'Diproses';
      case 'resolved':
        return 'Selesai';
      case 'rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 21, 145, 137),
            ),
            child: Text(
              'Ya',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reporterName =
        widget.complaint.reporter?['name']?.toString() ?? 'Warga';
    final reporterPhone =
        widget.complaint.reporter?['phone']?.toString() ?? '-';
    final reporterAddress = widget.complaint.reporter?['address']?.toString() ??
        widget.complaint.location ??
        '-';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Detail Pelaporan',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 21, 145, 137),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Badge
                Container(
                  color: _getStatusColor().withOpacity(0.1),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: _getStatusColor(),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Status: ${widget.complaint.statusText}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Complaint Info
                _buildSection(
                  title: 'Informasi Pelaporan',
                  children: [
                    _buildInfoRow(
                      icon: Icons.category_outlined,
                      label: 'Jenis',
                      value: widget.complaint.typeText,
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.access_time,
                      label: 'Tanggal',
                      value: DateFormat('dd MMMM yyyy, HH:mm')
                          .format(widget.complaint.createdAt),
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.description_outlined,
                      label: 'Deskripsi',
                      value: widget.complaint.description,
                      isMultiline: true,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Reporter Info
                _buildSection(
                  title: 'Informasi Pelapor',
                  children: [
                    _buildInfoRow(
                      icon: Icons.person_outline,
                      label: 'Nama',
                      value: reporterName,
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Telepon',
                      value: reporterPhone,
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Alamat',
                      value: reporterAddress,
                      isMultiline: true,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Photos
                if (widget.complaint.photos.isNotEmpty)
                  _buildSection(
                    title: 'Foto Bukti',
                    children: [
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.complaint.photos.length,
                          itemBuilder: (context, index) {
                            final photo = widget.complaint.photos[index];
                            return Container(
                              margin: const EdgeInsets.only(right: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  photo.url,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    width: 120,
                                    height: 120,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.broken_image),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Update Status Section
                if (widget.complaint.status.toLowerCase() != 'resolved')
                  _buildSection(
                    title: 'Update Status',
                    children: [
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Catatan (opsional)',
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey[400],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 21, 145, 137),
                              width: 2,
                            ),
                          ),
                        ),
                        style: GoogleFonts.poppins(),
                      ),
                      const SizedBox(height: 16),
                      if (_selectedImage != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              Image.file(
                                _selectedImage!,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedImage = null;
                                    });
                                  },
                                  icon: const Icon(Icons.close),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.camera_alt),
                        label: Text(
                          _selectedImage == null
                              ? 'Ambil Foto Bukti'
                              : 'Ganti Foto',
                          style: GoogleFonts.poppins(),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              const Color.fromARGB(255, 21, 145, 137),
                          side: const BorderSide(
                            color: Color.fromARGB(255, 21, 145, 137),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (widget.complaint.status.toLowerCase() == 'open')
                        ElevatedButton(
                          onPressed:
                              _isUpdating ? null : () => _updateStatus('in_progress'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            disabledBackgroundColor: Colors.grey[300],
                          ),
                          child: Text(
                            'Mulai Proses',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (widget.complaint.status.toLowerCase() == 'in_progress')
                        ElevatedButton(
                          onPressed:
                              _isUpdating ? null : () => _updateStatus('resolved'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            disabledBackgroundColor: Colors.grey[300],
                          ),
                          child: Text(
                            'Selesaikan',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),

                const SizedBox(height: 100),
              ],
            ),
          ),
          if (_isUpdating)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color.fromARGB(255, 21, 145, 137),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isMultiline = false,
  }) {
    return Row(
      crossAxisAlignment:
          isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color.fromARGB(255, 21, 145, 137),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
