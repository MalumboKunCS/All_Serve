import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared/shared.dart' as shared;
import '../../services/admin_notification_service.dart';

class ProviderVerificationScreen extends StatefulWidget {
  const ProviderVerificationScreen({super.key});

  @override
  State<ProviderVerificationScreen> createState() => _ProviderVerificationScreenState();
}

class _ProviderVerificationScreenState extends State<ProviderVerificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedStatus = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: shared.AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Provider Verification'),
        backgroundColor: shared.AppTheme.surfaceDark,
        actions: [
          // Filter dropdown
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: DropdownButton<String>(
              value: _selectedStatus,
              underline: Container(),
              style: shared.AppTheme.bodyMedium.copyWith(color: shared.AppTheme.textPrimary),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Providers')),
                DropdownMenuItem(value: 'pending', child: Text('Pending Review')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (value) {
                setState(() => _selectedStatus = value!);
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Cards
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Pending Review',
                    _getPendingCount(),
                    Icons.schedule,
                    shared.AppTheme.warning,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Approved',
                    _getApprovedCount(),
                    Icons.check_circle,
                    shared.AppTheme.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Rejected',
                    _getRejectedCount(),
                    Icons.cancel,
                    shared.AppTheme.error,
                  ),
                ),
              ],
            ),
          ),
          
          // Providers List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getProvidersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading providers: ${snapshot.error}',
                      style: const TextStyle(color: shared.AppTheme.error),
                    ),
                  );
                }

                final providers = snapshot.data?.docs ?? [];
                
                if (providers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: shared.AppTheme.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No providers found',
                          style: shared.AppTheme.bodyLarge.copyWith(
                            color: shared.AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: providers.length,
                  itemBuilder: (context, index) {
                    final provider = providers[index];
                    return _buildProviderCard(provider);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, Stream<int> count, IconData icon, Color color) {
    return Card(
      color: shared.AppTheme.cardDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            StreamBuilder<int>(
              stream: count,
              builder: (context, snapshot) {
                return Text(
                  '${snapshot.data ?? 0}',
                  style: shared.AppTheme.heading2.copyWith(
                    color: shared.AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            Text(
              title,
              style: shared.AppTheme.caption.copyWith(
                color: shared.AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard(QueryDocumentSnapshot queueDoc) {
    final queueData = queueDoc.data() as Map<String, dynamic>;
    final providerId = queueData['providerId'] ?? '';
    final status = queueData['status'] ?? 'pending';
    final submittedAt = queueData['submittedAt'];

    return Card(
      color: shared.AppTheme.cardDark,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('providers').doc(providerId).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Text(
                'Provider data not found',
                style: shared.AppTheme.bodyMedium.copyWith(color: shared.AppTheme.error),
              );
            }
            
            final providerData = snapshot.data!.data() as Map<String, dynamic>;
            final businessName = providerData['businessName'] ?? 'Unknown Business';
            final description = providerData['description'] ?? '';
            final categoryId = providerData['categoryId'] ?? '';
            final customCategory = providerData['customCategory'];
            final ownerName = providerData['ownerName'] ?? 'Unknown Owner';
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            businessName,
                            style: shared.AppTheme.bodyLarge.copyWith(
                              color: shared.AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      const SizedBox(height: 4),
                      Text(
                        'Owner: $ownerName',
                        style: shared.AppTheme.bodyMedium.copyWith(
                          color: shared.AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: shared.AppTheme.caption.copyWith(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Provider Details
            Row(
              children: [
                Icon(Icons.business, size: 16, color: shared.AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'ID: ${providerId.length >= 8 ? providerId.substring(0, 8) : providerId}...',
                  style: shared.AppTheme.bodyMedium.copyWith(
                    color: shared.AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.category, size: 16, color: shared.AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Category: ${customCategory != null ? customCategory : categoryId}',
                  style: shared.AppTheme.bodyMedium.copyWith(
                    color: shared.AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            
            // Description
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Description: $description',
                style: shared.AppTheme.bodyMedium.copyWith(
                  color: shared.AppTheme.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            if (submittedAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: shared.AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Submitted: ${_formatDate((submittedAt as Timestamp).toDate())}',
                    style: shared.AppTheme.bodyMedium.copyWith(
                      color: shared.AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewProviderDetails(providerId),
                    icon: const Icon(Icons.visibility),
                    label: const Text('View Details'),
                    style: shared.AppTheme.outlineButtonStyle,
                  ),
                ),
                const SizedBox(width: 12),
                if (status == 'pending') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveProvider(providerId, businessName, ownerName),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: shared.AppTheme.primaryButtonStyle.copyWith(
                        backgroundColor: MaterialStateProperty.all(shared.AppTheme.success),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectProvider(providerId, businessName, ownerName),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: shared.AppTheme.outlineButtonStyle.copyWith(
                        foregroundColor: MaterialStateProperty.all(shared.AppTheme.error),
                        side: MaterialStateProperty.all(BorderSide(color: shared.AppTheme.error)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
          },
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getProvidersStream() {
    if (_selectedStatus == 'all') {
      return _firestore
          .collection('verification_queue')
          .orderBy('submittedAt', descending: true)
          .snapshots();
    } else {
      return _firestore
          .collection('verification_queue')
          .where('status', isEqualTo: _selectedStatus)
          .orderBy('submittedAt', descending: true)
          .snapshots();
    }
  }

  Stream<int> _getPendingCount() {
    return _firestore
        .collection('verification_queue')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> _getApprovedCount() {
    return _firestore
        .collection('providers')
        .where('verificationStatus', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> _getRejectedCount() {
    return _firestore
        .collection('providers')
        .where('verificationStatus', isEqualTo: 'rejected')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return shared.AppTheme.warning;
      case 'approved':
        return shared.AppTheme.success;
      case 'rejected':
        return shared.AppTheme.error;
      default:
        return shared.AppTheme.textSecondary;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _viewProviderDetails(String providerId) {
    // TODO: Navigate to detailed provider view
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing details for provider: ${providerId.length >= 8 ? providerId.substring(0, 8) : providerId}...'),
        backgroundColor: shared.AppTheme.info,
      ),
    );
  }

  Future<void> _approveProvider(String providerId, String businessName, String ownerName) async {
    final confirmed = await _showConfirmationDialog(
      'Approve Provider',
      'Are you sure you want to approve $businessName?',
    );

    if (!confirmed) return;

    setState(() {});

    try {
      // Get provider data to check for custom category
      final providerDoc = await _firestore.collection('providers').doc(providerId).get();
      final providerData = providerDoc.data();
      final customCategory = providerData?['customCategory'];
      
      // Add custom category to categories collection if it exists and is unique
      if (customCategory != null && customCategory.isNotEmpty) {
        await _addCustomCategoryIfUnique(customCategory);
      }
      
      // Update provider status
      await _firestore.collection('providers').doc(providerId).update({
        'verificationStatus': 'approved',
        'status': 'active',
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Remove from verification queue
      final queueQuery = await _firestore
          .collection('verification_queue')
          .where('providerId', isEqualTo: providerId)
          .get();

      for (final doc in queueQuery.docs) {
        await doc.reference.delete();
      }

      // Notify provider
      await AdminNotificationService.notifyProviderVerificationStatus(
        providerId: providerId,
        status: 'approved',
        reason: null,
        adminName: 'Admin', // TODO: Get actual admin name
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$businessName has been approved successfully'),
            backgroundColor: shared.AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving provider: $e'),
            backgroundColor: shared.AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _rejectProvider(String providerId, String businessName, String ownerName) async {
    final reason = await _showRejectionDialog();
    if (reason == null) return;

    setState(() {});

    try {
      // Update provider status
      await _firestore.collection('providers').doc(providerId).update({
        'verificationStatus': 'rejected',
        'status': 'inactive',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update verification queue with rejection reason
      final queueQuery = await _firestore
          .collection('verification_queue')
          .where('providerId', isEqualTo: providerId)
          .get();

      for (final doc in queueQuery.docs) {
        await doc.reference.update({
          'status': 'rejected',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': 'Admin', // TODO: Get actual admin name
          'notes': reason,
        });
      }

      // Notify provider
      await AdminNotificationService.notifyProviderVerificationStatus(
        providerId: providerId,
        status: 'rejected',
        reason: reason,
        adminName: 'Admin', // TODO: Get actual admin name
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$businessName has been rejected'),
            backgroundColor: shared.AppTheme.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting provider: $e'),
            backgroundColor: shared.AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: shared.AppTheme.surfaceDark,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: shared.AppTheme.primaryButtonStyle,
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<String?> _showRejectionDialog() async {
    final reasonController = TextEditingController();
    
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: shared.AppTheme.surfaceDark,
        title: const Text('Reject Provider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Enter rejection reason...',
                hintStyle: TextStyle(color: shared.AppTheme.textTertiary),
                filled: true,
                fillColor: shared.AppTheme.cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: shared.AppTheme.textPrimary),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(reasonController.text.trim());
              }
            },
            style: shared.AppTheme.primaryButtonStyle,
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _addCustomCategoryIfUnique(String categoryName) async {
    try {
      // Check if category already exists
      final existingCategories = await _firestore
          .collection('categories')
          .where('name', isEqualTo: categoryName.toLowerCase())
          .get();
      
      if (existingCategories.docs.isEmpty) {
        // Add new category
        await _firestore.collection('categories').add({
          'name': categoryName,
          'description': 'Custom category added by admin approval',
          'createdAt': FieldValue.serverTimestamp(),
          'isCustom': true,
        });
        
        print('Added new custom category: $categoryName');
      }
    } catch (e) {
      print('Error adding custom category: $e');
    }
  }
}
