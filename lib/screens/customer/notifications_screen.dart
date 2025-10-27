import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart' as shared;
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import '../../utils/responsive_utils.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<shared.AuthService>(context);
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: AppTheme.surfaceDark,
        ),
        body: const Center(
          child: Text(
            'Please log in to view notifications',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          color: AppTheme.textPrimary,
        ),
        title: const Text('Notifications'),
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => _markAllAsRead(currentUser.uid),
            child: Text(
              'Mark all read',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.primaryPurple,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notifications')
            .where('receiverId', isEqualTo: currentUser.uid)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading notifications',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.error,
                ),
              ),
            );
          }

          final notifications = snapshot.data?.docs ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: AppTheme.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: AppTheme.heading3.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When you get notifications, they\'ll show up here',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.all(
              ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: 16,
                tablet: 20,
                desktop: 24,
              ),
            ),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildNotificationCard(doc.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(String notificationId, Map<String, dynamic> data) {
    final title = data['title'] as String? ?? 'Notification';
    final body = data['body'] as String? ?? '';
    final type = data['type'] as String? ?? 'info';
    final isRead = data['isRead'] as bool? ?? false;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    return Card(
      color: isRead ? AppTheme.cardDark : AppTheme.cardDark.withValues(alpha: 0.8),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRead
              ? Colors.transparent
              : AppTheme.primaryPurple.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _handleNotificationTap(notificationId, data),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getNotificationColor(type).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getNotificationIcon(type),
                  color: _getNotificationColor(type),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTheme.bodyLarge.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTimestamp(createdAt),
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'new_booking':
      case 'booking_confirmed':
        return Icons.event_available;
      case 'booking_accepted':
        return Icons.check_circle;
      case 'booking_rejected':
        return Icons.cancel;
      case 'booking_completed':
        return Icons.task_alt;
      case 'booking_cancelled':
        return Icons.event_busy;
      case 'payment':
        return Icons.payment;
      case 'review':
        return Icons.star;
      case 'message':
        return Icons.message;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'new_booking':
      case 'booking_confirmed':
        return AppTheme.info;
      case 'booking_accepted':
      case 'booking_completed':
        return AppTheme.success;
      case 'booking_rejected':
      case 'booking_cancelled':
        return AppTheme.error;
      case 'payment':
        return AppTheme.warning;
      case 'review':
        return AppTheme.warning;
      default:
        return AppTheme.primaryPurple;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  Future<void> _handleNotificationTap(String notificationId, Map<String, dynamic> data) async {
    try {
      // Mark as read
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });

      // Handle navigation based on type
      final type = data['type'] as String?;
      final bookingId = data['data']?['bookingId'] as String?;

      if (bookingId != null && type != null && type.contains('booking')) {
        // Navigate to booking details
        // TODO: Add navigation to booking status screen
        AppLogger.info('Navigate to booking: $bookingId');
      }
    } catch (e) {
      AppLogger.error('Error handling notification tap: $e');
    }
  }

  Future<void> _markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error marking all as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark notifications as read: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}
