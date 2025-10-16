import 'package:flutter/material.dart';
import 'package:shared/shared.dart' as shared;
import '../services/provider_management_service.dart';

class FlaggedProvidersWidget extends StatefulWidget {
  const FlaggedProvidersWidget({super.key});

  @override
  State<FlaggedProvidersWidget> createState() => _FlaggedProvidersWidgetState();
}

class _FlaggedProvidersWidgetState extends State<FlaggedProvidersWidget> {
  List<Map<String, dynamic>> _flaggedProviders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFlaggedProviders();
  }

  Future<void> _loadFlaggedProviders() async {
    setState(() => _isLoading = true);
    
    try {
      final flaggedProviders = await ProviderManagementService.getFlaggedProviders();
      setState(() {
        _flaggedProviders = flaggedProviders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading flagged providers: $e'),
            backgroundColor: shared.AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Flagged Providers',
                style: shared.AppTheme.heading2.copyWith(
                  color: shared.AppTheme.textPrimary,
                ),
              ),
              IconButton(
                onPressed: _loadFlaggedProviders,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Providers with suspicious behavior or poor performance',
            style: shared.AppTheme.bodyMedium.copyWith(
              color: shared.AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _flaggedProviders.isEmpty
                    ? _buildEmptyState()
                    : _buildFlaggedProvidersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: shared.AppTheme.success,
          ),
          const SizedBox(height: 16),
          Text(
            'No Flagged Providers',
            style: shared.AppTheme.heading3.copyWith(
              color: shared.AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All providers are performing well',
            style: shared.AppTheme.bodyMedium.copyWith(
              color: shared.AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlaggedProvidersList() {
    return ListView.builder(
      itemCount: _flaggedProviders.length,
      itemBuilder: (context, index) {
        final flaggedProvider = _flaggedProviders[index];
        final providerData = flaggedProvider['providerData'] as Map<String, dynamic>;
        final analytics = flaggedProvider['analytics'] as Map<String, dynamic>;
        final reason = flaggedProvider['reason'] as String;
        final providerId = flaggedProvider['providerId'] as String;

        return _buildFlaggedProviderCard(
          providerId,
          providerData,
          analytics,
          reason,
        );
      },
    );
  }

  Widget _buildFlaggedProviderCard(
    String providerId,
    Map<String, dynamic> providerData,
    Map<String, dynamic> analytics,
    String reason,
  ) {
    final businessName = providerData['businessName'] as String? ?? 'Unknown';
    final logoUrl = providerData['logoUrl'] as String?;
    final cancellationRate = analytics['cancellationRate'] ?? 0.0;
    final averageRating = analytics['averageRating'] ?? 0.0;
    final totalReviews = analytics['totalReviews'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: shared.AppTheme.cardDark,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: shared.AppTheme.error.withValues(alpha:0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                // Provider Logo
                CircleAvatar(
                  radius: 25,
                  backgroundColor: shared.AppTheme.error.withValues(alpha:0.1),
                  backgroundImage: logoUrl != null && logoUrl.isNotEmpty
                      ? NetworkImage(logoUrl)
                      : null,
                  child: logoUrl == null || logoUrl.isEmpty
                      ? Text(
                          businessName.isNotEmpty 
                              ? businessName.substring(0, 1).toUpperCase()
                              : 'P',
                          style: shared.AppTheme.bodyLarge.copyWith(
                            color: shared.AppTheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                
                // Provider Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        businessName,
                        style: shared.AppTheme.bodyLarge.copyWith(
                          color: shared.AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: shared.AppTheme.error.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: shared.AppTheme.error.withValues(alpha:0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flag,
                              size: 14,
                              color: shared.AppTheme.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'FLAGGED',
                              style: shared.AppTheme.caption.copyWith(
                                color: shared.AppTheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Action Buttons
                PopupMenuButton<String>(
                  onSelected: (action) => _handleAction(providerId, action),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view_details',
                      child: ListTile(
                        leading: Icon(Icons.visibility),
                        title: Text('View Details'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'suspend',
                      child: ListTile(
                        leading: Icon(Icons.pause_circle_outline),
                        title: Text('Suspend Provider'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'contact',
                      child: ListTile(
                        leading: Icon(Icons.message),
                        title: Text('Contact Provider'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Flag Reason
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: shared.AppTheme.error.withValues(alpha:0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: shared.AppTheme.error.withValues(alpha:0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning,
                    size: 16,
                    color: shared.AppTheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: shared.AppTheme.bodyMedium.copyWith(
                        color: shared.AppTheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Performance Metrics
            Row(
              children: [
                _buildMetricCard(
                  'Cancellation Rate',
                  '${cancellationRate.toStringAsFixed(1)}%',
                  cancellationRate > 30 ? shared.AppTheme.error : shared.AppTheme.warning,
                ),
                const SizedBox(width: 12),
                _buildMetricCard(
                  'Average Rating',
                  '${averageRating.toStringAsFixed(1)} ⭐',
                  averageRating < 2.5 ? shared.AppTheme.error : shared.AppTheme.warning,
                ),
                const SizedBox(width: 12),
                _buildMetricCard(
                  'Total Reviews',
                  '$totalReviews',
                  shared.AppTheme.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: shared.AppTheme.cardLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: shared.AppTheme.bodyLarge.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: shared.AppTheme.caption.copyWith(
                color: shared.AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(String providerId, String action) async {
    switch (action) {
      case 'view_details':
        // TODO: Navigate to provider details
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Viewing details for provider: $providerId'),
            backgroundColor: shared.AppTheme.info,
          ),
        );
        break;
      case 'suspend':
        await _suspendProvider(providerId);
        break;
      case 'contact':
        await _contactProvider(providerId);
        break;
    }
  }

  Future<void> _suspendProvider(String providerId) async {
    final confirmed = await _showConfirmationDialog(
      'Suspend Provider',
      'Are you sure you want to suspend this provider?',
    );

    if (!confirmed) return;

    try {
      final success = await ProviderManagementService.suspendProvider(providerId, true);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Provider suspended successfully'),
            backgroundColor: shared.AppTheme.success,
          ),
        );
        _loadFlaggedProviders(); // Refresh the list
      } else {
        throw Exception('Failed to suspend provider');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to suspend provider: $e'),
          backgroundColor: shared.AppTheme.error,
        ),
      );
    }
  }

  Future<void> _contactProvider(String providerId) async {
    // TODO: Implement contact provider functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contacting provider: $providerId'),
        backgroundColor: shared.AppTheme.info,
      ),
    );
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
            style: ElevatedButton.styleFrom(
              backgroundColor: shared.AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }
}








