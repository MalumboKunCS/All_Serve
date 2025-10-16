import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared/shared.dart' as shared;
import '../services/verification_service.dart';
import '../theme/app_theme.dart';
import '../screens/provider/provider_registration_screen.dart';
import '../utils/app_logger.dart';

class RegistrationTrackerCard extends StatefulWidget {
  const RegistrationTrackerCard({super.key});

  @override
  State<RegistrationTrackerCard> createState() => _RegistrationTrackerCardState();
}

class _RegistrationTrackerCardState extends State<RegistrationTrackerCard> {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<shared.AuthService>(context, listen: true);
    final currentUser = authService.currentUser;
    
    AppLogger.info('RegistrationTrackerCard: Building with user: ${currentUser?.uid}');
    
    if (currentUser == null) {
      AppLogger.info('RegistrationTrackerCard: No current user, showing no registration card');
      return _buildNoRegistrationCard();
    }

    return StreamBuilder<Map<String, dynamic>?>(
      key: ValueKey(currentUser.uid),
      stream: VerificationService.getVerificationStatusStream(currentUser.uid),
      builder: (context, snapshot) {
        AppLogger.info('RegistrationTrackerCard: StreamBuilder - connectionState: ${snapshot.connectionState}, hasError: ${snapshot.hasError}, hasData: ${snapshot.hasData}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          AppLogger.info('RegistrationTrackerCard: Showing loading card');
          return _buildLoadingCard();
        }

        if (snapshot.hasError) {
          AppLogger.info('RegistrationTrackerCard: Error: ${snapshot.error}');
          return _buildErrorCard();
        }

        final verificationStatus = snapshot.data;
        AppLogger.info('RegistrationTrackerCard: Verification status: $verificationStatus');
        
        if (verificationStatus == null) {
          AppLogger.info('RegistrationTrackerCard: No verification status, showing no registration card');
          return _buildNoRegistrationCard();
        }

        AppLogger.info('RegistrationTrackerCard: Showing registration status card with status: ${verificationStatus['status']}');
        return _buildRegistrationStatusCard(verificationStatus);
      },
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      color: AppTheme.cardDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(
              'Loading registration status...',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: AppTheme.cardDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: AppTheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Registration Tracker',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Error loading registration status. Please try again.',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRegistrationCard() {
    return Card(
      color: AppTheme.cardDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.assignment_outlined,
                  color: AppTheme.textTertiary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Registration Tracker',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'You have not submitted a registration yet.',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProviderRegistrationScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Submit Registration'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationStatusCard(Map<String, dynamic> verificationStatus) {
    final status = verificationStatus['status'] as String;
    final submittedAt = verificationStatus['submittedAt'];
    final reviewedAt = verificationStatus['reviewedAt'];
    final adminRemarks = verificationStatus['adminRemarks'] as String?;

    return Card(
      color: AppTheme.cardDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  _getStatusIcon(status),
                  color: _getStatusColor(status),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Registration Tracker',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getStatusColor(status).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStatusIcon(status),
                    color: _getStatusColor(status),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getStatusText(status),
                    style: AppTheme.bodyMedium.copyWith(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Details
            _buildDetailRow(
              'Submission Date',
              _formatTimestamp(submittedAt),
              Icons.calendar_today,
            ),
            
            if (reviewedAt != null)
              _buildDetailRow(
                'Last Review',
                _formatTimestamp(reviewedAt),
                Icons.verified_user,
              ),

            if (adminRemarks != null && adminRemarks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.feedback,
                          color: AppTheme.error,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Admin Feedback',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      adminRemarks,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action buttons
            const SizedBox(height: 16),
            if (status == 'rejected') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProviderRegistrationScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Resubmit Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ] else if (status == 'pending') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: AppTheme.warning,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your registration is under review. We will notify you once the review is complete.',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppTheme.textTertiary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return AppTheme.success;
      case 'rejected':
        return AppTheme.error;
      case 'pending':
      default:
        return AppTheme.warning;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.schedule;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
      default:
        return 'Under Review';
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Not available';
    
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else {
      return 'Invalid date';
    }
    
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
