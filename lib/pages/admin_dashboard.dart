import 'package:flutter/material.dart';
import 'package:all_server/models/provider.dart';
import 'package:all_server/services/admin_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _adminStats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAdminStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminStats() async {
    final stats = await AdminService.getDashboardStats();
    setState(() {
      _adminStats = stats;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ALL SERVE - Admin Dashboard'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.red.shade200,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Pending Verifications'),
            Tab(text: 'All Providers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildPendingVerificationsTab(),
          _buildAllProvidersTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Dashboard Overview',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage providers, verifications, and system overview',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),

          // Stats Cards
          if (_adminStats != null)
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  'Total Users',
                  '${_adminStats!['totalUsers'] ?? 0}',
                  Icons.people,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Total Providers',
                  '${_adminStats!['totalProviders'] ?? 0}',
                  Icons.business,
                  Colors.green,
                ),
                _buildStatCard(
                  'Verified Providers',
                  '${_adminStats!['activeProviders'] ?? 0}',
                  Icons.verified,
                  Colors.purple,
                ),
                _buildStatCard(
                  'Pending Verifications',
                  '${_adminStats!['pendingVerifications'] ?? 0}',
                  Icons.pending,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Suspended Providers',
                  '${_adminStats!['suspendedProviders'] ?? 0}',
                  Icons.block,
                  Colors.red,
                ),
                _buildStatCard(
                  'Total Bookings',
                  '${_adminStats!['totalBookings'] ?? 0}',
                  Icons.calendar_month,
                  Colors.teal,
                ),
              ],
            ),
          const SizedBox(height: 32),

          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  'Send Announcement',
                  'Send notification to all providers',
                  Icons.announcement,
                  Colors.blue,
                  () => _showAnnouncementDialog(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionCard(
                  'Refresh Stats',
                  'Update dashboard statistics',
                  Icons.refresh,
                  Colors.green,
                  () => _loadAdminStats(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingVerificationsTab() {
    return StreamBuilder<List<Provider>>(
      stream: AdminService.getPendingVerifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final pendingProviders = snapshot.data ?? [];

        if (pendingProviders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text(
                  'No pending verifications',
                  style: TextStyle(fontSize: 18),
                ),
                Text('All provider verifications are up to date'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pendingProviders.length,
          itemBuilder: (context, index) {
            final provider = pendingProviders[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: Icon(Icons.business, color: Colors.orange.shade700),
                ),
                title: Text(
                  provider.businessName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Category: ${provider.category}'),
                    Text('Owner: ${provider.ownerName ?? 'Not provided'}'),
                    Text('Submitted: ${_formatDate(provider.createdAt)}'),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Business Description:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(provider.description),
                        const SizedBox(height: 16),
                        
                        // Documents
                        Text(
                          'Submitted Documents:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (provider.businessLicense != null)
                          _buildDocumentLink('Business License', provider.businessLicense!),
                        if (provider.pacraRegistration != null)
                          _buildDocumentLink('PACRA Registration', provider.pacraRegistration!),
                        if (provider.verificationDocuments != null)
                          ...provider.verificationDocuments!.map((doc) =>
                              _buildDocumentLink('Additional Document', doc)),
                        
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showRejectDialog(provider),
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showApproveDialog(provider),
                                icon: const Icon(Icons.check),
                                label: const Text('Approve'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAllProvidersTab() {
    return StreamBuilder<List<Provider>>(
      stream: AdminService.getAllProviders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final providers = snapshot.data ?? [];

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: providers.length,
          itemBuilder: (context, index) {
            final provider = providers[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(provider.status)
                      .withValues(alpha: 0.2),
                  child: Icon(
                    _getStatusIcon(provider.status),
                    color: _getStatusColor(provider.status),
                  ),
                ),
                title: Text(
                  provider.businessName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${provider.category} • ${provider.ownerName ?? 'No owner'}'),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(provider.status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(provider.status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (provider.rating > 0)
                          Row(
                            children: [
                              const Icon(Icons.star, size: 14, color: Colors.amber),
                              Text(' ${provider.rating.toStringAsFixed(1)}'),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) => _handleProviderAction(value, provider),
                  itemBuilder: (context) => [
                    if (provider.status != ProviderStatus.suspended)
                      const PopupMenuItem(
                        value: 'suspend',
                        child: Row(
                          children: [
                            Icon(Icons.block, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Suspend'),
                          ],
                        ),
                      ),
                    if (provider.status == ProviderStatus.suspended)
                      const PopupMenuItem(
                        value: 'reactivate',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Reactivate'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentLink(String title, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.description, size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                // In a real app, this would open the document
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Document view not implemented')),
                );
              },
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.blue.shade600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(Provider provider) {
    final TextEditingController notesController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Provider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Approve ${provider.businessName} for the platform?'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Admin Notes (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await AdminService.approveProvider(
                provider.id,
                notesController.text.trim(),
              );
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Provider approved successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(Provider provider) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Provider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reject ${provider.businessName}\'s verification?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason *',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a rejection reason')),
                );
                return;
              }
              
              final success = await AdminService.rejectProvider(
                provider.id,
                reasonController.text.trim(),
              );
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Provider rejected'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showAnnouncementDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Announcement'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty || 
                  messageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in all fields')),
                );
                return;
              }
              
              final success = await AdminService.sendSystemNotification(
                title: titleController.text.trim(),
                body: messageController.text.trim(),
                targetAudience: 'providers',
              );
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Announcement sent to all providers!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _handleProviderAction(String action, Provider provider) {
    switch (action) {
      case 'suspend':
        _showSuspendDialog(provider);
        break;
      case 'reactivate':
        AdminService.reactivateProvider(provider.id);
        break;
      case 'view':
        // Show provider details
        break;
    }
  }

  void _showSuspendDialog(Provider provider) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspend Provider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Suspend ${provider.businessName}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Suspension Reason *',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a suspension reason')),
                );
                return;
              }
              
              final success = await AdminService.suspendProvider(
                provider.id,
                reasonController.text.trim(),
              );
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Provider suspended'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ProviderStatus status) {
    switch (status) {
      case ProviderStatus.verified:
        return Colors.green;
      case ProviderStatus.pending:
        return Colors.orange;
      case ProviderStatus.suspended:
        return Colors.red;
      case ProviderStatus.rejected:
        return Colors.red.shade800;
    }
  }

  IconData _getStatusIcon(ProviderStatus status) {
    switch (status) {
      case ProviderStatus.verified:
        return Icons.verified;
      case ProviderStatus.pending:
        return Icons.pending;
      case ProviderStatus.suspended:
        return Icons.block;
      case ProviderStatus.rejected:
        return Icons.cancel;
    }
  }

  String _getStatusText(ProviderStatus status) {
    switch (status) {
      case ProviderStatus.verified:
        return 'Verified';
      case ProviderStatus.pending:
        return 'Pending';
      case ProviderStatus.suspended:
        return 'Suspended';
      case ProviderStatus.rejected:
        return 'Rejected';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}




