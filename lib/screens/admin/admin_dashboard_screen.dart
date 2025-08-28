import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

import 'admin_verification_queue_screen.dart';
import 'admin_providers_screen.dart';
import 'admin_reviews_screen.dart';
import 'admin_announcements_screen.dart';


class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  
  // Dashboard stats
  int _totalUsers = 0;
  int _totalProviders = 0;
  int _pendingVerifications = 0;
  int _totalBookings = 0;
  int _flaggedReviews = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      // Load dashboard statistics
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      final providersSnapshot = await FirebaseFirestore.instance.collection('providers').get();
      final bookingsSnapshot = await FirebaseFirestore.instance.collection('bookings').get();
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('flagged', isEqualTo: true)
          .get();
      final verificationSnapshot = await FirebaseFirestore.instance
          .collection('verificationQueue')
          .where('status', isEqualTo: 'pending')
          .get();

      if (mounted) {
        setState(() {
          _totalUsers = usersSnapshot.docs.length;
          _totalProviders = providersSnapshot.docs.length;
          _totalBookings = bookingsSnapshot.docs.length;
          _flaggedReviews = reviewsSnapshot.docs.length;
          _pendingVerifications = verificationSnapshot.docs.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load dashboard: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              await authService.signOut();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats Overview
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Users',
                          '$_totalUsers',
                          Icons.people,
                          AppTheme.primaryPurple,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Providers',
                          '$_totalProviders',
                          Icons.business,
                          AppTheme.accentBlue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Pending Verifications',
                          '$_pendingVerifications',
                          Icons.pending,
                          AppTheme.warning,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Flagged Reviews',
                          '$_flaggedReviews',
                          Icons.flag,
                          AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Tab Bar
                Container(
                  color: AppTheme.surfaceDark,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primaryPurple,
                    unselectedLabelColor: AppTheme.textTertiary,
                    indicatorColor: AppTheme.primaryPurple,
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Verifications'),
                      Tab(text: 'Providers'),
                      Tab(text: 'Reviews'),
                      Tab(text: 'Announcements'),
                    ],
                  ),
                ),
                
                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      const AdminVerificationQueueScreen(),
                      const AdminProvidersScreen(),
                      const AdminReviewsScreen(),
                      const AdminAnnouncementsScreen(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.heading2.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: AppTheme.caption.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
      color: AppTheme.surfaceDark,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: AppTheme.bodyText.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTheme.caption.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Platform Overview',
            style: AppTheme.heading1.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Monitor and manage the All-Serve marketplace',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Platform Statistics
          Text(
            'Platform Statistics',
            style: AppTheme.heading2.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard('Total Users', '$_totalUsers', Icons.people, AppTheme.accentBlue),
              _buildStatCard('Providers', '$_totalProviders', Icons.business, AppTheme.primaryPurple),
              _buildStatCard('Total Bookings', '$_totalBookings', Icons.event, AppTheme.success),
              _buildStatCard('Flagged Reviews', '$_flaggedReviews', Icons.flag, AppTheme.warning),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Quick Actions
          Text(
            'Quick Actions',
            style: AppTheme.heading2.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildActionCard(
                'Review Providers',
                'Check pending verifications',
                Icons.verified_user,
                AppTheme.primaryPurple,
                () {
                  _tabController.animateTo(1);
                },
              ),
              _buildActionCard(
                'Manage Users',
                'View and manage all users',
                Icons.people,
                AppTheme.accentBlue,
                () {
                  _tabController.animateTo(2);
                },
              ),
              _buildActionCard(
                'Moderate Reviews',
                'Review flagged content',
                Icons.rate_review,
                AppTheme.warning,
                () {
                  _tabController.animateTo(3);
                },
              ),
              _buildActionCard(
                'Send Announcements',
                'Broadcast messages',
                Icons.announcement,
                AppTheme.info,
                () {
                  _tabController.animateTo(4);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }




}

