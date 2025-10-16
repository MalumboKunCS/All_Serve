import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared/shared.dart' as shared;

class ProviderListWidget extends StatefulWidget {
  final Function(shared.Provider) onProviderSelected;
  final Function(shared.Provider, String) onProviderAction;

  const ProviderListWidget({
    super.key,
    required this.onProviderSelected,
    required this.onProviderAction,
  });

  @override
  State<ProviderListWidget> createState() => _ProviderListWidgetState();
}

class _ProviderListWidgetState extends State<ProviderListWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedStatus = 'all';
  String _sortBy = 'businessName';
  bool _sortAscending = true;
  
  final List<String> _categories = ['all'];
  final List<String> _statuses = ['all', 'active', 'suspended', 'pending'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      // Get categories from categories collection
      final categoriesSnapshot = await _firestore.collection('categories').get();
      final categoriesFromCollection = categoriesSnapshot.docs
          .map((doc) => doc.data()['name'] as String)
          .toList();
      
      // Get categories from existing providers
      final providersSnapshot = await _firestore
          .collection('providers')
          .where('verified', isEqualTo: true)
          .where('verificationStatus', isEqualTo: 'approved')
          .get();
      
      final providerCategories = providersSnapshot.docs
          .map((doc) => doc.data()['categoryId'] as String)
          .where((category) => category.isNotEmpty)
          .toSet()
          .toList();
      
      // Combine and deduplicate categories
      final allCategories = <String>{};
      allCategories.addAll(categoriesFromCollection);
      allCategories.addAll(providerCategories);
      
      setState(() {
        _categories.clear();
        _categories.addAll(['all', ...allCategories.toList()..sort()]);
      });
    } catch (e) {
      print('Error loading categories: $e');
      // Fallback to basic categories
      setState(() {
        _categories.clear();
        _categories.addAll(['all', 'plumbing', 'electrical', 'gardening', 'cleaning', 'tutoring']);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filters and Search
        _buildFiltersSection(),
        const SizedBox(height: 16),
        
        // Provider List
        Expanded(
          child: _buildProvidersList(),
        ),
      ],
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shared.AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: shared.AppTheme.cardLight,
        ),
      ),
      child: Column(
        children: [
          // Search Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: shared.AppTheme.inputDecoration.copyWith(
                    labelText: 'Search providers...',
                    hintText: 'Search by business name, category, or location',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty || _selectedCategory != 'all' || _selectedStatus != 'all')
                IconButton(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.filter_alt_off),
                  tooltip: 'Clear all filters',
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Filter Row
          Row(
            children: [
              // Category Filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: shared.AppTheme.inputDecoration.copyWith(
                    labelText: 'Category',
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category == 'all' ? 'All Categories' : category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              
              // Status Filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: shared.AppTheme.inputDecoration.copyWith(
                    labelText: 'Status',
                  ),
                  items: _statuses.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(_getStatusDisplayName(status)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              
              // Sort Options
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sortBy,
                  decoration: shared.AppTheme.inputDecoration.copyWith(
                    labelText: 'Sort By',
                  ),
                  items: [
                    DropdownMenuItem(value: 'businessName', child: Text('Business Name')),
                    DropdownMenuItem(value: 'ratingAvg', child: Text('Rating')),
                    DropdownMenuItem(value: 'totalBookings', child: Text('Total Bookings')),
                    DropdownMenuItem(value: 'createdAt', child: Text('Joined Date')),
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
                icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                ),
                tooltip: _sortAscending ? 'Sort Ascending' : 'Sort Descending',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProvidersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getProvidersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading providers: ${snapshot.error}',
              style: shared.AppTheme.bodyMedium.copyWith(
                color: shared.AppTheme.error,
              ),
            ),
          );
        }

        final allProviders = snapshot.data?.docs ?? [];
        
        // Convert to Provider objects
        final providers = allProviders.map((doc) {
          final providerData = doc.data() as Map<String, dynamic>;
          return shared.Provider.fromMap(providerData, id: doc.id);
        }).toList();

        // Apply filters and search
        final filteredProviders = _applyFiltersAndSearch(providers);
        
        // Show results count
        if (providers.isNotEmpty) {
          return Column(
            children: [
              // Results count
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: shared.AppTheme.cardLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Showing ${filteredProviders.length} of ${providers.length} providers',
                  style: shared.AppTheme.bodyMedium.copyWith(
                    color: shared.AppTheme.textSecondary,
                  ),
                ),
              ),
              
              // Providers list
              Expanded(
                child: filteredProviders.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: filteredProviders.length,
                        itemBuilder: (context, index) {
                          return _buildProviderCard(filteredProviders[index]);
                        },
                      ),
              ),
            ],
          );
        }
        
        return _buildEmptyState();
      },
    );
  }

  Stream<QuerySnapshot> _getProvidersStream() {
    // Only get approved and verified providers
    return _firestore
        .collection('providers')
        .where('verified', isEqualTo: true)
        .where('verificationStatus', isEqualTo: 'approved')
        .snapshots();
  }

  List<shared.Provider> _applyFiltersAndSearch(List<shared.Provider> providers) {
    List<shared.Provider> filtered = providers;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((provider) {
        final query = _searchQuery.toLowerCase();
        return provider.businessName.toLowerCase().contains(query) ||
               provider.categoryId.toLowerCase().contains(query) ||
               provider.description.toLowerCase().contains(query) ||
               provider.keywords.any((keyword) => keyword.toLowerCase().contains(query));
      }).toList();
    }

    // Apply category filter
    if (_selectedCategory != 'all') {
      filtered = filtered.where((provider) {
        return provider.categoryId.toLowerCase() == _selectedCategory.toLowerCase();
      }).toList();
    }

    // Apply status filter
    if (_selectedStatus != 'all') {
      filtered = filtered.where((provider) {
        return provider.status.toLowerCase() == _selectedStatus.toLowerCase();
      }).toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;
      
      switch (_sortBy) {
        case 'businessName':
          comparison = a.businessName.compareTo(b.businessName);
          break;
        case 'ratingAvg':
          comparison = a.ratingAvg.compareTo(b.ratingAvg);
          break;
        case 'totalBookings':
          // Using ratingCount as proxy for totalBookings since it's not in the model
          comparison = a.ratingCount.compareTo(b.ratingCount);
          break;
        case 'createdAt':
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        default:
          comparison = a.businessName.compareTo(b.businessName);
      }
      
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _selectedCategory = 'all';
      _selectedStatus = 'all';
      _sortBy = 'businessName';
      _sortAscending = true;
      _searchController.clear();
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business_outlined,
            size: 64,
            color: shared.AppTheme.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No providers found',
            style: shared.AppTheme.heading3.copyWith(
              color: shared.AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedCategory != 'all' || _selectedStatus != 'all'
                ? 'No providers match your current search and filters'
                : 'No approved providers available',
            style: shared.AppTheme.bodyMedium.copyWith(
              color: shared.AppTheme.textTertiary,
            ),
          ),
          if (_searchQuery.isNotEmpty || _selectedCategory != 'all' || _selectedStatus != 'all') ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Filters'),
              style: shared.AppTheme.secondaryButtonStyle,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProviderCard(shared.Provider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: shared.AppTheme.cardDark,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => widget.onProviderSelected(provider),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Provider Logo/Avatar
              CircleAvatar(
                radius: 30,
                backgroundColor: shared.AppTheme.primaryPurple.withValues(alpha:0.1),
                backgroundImage: provider.logoUrl != null && provider.logoUrl!.isNotEmpty
                    ? NetworkImage(provider.logoUrl!)
                    : null,
                child: provider.logoUrl == null || provider.logoUrl!.isEmpty
                    ? Text(
                        provider.businessName.isNotEmpty 
                            ? provider.businessName.substring(0, 1).toUpperCase()
                            : 'P',
                        style: shared.AppTheme.heading3.copyWith(
                          color: shared.AppTheme.primaryPurple,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              
              // Provider Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Business Name
                    Text(
                      provider.businessName,
                      style: shared.AppTheme.bodyLarge.copyWith(
                        color: shared.AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // Category and Status
                    Row(
                      children: [
                        _buildStatusChip(provider.status),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: shared.AppTheme.cardLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            provider.categoryId,
                            style: shared.AppTheme.caption.copyWith(
                              color: shared.AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Rating and Bookings
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: shared.AppTheme.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${provider.ratingAvg.toStringAsFixed(1)} (${provider.ratingCount} reviews)',
                          style: shared.AppTheme.caption.copyWith(
                            color: shared.AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.book_online,
                          size: 16,
                          color: shared.AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${provider.ratingCount} bookings',
                          style: shared.AppTheme.caption.copyWith(
                            color: shared.AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Action Buttons
              Column(
                children: [
                  IconButton(
                    onPressed: () => widget.onProviderSelected(provider),
                    icon: const Icon(Icons.visibility),
                    tooltip: 'View Details',
                  ),
                  PopupMenuButton<String>(
                    onSelected: (action) => widget.onProviderAction(provider, action),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'suspend',
                        child: ListTile(
                          leading: Icon(Icons.pause_circle_outline),
                          title: Text('Suspend'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'promote',
                        child: ListTile(
                          leading: Icon(Icons.star_outline),
                          title: Text('Promote to Featured'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'reset_password',
                        child: ListTile(
                          leading: Icon(Icons.lock_reset),
                          title: Text('Reset Password'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: Colors.red),
                          title: Text('Delete', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
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
    
    switch (status.toLowerCase()) {
      case 'active':
        color = shared.AppTheme.success;
        icon = Icons.check_circle;
        break;
      case 'suspended':
        color = shared.AppTheme.error;
        icon = Icons.pause_circle;
        break;
      case 'pending':
        color = shared.AppTheme.warning;
        icon = Icons.pending;
        break;
      default:
        color = shared.AppTheme.textTertiary;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
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

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'all':
        return 'All Statuses';
      case 'active':
        return 'Active';
      case 'suspended':
        return 'Suspended';
      case 'pending':
        return 'Pending';
      default:
        return status;
    }
  }
}
