import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'notification_service.dart';
import '../auth/auth_service.dart';

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
    final userId = await AuthService.getUserId();
    if (userId == null || userId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final notifications = await NotificationService.getNotifications(userId);
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
      case 'trip_request': return Icons.directions_car_rounded;
      case 'driver_accepted': return Icons.check_circle_rounded;
      case 'driver_arrived': return Icons.location_on_rounded;
      case 'trip_started': return Icons.play_circle_filled_rounded;
      case 'trip_ended': return Icons.flag_rounded;
      case 'trip_canceled': return Icons.cancel_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0a0a0a),
        appBar: AppBar(
          backgroundColor: const Color(0xff111315),
          elevation: 0,
          title: const Text('الإشعارات', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xffF97316)))
            : _notifications.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: const Color(0xffF97316).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.notifications_off_outlined, color: Color(0xffF97316), size: 38),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'لا توجد إشعارات حالياً',
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'ستصلك إشعارات وتحديثات فورية فور قبول عروض السائقين أو تحديث حالة رحلاتك.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xff94A3B8), fontSize: 13.5, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: const Color(0xffF97316),
                    onRefresh: _fetchNotifications,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: notif.isRead ? const Color(0xff111315) : const Color(0xff1A1D21),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: notif.isRead ? const Color(0xff2A2D33) : const Color(0xffF97316).withOpacity(0.4),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: notif.isRead ? const Color(0xff2A2D33) : const Color(0xffF97316).withOpacity(0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getIconForType(notif.type),
                                color: notif.isRead ? const Color(0xff94A3B8) : const Color(0xffF97316),
                                size: 22,
                              ),
                            ),
                            title: Text(
                              notif.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  notif.body,
                                  style: TextStyle(color: notif.isRead ? const Color(0xff94A3B8) : const Color(0xffCBD5E1), fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  DateFormat('yyyy-MM-dd HH:mm').format(notif.createdAt.toLocal()),
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xff64748B)),
                                ),
                              ],
                            ),
                            onTap: () => _markAsRead(notif, index),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
