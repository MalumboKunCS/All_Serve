import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../theme/app_theme.dart';
import 'package:shared/shared.dart' as shared;
import '../../models/provider.dart' as app_provider;
import '../../models/booking.dart';
import '../../services/enhanced_booking_service.dart';
import '../../services/verification_service.dart';
import '../../services/app_notification_service.dart';
import 'provider_profile_screen.dart';
import 'provider_services_screen.dart';
import 'provider_bookings_screen.dart';
import 'provider_reviews_screen.dart';
import 'provider_settings_screen.dart';
import 'notifications_screen.dart';
import 'provider_registration_screen.dart';
import '../../widgets/provider_registration_status_widget.dart';
import '../../widgets/registration_tracker_card.dart';
import '../../utils/firestore_debug_utils.dart';
import '../../services/provider_creation_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/responsive_utils.dart';

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
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild when tab changes
      // Reload data when switching to Overview tab (index 0) or Services tab (index 2)
      if ((_tabController.index == 0 || _tabController.index == 2) && !_isLoading) {
        _loadDashboardData();
      }
    });
    _loadDashboardData();
  }

  Future<void> _updateNotificationToken() async {
    try {
      final authService = shared.AuthService();
      final currentUser = authService.currentUser;
      if (currentUser != null) {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await authService.addDeviceToken(currentUser.uid, fcmToken);
          AppLogger.info('ProviderDashboardScreen: Updated FCM token for user ${currentUser.uid}');
        }
      }
    } catch (e) {
      AppLogger.error('ProviderDashboardScreen: Error updating notification token: $e');
    }
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
      AppLogger.debug('ProviderDashboardScreen: Loading provider for ownerUid: ${currentUser.uid}');
      final providerQuery = await FirebaseFirestore.instance
          .collection('providers')
          .where('ownerUid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      AppLogger.debug('ProviderDashboardScreen: Found ${providerQuery.docs.length} provider documents');
      if (providerQuery.docs.isNotEmpty) {
        _provider = app_provider.Provider.fromFirestore(providerQuery.docs.first);
        AppLogger.debug('ProviderDashboardScreen: Loaded provider with ${_provider!.services.length} services');
        AppLogger.debug('ProviderDashboardScreen: Provider ID: ${_provider!.providerId}');
        AppLogger.debug('ProviderDashboardScreen: Provider business name: ${_provider!.businessName}');
      } else {
        AppLogger.debug('ProviderDashboardScreen: No provider document found for ownerUid: ${currentUser.uid}');
        
        // Debug: Check if there are any provider documents at all
        await FirestoreDebugUtils.debugUserProviders(currentUser.uid);
        
        // Try to create a provider document if it doesn't exist
        AppLogger.debug('ProviderDashboardScreen: Attempting to create provider document...');
        _provider = await ProviderCreationService.createProviderIfNotExists();
        
        if (_provider != null) {
          AppLogger.debug('ProviderDashboardScreen: Successfully created provider document');
        } else {
          AppLogger.debug('ProviderDashboardScreen: Failed to create provider document');
          _provider = null;
        }
      }

      // Load recent bookings for this provider using enhanced service (only if provider exists)
      if (_provider != null) {
        final bookingsStream = EnhancedBookingService.getBookingsStream(
          userId: _provider!.providerId,
          userType: UserType.provider,
        );
        
        // Get all bookings from the stream for stats calculation
        await for (final bookings in bookingsStream) {
          _allBookings = bookings;
          // Only show pending bookings in Recent Activity
          _recentBookings = bookings
              .where((booking) => booking.status == BookingStatus.pending)
              .take(5)
            .toList();
          break; // Only take the first batch
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppLogger.debug('Error loading dashboard data: $e');
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

  Stream<int> _getUnreadNotificationCount() {
    final authService = Provider.of<shared.AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    if (currentUser == null) {
      return Stream.value(0);
    }
    
    return AppNotificationService.getUnreadCountStream(currentUser.uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Provider Dashboard'),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
          // Notification Bell with Badge
          StreamBuilder<int>(
            stream: _getUnreadNotificationCount(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
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
                // Status Banner
                _buildStatusBanner(),
                // Stats Cards - Enhanced Design with Progress
                Container(
                  padding: ResponsiveUtils.getResponsivePadding(context),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.surfaceDark,
                        AppTheme.backgroundDark,
                      ],
                    ),
                  ),
                  child: ResponsiveLayoutBuilder(
                    builder: (context, screenType) {
                      // For mobile, show 2x2 grid; for tablet/desktop, show horizontal row
                      if (screenType == ScreenType.mobile) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    title: 'Total\nBookings',
                                    value: '${_allBookings.length}',
                                    icon: Icons.calendar_today_rounded,
                                    color: AppTheme.primaryPurple,
                                    tooltip: 'Total number of bookings received',
                                  ),
                                ),
                                SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                                  context,
                                  mobile: AppTheme.spacingSm,
                                  tablet: AppTheme.spacingMd,
                                  desktop: AppTheme.spacingLg,
                                )),
                                Expanded(
                                  child: _buildStatCard(
                                    title: 'Pending',
                                    value: '${_getBookingsByStatus(BookingStatus.pending).length}',
                                    icon: Icons.schedule_rounded,
                                    color: AppTheme.warning,
                                    tooltip: 'Bookings awaiting your response',
                                    progress: _allBookings.isEmpty ? 0 : _getBookingsByStatus(BookingStatus.pending).length / _allBookings.length,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                              context,
                              mobile: AppTheme.spacingSm,
                              tablet: AppTheme.spacingMd,
                              desktop: AppTheme.spacingLg,
                            )),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    title: 'Completed',
                                    value: '${_getBookingsByStatus(BookingStatus.completed).length}',
                                    icon: Icons.check_circle_rounded,
                                    color: AppTheme.success,
                                    tooltip: 'Successfully completed bookings',
                                    progress: _allBookings.isEmpty ? 0 : _getBookingsByStatus(BookingStatus.completed).length / _allBookings.length,
                                  ),
                                ),
                                SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                                  context,
                                  mobile: AppTheme.spacingSm,
                                  tablet: AppTheme.spacingMd,
                                  desktop: AppTheme.spacingLg,
                                )),
                                Expanded(
                                  child: _buildStatCard(
                                    title: 'Rating',
                                    value: _provider?.ratingAvg.toStringAsFixed(1) ?? '0.0',
                                    icon: Icons.star_rounded,
                                    color: const Color(0xFFFFB800),
                                    tooltip: 'Your average customer rating',
                                    subtitle: '${_provider?.ratingCount ?? 0} reviews',
                                    showProgress: false,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      } else {
                        // Tablet and desktop - horizontal layout
                        return Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                title: 'Total\nBookings',
                                value: '${_allBookings.length}',
                                icon: Icons.calendar_today_rounded,
                                color: AppTheme.primaryPurple,
                                tooltip: 'Total number of bookings received',
                              ),
                            ),
                            SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                              context,
                              mobile: AppTheme.spacingSm,
                              tablet: AppTheme.spacingMd,
                              desktop: AppTheme.spacingLg,
                            )),
                            Expanded(
                              child: _buildStatCard(
                                title: 'Pending',
                                value: '${_getBookingsByStatus(BookingStatus.pending).length}',
                                icon: Icons.schedule_rounded,
                                color: AppTheme.warning,
                                tooltip: 'Bookings awaiting your response',
                                progress: _allBookings.isEmpty ? 0 : _getBookingsByStatus(BookingStatus.pending).length / _allBookings.length,
                              ),
                            ),
                            SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                              context,
                              mobile: AppTheme.spacingSm,
                              tablet: AppTheme.spacingMd,
                              desktop: AppTheme.spacingLg,
                            )),
                            Expanded(
                              child: _buildStatCard(
                                title: 'Completed',
                                value: '${_getBookingsByStatus(BookingStatus.completed).length}',
                                icon: Icons.check_circle_rounded,
                                color: AppTheme.success,
                                tooltip: 'Successfully completed bookings',
                                progress: _allBookings.isEmpty ? 0 : _getBookingsByStatus(BookingStatus.completed).length / _allBookings.length,
                              ),
                            ),
                            SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                              context,
                              mobile: AppTheme.spacingSm,
                              tablet: AppTheme.spacingMd,
                              desktop: AppTheme.spacingLg,
                            )),
                            Expanded(
                              child: _buildStatCard(
                                title: 'Rating',
                                value: _provider?.ratingAvg.toStringAsFixed(1) ?? '0.0',
                                icon: Icons.star_rounded,
                                color: const Color(0xFFFFB800),
                                tooltip: 'Your average customer rating',
                                subtitle: '${_provider?.ratingCount ?? 0} reviews',
                                showProgress: false,
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
                
                // Tab Bar - Enhanced with Icons and Better Styling
                Container(
                  decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primaryPurple,
                    unselectedLabelColor: AppTheme.textTertiary,
                    labelStyle: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 14,
                        tablet: 16,
                        desktop: 18,
                      ),
                    ),
                    unselectedLabelStyle: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.normal,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 14,
                        tablet: 16,
                        desktop: 18,
                      ),
                    ),
                    indicatorColor: AppTheme.primaryPurple,
                    indicatorWeight: 3,
                    indicatorPadding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: AppTheme.spacingMd,
                        tablet: AppTheme.spacingLg,
                        desktop: AppTheme.spacingXl,
                      ),
                    ),
                    tabs: [
                      Tab(
                        icon: Icon(
                          Icons.dashboard_rounded,
                          size: ResponsiveUtils.getResponsiveIconSize(
                            context,
                            mobile: 20,
                            tablet: 22,
                            desktop: 24,
                          ),
                        ),
                        text: 'Overview',
                        iconMargin: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: AppTheme.spacingXs,
                          tablet: AppTheme.spacingSm,
                          desktop: AppTheme.spacingMd,
                        )),
                      ),
                      Tab(
                        icon: Icon(
                          Icons.event_note_rounded,
                          size: ResponsiveUtils.getResponsiveIconSize(
                            context,
                            mobile: 20,
                            tablet: 22,
                            desktop: 24,
                          ),
                        ),
                        text: 'Bookings',
                        iconMargin: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: AppTheme.spacingXs,
                          tablet: AppTheme.spacingSm,
                          desktop: AppTheme.spacingMd,
                        )),
                      ),
                      Tab(
                        icon: Icon(
                          Icons.work_rounded,
                          size: ResponsiveUtils.getResponsiveIconSize(
                            context,
                            mobile: 20,
                            tablet: 22,
                            desktop: 24,
                          ),
                        ),
                        text: 'Services',
                        iconMargin: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: AppTheme.spacingXs,
                          tablet: AppTheme.spacingSm,
                          desktop: AppTheme.spacingMd,
                        )),
                      ),
                      Tab(
                        icon: Icon(
                          Icons.star_rounded,
                          size: ResponsiveUtils.getResponsiveIconSize(
                            context,
                            mobile: 20,
                            tablet: 22,
                            desktop: 24,
                          ),
                        ),
                        text: 'Reviews',
                        iconMargin: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: AppTheme.spacingXs,
                          tablet: AppTheme.spacingSm,
                          desktop: AppTheme.spacingMd,
                        )),
                      ),
                      Tab(
                        icon: Icon(
                          Icons.person_rounded,
                          size: ResponsiveUtils.getResponsiveIconSize(
                            context,
                            mobile: 20,
                            tablet: 22,
                            desktop: 24,
                          ),
                        ),
                        text: 'Profile',
                        iconMargin: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: AppTheme.spacingXs,
                          tablet: AppTheme.spacingSm,
                          desktop: AppTheme.spacingMd,
                        )),
                      ),
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
                      ProviderServicesScreen(
                        provider: _provider,
                        onServiceUpdated: () {
                          // Reload provider data when services are updated
                          AppLogger.debug('ProviderDashboardScreen: onServiceUpdated callback triggered');
                          _loadDashboardData();
                        },
                      ),
                      if (_provider != null)
                        ProviderReviewsScreen(provider: _provider!)
                      else
                        const Center(child: CircularProgressIndicator()),
                      ProviderProfileScreen(provider: _provider),
                    ],
                  ),
                ),

              ],
            ),
      // Removed floating action button to avoid duplicate "Add Service" buttons
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String tooltip,
    String? subtitle,
    double? progress,
    bool showProgress = true,
  }) {
    return Tooltip(
      message: tooltip,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, animValue, child) {
          return Container(
            padding: ResponsiveUtils.getResponsivePadding(context),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.12),
                  color.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: 0.25),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with optional progress ring
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (showProgress && progress != null)
                      SizedBox(
                        width: ResponsiveUtils.getResponsiveIconSize(
                          context,
                          mobile: 40,
                          tablet: 44,
                          desktop: 48,
                        ),
                        height: ResponsiveUtils.getResponsiveIconSize(
                          context,
                          mobile: 40,
                          tablet: 44,
                          desktop: 48,
                        ),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: progress * animValue),
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return CircularProgressIndicator(
                              value: value,
                              strokeWidth: 3,
                              backgroundColor: color.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            );
                          },
                        ),
                      ),
                    Container(
                      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: AppTheme.spacingSm,
                        tablet: AppTheme.spacingMd,
                        desktop: AppTheme.spacingLg,
                      )),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: ResponsiveUtils.getResponsiveIconSize(
                          context,
                          mobile: 18,
                          tablet: 20,
                          desktop: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                  context,
                  mobile: AppTheme.spacingSm,
                  tablet: AppTheme.spacingMd,
                  desktop: AppTheme.spacingLg,
                )),
                
                // Animated value
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: double.tryParse(value) ?? 0.0),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedValue, child) {
                    // Check if value has decimal point (for rating)
                    final displayValue = value.contains('.')
                        ? animatedValue.toStringAsFixed(1)
                        : animatedValue.toInt().toString();
                    
                    return Text(
                      displayValue,
                      style: AppTheme.heading2.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 20,
                          tablet: 24,
                          desktop: 26,
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                  context,
                  mobile: AppTheme.spacingXs,
                  tablet: AppTheme.spacingSm,
                  desktop: AppTheme.spacingMd,
                )),
                
                // Title
                Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      mobile: 10,
                      tablet: 11,
                      desktop: 12,
                    ),
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                // Optional subtitle
                if (subtitle != null) ...[
                  SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: AppTheme.spacingXs,
                    tablet: AppTheme.spacingSm,
                    desktop: AppTheme.spacingMd,
                  )),
                  Text(
                    subtitle,
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.textTertiary,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 9,
                        tablet: 10,
                        desktop: 11,
                      ),
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner() {
    final authService = Provider.of<shared.AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    if (currentUser == null) return const SizedBox.shrink();
    
    return StreamBuilder<Map<String, dynamic>?>(
      stream: VerificationService.getVerificationStatusStream(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        
        final verificationStatus = snapshot.data;
        if (verificationStatus == null) return const SizedBox.shrink();
        
        final status = verificationStatus['status'] as String;
        final adminRemarks = verificationStatus['adminRemarks'] as String?;
        
        if (status == 'pending') {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: AppTheme.warning,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '⏳ Your business registration is under review. You can still add services while waiting for approval.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else if (status == 'rejected') {
    return Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.error.withValues(alpha: 0.3),
              ),
      ),
      child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
        children: [
                    Icon(
                      Icons.cancel,
                      color: AppTheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your business registration has been rejected.',
                        style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
            ),
          ),
                  ],
                ),
                if (adminRemarks != null && adminRemarks.isNotEmpty) ...[
                  const SizedBox(height: 8),
          Text(
                    'Feedback: $adminRemarks',
            style: AppTheme.caption.copyWith(
              color: AppTheme.textSecondary,
            ),
                  ),
                ],
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProviderRegistrationScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Resubmit Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
          ),
        ],
      ),
          );
        }
        
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _provider != null 
                ? 'Welcome back, ${_provider!.businessName}'
                : 'Welcome back!',
            style: AppTheme.heading1.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _provider != null
                ? 'Here\'s what\'s happening with your business today'
                : 'Complete your provider registration to get started',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Registration Tracker Card
          const RegistrationTrackerCard(),
          
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
          
          // Recent Activity - Enhanced Design
          Card(
            color: AppTheme.cardDark,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.history_rounded,
                          color: AppTheme.primaryPurple,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
          Text(
            'Recent Activity',
                        style: AppTheme.heading3.copyWith(
              color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
            ),
          ),
                    ],
                  ),
                  const SizedBox(height: 20),
          
          if (_recentBookings.isEmpty)
            Container(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
              child: Column(
                children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_circle_outline_rounded,
                    size: 64,
                              color: AppTheme.success.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '✨ All caught up!',
                            style: AppTheme.heading3.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                  Text(
                            'You have no pending bookings at the moment.\nNew bookings will appear here for you to review.',
                            style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          if (_recentBookings.isNotEmpty)
            Card(
              color: AppTheme.cardDark,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.pending_actions_rounded,
                            color: AppTheme.warning,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                  Text(
                          'Pending Bookings',
                          style: AppTheme.heading3.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
                    const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentBookings.take(5).length,
              itemBuilder: (context, index) {
                final booking = _recentBookings[index];
                        return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getStatusColor(booking.status).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                  child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _getStatusColor(booking.status).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _getStatusColor(booking.status).withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                      child: Icon(
                        _getStatusIcon(booking.status),
                                color: _getStatusColor(booking.status),
                                size: 22,
                      ),
                    ),
                    title: Text(
                              'Booking #${booking.bookingId.length >= 8 ? booking.bookingId.substring(0, 8) : booking.bookingId}',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${booking.statusDisplayName} • ${_formatDate(booking.scheduledAt)}',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                                ),
                      ),
                    ),
                    trailing: Icon(
                              Icons.arrow_forward_ios_rounded,
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
              ),
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
      color: statusColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
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
    return Card(
      color: AppTheme.cardDark,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.bolt_rounded,
                    color: AppTheme.primaryPurple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
        Text(
          'Quick Actions',
                  style: AppTheme.heading3.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                    '+ Add / Edit Services',
                    'Manage your service offerings',
                    Icons.shopping_bag_rounded,
                    [AppTheme.primaryPurple, const Color(0xFF9D50FF)],
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProviderServicesScreen(provider: _provider),
                  ),
                ),
              ),
            ),
                const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                    '⭐ View Customer Reviews',
                    'Check feedback and ratings',
                    Icons.star_rounded,
                    [const Color(0xFFFFB800), const Color(0xFFFF8C00)],
                () {
                  if (_provider != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProviderReviewsScreen(provider: _provider!),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please complete your provider profile first'),
                        backgroundColor: AppTheme.warning,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
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
    List<Color> gradientColors,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
          borderRadius: BorderRadius.circular(16),
        child: Padding(
            padding: const EdgeInsets.all(24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                ),
                  child: Icon(icon, color: Colors.white, size: 36),
              ),
                const SizedBox(height: 16),
              Text(
                title,
                  style: AppTheme.heading3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                ),
                textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
              ),
                const SizedBox(height: 8),
              Text(
                subtitle,
                  style: AppTheme.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            ),
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
      case BookingStatus.pendingCustomerConfirmation:
        return AppTheme.info;
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
      case BookingStatus.pendingCustomerConfirmation:
        return Icons.pending_actions;
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

