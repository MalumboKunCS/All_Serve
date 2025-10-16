import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import 'package:shared/shared.dart' as shared;

class TwoFAVerificationScreen extends StatefulWidget {
  final String email;
  final String password;

  const TwoFAVerificationScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<TwoFAVerificationScreen> createState() => _TwoFAVerificationScreenState();
}

class _TwoFAVerificationScreenState extends State<TwoFAVerificationScreen> {
  final _codeController = TextEditingController();
  final _backupCodeController = TextEditingController();
  bool _isLoading = false;
  bool _useBackupCode = false;

  @override
  void dispose() {
    _codeController.dispose();
    _backupCodeController.dispose();
    super.dispose();
  }

  Future<void> _verify2FA() async {
    final code = _useBackupCode 
      ? _backupCodeController.text.trim()
      : _codeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_useBackupCode 
            ? 'Please enter your backup code' 
            : 'Please enter the 6-digit code'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<shared.AuthService>(context, listen: false);
      
      final userCredential = await authService.verify2FACode(
        code,
      );

      if (userCredential.user != null && mounted) {
        // Navigate to appropriate screen based on user role
        // This will be handled by the auth service automatically
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/', 
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Two-Factor Authentication'),
        backgroundColor: AppTheme.surfaceDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.security,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Enter Verification Code',
                      style: AppTheme.heading1.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _useBackupCode
                        ? 'Enter one of your backup codes'
                        : 'Enter the 6-digit code from your authenticator app',
                      style: AppTheme.bodyText.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Toggle between TOTP and Backup Code
              Card(
                color: AppTheme.surfaceDark,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _useBackupCode = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_useBackupCode 
                                ? AppTheme.primary.withValues(alpha:0.2)
                                : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: !_useBackupCode 
                                  ? AppTheme.primary 
                                  : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              'Authenticator Code',
                              textAlign: TextAlign.center,
                              style: AppTheme.bodyText.copyWith(
                                color: !_useBackupCode 
                                  ? AppTheme.primary 
                                  : AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _useBackupCode = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _useBackupCode 
                                ? AppTheme.primary.withValues(alpha:0.2)
                                : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _useBackupCode 
                                  ? AppTheme.primary 
                                  : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              'Backup Code',
                              textAlign: TextAlign.center,
                              style: AppTheme.bodyText.copyWith(
                                color: _useBackupCode 
                                  ? AppTheme.primary 
                                  : AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Input Field
              if (!_useBackupCode) ...[
                // TOTP Code Input
                TextFormField(
                  controller: _codeController,
                  decoration: AppTheme.inputDecoration.copyWith(
                    labelText: '6-Digit Code',
                    prefixIcon: const Icon(Icons.confirmation_number),
                    hintText: '000000',
                  ),
                  style: AppTheme.heading2.copyWith(
                    color: AppTheme.textPrimary,
                    letterSpacing: 8,
                  ),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (value) {
                    if (value.length == 6) {
                      // Auto-verify when 6 digits are entered
                      _verify2FA();
                    }
                  },
                ),
              ] else ...[
                // Backup Code Input
                TextFormField(
                  controller: _backupCodeController,
                  decoration: AppTheme.inputDecoration.copyWith(
                    labelText: 'Backup Code',
                    prefixIcon: const Icon(Icons.vpn_key),
                    hintText: 'Enter your backup code',
                  ),
                  style: AppTheme.bodyText.copyWith(
                    color: AppTheme.textPrimary,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  ],
                ),
              ],

              const SizedBox(height: 32),

              // Verify Button
              ElevatedButton(
                onPressed: _isLoading ? null : _verify2FA,
                style: AppTheme.primaryButtonStyle,
                child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(_useBackupCode ? 'Verify Backup Code' : 'Verify Code'),
              ),

              const SizedBox(height: 24),

              // Help Section
              if (!_useBackupCode) ...[
                Card(
                  color: AppTheme.surfaceDark.withValues(alpha:0.5),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: AppTheme.accent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Having trouble?',
                              style: AppTheme.bodyText.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Make sure your device time is correct\n'
                          '• Check your authenticator app (Google Authenticator, Authy, etc.)\n'
                          '• Use a backup code if your authenticator is unavailable',
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Contact Support
              TextButton(
                onPressed: () {
                  // TODO: Implement contact support
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Contact support feature coming soon'),
                      backgroundColor: AppTheme.info,
                    ),
                  );
                },
                child: Text(
                  'Need help? Contact Support',
                  style: AppTheme.bodyText.copyWith(
                    color: AppTheme.accent,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}