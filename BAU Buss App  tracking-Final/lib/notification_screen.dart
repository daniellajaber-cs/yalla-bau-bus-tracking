import 'package:flutter/material.dart'
    show
        AppBar,
        Border,
        BorderRadius,
        BoxDecoration,
        BoxShape,
        BuildContext,
        Center,
        CircularProgressIndicator,
        Color,
        Colors,
        Column,
        ConnectionState,
        Container,
        CrossAxisAlignment,
        EdgeInsets,
        Expanded,
        FontWeight,
        Icon,
        IconData,
        IconThemeData,
        Icons,
        ListView,
        Row,
        Scaffold,
        SizedBox,
        StatelessWidget,
        StreamBuilder,
        Text,
        TextButton,
        TextStyle,
        Widget;
import 'notification_service.dart';

/// This screen shows all user notifications
class NotificationScreen extends StatelessWidget {
  NotificationScreen({super.key});

  //This line creates an object from NotificationService to access notification functions.
  final NotificationService notificationService = NotificationService();

  //This function is used to display how long ago the notification was sent (e.g., just now, 5 minutes ago).
  String formatTime(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Just now'; //the moment the notification is sent it sends just now
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} h ago';
    }
    return '${difference.inDays} d ago';
  }

  /// This function returns a color based on notification type
  Color getTypeColor(String type) {
    switch (type) {
      case 'near_stop':
        return const Color(0xFFF79009); // orange color
      case 'destination_arrived':
        return const Color(0xFF12B76A); // green color
      default:
        return const Color(0xFF2F80ED); // default blue color
    }
  }

  /// This function returns an icon based on notification type
  IconData getTypeIcon(String type) {
    switch (type) {
      case 'near_stop':
        return Icons.location_on_outlined; // location icon
      case 'destination_arrived':
        return Icons.flag_outlined; // flag icon
      default:
        return Icons.notifications_none_rounded; // default notification icon
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      // top app bar
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        centerTitle: true,

        // title of the screen
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF101828),
            fontWeight: FontWeight.w700,
          ),
        ),

        iconTheme: const IconThemeData(color: Color(0xFF101828)),

        // buttons on the right side
        actions: [
          TextButton(
            onPressed: () async {
              // mark all notifications as read
              await notificationService.markAllAsRead();
            },
            child: const Text('Read all'),
          ),
          TextButton(
            onPressed: () async {
              // delete all notifications
              await notificationService.clearAllNotifications();
            },
            child: const Text('Clear all', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),

      // body of the screen
      body: StreamBuilder<List<UserNotificationItem>>(
        // listen to live notifications from service
        stream: notificationService.notificationsStream(),

        builder: (context, snapshot) {
          // show loading while waiting for data
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // get notifications list (or empty if null)
          final notifications = snapshot.data ?? [];

          // if no notifications exist
          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                'No notifications yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF667085),
                ),
              ),
            );
          }

          // display notifications in a list
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,

            // space between each notification card
            separatorBuilder: (_, __) => const SizedBox(height: 12),

            itemBuilder: (context, index) {
              final item = notifications[index];

              // get color depending on notification type
              final accentColor = getTypeColor(item.type);

              return Container(
                padding: const EdgeInsets.all(14),

                // card styling
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),

                  // border changes if notification is read or not
                  border: Border.all(
                    color:
                        item.isRead
                            ? const Color(0xFFEAECF0)
                            : accentColor.withValues(alpha: 0.35),
                  ),
                ),

                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // icon container
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(getTypeIcon(item.type), color: accentColor),
                    ),

                    const SizedBox(width: 12),

                    // notification content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // notification title
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF101828),
                                  ),
                                ),
                              ),

                              // show small dot if notification is unread
                              if (!item.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2F80ED),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          // notification body text
                          Text(
                            item.body,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: Color(0xFF475467),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // time (e.g., 5 min ago)
                          Text(
                            formatTime(item.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF98A2B3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
