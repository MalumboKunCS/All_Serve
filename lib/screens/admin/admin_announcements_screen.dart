import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../theme/app_theme.dart';
import '../../models/announcement.dart';
import '../../services/auth_service.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() => _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with Create Button
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Announcements',
                style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showCreateAnnouncementDialog,
                style: AppTheme.primaryButtonStyle,
                icon: const Icon(Icons.campaign),
                label: const Text('Create Announcement'),
              ),
            ],
          ),
        ),

        // Announcements List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('announcements')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: AppTheme.error),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading announcements',
                        style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                );
              }

              final announcements = snapshot.data?.docs ?? [];

              if (announcements.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.campaign_outlined,
                        size: 64,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No announcements',
                        style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create announcements to broadcast to users',
                        style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: announcements.length,
                itemBuilder: (context, index) {
                  final announcementDoc = announcements[index];
                  final announcement = Announcement.fromFirestore(announcementDoc);
                  return _buildAnnouncementCard(announcement);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementCard(Announcement announcement) {
    return Card(
      color: AppTheme.surfaceDark,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    announcement.title,
                    style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                  ),
                ),
                _buildStatusBadge(announcement),
              ],
            ),

            const SizedBox(height: 8),

            // Message
            Text(
              announcement.message,
              style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            // Info Row
            Row(
              children: [
                _buildInfoChip(
                  Icons.people,
                  announcement.audienceDisplayText,
                  _getAudienceColor(announcement.audience),
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  Icons.priority_high,
                  announcement.priorityDisplayText,
                  _getPriorityColor(announcement.priority),
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  Icons.category,
                  announcement.typeDisplayText,
                  _getTypeColor(announcement.type),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Stats and actions row
            Row(
              children: [
                Icon(Icons.send, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Sent to ${announcement.sentCount} user${announcement.sentCount != 1 ? 's' : ''}',
                  style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 16),
                Icon(Icons.schedule, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  announcement.timeAgo,
                  style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                ),
                const Spacer(),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: AppTheme.textSecondary),
                  color: AppTheme.surfaceDark,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.visibility, color: AppTheme.textPrimary),
                          const SizedBox(width: 8),
                          Text('View Details', style: TextStyle(color: AppTheme.textPrimary)),
                        ],
                      ),
                      onTap: () => _viewAnnouncementDetails(announcement),
                    ),
                    if (announcement.isActive)
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(Icons.pause, color: AppTheme.warning),
                            const SizedBox(width: 8),
                            Text('Deactivate', style: TextStyle(color: AppTheme.warning)),
                          ],
                        ),
                        onTap: () => _toggleAnnouncementStatus(announcement, false),
                      )
                    else
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(Icons.play_arrow, color: AppTheme.success),
                            const SizedBox(width: 8),
                            Text('Activate', style: TextStyle(color: AppTheme.success)),
                          ],
                        ),
                        onTap: () => _toggleAnnouncementStatus(announcement, true),
                      ),
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: AppTheme.error),
                          const SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: AppTheme.error)),
                        ],
                      ),
                      onTap: () => _deleteAnnouncement(announcement),
                    ),
                  ],
                ),
              ],
            ),

            // Expiry info
            if (announcement.expiresAt != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: announcement.isExpired 
                    ? AppTheme.error.withOpacity(0.1)
                    : AppTheme.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      announcement.isExpired ? Icons.schedule_outlined : Icons.schedule,
                      size: 14,
                      color: announcement.isExpired ? AppTheme.error : AppTheme.info,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      announcement.timeUntilExpiry ?? 'Expired',
                      style: AppTheme.caption.copyWith(
                        color: announcement.isExpired ? AppTheme.error : AppTheme.info,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Announcement announcement) {
    Color color;
    String text;
    
    if (announcement.isExpired) {
      color = AppTheme.error;
      text = 'EXPIRED';
    } else if (!announcement.isActive) {
      color = AppTheme.textSecondary;
      text = 'INACTIVE';
    } else {
      color = AppTheme.success;
      text = 'ACTIVE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: AppTheme.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTheme.caption.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getAudienceColor(String audience) {
    switch (audience) {
      case 'customers':
        return AppTheme.primary;
      case 'providers':
        return AppTheme.accent;
      case 'admins':
        return AppTheme.warning;
      default:
        return AppTheme.info;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return AppTheme.error;
      case 'high':
        return AppTheme.warning;
      case 'low':
        return AppTheme.textSecondary;
      default:
        return AppTheme.info;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'warning':
        return AppTheme.error;
      case 'promotion':
        return AppTheme.success;
      case 'maintenance':
        return AppTheme.warning;
      case 'update':
        return AppTheme.accent;
      default:
        return AppTheme.info;
    }
  }

  void _showCreateAnnouncementDialog() {
    showDialog(
      context: context,
      builder: (context) => const _CreateAnnouncementDialog(),
    );
  }

  void _viewAnnouncementDetails(Announcement announcement) {
    showDialog(
      context: context,
      builder: (context) => _AnnouncementDetailsDialog(announcement: announcement),
    );
  }

  Future<void> _toggleAnnouncementStatus(Announcement announcement, bool isActive) async {
    try {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(announcement.announcementId)
          .update({'isActive': isActive});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Announcement ${isActive ? 'activated' : 'deactivated'}'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update announcement: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteAnnouncement(Announcement announcement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(
          'Delete Announcement',
          style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${announcement.title}"?',
          style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(announcement.announcementId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Announcement deleted'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete announcement: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}

class _CreateAnnouncementDialog extends StatefulWidget {
  const _CreateAnnouncementDialog();

  @override
  State<_CreateAnnouncementDialog> createState() => _CreateAnnouncementDialogState();
}

class _CreateAnnouncementDialogState extends State<_CreateAnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _audience = 'all';
  String _priority = 'medium';
  String _type = 'info';
  DateTime? _expiresAt;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      title: Text(
        'Create Announcement',
        style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: AppTheme.inputDecoration.copyWith(labelText: 'Title'),
                style: const TextStyle(color: AppTheme.textPrimary),
                validator: (value) => value?.trim().isEmpty ?? true ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: AppTheme.inputDecoration.copyWith(labelText: 'Message'),
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 4,
                validator: (value) => value?.trim().isEmpty ?? true ? 'Message is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _audience,
                decoration: AppTheme.inputDecoration.copyWith(labelText: 'Audience'),
                dropdownColor: AppTheme.surfaceDark,
                style: const TextStyle(color: AppTheme.textPrimary),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Users')),
                  DropdownMenuItem(value: 'customers', child: Text('Customers Only')),
                  DropdownMenuItem(value: 'providers', child: Text('Providers Only')),
                  DropdownMenuItem(value: 'admins', child: Text('Admins Only')),
                ],
                onChanged: (value) => setState(() => _audience = value ?? 'all'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _priority,
                      decoration: AppTheme.inputDecoration.copyWith(labelText: 'Priority'),
                      dropdownColor: AppTheme.surfaceDark,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                      ],
                      onChanged: (value) => setState(() => _priority = value ?? 'medium'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _type,
                      decoration: AppTheme.inputDecoration.copyWith(labelText: 'Type'),
                      dropdownColor: AppTheme.surfaceDark,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      items: const [
                        DropdownMenuItem(value: 'info', child: Text('Information')),
                        DropdownMenuItem(value: 'warning', child: Text('Warning')),
                        DropdownMenuItem(value: 'promotion', child: Text('Promotion')),
                        DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                        DropdownMenuItem(value: 'update', child: Text('Update')),
                      ],
                      onChanged: (value) => setState(() => _type = value ?? 'info'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createAnnouncement,
          style: AppTheme.primaryButtonStyle,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
      ],
    );
  }

  Future<void> _createAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final adminUid = authService.currentUser?.uid;

      if (adminUid == null) {
        throw Exception('Admin not authenticated');
      }

      // Call Cloud Function to send announcement
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('sendAnnouncement');
      
      final result = await callable.call({
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'audience': _audience,
        'priority': _priority,
        'type': _type,
        'expiresAt': _expiresAt?.toIso8601String(),
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Announcement sent to ${result.data['recipientCount']} users'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send announcement: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _AnnouncementDetailsDialog extends StatelessWidget {
  final Announcement announcement;

  const _AnnouncementDetailsDialog({required this.announcement});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      title: Text(
        announcement.title,
        style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              announcement.message,
              style: AppTheme.bodyText.copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Audience', announcement.audienceDisplayText),
            _buildDetailRow('Priority', announcement.priorityDisplayText),
            _buildDetailRow('Type', announcement.typeDisplayText),
            _buildDetailRow('Created', announcement.formattedCreatedAt),
            _buildDetailRow('Status', announcement.statusText),
            _buildDetailRow('Recipients', '${announcement.sentCount} users'),
            if (announcement.expiresAt != null)
              _buildDetailRow('Expires', announcement.formattedExpiresAt),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close', style: TextStyle(color: AppTheme.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: AppTheme.caption.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.caption.copyWith(color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
