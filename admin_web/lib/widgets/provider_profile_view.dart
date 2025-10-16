import 'package:flutter/material.dart';
import 'package:shared/shared.dart' as shared;

class ProviderProfileView extends StatefulWidget {
  final shared.Provider provider;
  final Function(shared.Provider, String) onAction;

  const ProviderProfileView({
    super.key,
    required this.provider,
    required this.onAction,
  });

  @override
  State<ProviderProfileView> createState() => _ProviderProfileViewState();
}

class _ProviderProfileViewState extends State<ProviderProfileView> {
  // FirebaseFirestore instance removed as it's not used
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 24),
            
            // Content Sections
            _buildBusinessInformation(),
            const SizedBox(height: 24),
            
            _buildContactInformation(),
            const SizedBox(height: 24),
            
            _buildServicesSection(),
            const SizedBox(height: 24),
            
            _buildBookingStats(),
            const SizedBox(height: 24),
            
            _buildReviewsSection(),
            const SizedBox(height: 24),
            
            _buildVerificationDocuments(),
            const SizedBox(height: 24),
            
            _buildAdminActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: shared.AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: shared.AppTheme.cardLight),
      ),
      child: Row(
        children: [
          // Provider Logo
          CircleAvatar(
            radius: 40,
            backgroundColor: shared.AppTheme.primaryPurple.withValues(alpha:0.1),
            backgroundImage: widget.provider.logoUrl != null && widget.provider.logoUrl!.isNotEmpty
                ? NetworkImage(widget.provider.logoUrl!)
                : null,
            child: widget.provider.logoUrl == null || widget.provider.logoUrl!.isEmpty
                ? Text(
                    widget.provider.businessName.isNotEmpty 
                        ? widget.provider.businessName.substring(0, 1).toUpperCase()
                        : 'P',
                    style: shared.AppTheme.heading1.copyWith(
                      color: shared.AppTheme.primaryPurple,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 20),
          
          // Provider Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.provider.businessName,
                  style: shared.AppTheme.heading2.copyWith(
                    color: shared.AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                _buildStatusChip(widget.provider.status),
                const SizedBox(height: 8),
                Text(
                  widget.provider.description,
                  style: shared.AppTheme.bodyMedium.copyWith(
                    color: shared.AppTheme.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          // Quick Stats
          Column(
            children: [
              _buildStatCard('Rating', '${widget.provider.ratingAvg.toStringAsFixed(1)} ⭐'),
              const SizedBox(height: 8),
              _buildStatCard('Bookings', '${widget.provider.ratingCount}'),
              const SizedBox(height: 8),
              _buildStatCard('Reviews', '${widget.provider.ratingCount}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: shared.AppTheme.cardLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: shared.AppTheme.bodyLarge.copyWith(
              color: shared.AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: shared.AppTheme.caption.copyWith(
              color: shared.AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessInformation() {
    return _buildSection(
      'Business Information',
      Icons.business,
      [
        _buildInfoRow('Business Name', widget.provider.businessName),
        _buildInfoRow('Description', widget.provider.description),
        _buildInfoRow('Category', widget.provider.categoryId),
        _buildInfoRow('Website', widget.provider.websiteUrl ?? 'Not provided'),
        _buildInfoRow('Service Area', '${widget.provider.serviceAreaKm} km'),
        _buildInfoRow('Joined Date', _formatDate(widget.provider.createdAt)),
      ],
    );
  }

  Widget _buildContactInformation() {
    return _buildSection(
      'Contact Information',
      Icons.contact_phone,
      [
        _buildInfoRow('Owner UID', widget.provider.ownerUid),
        _buildInfoRow('Location', '${widget.provider.lat}, ${widget.provider.lng}'),
        _buildInfoRow('Geohash', widget.provider.geohash),
        _buildInfoRow('Address', _getAddressFromLocation()),
      ],
    );
  }

  Widget _buildServicesSection() {
    return _buildSection(
      'Services Offered',
      Icons.work,
      widget.provider.services.isEmpty
          ? [Text('No services listed')]
          : widget.provider.services.map((service) => _buildServiceCard(service)).toList(),
    );
  }

  Widget _buildServiceCard(shared.Service service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shared.AppTheme.cardLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service.title,
            style: shared.AppTheme.bodyLarge.copyWith(
              color: shared.AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.attach_money, size: 16, color: shared.AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                '\$${service.priceFrom} - \$${service.priceTo}',
                style: shared.AppTheme.bodyMedium.copyWith(
                  color: shared.AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.schedule, size: 16, color: shared.AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${service.durationMin} minutes',
                style: shared.AppTheme.bodyMedium.copyWith(
                  color: shared.AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          // Service description removed as it's not in the Service model
        ],
      ),
    );
  }

  Widget _buildBookingStats() {
    return _buildSection(
      'Booking Statistics',
      Icons.analytics,
      [
        _buildStatRow('Total Bookings', '${widget.provider.ratingCount}'),
        _buildStatRow('Completed Bookings', '${widget.provider.ratingCount}'),
        _buildStatRow('Cancellation Rate', '${_calculateCancellationRate()}%'),
        _buildStatRow('Average Rating', '${widget.provider.ratingAvg.toStringAsFixed(1)} ⭐'),
      ],
    );
  }

  Widget _buildReviewsSection() {
    return _buildSection(
      'Reviews & Ratings',
      Icons.star,
      [
        // TODO: Implement reviews list
        Text(
          'Reviews will be implemented when review system is ready',
          style: shared.AppTheme.bodyMedium.copyWith(
            color: shared.AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationDocuments() {
    return _buildSection(
      'Verification Documents',
      Icons.description,
      widget.provider.documents.isEmpty
          ? [Text('No documents uploaded')]
          : widget.provider.documents.entries.map((entry) {
              return _buildDocumentCard(entry.key, entry.value);
            }).toList(),
    );
  }

  Widget _buildDocumentCard(String docType, String url) {
    IconData icon;
    String label;
    
    switch (docType) {
      case 'nrcUrl':
        icon = Icons.badge;
        label = 'National Registration Card (NRC)';
        break;
      case 'businessLicenseUrl':
        icon = Icons.business;
        label = 'Business License';
        break;
      case 'otherDocs':
        icon = Icons.description;
        label = 'Other Documents';
        break;
      default:
        icon = Icons.attach_file;
        label = docType;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _viewDocument(url),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: shared.AppTheme.cardLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: shared.AppTheme.primaryPurple.withValues(alpha:0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: shared.AppTheme.primaryPurple, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: shared.AppTheme.bodyMedium.copyWith(
                    color: shared.AppTheme.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.open_in_new,
                color: shared.AppTheme.primaryPurple,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminActions() {
    return _buildSection(
      'Admin Actions',
      Icons.admin_panel_settings,
      [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => widget.onAction(widget.provider, 'suspend'),
                icon: const Icon(Icons.pause_circle_outline),
                label: Text(widget.provider.status == 'suspended' ? 'Unsuspend' : 'Suspend'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.provider.status == 'suspended' 
                      ? shared.AppTheme.success 
                      : shared.AppTheme.warning,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => widget.onAction(widget.provider, 'promote'),
                icon: const Icon(Icons.star_outline),
                label: const Text('Promote to Featured'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: shared.AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => widget.onAction(widget.provider, 'reset_password'),
                icon: const Icon(Icons.lock_reset),
                label: const Text('Reset Password'),
                style: shared.AppTheme.secondaryButtonStyle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => widget.onAction(widget.provider, 'delete'),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete Provider'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: shared.AppTheme.error,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: shared.AppTheme.primaryPurple, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: shared.AppTheme.heading3.copyWith(
                color: shared.AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: shared.AppTheme.cardDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: shared.AppTheme.cardLight),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: shared.AppTheme.bodyMedium.copyWith(
                color: shared.AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: shared.AppTheme.bodyMedium.copyWith(
                color: shared.AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: shared.AppTheme.bodyMedium.copyWith(
              color: shared.AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: shared.AppTheme.bodyMedium.copyWith(
              color: shared.AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    
    switch (status.toLowerCase()) {
      case 'active':
        color = shared.AppTheme.success;
        icon = Icons.check_circle;
        break;
      case 'suspended':
        color = shared.AppTheme.error;
        icon = Icons.pause_circle;
        break;
      case 'pending':
        color = shared.AppTheme.warning;
        icon = Icons.pending;
        break;
      default:
        color = shared.AppTheme.textTertiary;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: shared.AppTheme.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _viewDocument(String url) {
    // TODO: Implement document viewer
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening document: $url'),
        backgroundColor: shared.AppTheme.info,
      ),
    );
  }

  String _getAddressFromLocation() {
    // TODO: Implement reverse geocoding
    return '${widget.provider.lat}, ${widget.provider.lng}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day}/${date.month}/${date.year}';
  }

  double _calculateCancellationRate() {
    // TODO: Calculate actual cancellation rate from bookings data
    return 5.2; // Placeholder
  }
}
