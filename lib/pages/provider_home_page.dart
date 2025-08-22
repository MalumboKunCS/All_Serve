import 'package:flutter/material.dart';
import 'package:all_server/auth.dart';
import 'package:all_server/models/provider.dart';
import 'package:all_server/services/provider_service.dart';
import 'package:all_server/pages/provider_dashboard_content.dart';
import 'package:all_server/pages/provider_profile_page.dart';
import 'package:all_server/pages/provider_services_page.dart';
import 'package:all_server/pages/provider_bookings_page.dart';
import 'package:all_server/pages/provider_reviews_page.dart';
import 'package:all_server/pages/provider_earnings_page.dart';
import 'package:all_server/pages/provider_verification_page.dart';

class ProviderHomePage extends StatefulWidget {
  const ProviderHomePage({super.key});

  @override
  State<ProviderHomePage> createState() => _ProviderHomePageState();
}

class _ProviderHomePageState extends State<ProviderHomePage> {
  final ProviderService _providerService = ProviderService();
  Provider? _provider;
  int _selectedIndex = 0;
  bool _isLoading = true;

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.dashboard,
      label: 'Dashboard',
      selectedIcon: Icons.dashboard,
    ),
    NavigationItem(
      icon: Icons.business_outlined,
      label: 'Profile',
      selectedIcon: Icons.business,
    ),
    NavigationItem(
      icon: Icons.work_outline,
      label: 'Services',
      selectedIcon: Icons.work,
    ),
    NavigationItem(
      icon: Icons.calendar_month_outlined,
      label: 'Bookings',
      selectedIcon: Icons.calendar_month,
    ),
    NavigationItem(
      icon: Icons.star_outline,
      label: 'Reviews',
      selectedIcon: Icons.star,
    ),
    NavigationItem(
      icon: Icons.attach_money_outlined,
      label: 'Earnings',
      selectedIcon: Icons.attach_money,
    ),
    NavigationItem(
      icon: Icons.verified_outlined,
      label: 'Verification',
      selectedIcon: Icons.verified,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadProvider();
  }

  Future<void> _loadProvider() async {
    final user = Auth().currentUser;
    if (user != null) {
      final provider = await _providerService.getProvider(user.uid);
      setState(() {
        _provider = provider;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Auth().signOut();
    }
  }

  Widget _buildCurrentPage() {
    if (_provider == null) {
      return const Center(
        child: Text('Provider profile not found. Please contact support.'),
      );
    }

    switch (_selectedIndex) {
      case 0:
        return ProviderDashboardContent(provider: _provider!);
      case 1:
        return ProviderProfilePage(provider: _provider!);
      case 2:
        return ProviderServicesPage(provider: _provider!);
      case 3:
        return ProviderBookingsPage(provider: _provider!);
      case 4:
        return ProviderReviewsPage(provider: _provider!);
      case 5:
        return ProviderEarningsPage(provider: _provider!);
      case 6:
        return ProviderVerificationPage(provider: _provider!);
      default:
        return ProviderDashboardContent(provider: _provider!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          Container(
            width: 280,
            color: Colors.blue.shade800,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.blue.shade900,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        backgroundImage: _provider?.profileImageUrl != null
                            ? NetworkImage(_provider!.profileImageUrl!)
                            : null,
                        child: _provider?.profileImageUrl == null
                            ? Icon(
                                Icons.business,
                                size: 40,
                                color: Colors.blue.shade800,
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _provider?.businessName ?? 'Provider',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(_provider?.status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatusText(_provider?.status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Navigation Items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _navigationItems.length,
                    itemBuilder: (context, index) {
                      final item = _navigationItems[index];
                      final isSelected = _selectedIndex == index;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        child: ListTile(
                          leading: Icon(
                            isSelected ? item.selectedIcon : item.icon,
                            color: isSelected ? Colors.white : Colors.blue.shade200,
                          ),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.blue.shade200,
                              fontWeight: isSelected 
                                  ? FontWeight.w600 
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedTileColor: Colors.blue.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedIndex = index;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),

                // Sign Out Button
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        'Sign Out',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Content Area
          Expanded(
            child: Container(
              color: Colors.grey.shade50,
              child: _buildCurrentPage(),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ProviderStatus? status) {
    switch (status) {
      case ProviderStatus.verified:
        return Colors.green;
      case ProviderStatus.pending:
        return Colors.orange;
      case ProviderStatus.suspended:
        return Colors.red;
      case ProviderStatus.rejected:
        return Colors.red.shade800;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(ProviderStatus? status) {
    switch (status) {
      case ProviderStatus.verified:
        return 'Verified';
      case ProviderStatus.pending:
        return 'Pending';
      case ProviderStatus.suspended:
        return 'Suspended';
      case ProviderStatus.rejected:
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }
}

class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}



