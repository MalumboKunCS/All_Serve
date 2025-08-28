import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../theme/app_theme.dart';
import '../../models/verification_queue.dart';
import '../../models/provider.dart' as app_provider;
import '../../models/user.dart' as app_user;

import '../../services/auth_service.dart';

class AdminVerificationQueueScreen extends StatefulWidget {
  const AdminVerificationQueueScreen({super.key});

  @override
  State<AdminVerificationQueueScreen> createState() => _AdminVerificationQueueScreenState();
}

class _AdminVerificationQueueScreenState extends State<AdminVerificationQueueScreen> {
  String _statusFilter = 'pending';

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
                'Verification Queue',
                style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
              ),
              const Spacer(),
              DropdownButton<String>(
                value: _statusFilter,
                dropdownColor: AppTheme.surfaceDark,
                style: const TextStyle(color: AppTheme.textPrimary),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Requests')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: (value) {
                  setState(() => _statusFilter = value ?? 'pending');
                },
              ),
            ],
          ),
        ),

        // Verification List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _statusFilter == 'all'
                ? FirebaseFirestore.instance
                    .collection('verificationQueue')
                    .orderBy('submittedAt', descending: true)
                    .snapshots()
                : FirebaseFirestore.instance
                    .collection('verificationQueue')
                    .where('status', isEqualTo: _statusFilter)
                    .orderBy('submittedAt', descending: true)
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
                        'Error loading verification queue',
                        style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                );
              }

              final verifications = snapshot.data?.docs ?? [];

              if (verifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 64,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No verification requests',
                        style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Provider verification requests will appear here',
                        style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: verifications.length,
                itemBuilder: (context, index) {
                  final verificationDoc = verifications[index];
                  final verification = VerificationQueue.fromFirestore(verificationDoc);
                  return _buildVerificationCard(verification);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationCard(VerificationQueue verification) {
    return Card(
      color: AppTheme.surfaceDark,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verification Request',
                        style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Submitted ${verification.submissionTimeAgo}',
                        style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(verification.status),
              ],
            ),

            const SizedBox(height: 16),

            // Provider Info
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('providers')
                  .doc(verification.providerId)
                  .get(),
              builder: (context, providerSnapshot) {
                if (providerSnapshot.hasData && providerSnapshot.data!.exists) {
                  final provider = app_provider.Provider.fromFirestore(providerSnapshot.data!);
                  return Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: AppTheme.primary,
                            backgroundImage: (provider.logoUrl?.isNotEmpty ?? false)
                                ? NetworkImage(provider.logoUrl!)
                                : null,
                            child: (provider.logoUrl?.isEmpty ?? true)
                                ? const Icon(Icons.business, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.businessName,
                                  style: AppTheme.bodyText.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  provider.description,
                                  style: AppTheme.caption.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Owner Info
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(verification.ownerUid)
                            .get(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.hasData && userSnapshot.data!.exists) {
                            final owner = app_user.User.fromFirestore(userSnapshot.data!);
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundDark.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.person, size: 16, color: AppTheme.textSecondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Owner: ${owner.name} (${owner.email})',
                                    style: AppTheme.caption.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),

            const SizedBox(height: 16),

            // Documents Section
            _buildDocumentsSection(verification),

            const SizedBox(height: 16),

            // Admin Notes (if any)
            if (verification.adminNotes?.isNotEmpty ?? false) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Notes:',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      verification.adminNotes!,
                      style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            if (verification.isPending) _buildActionButtons(verification),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'pending':
        color = AppTheme.warning;
        icon = Icons.pending;
        break;
      case 'approved':
        color = AppTheme.success;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = AppTheme.error;
        icon = Icons.cancel;
        break;
      default:
        color = AppTheme.textSecondary;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: AppTheme.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection(VerificationQueue verification) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Submitted Documents',
          style: AppTheme.bodyText.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        if (verification.docs.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: AppTheme.error, size: 16),
                const SizedBox(width: 8),
                Text(
                  'No documents submitted',
                  style: AppTheme.caption.copyWith(color: AppTheme.error),
                ),
              ],
            ),
          )
        else
          ...verification.docs.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.description, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getDocumentDisplayName(entry.key),
                      style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _viewDocument(entry.value),
                    child: Text(
                      'View',
                      style: TextStyle(color: AppTheme.accent),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

        // Missing documents warning
        if (verification.missingDocuments.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: AppTheme.warning, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Missing Documents:',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...verification.missingDocuments.map((doc) => Padding(
                  padding: const EdgeInsets.only(left: 24, top: 2),
                  child: Text(
                    '• $doc',
                    style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                  ),
                )).toList(),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(VerificationQueue verification) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showRejectDialog(verification),
            style: AppTheme.outlineButtonStyle.copyWith(
              foregroundColor: MaterialStateProperty.all(AppTheme.error),
              side: MaterialStateProperty.all(BorderSide(color: AppTheme.error)),
            ),
            icon: const Icon(Icons.cancel),
            label: const Text('Reject'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: verification.hasAllRequiredDocuments
                ? () => _approveVerification(verification)
                : null,
            style: AppTheme.primaryButtonStyle,
            icon: const Icon(Icons.check_circle),
            label: const Text('Approve'),
          ),
        ),
      ],
    );
  }

  String _getDocumentDisplayName(String key) {
    switch (key) {
      case 'nrcUrl':
        return 'National Registration Card';
      case 'businessLicenseUrl':
        return 'Business License';
      case 'certificatesUrl':
        return 'Professional Certificates';
      default:
        return key.replaceAll('Url', '').replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(1)!.toLowerCase()}',
        ).trim();
    }
  }

  Future<void> _viewDocument(String url) async {
    // TODO: Implement document viewer
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Document viewer: $url'),
        backgroundColor: AppTheme.info,
      ),
    );
  }

  Future<void> _approveVerification(VerificationQueue verification) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final adminUid = authService.currentUser?.uid;

      if (adminUid == null) {
        throw Exception('Admin not authenticated');
      }

      // Call Cloud Function to approve verification
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('adminApproveProvider');
      
      await callable.call({
        'providerId': verification.providerId,
        'approve': true,
        'notes': 'Documents verified and approved by admin',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Provider verification approved successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve verification: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showRejectDialog(VerificationQueue verification) async {
    final notesController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(
          'Reject Verification',
          style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Please provide a reason for rejection:',
              style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: AppTheme.inputDecoration.copyWith(
                labelText: 'Rejection Reason',
                hintText: 'e.g., Invalid documents, incomplete information...',
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _rejectVerification(verification, notesController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectVerification(VerificationQueue verification, String reason) async {
    if (reason.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please provide a rejection reason'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final adminUid = authService.currentUser?.uid;

      if (adminUid == null) {
        throw Exception('Admin not authenticated');
      }

      // Call Cloud Function to reject verification
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('adminApproveProvider');
      
      await callable.call({
        'providerId': verification.providerId,
        'approve': false,
        'notes': reason.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Provider verification rejected'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject verification: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}
