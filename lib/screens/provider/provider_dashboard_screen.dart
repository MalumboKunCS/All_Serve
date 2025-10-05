import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import 'package:shared/shared.dart' as shared;
import '../../models/provider.dart' as app_provider;
import '../../models/booking.dart';
import '../../services/enhanced_booking_service.dart';
import 'provider_profile_screen.dart';
import 'provider_services_screen.dart';
import 'provider_bookings_screen.dart';
import 'provider_reviews_screen.dart';
import 'provider_settings_screen.dart';
import '../../widgets/provider_registration_status_widget.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});

  @override
  State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  app_provider.Provider? _provider;
  List<Booking> _recentBookings = [];
  List<Booking> _allBookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      final authService = Provider.of<shared.AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Load provider data
      final providerQuery = await FirebaseFirestore.instance
          .collection('providers')
          .where('ownerUid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (providerQuery.docs.isNotEmpty) {
        _provider = app_provider.Provider.fromFirestore(providerQuery.docs.first);
        
        // Load recent bookings for this provider using enhanced service
        final bookingsStream = EnhancedBookingService.getBookingsStream(
          userId: _provider!.providerId,
          userType: UserType.provider,
        );
        
        // Get all bookings from the stream for stats calculation
        await for (final bookings in bookingsStream) {
          _allBookings = bookings;
          _recentBookings = bookings.take(10).toList();
          break; // Only take the first batch
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
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
        title: const Text('Provider Dashboard'),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProviderSettingsScreen(provider: _provider),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats Cards
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Bookings',
                          '${_allBookings.length}',
                          Icons.bookmark,
                          AppTheme.primaryPurple,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Pending',
                          '${_getBookingsByStatus(BookingStatus.pending).length}',
                          Icons.schedule,
                          AppTheme.warning,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Completed',
                          '${_getBookingsByStatus(BookingStatus.completed).length}',
                          Icons.done_all,
                          AppTheme.success,
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
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Bookings'),
                      Tab(text: 'Services'),
                      Tab(text: 'Profile'),
                    ],
                  ),
                ),
                
                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      ProviderBookingsScreen(provider: _provider),
                      ProviderServicesScreen(provider: _provider),
                      ProviderProfileScreen(provider: _provider),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProviderServicesScreen(provider: _provider),
            ),
          );
        },
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Service', style: TextStyle(color: Colors.white)),
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

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome Back!',
            style: AppTheme.heading1.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Here\'s what\'s happening with your business today',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Registration Status Widget
          const ProviderRegistrationStatusWidget(),
          
          const SizedBox(height: 24),
          
          // Verification Status Card
          if (_provider != null) _buildVerificationStatusCard(),
          
          const SizedBox(height: 24),
          
          // Quick Actions
          _buildQuickActions(),
          
          const SizedBox(height: 24),
          
          // Recent Activity
          Text(
            'Recent Activity',
            style: AppTheme.heading2.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_recentBookings.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 64,
                    color: AppTheme.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No recent bookings',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'New bookings will appear here',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentBookings.take(5).length,
              itemBuilder: (context, index) {
                final booking = _recentBookings[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: AppTheme.cardDark,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(booking.status),
                      child: Icon(
                        _getStatusIcon(booking.status),
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      'Booking #${booking.bookingId.length >= 8 ? booking.bookingId.substring(0, 8) : booking.bookingId}',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${booking.statusDisplayName} • ${_formatDate(booking.scheduledAt)}',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: AppTheme.textTertiary,
                      size: 16,
                    ),
                    onTap: () {
                      // TODO: Navigate to booking detail
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }



  Widget _buildVerificationStatusCard() {
    if (_provider == null) return const SizedBox.shrink();
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String statusMessage;

    switch (_provider!.verificationStatus) {
      case 'pending':
        statusColor = AppTheme.warning;
        statusIcon = Icons.pending;
        statusText = 'Verification Pending';
        statusMessage = 'Your documents are being reviewed by our admin team';
        break;
      case 'approved':
        statusColor = AppTheme.success;
        statusIcon = Icons.verified;
        statusText = 'Verified Provider';
        statusMessage = 'Your business is verified and active';
        break;
      case 'rejected':
        statusColor = AppTheme.error;
        statusIcon = Icons.cancel;
        statusText = 'Verification Rejected';
        statusMessage = 'Please resubmit your documents with correct information';
        break;
      default:
        statusColor = AppTheme.textSecondary;
        statusIcon = Icons.help;
        statusText = 'Unknown Status';
        statusMessage = 'Contact support for assistance';
    }

    return Card(
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: AppTheme.bodyText.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    statusMessage,
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Manage Services',
                'Add or edit your services',
                Icons.work,
                AppTheme.primary,
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProviderServicesScreen(provider: _provider),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'View Reviews',
                'Check customer feedback',
                Icons.star,
                AppTheme.warning,
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProviderReviewsScreen(provider: _provider),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
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
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: color, size: 20),
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

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return AppTheme.warning;
      case BookingStatus.accepted:
        return AppTheme.success;
      case BookingStatus.inProgress:
        return AppTheme.primaryPurple;
      case BookingStatus.completed:
        return AppTheme.success;
      case BookingStatus.cancelled:
        return AppTheme.error;
      case BookingStatus.rejected:
        return AppTheme.error;
      case BookingStatus.rescheduled:
        return AppTheme.warning;
    }
  }

  IconData _getStatusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Icons.schedule;
      case BookingStatus.accepted:
        return Icons.check_circle;
      case BookingStatus.inProgress:
        return Icons.play_circle;
      case BookingStatus.completed:
        return Icons.done_all;
      case BookingStatus.cancelled:
        return Icons.cancel;
      case BookingStatus.rejected:
        return Icons.close;
      case BookingStatus.rescheduled:
        return Icons.schedule;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  List<Booking> _getBookingsByStatus(BookingStatus status) {
    return _allBookings.where((booking) => booking.status == status).toList();
  }
}

