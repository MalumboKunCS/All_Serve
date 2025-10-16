import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart' as shared;
import '../theme/app_theme.dart';
import '../services/provider_registration_service.dart';
import '../screens/provider/provider_registration_screen.dart';

class ProviderRegistrationStatusWidget extends StatefulWidget {
  const ProviderRegistrationStatusWidget({super.key});

  @override
  State<ProviderRegistrationStatusWidget> createState() => _ProviderRegistrationStatusWidgetState();
}

class _ProviderRegistrationStatusWidgetState extends State<ProviderRegistrationStatusWidget> {
  Map<String, dynamic>? _registrationStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRegistrationStatus();
  }

  Future<void> _loadRegistrationStatus() async {
    try {
      final authService = Provider.of<shared.AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser != null) {
        final status = await ProviderRegistrationService.getRegistrationStatus(currentUser.uid);
        if (mounted) {
          setState(() {
            _registrationStatus = status;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        color: AppTheme.cardDark,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Text(
                'Loading registration status...',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_registrationStatus == null) {
      return const SizedBox.shrink();
    }

    final isComplete = _registrationStatus!['isComplete'] as bool;
    final progress = _registrationStatus!['progress'] as double;
    final missingFields = _registrationStatus!['missingFields'] as List<String>;

    if (isComplete) {
      return const SizedBox.shrink(); // Don't show if registration is complete
    }

    return Card(
      color: AppTheme.warning.withValues(alpha:0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pending_actions, color: AppTheme.warning, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complete Your Registration',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${progress.toInt()}% complete - ${missingFields.length} items remaining',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProviderRegistrationScreen(),
                      ),
                    );
                  },
                  style: AppTheme.primaryButtonStyle.copyWith(
                    backgroundColor: MaterialStateProperty.all(AppTheme.warning),
                  ),
                  child: const Text('Continue'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Progress bar
            LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: AppTheme.cardDark,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warning),
            ),
            
            if (missingFields.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Missing:',
                style: AppTheme.caption.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: missingFields.map((field) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getFieldDisplayName(field),
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getFieldDisplayName(String field) {
    switch (field) {
      case 'business_name':
        return 'Business Name';
      case 'description':
        return 'Description';
      case 'category':
        return 'Category';
      case 'location':
        return 'Location';
      case 'nrc_document':
        return 'NRC Document';
      case 'business_license':
        return 'Business License';
      case 'certificates':
        return 'Certificates';
      case 'provider_document':
        return 'Provider Profile';
      default:
        return field.replaceAll('_', ' ').toUpperCase();
    }
  }
}











