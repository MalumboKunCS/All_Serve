import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared/shared.dart' as shared;
import '../../../widgets/application_viewer_dialog.dart';
import '../../../widgets/document_viewer_dialog.dart';
import '../../../utils/app_logger.dart';

class VerificationQueueTab extends StatefulWidget {
  final VoidCallback onRefresh;

  const VerificationQueueTab({
    super.key,
    required this.onRefresh,
  });

  @override
  State<VerificationQueueTab> createState() => _VerificationQueueTabState();
}

class _VerificationQueueTabState extends State<VerificationQueueTab> {
  bool _isProcessing = false;
  String _selectedStatus = 'pending';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
              Text(
                'Verification Queue',
                style: shared.AppTheme.heading2.copyWith(
                  color: shared.AppTheme.textPrimary,
                ),
              ),
              // Status Filter
              Row(
                children: [
                  Text(
                    'Filter:',
                    style: shared.AppTheme.bodyMedium.copyWith(
                      color: shared.AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _selectedStatus,
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value!;
                      });
                    },
                    items: [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'approved', child: Text('Approved')),
                      DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Applications List
          Expanded(
            child: _buildApplicationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getApplicationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading applications: ${snapshot.error}',
              style: shared.AppTheme.bodyMedium.copyWith(
                color: shared.AppTheme.error,
              ),
            ),
          );
        }

        final allApplications = snapshot.data?.docs ?? [];
        
        // Filter applications client-side based on selected status
        final applications = _selectedStatus == 'all' 
            ? allApplications 
            : allApplications.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['status'] as String? ?? 'pending') == _selectedStatus;
              }).toList();
        
        if (applications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: shared.AppTheme.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No applications found',
                  style: shared.AppTheme.heading3.copyWith(
                    color: shared.AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Provider applications will appear here when submitted',
                  style: shared.AppTheme.bodyMedium.copyWith(
                    color: shared.AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final application = applications[index];
            final data = application.data() as Map<String, dynamic>;
            final providerId = data['providerId'] as String?;
            final status = data['status'] as String? ?? 'pending';
            final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
            final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
            final notes = data['notes'] as String?;

            return _buildApplicationCard(
              applicationId: application.id,
              providerId: providerId!,
              status: status,
              submittedAt: submittedAt,
              reviewedAt: reviewedAt,
              notes: notes,
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getApplicationsStream() {
    // Get all applications and filter client-side to avoid index requirement
    return _firestore
        .collection('verification_queue')
        .orderBy('submittedAt', descending: true)
        .snapshots();
  }

  Widget _buildApplicationCard({
    required String applicationId,
    required String providerId,
    required String status,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? notes,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: shared.AppTheme.cardDark,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Application #${applicationId.length >= 8 ? applicationId.substring(0, 8) : applicationId}',
                  style: shared.AppTheme.heading3.copyWith(
                    color: shared.AppTheme.textPrimary,
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 16),

            // Provider Details
            FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('providers').doc(providerId).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Text(
                    'Provider data not found',
                    style: shared.AppTheme.bodyMedium.copyWith(
                      color: shared.AppTheme.error,
                    ),
                  );
                }

                final providerData = snapshot.data!.data() as Map<String, dynamic>;
                final applicationData = {
                  'providerId': providerId,
                  'status': status,
                  'submittedAt': submittedAt,
                  'reviewedAt': reviewedAt,
                  'notes': notes,
                };
                
                // Debug logging to trace data flow
                AppLogger.debug('=== VERIFICATION QUEUE DEBUG ===');
                AppLogger.debug('Provider ID: $providerId');
                AppLogger.debug('Raw provider data keys: ${providerData.keys.toList()}');
                AppLogger.debug('Business Name field: ${providerData['businessName']}');
                AppLogger.debug('Description field: ${providerData['description']}');
                AppLogger.debug('Documents field: ${providerData['documents']}');
                AppLogger.debug('Full provider data: $providerData');
                AppLogger.debug('=== END VERIFICATION QUEUE DEBUG ===');
                
                final businessName = providerData['businessName'] as String? ?? 'Unknown';
                final description = providerData['description'] as String? ?? '';
                
                // Handle both document storage formats:
                // 1. Individual fields (nrcUrl, businessLicenseUrl, certificatesUrl)
                // 2. Documents map (documents: {nrcUrl: "...", businessLicenseUrl: "..."})
                Map<String, dynamic> documents = {};
                
                // First, try to get documents from the verification queue entry (which should have the most up-to-date documents)
                // We need to fetch the actual verification queue document to get the docs field
                // This requires an additional Firestore query to get the actual verification queue entry
                // For now, we'll handle this in the ApplicationViewerDialog which has access to the full verification queue entry

                // Fall back to provider data for documents
                if (providerData['documents'] != null && providerData['documents'] is Map) {
                  documents = Map<String, dynamic>.from(providerData['documents']);
                } else {
                  // Check for individual document fields in provider data
                  if (providerData['nrcUrl'] != null && providerData['nrcUrl'].toString().isNotEmpty) {
                    documents['nrcUrl'] = providerData['nrcUrl'];
                  }
                  if (providerData['businessLicenseUrl'] != null && providerData['businessLicenseUrl'].toString().isNotEmpty) {
                    documents['businessLicenseUrl'] = providerData['businessLicenseUrl'];
                  }
                  if (providerData['certificatesUrl'] != null && providerData['certificatesUrl'].toString().isNotEmpty) {
                    documents['certificatesUrl'] = providerData['certificatesUrl'];
                  }
                }
                
                AppLogger.debug('Processed documents: $documents');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Business Info
                    Row(
                      children: [
                        Icon(
                          Icons.business,
                          size: 20,
                          color: shared.AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            businessName,
                            style: shared.AppTheme.bodyLarge.copyWith(
                              color: shared.AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    if (description.isNotEmpty) ...[
                      Text(
                        description,
                        style: shared.AppTheme.bodyMedium.copyWith(
                          color: shared.AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Documents
                    if (documents.isNotEmpty) ...[
                      Text(
                        'Submitted Documents:',
                        style: shared.AppTheme.bodyMedium.copyWith(
                          color: shared.AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: documents.entries.map((entry) {
                          return _buildDocumentChip(entry.key, entry.value);
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Timestamps
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: shared.AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Submitted: ${_formatDate(submittedAt)}',
                          style: shared.AppTheme.caption.copyWith(
                            color: shared.AppTheme.textTertiary,
                          ),
                        ),
                        if (reviewedAt != null) ...[
                          const SizedBox(width: 16),
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: shared.AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Reviewed: ${_formatDate(reviewedAt)}',
                            style: shared.AppTheme.caption.copyWith(
                              color: shared.AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),

                    if (notes != null && notes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: shared.AppTheme.cardLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin Notes:',
                              style: shared.AppTheme.bodyMedium.copyWith(
                                color: shared.AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notes,
                              style: shared.AppTheme.bodyMedium.copyWith(
                                color: shared.AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // Action Buttons
            if (status == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _viewApplication(applicationId, providerId),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View Details'),
                      style: shared.AppTheme.secondaryButtonStyle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _approveApplication(applicationId, providerId),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: shared.AppTheme.success,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _rejectApplication(applicationId, providerId),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: shared.AppTheme.error,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _viewApplication(applicationId, providerId),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View Details'),
                      style: shared.AppTheme.secondaryButtonStyle,
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

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case 'approved':
        color = shared.AppTheme.success;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = shared.AppTheme.error;
        icon = Icons.cancel;
        break;
      default:
        color = shared.AppTheme.warning;
        icon = Icons.pending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: shared.AppTheme.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentChip(String docType, String url) {
    IconData icon;
    String label;
    
    switch (docType) {
      case 'nrcUrl':
        icon = Icons.badge;
        label = 'National Registration Card (NRC)';
        break;
      case 'businessLicenseUrl':
        icon = Icons.business;
        label = 'Business License';
        break;
      case 'certificatesUrl':
        icon = Icons.verified_user;
        label = 'Professional Certificates';
        break;
      case 'otherDocs':
        icon = Icons.description;
        label = 'Other Documents';
        break;
      default:
        icon = Icons.attach_file;
        label = docType;
    }

    return InkWell(
      onTap: () => _viewDocument(docType, url),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: shared.AppTheme.primaryPurple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: shared.AppTheme.primaryPurple.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: shared.AppTheme.primaryPurple),
            const SizedBox(width: 4),
            Text(
              label,
              style: shared.AppTheme.caption.copyWith(
                color: shared.AppTheme.primaryPurple,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewApplication(String applicationId, String providerId) async {
    showDialog(
      context: context,
      builder: (context) => ApplicationViewerDialog(
        applicationId: applicationId,
        providerId: providerId,
      ),
    );
  }

  Future<void> _viewDocument(String docType, String url) async {
    showDialog(
      context: context,
      builder: (context) => DocumentViewerDialog(
        documentType: docType,
        documentUrl: url,
      ),
    );
  }

  Future<void> _approveApplication(String applicationId, String providerId) async {
    if (_isProcessing) return;

    final confirmed = await _showConfirmationDialog(
      'Approve Application',
      'Are you sure you want no approve this provider application?',
    );

    if (!confirmed) return;

    setState(() => _isProcessing = true);

    try {
      // Update verification queue status
      await _firestore.collection('verification_queue').doc(applicationId).update({
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': shared.AuthService().currentUser?.uid,
        'notes': 'Approved by admin',
      });

      // Update provider verification status
      await _firestore.collection('providers').doc(providerId).update({
        'verificationStatus': 'approved',
        'verified': true,
        'status': 'active',
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': shared.AuthService().currentUser?.uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Provider application approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _rejectApplication(String applicationId, String providerId) async {
    if (_isProcessing) return;

    final reason = await _showRejectionDialog();
    if (reason == null || reason.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      // Update verification queue status
      await _firestore.collection('verification_queue').doc(applicationId).update({
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': shared.AuthService().currentUser?.uid,
        'notes': reason,
      });

      // Update provider verification status
      await _firestore.collection('providers').doc(providerId).update({
        'verificationStatus': 'rejected',
        'verified': false,
        'status': 'inactive',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': shared.AuthService().currentUser?.uid,
        'rejectionReason': reason,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Provider application rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: shared.AppTheme.cardDark,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: shared.AppTheme.primaryButtonStyle,
            child: Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<String?> _showRejectionDialog() async {
    final controller = TextEditingController();
    
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: shared.AppTheme.cardDark,
        title: Text('Reject Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: shared.AppTheme.inputDecoration.copyWith(
                labelText: 'Rejection Reason',
                hintText: 'Enter reason for rejection...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: shared.AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text('Reject'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    
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
}
