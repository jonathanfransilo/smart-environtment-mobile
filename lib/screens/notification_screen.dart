import 'package:flutter/material.dart';
import 'notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

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
    final list = await NotificationService.getNotifications();
    setState(() {
      _notifications = list;
    });
  }

  Future<void> _markAsRead(String id) async {
    await NotificationService.markAsRead(id);
    await _loadNotifications(); // refresh list setelah update
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifikasi"),
        actions: [
          TextButton(
            onPressed: () async {
              await NotificationService.markAllAsRead();
              await _loadNotifications();
            },
            child: const Text("Tandai semua dibaca", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? const Center(child: Text("Belum ada notifikasi"))
          : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notif = _notifications[index];
                final isRead = notif['isRead'] == true;

                return ListTile(
                  leading: Icon(
                    isRead ? Icons.mark_email_read : Icons.mark_email_unread,
                    color: isRead ? Colors.grey : Colors.green,
                  ),
                  title: Text(
                    notif['message'] ?? '',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    notif['time'] ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () async {
                    await _markAsRead(notif['id']); // ✅ hanya item ini yg ditandai read
                  },
                );
              },
            ),
    );
  }
}
