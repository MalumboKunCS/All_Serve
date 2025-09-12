import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/database_setup.dart';

class DatabaseSetupScreen extends StatefulWidget {
  const DatabaseSetupScreen({super.key});

  @override
  State<DatabaseSetupScreen> createState() => _DatabaseSetupScreenState();
}

class _DatabaseSetupScreenState extends State<DatabaseSetupScreen> {
  final DatabaseSetup _databaseSetup = DatabaseSetup();
  bool _isLoading = false;
  String _status = 'Ready to setup database';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Database Setup'),
        backgroundColor: AppTheme.primaryPurple,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: AppTheme.surfaceDark,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Database Status',
                      style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Setup Options
            Text(
              'Setup Options',
              style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            
            // Initialize Database Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _initializeDatabase,
              icon: const Icon(Icons.build),
              label: const Text('Initialize Database'),
              style: AppTheme.primaryButtonStyle,
            ),
            
            const SizedBox(height: 12),
            
            // Complete Setup Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _setupCompleteDatabase,
              icon: const Icon(Icons.storage),
              label: const Text('Complete Database Setup'),
              style: AppTheme.primaryButtonStyle,
            ),
            
            const SizedBox(height: 12),
            
            // Create Sample Data Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _createSampleData,
              icon: const Icon(Icons.data_usage),
              label: const Text('Create Sample Data Only'),
              style: AppTheme.secondaryButtonStyle,
            ),
            
            const SizedBox(height: 12),
            
            // Clear Data Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _clearAllData,
              icon: const Icon(Icons.delete_forever),
              label: const Text('Clear All Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: AppTheme.textPrimary,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Instructions
            Card(
              color: AppTheme.surfaceDark,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions',
                      style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Initialize Database: Creates basic structure and admin user\n'
                      '2. Complete Setup: Creates all sample data for testing\n'
                      '3. Sample Data Only: Adds sample data to existing database\n'
                      '4. Clear All Data: Removes all data (use with caution)',
                      style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Admin Credentials
            Card(
              color: AppTheme.surfaceDark,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Credentials',
                      style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Email: admin@allserve.com\nPassword: admin123456',
                      style: AppTheme.bodyText.copyWith(
                        color: AppTheme.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initializeDatabase() async {
    setState(() {
      _isLoading = true;
      _status = 'Initializing database...';
    });

    try {
      await _databaseSetup.initializeDatabase();
      setState(() {
        _status = 'Database initialized successfully!';
      });
      _showSuccessMessage('Database initialized successfully!');
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      _showErrorMessage('Failed to initialize database: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _setupCompleteDatabase() async {
    setState(() {
      _isLoading = true;
      _status = 'Setting up complete database...';
    });

    try {
      await _databaseSetup.setupCompleteDatabase();
      setState(() {
        _status = 'Complete database setup finished!';
      });
      _showSuccessMessage('Complete database setup finished successfully!');
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      _showErrorMessage('Failed to setup complete database: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createSampleData() async {
    setState(() {
      _isLoading = true;
      _status = 'Creating sample data...';
    });

    try {
      await _databaseSetup.createSampleBookings();
      await _databaseSetup.createSampleReviews();
      await _databaseSetup.createVerificationQueue();
      await _databaseSetup.createSampleAnnouncements();
      
      setState(() {
        _status = 'Sample data created successfully!';
      });
      _showSuccessMessage('Sample data created successfully!');
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      _showErrorMessage('Failed to create sample data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(
          'Clear All Data',
          style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Are you sure you want to clear all data? This action cannot be undone.',
          style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _status = 'Clearing all data...';
    });

    try {
      await _databaseSetup.clearAllData();
      setState(() {
        _status = 'All data cleared successfully!';
      });
      _showSuccessMessage('All data cleared successfully!');
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      _showErrorMessage('Failed to clear data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
      ),
    );
  }
}
