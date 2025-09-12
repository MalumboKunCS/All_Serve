import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/provider.dart' as app_provider;
import '../../services/auth_service.dart';
import 'provider_profile_screen.dart';
import 'provider_documents_screen.dart';
import 'provider_gallery_screen.dart';
import 'provider_settings_subscreens.dart';

class ProviderSettingsScreen extends StatefulWidget {
  final app_provider.Provider? provider;

  const ProviderSettingsScreen({
    super.key,
    this.provider,
  });

  @override
  State<ProviderSettingsScreen> createState() => _ProviderSettingsScreenState();
}

class _ProviderSettingsScreenState extends State<ProviderSettingsScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            _buildSectionHeader('Business Profile'),
            const SizedBox(height: 16),
            
            _buildSettingsTile(
              icon: Icons.business,
              title: 'Edit Business Profile',
              subtitle: 'Update business information, location, and services',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProviderProfileScreen(provider: widget.provider),
                  ),
                );
              },
            ),

            if (widget.provider != null) ...[
              _buildSettingsTile(
                icon: Icons.verified,
                title: 'Verification Status',
                subtitle: _getVerificationStatusText(),
                trailing: _buildVerificationStatusBadge(),
                onTap: null,
              ),

              _buildSettingsTile(
                icon: Icons.toggle_on,
                title: 'Account Status',
                subtitle: 'Currently ${widget.provider!.status}',
                trailing: _buildStatusToggle(),
                onTap: null,
              ),
            ],

            const SizedBox(height: 32),

            // Document Management
            _buildSectionHeader('Document Management'),
            const SizedBox(height: 16),
            
            _buildSettingsTile(
              icon: Icons.upload_file,
              title: 'Upload Documents',
              subtitle: 'NRC, Business License, Certificates',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProviderDocumentsScreen(provider: widget.provider),
                  ),
                );
              },
            ),

            _buildSettingsTile(
              icon: Icons.folder,
              title: 'Manage Gallery',
              subtitle: 'Upload and manage business photos',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProviderGalleryScreen(provider: widget.provider),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Account Settings
            _buildSectionHeader('Account Settings'),
            const SizedBox(height: 16),
            
            _buildSettingsTile(
              icon: Icons.security,
              title: 'Security Settings',
              subtitle: 'Password, 2FA, and security preferences',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProviderSecurityScreen(),
                  ),
                );
              },
            ),

            _buildSettingsTile(
              icon: Icons.notifications,
              title: 'Notification Settings',
              subtitle: 'Manage booking and review notifications',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProviderNotificationSettingsScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Support Section
            _buildSectionHeader('Support & Information'),
            const SizedBox(height: 16),
            
            _buildSettingsTile(
              icon: Icons.help,
              title: 'Help & Support',
              subtitle: 'FAQs, contact support, and guides',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProviderHelpScreen(),
                  ),
                );
              },
            ),

            _buildSettingsTile(
              icon: Icons.policy,
              title: 'Terms & Privacy',
              subtitle: 'Terms of service and privacy policy',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProviderTermsScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _logout,
                style: AppTheme.outlineButtonStyle.copyWith(
                  foregroundColor: MaterialStateProperty.all(AppTheme.error),
                  side: MaterialStateProperty.all(BorderSide(color: AppTheme.error)),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ),

            const SizedBox(height: 16),

            // App Version
            Center(
              child: Text(
                'All-Serve Provider v1.0.0',
                style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTheme.heading3.copyWith(
        color: AppTheme.textPrimary,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      color: AppTheme.surfaceDark,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppTheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: AppTheme.bodyText.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
        ),
        trailing: trailing ?? (onTap != null ? Icon(
          Icons.chevron_right,
          color: AppTheme.textSecondary,
        ) : null),
        onTap: onTap,
      ),
    );
  }

  String _getVerificationStatusText() {
    if (widget.provider == null) return 'Unknown status';
    
    switch (widget.provider!.verificationStatus) {
      case 'pending':
        return 'Verification pending - documents under review';
      case 'approved':
        return 'Verified provider - approved by admin';
      case 'rejected':
        return 'Verification rejected - please resubmit documents';
      default:
        return 'Verification status: ${widget.provider!.verificationStatus}';
    }
  }

  Widget _buildVerificationStatusBadge() {
    if (widget.provider == null) return const SizedBox.shrink();
    
    Color color;
    IconData icon;
    String text;

    switch (widget.provider!.verificationStatus) {
      case 'pending':
        color = AppTheme.warning;
        icon = Icons.pending;
        text = 'PENDING';
        break;
      case 'approved':
        color = AppTheme.success;
        icon = Icons.verified;
        text = 'VERIFIED';
        break;
      case 'rejected':
        color = AppTheme.error;
        icon = Icons.cancel;
        text = 'REJECTED';
        break;
      default:
        color = AppTheme.textSecondary;
        icon = Icons.help;
        text = 'UNKNOWN';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTheme.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusToggle() {
    if (widget.provider == null) return const SizedBox.shrink();
    
    final isActive = widget.provider!.status == 'active';
    
    return Switch(
      value: isActive,
      onChanged: (value) => _toggleProviderStatus(value),
      activeColor: AppTheme.success,
      inactiveThumbColor: AppTheme.textSecondary,
      inactiveTrackColor: AppTheme.textTertiary,
    );
  }

  Future<void> _toggleProviderStatus(bool isActive) async {
    if (widget.provider == null) return;

    setState(() => _isLoading = true);

    try {
      final newStatus = isActive ? 'active' : 'inactive';
      
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.provider!.providerId)
          .update({'status': newStatus});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $newStatus'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();
      
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to logout: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}

