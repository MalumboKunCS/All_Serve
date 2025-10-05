import 'package:flutter/material.dart';
import 'package:shared/shared.dart' as shared;
import '../../../widgets/provider_list_widget.dart';
import '../../../widgets/provider_profile_view.dart';
import '../../../services/provider_management_service.dart';

class ProvidersTab extends StatefulWidget {
  const ProvidersTab({super.key});

  @override
  State<ProvidersTab> createState() => _ProvidersTabState();
}

class _ProvidersTabState extends State<ProvidersTab> {
  shared.Provider? _selectedProvider;
  bool _showProfileView = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Providers Management',
                    style: shared.AppTheme.heading1.copyWith(
                      color: shared.AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage all approved service providers on the platform',
                    style: shared.AppTheme.bodyLarge.copyWith(
                      color: shared.AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              if (_showProfileView)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showProfileView = false;
                      _selectedProvider = null;
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to List',
                ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Content
          Expanded(
            child: _showProfileView && _selectedProvider != null
                ? ProviderProfileView(
                    provider: _selectedProvider!,
                    onAction: _handleProviderAction,
                  )
                : ProviderListWidget(
                    onProviderSelected: _handleProviderSelected,
                    onProviderAction: _handleProviderAction,
                  ),
          ),
        ],
      ),
    );
  }

  void _handleProviderSelected(shared.Provider provider) {
    setState(() {
      _selectedProvider = provider;
      _showProfileView = true;
    });
  }

  Future<void> _handleProviderAction(shared.Provider provider, String action) async {
    switch (action) {
      case 'suspend':
        await _suspendProvider(provider);
        break;
      case 'promote':
        await _promoteProvider(provider);
        break;
      case 'reset_password':
        await _resetProviderPassword(provider);
        break;
      case 'delete':
        await _deleteProvider(provider);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unknown action: $action'),
            backgroundColor: shared.AppTheme.error,
          ),
        );
    }
  }

  Future<void> _suspendProvider(shared.Provider provider) async {
    final confirmed = await _showConfirmationDialog(
      'Suspend Provider',
      'Are you sure you want to ${provider.status == 'suspended' ? 'unsuspend' : 'suspend'} ${provider.businessName}?',
    );

    if (!confirmed) return;

    try {
      final success = await ProviderManagementService.suspendProvider(
        provider.providerId,
        provider.status != 'suspended',
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Provider ${provider.status == 'suspended' ? 'unsuspended' : 'suspended'} successfully'),
            backgroundColor: shared.AppTheme.success,
          ),
        );
        
        // Refresh the view
        setState(() {});
      } else {
        throw Exception('Failed to update provider status');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${provider.status == 'suspended' ? 'unsuspend' : 'suspend'} provider: $e'),
          backgroundColor: shared.AppTheme.error,
        ),
      );
    }
  }

  Future<void> _promoteProvider(shared.Provider provider) async {
    final confirmed = await _showConfirmationDialog(
      'Promote Provider',
      'Are you sure you want to promote ${provider.businessName} to featured status?',
    );

    if (!confirmed) return;

    try {
      final success = await ProviderManagementService.promoteProvider(
        provider.providerId,
        true, // Promote to featured
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Provider promoted to featured successfully'),
            backgroundColor: shared.AppTheme.success,
          ),
        );
        
        // Refresh the view
        setState(() {});
      } else {
        throw Exception('Failed to promote provider');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to promote provider: $e'),
          backgroundColor: shared.AppTheme.error,
        ),
      );
    }
  }

  Future<void> _resetProviderPassword(shared.Provider provider) async {
    final confirmed = await _showConfirmationDialog(
      'Reset Password',
      'Are you sure you want to reset the password for ${provider.businessName}?',
    );

    if (!confirmed) return;

    try {
      final success = await ProviderManagementService.resetProviderPassword(
        provider.providerId,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to provider'),
            backgroundColor: shared.AppTheme.success,
          ),
        );
      } else {
        throw Exception('Failed to reset password');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reset password: $e'),
          backgroundColor: shared.AppTheme.error,
        ),
      );
    }
  }

  Future<void> _deleteProvider(shared.Provider provider) async {
    final confirmed = await _showConfirmationDialog(
      'Delete Provider',
      'Are you sure you want to permanently delete ${provider.businessName}? This action cannot be undone.',
    );

    if (!confirmed) return;

    try {
      final success = await ProviderManagementService.deleteProvider(
        provider.providerId,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Provider deleted successfully'),
            backgroundColor: shared.AppTheme.success,
          ),
        );
        
        // Go back to list view
        setState(() {
          _showProfileView = false;
          _selectedProvider = null;
        });
      } else {
        throw Exception('Failed to delete provider');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete provider: $e'),
          backgroundColor: shared.AppTheme.error,
        ),
      );
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: shared.AppTheme.cardDark,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: shared.AppTheme.primaryButtonStyle,
            child: Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }
}