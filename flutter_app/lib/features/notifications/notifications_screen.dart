import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  NotificationsScreenState createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    final notifications = await NotificationService.getNotifications('user_dummy_123');
    setState(() {
      _notifications = notifications;
      _isLoading = false;
    });
  }

  Future<void> _markAsRead(NotificationModel notif, int index) async {
    if (notif.isRead) return;
    final success = await NotificationService.markAsRead(notif.id);
    if (success) {
      setState(() {
        _notifications[index] = NotificationModel(
          id: notif.id,
          title: notif.title,
          body: notif.body,
          type: notif.type,
          isRead: true,
          createdAt: notif.createdAt,
        );
      });
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'trip_request': return Icons.car_rental;
      case 'driver_accepted': return Icons.check_circle;
      case 'driver_arrived': return Icons.location_on;
      case 'trip_started': return Icons.play_circle_filled;
      case 'trip_ended': return Icons.flag;
      case 'trip_canceled': return Icons.cancel;
      default: return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات'), centerTitle: true),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _notifications.isEmpty 
          ? const Center(child: Text('لا توجد إشعارات حالياً', style: TextStyle(fontSize: 18)))
          : RefreshIndicator(
              onRefresh: _fetchNotifications,
              child: ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notif = _notifications[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: notif.isRead ? Colors.grey.shade200 : Colors.blue.shade100,
                      child: Icon(_getIconForType(notif.type), color: notif.isRead ? Colors.grey : Colors.blue),
                    ),
                    title: Text(
                      notif.title, 
                      style: TextStyle(fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notif.body),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(notif.createdAt.toLocal()),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    tileColor: notif.isRead ? Colors.transparent : Colors.blue.withOpacity(0.05),
                    onTap: () => _markAsRead(notif, index),
                  );
                },
              ),
            ),
    );
  }
}
