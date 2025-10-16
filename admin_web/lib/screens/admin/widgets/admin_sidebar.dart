import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared/shared.dart' as shared;

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: shared.AppTheme.surfaceDark,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: shared.AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Admin Dashboard',
                  style: shared.AppTheme.heading3.copyWith(
                    color: shared.AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All-Serve Management',
                  style: shared.AppTheme.caption.copyWith(
                    color: shared.AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: shared.AppTheme.cardLight),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(
                  icon: Icons.dashboard_outlined,
                  title: 'Dashboard',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.verified_user_outlined,
                  title: 'Verification Queue',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.business_outlined,
                  title: 'Providers',
                  index: 2,
                ),
                _buildNavItem(
                  icon: Icons.report_outlined,
                  title: 'Provider Reports',
                  index: 3,
                ),
                _buildNavItem(
                  icon: Icons.star_outline,
                  title: 'Reviews',
                  index: 4,
                ),
                _buildNavItem(
                  icon: Icons.people_outline,
                  title: 'Customers',
                  index: 5,
                ),
                _buildNavItem(
                  icon: Icons.campaign_outlined,
                  title: 'Announcements',
                  index: 6,
                ),
                _buildNavItem(
                  icon: Icons.admin_panel_settings,
                  title: 'Admin Management',
                  index: 7,
                ),
              ],
            ),
          ),
          
          // Logout Button
          Container(
            padding: const EdgeInsets.all(16),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                'Logout',
                style: GoogleFonts.inter(color: Colors.red),
              ),
              onTap: () => _handleLogout(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final isSelected = selectedIndex == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? shared.AppTheme.primaryPurple : shared.AppTheme.textSecondary,
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: isSelected ? shared.AppTheme.primaryPurple : shared.AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedTileColor: shared.AppTheme.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        onTap: () => onItemSelected(index),
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    try {
      final authService = context.read<shared.AuthService>();
      await authService.signOut();
      // The AuthWrapper will automatically redirect to login
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
