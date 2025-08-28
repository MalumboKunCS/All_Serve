import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/admin_audit_log.dart';
import '../../models/user.dart' as app_user;

class AdminAuditLogsScreen extends StatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  State<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends State<AdminAuditLogsScreen> {
  String _actionFilter = 'all';
  int _limit = 50;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Bar
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Audit Logs',
                style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
              ),
              const Spacer(),
              DropdownButton<String>(
                value: _actionFilter,
                dropdownColor: AppTheme.surfaceDark,
                style: const TextStyle(color: AppTheme.textPrimary),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Actions')),
                  DropdownMenuItem(value: 'PROVIDER_APPROVED', child: Text('Provider Approvals')),
                  DropdownMenuItem(value: 'PROVIDER_REJECTED', child: Text('Provider Rejections')),
                  DropdownMenuItem(value: 'PROVIDER_SUSPENDED', child: Text('Provider Suspensions')),
                  DropdownMenuItem(value: 'REVIEW_FLAGGED', child: Text('Review Flags')),
                  DropdownMenuItem(value: 'REVIEW_REMOVED', child: Text('Review Removals')),
                  DropdownMenuItem(value: 'ANNOUNCEMENT_SENT', child: Text('Announcements')),
                ],
                onChanged: (value) {
                  setState(() => _actionFilter = value ?? 'all');
                },
              ),
              const SizedBox(width: 16),
              DropdownButton<int>(
                value: _limit,
                dropdownColor: AppTheme.surfaceDark,
                style: const TextStyle(color: AppTheme.textPrimary),
                items: const [
                  DropdownMenuItem(value: 25, child: Text('Last 25')),
                  DropdownMenuItem(value: 50, child: Text('Last 50')),
                  DropdownMenuItem(value: 100, child: Text('Last 100')),
                  DropdownMenuItem(value: 200, child: Text('Last 200')),
                ],
                onChanged: (value) {
                  setState(() => _limit = value ?? 50);
                },
              ),
            ],
          ),
        ),

        // Audit Logs List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildQuery().snapshots(),
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
                        'Error loading audit logs',
                        style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                );
              }

              final logs = snapshot.data?.docs ?? [];

              if (logs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No audit logs',
                        style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Admin actions will be logged here',
                        style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final logDoc = logs[index];
                  final log = AdminAuditLog.fromFirestore(logDoc);
                  return _buildLogCard(log);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('adminAuditLogs')
        .orderBy('timestamp', descending: true)
        .limit(_limit);

    if (_actionFilter != 'all') {
      query = query.where('action', isEqualTo: _actionFilter);
    }

    return query;
  }

  Widget _buildLogCard(AdminAuditLog log) {
    return Card(
      color: AppTheme.surfaceDark,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Action Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getActionColor(log.action).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _getActionIcon(log.action),
                color: _getActionColor(log.action),
                size: 20,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Log Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action Description
                  Text(
                    log.actionDescription,
                    style: AppTheme.bodyText.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Admin and Timestamp
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(log.actorUid)
                        .get(),
                    builder: (context, snapshot) {
                      String adminName = 'Unknown Admin';
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final admin = app_user.User.fromFirestore(snapshot.data!);
                        adminName = admin.name;
                      }
                      
                      return Row(
                        children: [
                          Icon(Icons.person, size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            adminName,
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.schedule, size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            log.formattedTimestamp,
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  
                  // Additional Details
                  if (_hasAdditionalDetails(log)) ...[
                    const SizedBox(height: 8),
                    _buildAdditionalDetails(log),
                  ],
                ],
              ),
            ),
            
            // Action Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: _getActionColor(log.action).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getActionColor(log.action).withOpacity(0.5),
                ),
              ),
              child: Text(
                _getActionDisplayName(log.action),
                style: AppTheme.caption.copyWith(
                  color: _getActionColor(log.action),
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'PROVIDER_APPROVED':
        return AppTheme.success;
      case 'PROVIDER_REJECTED':
      case 'PROVIDER_SUSPENDED':
      case 'REVIEW_REMOVED':
        return AppTheme.error;
      case 'REVIEW_FLAGGED':
        return AppTheme.warning;
      case 'ANNOUNCEMENT_SENT':
        return AppTheme.info;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'PROVIDER_APPROVED':
        return Icons.check_circle;
      case 'PROVIDER_REJECTED':
        return Icons.cancel;
      case 'PROVIDER_SUSPENDED':
        return Icons.block;
      case 'REVIEW_FLAGGED':
        return Icons.flag;
      case 'REVIEW_REMOVED':
        return Icons.delete;
      case 'ANNOUNCEMENT_SENT':
        return Icons.campaign;
      default:
        return Icons.info;
    }
  }

  String _getActionDisplayName(String action) {
    switch (action) {
      case 'PROVIDER_APPROVED':
        return 'APPROVED';
      case 'PROVIDER_REJECTED':
        return 'REJECTED';
      case 'PROVIDER_SUSPENDED':
        return 'SUSPENDED';
      case 'REVIEW_FLAGGED':
        return 'FLAGGED';
      case 'REVIEW_REMOVED':
        return 'REMOVED';
      case 'ANNOUNCEMENT_SENT':
        return 'ANNOUNCED';
      default:
        return action.replaceAll('_', ' ');
    }
  }

  bool _hasAdditionalDetails(AdminAuditLog log) {
    return log.detail.isNotEmpty;
  }

  Widget _buildAdditionalDetails(AdminAuditLog log) {
    final details = <Widget>[];
    
    switch (log.action) {
      case 'PROVIDER_APPROVED':
      case 'PROVIDER_REJECTED':
      case 'PROVIDER_SUSPENDED':
        if (log.detail.containsKey('businessName')) {
          details.add(_buildDetailItem(
            Icons.business,
            'Business: ${log.detail['businessName']}',
          ));
        }
        if (log.detail.containsKey('reason')) {
          details.add(_buildDetailItem(
            Icons.info,
            'Reason: ${log.detail['reason']}',
          ));
        }
        break;
        
      case 'REVIEW_FLAGGED':
      case 'REVIEW_REMOVED':
        if (log.detail.containsKey('reason')) {
          details.add(_buildDetailItem(
            Icons.info,
            'Reason: ${log.detail['reason']}',
          ));
        }
        break;
        
      case 'ANNOUNCEMENT_SENT':
        if (log.detail.containsKey('title')) {
          details.add(_buildDetailItem(
            Icons.title,
            'Title: ${log.detail['title']}',
          ));
        }
        if (log.detail.containsKey('audience') && log.detail.containsKey('recipientCount')) {
          details.add(_buildDetailItem(
            Icons.people,
            'Sent to ${log.detail['recipientCount']} ${log.detail['audience']} users',
          ));
        }
        break;
    }

    if (details.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: details,
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTheme.caption.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
