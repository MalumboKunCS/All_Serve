import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

class DashboardOverviewTab extends StatefulWidget {
  final Map<String, int> stats;
  final List<Provider> pendingProviders;
  final List<Review> flaggedReviews;
  final List<User> recentUsers;
  final VoidCallback? onReviewProviders;
  final VoidCallback? onFlaggedReviews;
  final VoidCallback? onSendAnnouncement;
  final VoidCallback? onViewAllUsers;
  final VoidCallback? onViewAllProviders;
  final VoidCallback? onViewPendingVerifications;

  const DashboardOverviewTab({
    super.key,
    required this.stats,
    required this.pendingProviders,
    required this.flaggedReviews,
    required this.recentUsers,
    this.onReviewProviders,
    this.onFlaggedReviews,
    this.onSendAnnouncement,
    this.onViewAllUsers,
    this.onViewAllProviders,
    this.onViewPendingVerifications,
  });

  @override
  State<DashboardOverviewTab> createState() => _DashboardOverviewTabState();
}

class _DashboardOverviewTabState extends State<DashboardOverviewTab> {
  Map<String, int> _currentStats = {};
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _currentStats = widget.stats;
    _loadRealTimeStats();
  }

  @override
  void didUpdateWidget(DashboardOverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stats != widget.stats) {
      _currentStats = widget.stats;
    }
  }

  void _loadRealTimeStats() {
    AdminService.getDashboardStatsStream().listen((stats) {
      if (mounted) {
        setState(() {
          _currentStats = stats.cast<String, int>();
          _isLoadingStats = false;
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
        print('Error loading real-time stats: $error');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Text(
            'Welcome back, Admin!',
            style: AppTheme.heading1.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Here\'s what\'s happening with your platform today.',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Stats Cards
          _buildStatsGrid(),
          const SizedBox(height: 32),

          // Quick Actions
          _buildQuickActions(),
          const SizedBox(height: 32),

          // Recent Activity
          _buildRecentUsers(),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Total Customers',
            value: _isLoadingStats ? '...' : (_currentStats['totalUsers']?.toString() ?? '0'),
            icon: Icons.people_outline,
            color: AppTheme.primaryBlue,
            onTap: widget.onViewAllUsers,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: 'Total Providers',
            value: _isLoadingStats ? '...' : (_currentStats['totalProviders']?.toString() ?? '0'),
            icon: Icons.business_outlined,
            color: AppTheme.primaryPurple,
            onTap: widget.onViewAllProviders,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: 'Pending Verifications',
            value: _isLoadingStats ? '...' : (_currentStats['pendingVerifications']?.toString() ?? '0'),
            icon: Icons.pending_actions_outlined,
            color: AppTheme.warning,
            onTap: widget.onViewPendingVerifications,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        color: AppTheme.cardDark,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
                      color: color.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_forward_ios,
                      color: AppTheme.textTertiary,
                      size: 16,
                    )
                  else
                    Icon(
                      Icons.trending_up,
                      color: AppTheme.success,
                      size: 16,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: AppTheme.heading2.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: AppTheme.caption.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Click to view details',
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      color: AppTheme.cardDark,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: AppTheme.heading3.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildActionButton(
                  icon: Icons.verified_user_outlined,
                  title: 'Review Providers',
                  subtitle: '${widget.pendingProviders.length} pending',
                  onTap: widget.onReviewProviders ?? () {},
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  icon: Icons.flag_outlined,
                  title: 'Flagged Reviews',
                  subtitle: '${widget.flaggedReviews.length} flagged',
                  onTap: widget.onFlaggedReviews ?? () {},
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  icon: Icons.campaign_outlined,
                  title: 'Send Announcement',
                  subtitle: 'Notify users',
                  onTap: widget.onSendAnnouncement ?? () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.cardLight,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: AppTheme.primaryPurple,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTheme.caption.copyWith(
                  color: AppTheme.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentUsers() {
    return Card(
      color: AppTheme.cardDark,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Users',
                  style: AppTheme.heading3.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (widget.onViewAllUsers != null)
                  TextButton(
                    onPressed: widget.onViewAllUsers,
                    child: Text(
                      'View All',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.recentUsers.isEmpty)
              Center(
                child: Text(
                  'No recent users',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
              )
            else
              ...widget.recentUsers.take(5).map((user) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryPurple,
                  child: Text(
                    user.name.isNotEmpty 
                      ? user.name.substring(0, 1).toUpperCase()
                      : 'U',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  user.name,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  user.role.toUpperCase(),
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
                trailing: Text(
                  _formatDate(user.createdAt),
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}





