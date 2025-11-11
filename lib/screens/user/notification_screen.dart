import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'notification_service.dart';

class NotificationScreen extends StatefulWidget {
  final bool isKolektor;

  const NotificationScreen({super.key, this.isKolektor = false});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final list = await NotificationService.getNotifications(
      isKolektor: widget.isKolektor,
    );
    setState(() {
      _notifications = list;
    });
  }

  Future<void> _markAsRead(String id) async {
    await NotificationService.markAsRead(id, isKolektor: widget.isKolektor);
    await _loadNotifications(); // refresh list setelah update
  }

  Future<void> _deleteNotification(String id) async {
    await NotificationService.deleteNotification(
      id,
      isKolektor: widget.isKolektor,
    );
    await _loadNotifications();
  }

  void _showNotificationDetail(Map<String, dynamic> notif) {
    final type = notif['type'] as String?;
    final title = notif['title'] as String? ?? '';
    final message = notif['message'] ?? '';
    final time = notif['time'] ?? '';

    // Tentukan icon dan color berdasarkan tipe
    IconData iconData;
    Color iconColor;

    switch (type) {
      case 'pickup_schedule':
        iconData = Icons.local_shipping;
        iconColor = const Color(0xFF4CAF50);
        break;
      case 'invoice_new':
      case 'invoice_reminder':
        iconData = Icons.receipt_long;
        iconColor = const Color(0xFFF57C00);
        break;
      case 'payment_success':
        iconData = Icons.check_circle;
        iconColor = const Color(0xFF2196F3);
        break;
      case 'article_new':
        iconData = Icons.article;
        iconColor = const Color(0xFF9C27B0);
        break;
      case 'report_created':
        iconData = Icons.report_outlined;
        iconColor = const Color(0xFFE91E63);
        break;
      case 'service_account_created':
        iconData = Icons.account_circle;
        iconColor = const Color.fromARGB(255, 21, 145, 137);
        break;
      default:
        iconData = Icons.notifications;
        iconColor = const Color.fromARGB(255, 21, 145, 137);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: iconColor, size: 48),
                ),
              ),

              const SizedBox(height: 20),

              // Title
              if (title.isNotEmpty) ...[
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.black87,
                    height: 1.6,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Time
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatTime(time),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);

                        // Konfirmasi hapus
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Text(
                              'Hapus Notifikasi',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            content: Text(
                              'Apakah Anda yakin ingin menghapus notifikasi ini?',
                              style: GoogleFonts.poppins(),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(
                                  'Batal',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Hapus',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await _deleteNotification(notif['id']);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Notifikasi berhasil dihapus',
                                  style: GoogleFonts.poppins(),
                                ),
                                backgroundColor: const Color.fromARGB(
                                  255,
                                  21,
                                  145,
                                  137,
                                ),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_outline, size: 20),
                      label: Text(
                        'Hapus',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check, size: 20),
                      label: Text(
                        'Tutup',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(
                          255,
                          21,
                          145,
                          137,
                        ),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} hari yang lalu';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} jam yang lalu';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} menit yang lalu';
      } else {
        return 'Baru saja';
      }
    } catch (e) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifikasi"),
        backgroundColor: const Color.fromARGB(255, 21, 145, 137),
        foregroundColor: Colors.white,
        actions: [
          if (_notifications.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'mark_all_read') {
                  await NotificationService.markAllAsRead(
                    isKolektor: widget.isKolektor,
                  );
                  await _loadNotifications();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Semua notifikasi ditandai sudah dibaca',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: const Color.fromARGB(
                          255,
                          21,
                          145,
                          137,
                        ),
                      ),
                    );
                  }
                } else if (value == 'delete_all') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(
                        'Hapus Semua Notifikasi',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      content: Text(
                        'Apakah Anda yakin ingin menghapus semua notifikasi? Tindakan ini tidak dapat dibatalkan.',
                        style: GoogleFonts.poppins(),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            'Batal',
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Hapus Semua',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await NotificationService.clearAll(
                      isKolektor: widget.isKolektor,
                    );
                    await _loadNotifications();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Semua notifikasi berhasil dihapus',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: const Color.fromARGB(
                            255,
                            21,
                            145,
                            137,
                          ),
                        ),
                      );
                    }
                  }
                }
              },
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'mark_all_read',
                  child: Row(
                    children: [
                      const Icon(Icons.done_all, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Tandai semua dibaca',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_sweep,
                        size: 20,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Hapus semua',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Bell Image dengan animasi
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Image.asset(
                          'assets/images/lonceng.png',
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Belum ada Informasi",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      "Saat ini belum ada notifikasi apa pun. Tunggu informasi dari kami!",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notif = _notifications[index];
                final isRead = notif['isRead'] == true;
                final type = notif['type'] as String?;
                final title = notif['title'] as String? ?? '';
                final message = notif['message'] ?? '';

                // Tentukan icon dan color berdasarkan tipe
                IconData iconData;
                Color iconColor;

                switch (type) {
                  case 'pickup_schedule':
                    iconData = Icons.local_shipping;
                    iconColor = const Color(0xFF4CAF50); // Hijau
                    break;
                  case 'invoice_new':
                  case 'invoice_reminder':
                    iconData = Icons.receipt_long;
                    iconColor = const Color(0xFFF57C00); // Orange
                    break;
                  case 'payment_success':
                    iconData = Icons.check_circle;
                    iconColor = const Color(0xFF2196F3); // Blue
                    break;
                  case 'article_new':
                    iconData = Icons.article;
                    iconColor = const Color(0xFF9C27B0); // Purple
                    break;
                  case 'report_created':
                    iconData = Icons.report_outlined;
                    iconColor = const Color(0xFFE91E63); // Pink
                    break;
                  case 'service_account_created':
                    iconData = Icons.account_circle;
                    iconColor = const Color.fromARGB(255, 21, 145, 137); // Teal
                    break;
                  default:
                    iconData = Icons.notifications;
                    iconColor = const Color.fromARGB(255, 21, 145, 137);
                }

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  elevation: isRead ? 0 : 2,
                  color: isRead ? Colors.grey.shade50 : Colors.white,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isRead
                            ? Colors.grey.shade300
                            : iconColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        iconData,
                        color: isRead ? Colors.grey : iconColor,
                        size: 24,
                      ),
                    ),
                    title: title.isNotEmpty
                        ? Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontWeight: isRead
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                              fontSize: 14,
                              color: isRead ? Colors.black54 : Colors.black87,
                            ),
                          )
                        : null,
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title.isNotEmpty) const SizedBox(height: 4),
                        Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontWeight: title.isEmpty && !isRead
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontSize: title.isEmpty ? 14 : 13,
                            color: isRead ? Colors.black54 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(notif['time'] ?? ''),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: iconColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        // Tombol hapus
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: Colors.grey.shade400,
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: Text(
                                  'Hapus Notifikasi',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                content: Text(
                                  'Apakah Anda yakin ingin menghapus notifikasi ini?',
                                  style: GoogleFonts.poppins(),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(
                                      'Batal',
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      'Hapus',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await _deleteNotification(notif['id']);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Notifikasi berhasil dihapus',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: const Color.fromARGB(
                                      255,
                                      21,
                                      145,
                                      137,
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    onTap: () async {
                      // Tandai sudah dibaca
                      if (!isRead) {
                        await _markAsRead(notif['id']);
                      }
                      // Tampilkan detail
                      _showNotificationDetail(notif);
                    },
                  ),
                );
              },
            ),
    );
  }
}
