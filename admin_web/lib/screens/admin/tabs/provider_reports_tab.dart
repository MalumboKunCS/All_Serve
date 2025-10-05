import 'package:flutter/material.dart';
import 'package:shared/shared.dart' as shared;
import '../../../services/provider_report_service.dart';

class ProviderReportsTab extends StatefulWidget {
  const ProviderReportsTab({super.key});

  @override
  State<ProviderReportsTab> createState() => _ProviderReportsTabState();
}

class _ProviderReportsTabState extends State<ProviderReportsTab> {
  String _selectedStatus = 'all';
  String _selectedType = 'all';
  int _selectedPriority = 0; // 0 = all, 1-4 = specific priority

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Provider Reports',
                    style: shared.AppTheme.heading1.copyWith(
                      color: shared.AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage complaints and reports against providers',
                    style: shared.AppTheme.bodyLarge.copyWith(
                      color: shared.AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showCreateReportDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create Report'),
                style: shared.AppTheme.primaryButtonStyle,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filters
          _buildFiltersSection(),
          const SizedBox(height: 16),

          // Reports List
          Expanded(
            child: _buildReportsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shared.AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: shared.AppTheme.cardLight),
      ),
      child: Row(
        children: [
          // Status Filter
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: shared.AppTheme.inputDecoration.copyWith(
                labelText: 'Status',
              ),
              items: [
                DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'investigating', child: Text('Investigating')),
                DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                DropdownMenuItem(value: 'dismissed', child: Text('Dismissed')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value!;
                });
              },
            ),
          ),
          const SizedBox(width: 16),

          // Type Filter
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: shared.AppTheme.inputDecoration.copyWith(
                labelText: 'Type',
              ),
              items: [
                DropdownMenuItem(value: 'all', child: Text('All Types')),
                DropdownMenuItem(value: 'complaint', child: Text('Complaint')),
                DropdownMenuItem(value: 'violation', child: Text('Violation')),
                DropdownMenuItem(value: 'qualityIssue', child: Text('Quality Issue')),
                DropdownMenuItem(value: 'safetyConcern', child: Text('Safety Concern')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
              },
            ),
          ),
          const SizedBox(width: 16),

          // Priority Filter
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _selectedPriority,
              decoration: shared.AppTheme.inputDecoration.copyWith(
                labelText: 'Priority',
              ),
              items: [
                DropdownMenuItem(value: 0, child: Text('All Priorities')),
                DropdownMenuItem(value: 1, child: Text('Low')),
                DropdownMenuItem(value: 2, child: Text('Medium')),
                DropdownMenuItem(value: 3, child: Text('High')),
                DropdownMenuItem(value: 4, child: Text('Critical')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPriority = value!;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList() {
    return StreamBuilder<List<shared.ProviderReport>>(
      stream: _getReportsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading reports: ${snapshot.error}',
              style: shared.AppTheme.bodyMedium.copyWith(
                color: shared.AppTheme.error,
              ),
            ),
          );
        }

        final reports = snapshot.data ?? [];
        
        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.report_outlined,
                  size: 64,
                  color: shared.AppTheme.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No reports found',
                  style: shared.AppTheme.heading3.copyWith(
                    color: shared.AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No reports match your current filters',
                  style: shared.AppTheme.bodyMedium.copyWith(
                    color: shared.AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: reports.length,
          itemBuilder: (context, index) {
            return _buildReportCard(reports[index]);
          },
        );
      },
    );
  }

  Stream<List<shared.ProviderReport>> _getReportsStream() {
    // For now, get all reports and filter client-side
    // In production, you might want to implement server-side filtering
    return ProviderReportService.getReportsStream().map((reports) {
      return reports.where((report) {
        // Apply status filter
        if (_selectedStatus != 'all' && report.status.name != _selectedStatus) {
          return false;
        }

        // Apply type filter
        if (_selectedType != 'all' && report.reportType.name != _selectedType) {
          return false;
        }

        // Apply priority filter
        if (_selectedPriority != 0 && report.priority != _selectedPriority) {
          return false;
        }

        return true;
      }).toList();
    });
  }

  Widget _buildReportCard(shared.ProviderReport report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: shared.AppTheme.cardDark,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showReportDetails(report),
        borderRadius: BorderRadius.circular(12),
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
                        Text(
                          report.title,
                          style: shared.AppTheme.bodyLarge.copyWith(
                            color: shared.AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reported by: ${report.reporterName}',
                          style: shared.AppTheme.bodyMedium.copyWith(
                            color: shared.AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(report.status),
                ],
              ),
              const SizedBox(height: 12),

              // Report Details
              Row(
                children: [
                  _buildInfoChip(
                    report.reportTypeDisplayName,
                    _getReportTypeColor(report.reportType),
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    'Priority: ${report.priorityDisplayName}',
                    _getPriorityColor(report.priority),
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    _formatDate(report.createdAt),
                    shared.AppTheme.textTertiary,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Description Preview
              Text(
                report.description,
                style: shared.AppTheme.bodyMedium.copyWith(
                  color: shared.AppTheme.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showReportDetails(report),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: shared.AppTheme.primaryPurple,
                        side: BorderSide(color: shared.AppTheme.primaryPurple),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (report.status == shared.ReportStatus.pending) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateReportStatus(report, shared.ReportStatus.investigating),
                        icon: const Icon(Icons.search, size: 16),
                        label: const Text('Investigate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: shared.AppTheme.warning,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ] else if (report.status == shared.ReportStatus.investigating) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateReportStatus(report, shared.ReportStatus.resolved),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Resolve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: shared.AppTheme.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(shared.ReportStatus status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case shared.ReportStatus.pending:
        color = shared.AppTheme.warning;
        icon = Icons.pending;
        break;
      case shared.ReportStatus.investigating:
        color = shared.AppTheme.info;
        icon = Icons.search;
        break;
      case shared.ReportStatus.resolved:
        color = shared.AppTheme.success;
        icon = Icons.check_circle;
        break;
      case shared.ReportStatus.dismissed:
        color = shared.AppTheme.error;
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status.name.toUpperCase(),
            style: shared.AppTheme.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: shared.AppTheme.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getReportTypeColor(shared.ReportType type) {
    switch (type) {
      case shared.ReportType.complaint:
        return shared.AppTheme.error;
      case shared.ReportType.violation:
        return Colors.red;
      case shared.ReportType.qualityIssue:
        return shared.AppTheme.warning;
      case shared.ReportType.safetyConcern:
        return Colors.orange;
      case shared.ReportType.other:
        return shared.AppTheme.textSecondary;
    }
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return shared.AppTheme.success;
      case 2:
        return shared.AppTheme.info;
      case 3:
        return shared.AppTheme.warning;
      case 4:
        return shared.AppTheme.error;
      default:
        return shared.AppTheme.textSecondary;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _showReportDetails(shared.ProviderReport report) async {
    // TODO: Implement detailed report view dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing report: ${report.title}'),
        backgroundColor: shared.AppTheme.info,
      ),
    );
  }

  Future<void> _updateReportStatus(shared.ProviderReport report, shared.ReportStatus newStatus) async {
    try {
      final success = await ProviderReportService.updateReportStatus(
        report.reportId,
        newStatus,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report status updated to ${newStatus.name}'),
            backgroundColor: shared.AppTheme.success,
          ),
        );
      } else {
        throw Exception('Failed to update report status');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update report status: $e'),
          backgroundColor: shared.AppTheme.error,
        ),
      );
    }
  }

  Future<void> _showCreateReportDialog() async {
    // TODO: Implement create report dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Create report dialog will be implemented'),
        backgroundColor: shared.AppTheme.info,
      ),
    );
  }
}
