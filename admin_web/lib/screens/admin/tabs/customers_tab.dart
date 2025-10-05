import 'package:flutter/material.dart';
import 'package:shared/shared.dart' as shared;
import '../../../services/customer_management_service.dart';

class CustomersTab extends StatefulWidget {
  const CustomersTab({super.key});

  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  String _searchQuery = '';
  String _selectedStatus = 'all';
  String _sortBy = 'createdAt';
  bool _sortAscending = false;
  bool _showProfileView = false;
  shared.User? _selectedCustomer;

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
                    'Customer Management',
                    style: shared.AppTheme.heading1.copyWith(
                      color: shared.AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage customer accounts and monitor activity',
                    style: shared.AppTheme.bodyLarge.copyWith(
                      color: shared.AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              if (_showProfileView)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showProfileView = false;
                      _selectedCustomer = null;
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(
                    backgroundColor: shared.AppTheme.cardDark,
                    foregroundColor: shared.AppTheme.textPrimary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          if (!_showProfileView) ...[
            // Filters and Search
            _buildFiltersSection(),
            const SizedBox(height: 16),

            // Customers List
            Expanded(
              child: _buildCustomersList(),
            ),
          ] else if (_selectedCustomer != null) ...[
            // Customer Profile View
            Expanded(
              child: CustomerProfileView(
                customer: _selectedCustomer!,
                onBack: () {
                  setState(() {
                    _showProfileView = false;
                    _selectedCustomer = null;
                  });
                },
              ),
            ),
          ],
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
      child: Column(
        children: [
          // Search Bar
          TextField(
            decoration: shared.AppTheme.inputDecoration.copyWith(
              labelText: 'Search customers...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
            ),
            style: shared.AppTheme.bodyMedium.copyWith(
              color: shared.AppTheme.textPrimary,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 16),

          // Filters Row
          Row(
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
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),

              // Sort By Filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sortBy,
                  decoration: shared.AppTheme.inputDecoration.copyWith(
                    labelText: 'Sort By',
                  ),
                  items: [
                    DropdownMenuItem(value: 'createdAt', child: Text('Date Joined')),
                    DropdownMenuItem(value: 'name', child: Text('Name')),
                    DropdownMenuItem(value: 'email', child: Text('Email')),
                    DropdownMenuItem(value: 'totalBookings', child: Text('Total Bookings')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),

              // Sort Direction
              IconButton(
                onPressed: () {
                  setState(() {
                    _sortAscending = !_sortAscending;
                  });
                },
                icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                style: IconButton.styleFrom(
                  backgroundColor: shared.AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersList() {
    return StreamBuilder<List<shared.User>>(
      stream: CustomerManagementService.getCustomersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading customers: ${snapshot.error}',
              style: shared.AppTheme.bodyMedium.copyWith(
                color: shared.AppTheme.error,
              ),
            ),
          );
        }

        final customers = snapshot.data ?? [];
        final filteredCustomers = _applyFiltersAndSearch(customers);
        
        if (filteredCustomers.isEmpty) {
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
                  customers.isEmpty ? 'No customers found' : 'No customers match your filters',
                  style: shared.AppTheme.heading3.copyWith(
                    color: shared.AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  customers.isEmpty 
                      ? 'Customers will appear here once they register'
                      : 'Try adjusting your search or filter criteria',
                  style: shared.AppTheme.bodyMedium.copyWith(
                    color: shared.AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Results Count
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '${filteredCustomers.length} customer${filteredCustomers.length == 1 ? '' : 's'} found',
                style: shared.AppTheme.bodyMedium.copyWith(
                  color: shared.AppTheme.textSecondary,
                ),
              ),
            ),

            // Customers List
            Expanded(
              child: ListView.builder(
                itemCount: filteredCustomers.length,
                itemBuilder: (context, index) {
                  return _buildCustomerCard(filteredCustomers[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<shared.User> _applyFiltersAndSearch(List<shared.User> customers) {
    var filtered = customers.where((customer) {
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!customer.name.toLowerCase().contains(query) &&
            !customer.email.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Apply status filter
      if (_selectedStatus != 'all') {
        if (customer.status != _selectedStatus) {
          return false;
        }
      }

      return true;
    }).toList();

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'email':
          comparison = a.email.compareTo(b.email);
          break;
        case 'createdAt':
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case 'totalBookings':
          // TODO: Implement totalBookings field in User model
          comparison = 0;
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  Widget _buildCustomerCard(shared.User customer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: shared.AppTheme.cardDark,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _onCustomerSelected(customer),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: shared.AppTheme.primaryPurple,
                child: Text(
                  customer.name.isNotEmpty 
                      ? customer.name.substring(0, 1).toUpperCase()
                      : 'C',
                  style: shared.AppTheme.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Customer Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: shared.AppTheme.bodyLarge.copyWith(
                        color: shared.AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customer.email,
                      style: shared.AppTheme.bodyMedium.copyWith(
                        color: shared.AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildStatusChip(customer.status),
                        const SizedBox(width: 8),
                        Text(
                          'Joined ${_formatDate(customer.createdAt)}',
                          style: shared.AppTheme.caption.copyWith(
                            color: shared.AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Row(
                children: [
                  IconButton(
                    onPressed: () => _onCustomerSelected(customer),
                    icon: const Icon(Icons.visibility),
                    tooltip: 'View Details',
                    style: IconButton.styleFrom(
                      backgroundColor: shared.AppTheme.primaryPurple.withOpacity(0.1),
                      foregroundColor: shared.AppTheme.primaryPurple,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _showCustomerActions(customer),
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'Actions',
                    style: IconButton.styleFrom(
                      backgroundColor: shared.AppTheme.cardLight,
                      foregroundColor: shared.AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case 'active':
        color = shared.AppTheme.success;
        icon = Icons.check_circle;
        break;
      case 'suspended':
        color = shared.AppTheme.error;
        icon = Icons.block;
        break;
      case 'inactive':
        color = shared.AppTheme.warning;
        icon = Icons.pause_circle;
        break;
      default:
        color = shared.AppTheme.textSecondary;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else {
      return 'Today';
    }
  }

  void _onCustomerSelected(shared.User customer) {
    setState(() {
      _selectedCustomer = customer;
      _showProfileView = true;
    });
  }

  Future<void> _showCustomerActions(shared.User customer) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: shared.AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Customer Actions',
              style: shared.AppTheme.heading3.copyWith(
                color: shared.AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(context, 'view');
              },
            ),
            ListTile(
              leading: Icon(
                customer.status == 'active' ? Icons.block : Icons.check_circle,
                color: customer.status == 'active' ? shared.AppTheme.error : shared.AppTheme.success,
              ),
              title: Text(customer.status == 'active' ? 'Suspend Account' : 'Activate Account'),
              onTap: () {
                Navigator.pop(context, customer.status == 'active' ? 'suspend' : 'activate');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: shared.AppTheme.error),
              title: const Text('Delete Account'),
              onTap: () {
                Navigator.pop(context, 'delete');
              },
            ),
          ],
        ),
      ),
    );

    if (action != null) {
      switch (action) {
        case 'view':
          _onCustomerSelected(customer);
          break;
        case 'suspend':
          await _suspendCustomer(customer);
          break;
        case 'activate':
          await _activateCustomer(customer);
          break;
        case 'delete':
          await _deleteCustomer(customer);
          break;
      }
    }
  }

  Future<void> _suspendCustomer(shared.User customer) async {
    final confirmed = await _showConfirmationDialog(
      'Suspend Customer',
      'Are you sure you want to suspend ${customer.name}? They will not be able to make bookings.',
    );

    if (confirmed) {
      try {
        await CustomerManagementService.suspendCustomer(customer.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${customer.name} has been suspended'),
              backgroundColor: shared.AppTheme.warning,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to suspend customer: $e'),
              backgroundColor: shared.AppTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _activateCustomer(shared.User customer) async {
    final confirmed = await _showConfirmationDialog(
      'Activate Customer',
      'Are you sure you want to activate ${customer.name}? They will be able to make bookings again.',
    );

    if (confirmed) {
      try {
        await CustomerManagementService.activateCustomer(customer.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${customer.name} has been activated'),
              backgroundColor: shared.AppTheme.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to activate customer: $e'),
              backgroundColor: shared.AppTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteCustomer(shared.User customer) async {
    final confirmed = await _showConfirmationDialog(
      'Delete Customer',
      'Are you sure you want to permanently delete ${customer.name}? This action cannot be undone.',
    );

    if (confirmed) {
      try {
        await CustomerManagementService.deleteCustomer(customer.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${customer.name} has been deleted'),
              backgroundColor: shared.AppTheme.error,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete customer: $e'),
              backgroundColor: shared.AppTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: shared.AppTheme.cardDark,
        title: Text(
          title,
          style: shared.AppTheme.heading3.copyWith(
            color: shared.AppTheme.textPrimary,
          ),
        ),
        content: Text(
          message,
          style: shared.AppTheme.bodyMedium.copyWith(
            color: shared.AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: shared.AppTheme.bodyMedium.copyWith(
                color: shared.AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: shared.AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Confirm',
              style: shared.AppTheme.bodyMedium.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// Customer Profile View Widget
class CustomerProfileView extends StatelessWidget {
  final shared.User customer;
  final VoidCallback onBack;

  const CustomerProfileView({
    super.key,
    required this.customer,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: shared.AppTheme.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: shared.AppTheme.cardLight),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: shared.AppTheme.primaryPurple,
                  child: Text(
                    customer.name.isNotEmpty 
                        ? customer.name.substring(0, 1).toUpperCase()
                        : 'C',
                    style: shared.AppTheme.heading1.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: shared.AppTheme.heading2.copyWith(
                          color: shared.AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        customer.email,
                        style: shared.AppTheme.bodyLarge.copyWith(
                          color: shared.AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStatusChip(customer.status),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: shared.AppTheme.cardLight,
                    foregroundColor: shared.AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Account Information
          _buildSectionCard(
            title: 'Account Information',
            children: [
              _buildInfoRow('Full Name', customer.name),
              _buildInfoRow('Email', customer.email),
              _buildInfoRow('Phone', customer.phone.isNotEmpty ? customer.phone : 'Not provided'),
              _buildInfoRow('Join Date', _formatDate(customer.createdAt)),
              _buildInfoRow('Status', customer.status.toUpperCase()),
            ],
          ),
          const SizedBox(height: 16),

          // Activity Stats (Placeholder)
          _buildSectionCard(
            title: 'Activity Stats',
            children: [
              _buildStatRow('Total Bookings', '0'), // TODO: Implement
              _buildStatRow('Completed Bookings', '0'), // TODO: Implement
              _buildStatRow('Cancelled Bookings', '0'), // TODO: Implement
              _buildStatRow('Reviews Written', '0'), // TODO: Implement
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: shared.AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: shared.AppTheme.cardLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: shared.AppTheme.heading3.copyWith(
              color: shared.AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: shared.AppTheme.bodyMedium.copyWith(
                color: shared.AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: shared.AppTheme.bodyMedium.copyWith(
                color: shared.AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: shared.AppTheme.bodyMedium.copyWith(
              color: shared.AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: shared.AppTheme.bodyLarge.copyWith(
              color: shared.AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case 'active':
        color = shared.AppTheme.success;
        icon = Icons.check_circle;
        break;
      case 'suspended':
        color = shared.AppTheme.error;
        icon = Icons.block;
        break;
      case 'inactive':
        color = shared.AppTheme.warning;
        icon = Icons.pause_circle;
        break;
      default:
        color = shared.AppTheme.textSecondary;
        icon = Icons.help_outline;
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
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: shared.AppTheme.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
