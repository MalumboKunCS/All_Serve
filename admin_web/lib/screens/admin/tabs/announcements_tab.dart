import 'package:flutter/material.dart';
import 'package:shared/shared.dart' as shared;
import '../../../widgets/announcement_dialog.dart';

class AnnouncementsTab extends StatefulWidget {
  const AnnouncementsTab({super.key});

  @override
  State<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<AnnouncementsTab> {
  String _selectedFilter = 'all';
  String _selectedSort = 'newest';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Announcements',
                      style: shared.AppTheme.heading1.copyWith(
                        color: shared.AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create and manage platform announcements',
                      style: shared.AppTheme.bodyLarge.copyWith(
                        color: shared.AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showCreateAnnouncementDialog,
                style: shared.AppTheme.primaryButtonStyle,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create Announcement'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Filters and search
          _buildFiltersSection(),
          const SizedBox(height: 24),
          
          // Announcements list
          Expanded(
            child: _buildAnnouncementsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Card(
      color: shared.AppTheme.cardDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Filter by status
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedFilter,
                decoration: shared.AppTheme.inputDecoration.copyWith(
                  labelText: 'Filter by Status',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Announcements')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'expired', child: Text('Expired')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                ],
                onChanged: (value) => setState(() => _selectedFilter = value!),
              ),
            ),
            const SizedBox(width: 16),
            
            // Sort by
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedSort,
                decoration: shared.AppTheme.inputDecoration.copyWith(
                  labelText: 'Sort by',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'newest', child: Text('Newest First')),
                  DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
                  DropdownMenuItem(value: 'priority', child: Text('Priority')),
                  DropdownMenuItem(value: 'audience', child: Text('Audience')),
                ],
                onChanged: (value) => setState(() => _selectedSort = value!),
              ),
            ),
            const SizedBox(width: 16),
            
            // Refresh button
            IconButton(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              color: shared.AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementsList() {
    return StreamBuilder<List<shared.Announcement>>(
      stream: shared.AdminService.getAnnouncementsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: shared.AppTheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading announcements',
                  style: shared.AppTheme.heading3.copyWith(
                    color: shared.AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: shared.AppTheme.bodyMedium.copyWith(
                    color: shared.AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        final announcements = snapshot.data ?? [];
        final filteredAnnouncements = _filterAndSortAnnouncements(announcements);
        
        if (filteredAnnouncements.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.campaign_outlined,
                  size: 64,
                  color: shared.AppTheme.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No announcements found',
                  style: shared.AppTheme.heading3.copyWith(
                    color: shared.AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first announcement to get started',
                  style: shared.AppTheme.bodyMedium.copyWith(
                    color: shared.AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          itemCount: filteredAnnouncements.length,
          itemBuilder: (context, index) {
            final announcement = filteredAnnouncements[index];
            return _buildAnnouncementCard(announcement);
          },
        );
      },
    );
  }

  List<shared.Announcement> _filterAndSortAnnouncements(List<shared.Announcement> announcements) {
    List<shared.Announcement> filtered = announcements;
    
    // Apply filter
    switch (_selectedFilter) {
      case 'active':
        filtered = announcements.where((a) => a.isActive && !a.isExpired).toList();
        break;
      case 'expired':
        filtered = announcements.where((a) => a.isExpired).toList();
        break;
      case 'inactive':
        filtered = announcements.where((a) => !a.isActive).toList();
        break;
      case 'all':
      default:
        // No filtering
        break;
    }
    
    // Apply sorting
    switch (_selectedSort) {
      case 'oldest':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'priority':
        filtered.sort((a, b) => _getPriorityWeight(b.priority).compareTo(_getPriorityWeight(a.priority)));
        break;
      case 'audience':
        filtered.sort((a, b) => a.audience.compareTo(b.audience));
        break;
      case 'newest':
      default:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    
    return filtered;
  }

  int _getPriorityWeight(String priority) {
    switch (priority) {
      case 'urgent': return 4;
      case 'high': return 3;
      case 'medium': return 2;
      case 'low': return 1;
      default: return 2;
    }
  }

  Widget _buildAnnouncementCard(shared.Announcement announcement) {
    return Card(
      color: shared.AppTheme.cardDark,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              announcement.title,
                              style: shared.AppTheme.heading3.copyWith(
                                color: shared.AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          _buildPriorityBadge(announcement.priority),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        announcement.message,
                        style: shared.AppTheme.bodyMedium.copyWith(
                          color: shared.AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleAnnouncementAction(value, announcement),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: announcement.isActive ? 'deactivate' : 'activate',
                      child: Row(
                        children: [
                          Icon(
                            announcement.isActive ? Icons.pause : Icons.play_arrow,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(announcement.isActive ? 'Deactivate' : 'Activate'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  child: Icon(
                    Icons.more_vert,
                    color: shared.AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Metadata
            Row(
              children: [
                _buildMetadataChip(
                  announcement.audienceDisplayText,
                  Icons.people,
                  shared.AppTheme.primaryPurple,
                ),
                const SizedBox(width: 8),
                _buildMetadataChip(
                  announcement.typeDisplayText,
                  _getTypeIcon(announcement.type),
                  _getTypeColor(announcement.type),
                ),
                const SizedBox(width: 8),
                _buildMetadataChip(
                  '${announcement.sentCount} sent',
                  Icons.send,
                  shared.AppTheme.success,
                ),
                const Spacer(),
                Text(
                  announcement.timeAgo,
                  style: shared.AppTheme.caption.copyWith(
                    color: shared.AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
            
            // Status and expiry
            if (announcement.expiresAt != null || !announcement.isActive) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (!announcement.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha:0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha:0.5)),
                      ),
                      child: Text(
                        'Inactive',
                        style: shared.AppTheme.caption.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (!announcement.isActive && announcement.expiresAt != null)
                    const SizedBox(width: 8),
                  if (announcement.expiresAt != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: announcement.isExpired 
                            ? Colors.orange.withValues(alpha:0.2)
                            : Colors.blue.withValues(alpha:0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: announcement.isExpired 
                              ? Colors.orange.withValues(alpha:0.5)
                              : Colors.blue.withValues(alpha:0.5),
                        ),
                      ),
                      child: Text(
                        announcement.isExpired 
                            ? 'Expired'
                            : announcement.timeUntilExpiry ?? '',
                        style: shared.AppTheme.caption.copyWith(
                          color: announcement.isExpired ? Colors.orange : Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color;
    switch (priority) {
      case 'urgent':
        color = Colors.red;
        break;
      case 'high':
        color = Colors.orange;
        break;
      case 'medium':
        color = Colors.blue;
        break;
      case 'low':
        color = Colors.grey;
        break;
      default:
        color = Colors.blue;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha:0.5)),
      ),
      child: Text(
        _getPriorityDisplayText(priority),
        style: shared.AppTheme.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMetadataChip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: shared.AppTheme.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'warning': return Icons.warning;
      case 'promotion': return Icons.local_offer;
      case 'maintenance': return Icons.build;
      case 'update': return Icons.update;
      default: return Icons.info;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'warning': return Colors.orange;
      case 'promotion': return Colors.green;
      case 'maintenance': return Colors.blue;
      case 'update': return Colors.purple;
      default: return Colors.grey;
    }
  }

  String _getPriorityDisplayText(String priority) {
    switch (priority) {
      case 'urgent': return 'URGENT';
      case 'high': return 'High';
      case 'medium': return 'Medium';
      case 'low': return 'Low';
      default: return priority.toUpperCase();
    }
  }

  void _showCreateAnnouncementDialog() {
    showDialog(
      context: context,
      builder: (context) => AnnouncementDialog(
        onSend: _sendAnnouncement,
      ),
    );
  }

  Future<void> _sendAnnouncement({
    required String title,
    required String message,
    required String audience,
    List<String> specificUserIds = const [],
    List<String> targetCategories = const [],
    String priority = 'medium',
    String type = 'info',
    DateTime? expiresAt,
  }) async {
    try {
      final success = await shared.AdminService.sendTargetedAnnouncement(
        title: title,
        message: message,
        audience: audience,
        specificUserIds: specificUserIds,
        targetCategories: targetCategories,
        priority: priority,
        type: type,
        expiresAt: expiresAt,
      );
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Announcement sent successfully to $audience!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Failed to send announcement');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send announcement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleAnnouncementAction(String action, shared.Announcement announcement) async {
    switch (action) {
      case 'activate':
      case 'deactivate':
        await _toggleAnnouncementStatus(announcement);
        break;
      case 'delete':
        await _deleteAnnouncement(announcement);
        break;
    }
  }

  Future<void> _toggleAnnouncementStatus(shared.Announcement announcement) async {
    try {
      final success = await shared.AdminService.updateAnnouncementStatus(
        announcement.announcementId,
        !announcement.isActive,
      );
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Announcement ${announcement.isActive ? 'deactivated' : 'activated'} successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Failed to update announcement status');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update announcement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAnnouncement(shared.Announcement announcement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: shared.AppTheme.cardDark,
        title: Text(
          'Delete Announcement',
          style: shared.AppTheme.heading3.copyWith(
            color: shared.AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${announcement.title}"? This action cannot be undone.',
          style: shared.AppTheme.bodyMedium.copyWith(
            color: shared.AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: shared.AppTheme.bodyMedium.copyWith(
                color: shared.AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final success = await shared.AdminService.deleteAnnouncement(
          announcement.announcementId,
        );
        
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Announcement deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            throw Exception('Failed to delete announcement');
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete announcement: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}






