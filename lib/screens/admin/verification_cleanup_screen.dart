import 'package:flutter/material.dart';
import '../../services/verification_cleanup_service.dart';
import '../../theme/app_theme.dart';

class VerificationCleanupScreen extends StatefulWidget {
  const VerificationCleanupScreen({super.key});

  @override
  State<VerificationCleanupScreen> createState() => _VerificationCleanupScreenState();
}

class _VerificationCleanupScreenState extends State<VerificationCleanupScreen> {
  bool _isRunning = false;
  String _status = 'Ready to run cleanup';
  String _details = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Verification Cleanup'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: AppTheme.warning),
                      const SizedBox(width: 8),
                      Text(
                        'Verification Queue Cleanup',
                        style: AppTheme.heading3.copyWith(
                          color: AppTheme.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This tool will clean up duplicate verification queue entries and fix missing ownerUid fields.',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status',
                    style: AppTheme.heading3.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _status,
                    style: AppTheme.bodyMedium.copyWith(
                      color: _isRunning ? AppTheme.warning : AppTheme.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_details.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _details,
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Run Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isRunning ? null : _runCleanup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isRunning
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Running Cleanup...',
                            style: AppTheme.bodyLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Run Cleanup',
                        style: AppTheme.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: AppTheme.info, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'What this cleanup does:',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.info,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Removes duplicate verification queue entries for the same provider\n'
                    '• Fixes missing ownerUid fields by looking up provider data\n'
                    '• Ensures all entries have the required docs field\n'
                    '• Keeps only the most recent entry for each provider',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runCleanup() async {
    setState(() {
      _isRunning = true;
      _status = 'Starting cleanup...';
      _details = '';
    });

    try {
      await VerificationCleanupService.cleanupDuplicateVerificationEntries();
      
      setState(() {
        _status = 'Cleanup completed successfully!';
        _details = 'All duplicate entries have been removed and missing fields have been fixed.';
      });
    } catch (e) {
      setState(() {
        _status = 'Cleanup failed';
        _details = 'Error: $e';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }
}
 