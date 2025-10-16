import 'package:flutter/material.dart';
import 'package:shared/shared.dart' as shared;
import 'admin/widgets/admin_sidebar.dart';
import 'admin/widgets/admin_app_bar.dart';
import 'admin/tabs/dashboard_overview_tab.dart';
import 'admin/tabs/verification_queue_tab.dart';
import 'admin/tabs/providers_tab.dart';
import 'admin/tabs/reviews_tab.dart';
import 'admin/tabs/customers_tab.dart';
import 'admin/tabs/announcements_tab.dart';
import 'admin/tabs/admin_management_tab.dart';
import 'admin/tabs/provider_reports_tab.dart';
import '../widgets/announcement_dialog.dart';
import '../utils/app_logger.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  
  Map<String, dynamic> _stats = {};
  List<shared.Provider> _pendingProviders = [];
  List<shared.Review> _flaggedReviews = [];
  List<shared.User> _recentUsers = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      AppLogger.info('Loading dashboard data...');
      AppLogger.info('Current user UID: ${shared.AuthService().currentUser?.uid}');
      AppLogger.info('Current user role: ${shared.AuthService().currentUser?.role}');
      final stats = await shared.AdminService.getDashboardStats();
      AppLogger.info('Dashboard stats loaded: $stats');
      
      final pendingProviders = await _getPendingProviders();
      AppLogger.info('Pending providers loaded: ${pendingProviders.length}');
      
      final flaggedReviews = await _getFlaggedReviews();
      AppLogger.info('Flagged reviews loaded: ${flaggedReviews.length}');
      
      final recentUsers = await _getRecentUsers();
      AppLogger.info('Recent users loaded: ${recentUsers.length}');

      if (mounted) {
        setState(() {
          _stats = stats;
          _pendingProviders = pendingProviders;
          _flaggedReviews = flaggedReviews;
          _recentUsers = recentUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.info('Error loading dashboard data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load dashboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<shared.Provider>> _getPendingProviders() async {
    try {
      return await shared.AdminService.getPendingProviders();
    } catch (e) {
      AppLogger.info('Error getting pending providers: $e');
      return [];
    }
  }

  Future<List<shared.Review>> _getFlaggedReviews() async {
    try {
      return await shared.AdminService.getFlaggedReviews();
    } catch (e) {
      AppLogger.info('Error getting flagged reviews: $e');
      return [];
    }
  }

  Future<List<shared.User>> _getRecentUsers() async {
    try {
      return await shared.AdminService.getRecentUsers();
    } catch (e) {
      AppLogger.info('Error getting recent users: $e');
      return [];
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: shared.AppTheme.backgroundDark,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: shared.AppTheme.backgroundDark,
      body: Row(
        children: [
          AdminSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
          Expanded(
            child: Column(
              children: [
                AdminAppBar(
                  onMenuPressed: () {
                    // Handle menu for mobile/tablet
                  },
                ),
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showAnnouncementDialog() {
    showDialog(
      context: context,
      builder: (context) => AnnouncementDialog(
        onSend: ({
          required String title,
          required String message,
          required String audience,
          List<String> specificUserIds = const [],
          List<String> targetCategories = const [],
          String priority = 'medium',
          String type = 'info',
          DateTime? expiresAt,
        }) async {
          await _sendAnnouncement(
            title: title,
            message: message,
            audience: audience,
            specificUserIds: specificUserIds,
            targetCategories: targetCategories,
            priority: priority,
            type: type,
            expiresAt: expiresAt,
          );
        },
      ),
    );
  }

  Future<void> _sendAnnouncement({
    required String title,
    required String message,
    required String audience,
    List<String> specificUserIds = const [],
    List<String> targetCategories = const [],
    String priority = 'medium',
    String type = 'info',
    DateTime? expiresAt,
  }) async {
    try {
      AppLogger.info('Sending announcement: $title - $message to $audience');
      
      final success = await shared.AdminService.sendTargetedAnnouncement(
        title: title,
        message: message,
        audience: audience,
        specificUserIds: specificUserIds,
        targetCategories: targetCategories,
        priority: priority,
        type: type,
        expiresAt: expiresAt,
      );
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Announcement sent successfully to $audience!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Failed to send announcement');
        }
      }
    } catch (e) {
      AppLogger.info('Error sending announcement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send announcement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return DashboardOverviewTab(
          stats: _stats.cast<String, int>(),
          pendingProviders: _pendingProviders,
          flaggedReviews: _flaggedReviews,
          recentUsers: _recentUsers,
          onReviewProviders: () => _navigateToTab(1), // Verification Queue
          onFlaggedReviews: () => _navigateToTab(3), // Reviews
          onSendAnnouncement: _showAnnouncementDialog,
          onViewAllUsers: () => _navigateToTab(5), // Customers tab
          onViewAllProviders: () => _navigateToTab(2), // Providers tab
          onViewPendingVerifications: () => _navigateToTab(1), // Verification Queue
        );
      case 1:
        return VerificationQueueTab(
          onRefresh: _loadDashboardData,
        );
      case 2:
        return ProvidersTab();
      case 3:
        return ProviderReportsTab();
      case 4:
        return ReviewsTab();
      case 5:
        return CustomersTab();
      case 6:
        return AnnouncementsTab();
      case 7:
        return AdminManagementTab();
      default:
        return DashboardOverviewTab(
          stats: _stats.cast<String, int>(),
          pendingProviders: _pendingProviders,
          flaggedReviews: _flaggedReviews,
          recentUsers: _recentUsers,
        );
    }
  }
}
