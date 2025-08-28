import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/provider.dart' as app_provider;
import '../../models/user.dart' as app_user;

class AdminProvidersScreen extends StatefulWidget {
  const AdminProvidersScreen({super.key});

  @override
  State<AdminProvidersScreen> createState() => _AdminProvidersScreenState();
}

class _AdminProvidersScreenState extends State<AdminProvidersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _verificationFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and Filter Bar
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Search Bar
              TextField(
                controller: _searchController,
                decoration: AppTheme.inputDecoration.copyWith(
                  labelText: 'Search Providers',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
                onChanged: (value) {
                  setState(() => _searchQuery = value.toLowerCase());
                },
              ),
              
              const SizedBox(height: 16),
              
              // Filter Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _statusFilter,
                      decoration: AppTheme.inputDecoration.copyWith(
                        labelText: 'Status',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      dropdownColor: AppTheme.surfaceDark,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Status')),
                        DropdownMenuItem(value: 'active', child: Text('Active')),
                        DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                        DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                      ],
                      onChanged: (value) {
                        setState(() => _statusFilter = value ?? 'all');
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _verificationFilter,
                      decoration: AppTheme.inputDecoration.copyWith(
                        labelText: 'Verification',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      dropdownColor: AppTheme.surfaceDark,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'approved', child: Text('Verified')),
                        DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                      ],
                      onChanged: (value) {
                        setState(() => _verificationFilter = value ?? 'all');
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Providers List
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
                        'Error loading providers',
                        style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                );
              }

              var providers = snapshot.data?.docs ?? [];

              // Apply additional client-side filtering
              providers = providers.where((doc) {
                final provider = app_provider.Provider.fromFirestore(doc);
                
                // Search filter
                if (_searchQuery.isNotEmpty) {
                  final searchText = '${provider.businessName} ${provider.description}'.toLowerCase();
                  if (!searchText.contains(_searchQuery)) {
                    return false;
                  }
                }
                
                return true;
              }).toList();

              if (providers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.business_outlined,
                        size: 64,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No providers found',
                        style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try adjusting your search or filters',
                        style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: providers.length,
                itemBuilder: (context, index) {
                  final providerDoc = providers[index];
                  final provider = app_provider.Provider.fromFirestore(providerDoc);
                  return _buildProviderCard(provider);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('providers');

    // Status filter
    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    }

    // Verification filter
    if (_verificationFilter != 'all') {
      if (_verificationFilter == 'approved') {
        query = query.where('verified', isEqualTo: true);
      } else {
        query = query.where('verificationStatus', isEqualTo: _verificationFilter);
      }
    }

    return query.orderBy('createdAt', descending: true);
  }

  Widget _buildProviderCard(app_provider.Provider provider) {
    return Card(
      color: AppTheme.surfaceDark,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              provider.businessName,
                              style: AppTheme.heading3.copyWith(
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          _buildVerificationBadge(provider),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider.description,
                        style: AppTheme.bodyText.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: AppTheme.textSecondary),
                  color: AppTheme.surfaceDark,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: AppTheme.textPrimary),
                          const SizedBox(width: 8),
                          Text('Edit', style: TextStyle(color: AppTheme.textPrimary)),
                        ],
                      ),
                      onTap: () => _showEditProviderDialog(provider),
                    ),
                    if (provider.status == 'active')
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(Icons.block, color: AppTheme.warning),
                            const SizedBox(width: 8),
                            Text('Suspend', style: TextStyle(color: AppTheme.warning)),
                          ],
                        ),
                        onTap: () => _changeProviderStatus(provider, 'suspended'),
                      )
                    else
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: AppTheme.success),
                            const SizedBox(width: 8),
                            Text('Activate', style: TextStyle(color: AppTheme.success)),
                          ],
                        ),
                        onTap: () => _changeProviderStatus(provider, 'active'),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Provider Stats
            Row(
              children: [
                _buildStatChip(
                  Icons.star,
                  '${provider.ratingAvg.toStringAsFixed(1)} (${provider.ratingCount})',
                  AppTheme.warning,
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  Icons.work,
                  '${provider.services.length} service${provider.services.length != 1 ? 's' : ''}',
                  AppTheme.primary,
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  Icons.location_on,
                  '${provider.serviceAreaKm.toStringAsFixed(0)}km radius',
                  AppTheme.info,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Owner Info
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(provider.ownerUid)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.exists) {
                  final owner = app_user.User.fromFirestore(snapshot.data!);
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
                        Expanded(
                          child: Text(
                            'Owner: ${owner.name} (${owner.email}) • ${owner.phone}',
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            const SizedBox(height: 12),

            // Status and Actions
            Row(
              children: [
                _buildStatusChip(provider.status),
                const Spacer(),
                TextButton(
                  onPressed: () => _viewProviderDetails(provider),
                  child: Text(
                    'View Details',
                    style: TextStyle(color: AppTheme.accent),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationBadge(app_provider.Provider provider) {
    if (provider.verified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.success.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.success),
        ),
        child: Text(
          'VERIFIED',
          style: AppTheme.caption.copyWith(
            color: AppTheme.success,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    Color color;
    String text;
    switch (provider.verificationStatus) {
      case 'pending':
        color = AppTheme.warning;
        text = 'PENDING';
        break;
      case 'rejected':
        color = AppTheme.error;
        text = 'REJECTED';
        break;
      default:
        color = AppTheme.textSecondary;
        text = 'UNVERIFIED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: AppTheme.caption.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'active':
        color = AppTheme.success;
        break;
      case 'suspended':
        color = AppTheme.error;
        break;
      case 'inactive':
        color = AppTheme.textSecondary;
        break;
      default:
        color = AppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: AppTheme.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
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
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeProviderStatus(app_provider.Provider provider, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(provider.providerId)
          .update({'status': newStatus});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Provider status updated to $newStatus'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showEditProviderDialog(app_provider.Provider provider) {
    // TODO: Implement detailed provider editing dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit provider: ${provider.businessName}'),
        backgroundColor: AppTheme.info,
      ),
    );
  }

  void _viewProviderDetails(app_provider.Provider provider) {
    // TODO: Navigate to detailed provider view
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('View details: ${provider.businessName}'),
        backgroundColor: AppTheme.info,
      ),
    );
  }
}
