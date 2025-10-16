import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart' as shared;

class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onMenuPressed;

  const AdminAppBar({
    super.key,
    required this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: shared.AppTheme.surfaceDark,
      foregroundColor: shared.AppTheme.textPrimary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: onMenuPressed,
      ),
      title: Text(
        'Admin Dashboard',
        style: shared.AppTheme.heading3.copyWith(
          color: shared.AppTheme.textPrimary,
        ),
      ),
      actions: [
        // Notifications
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            // TODO: Show notifications
          },
        ),
        
        // User Profile
        Consumer<shared.AuthService>(
          builder: (context, authService, child) {
            final user = authService.currentUser;
            return PopupMenuButton<String>(
              icon: CircleAvatar(
                backgroundColor: shared.AppTheme.primaryPurple,
                child: Text(
                  user?.name != null && user!.name.isNotEmpty 
                    ? user.name.substring(0, 1).toUpperCase()
                    : 'A',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'profile':
                    // TODO: Show profile
                    break;
                  case 'settings':
                    // TODO: Show settings
                    break;
                  case 'logout':
                    _handleLogout(context);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline),
                      const SizedBox(width: 8),
                      Text('Profile'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      const Icon(Icons.settings_outlined),
                      const SizedBox(width: 8),
                      Text('Settings'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, color: Colors.red),
                      const SizedBox(width: 8),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

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





