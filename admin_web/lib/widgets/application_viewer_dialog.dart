import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared/shared.dart' as shared;
import 'document_viewer_dialog.dart';
import '../utils/app_logger.dart';

class ApplicationViewerDialog extends StatefulWidget {
  final String applicationId;
  final String providerId;

  const ApplicationViewerDialog({
    super.key,
    required this.applicationId,
    required this.providerId,
  });

  @override
  State<ApplicationViewerDialog> createState() => _ApplicationViewerDialogState();
}

class _ApplicationViewerDialogState extends State<ApplicationViewerDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  shared.Provider? _provider;
  Map<String, dynamic>? _application;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApplicationData();
  }

  Future<void> _loadApplicationData() async {
    try {
      // Load provider data
      final providerDoc = await _firestore
          .collection('providers')
          .doc(widget.providerId)
          .get();
      
      if (providerDoc.exists) {
        final providerData = providerDoc.data()!;
        
        // Debug logging to trace data flow
        AppLogger.debug('=== APPLICATION VIEWER DEBUG ===');
        AppLogger.debug('Provider ID: ${widget.providerId}');
        AppLogger.debug('Raw provider data keys: ${providerData.keys.toList()}');
        AppLogger.debug('Business Name field: ${providerData['businessName']}');
        AppLogger.debug('Description field: ${providerData['description']}');
        AppLogger.debug('Documents field: ${providerData['documents']}');
        AppLogger.debug('Full provider data: $providerData');
        AppLogger.debug('=== END APPLICATION VIEWER DEBUG ===');
        
        // Create a normalized provider data structure
        final normalizedProviderData = Map<String, dynamic>.from(providerData);
        
        // Handle both document storage formats:
        // 1. Individual fields (nrcUrl, businessLicenseUrl, certificatesUrl)
        // 2. Documents map (documents: {nrcUrl: "...", businessLicenseUrl: "..."})
        Map<String, dynamic> documents = {};
        
        // Check if documents are stored as a map
        if (providerData['documents'] != null && providerData['documents'] is Map) {
          documents = Map<String, dynamic>.from(providerData['documents']);
        } else {
          // Check for individual document fields
          if (providerData['nrcUrl'] != null && providerData['nrcUrl'].toString().isNotEmpty) {
            documents['nrcUrl'] = providerData['nrcUrl'];
          }
          if (providerData['businessLicenseUrl'] != null && providerData['businessLicenseUrl'].toString().isNotEmpty) {
            documents['businessLicenseUrl'] = providerData['businessLicenseUrl'];
          }
          if (providerData['certificatesUrl'] != null && providerData['certificatesUrl'].toString().isNotEmpty) {
            documents['certificatesUrl'] = providerData['certificatesUrl'];
          }
        }
        
        // Ensure the documents field is properly set
        normalizedProviderData['documents'] = documents;
        
        AppLogger.debug('Normalized provider data documents: $documents');
        
        _provider = shared.Provider.fromMap(
          normalizedProviderData,
          id: widget.providerId,
        );
      }

      // Load application data
      final applicationDoc = await _firestore
          .collection('verification_queue')
          .doc(widget.applicationId)
          .get();
      
      if (applicationDoc.exists) {
        _application = applicationDoc.data();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading application data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: shared.AppTheme.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _provider == null
                ? Center(
                    child: Text(
                      'Application data not found',
                      style: shared.AppTheme.bodyLarge.copyWith(
                        color: shared.AppTheme.error,
                      ),
                    ),
                  )
                : _buildApplicationContent(),
      ),
    );
  }

  Widget _buildApplicationContent() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: shared.AppTheme.cardLight,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.business,
                color: shared.AppTheme.primaryPurple,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Provider Application Details',
                  style: shared.AppTheme.heading2.copyWith(
                    color: shared.AppTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                color: shared.AppTheme.textSecondary,
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Business Information
                _buildSection(
                  'Business Information',
                  Icons.business,
                  [
                    _buildInfoRow('Business Name', _provider!.businessName),
                    _buildInfoRow('Description', _provider!.description),
                    _buildInfoRow('Category ID', _provider!.categoryId),
                    _buildInfoRow('Website', _provider!.websiteUrl ?? 'Not provided'),
                    _buildInfoRow('Service Area', '${_provider!.serviceAreaKm} km'),
                  ],
                ),

                const SizedBox(height: 24),

                // Contact Information
                _buildSection(
                  'Contact Information',
                  Icons.contact_phone,
                  [
                    _buildInfoRow('Owner UID', _provider!.ownerUid),
                    _buildInfoRow('Location', '${_provider!.lat}, ${_provider!.lng}'),
                    _buildInfoRow('Geohash', _provider!.geohash),
                  ],
                ),

                const SizedBox(height: 24),

                // Services
                if (_provider!.services.isNotEmpty) ...[
                  _buildSection(
                    'Services Offered',
                    Icons.work,
                    _provider!.services.map((service) => _buildServiceInfo(service)).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // Documents
                _buildDocumentsSection(),

                const SizedBox(height: 24),

                // Images
                if (_provider!.images.isNotEmpty) ...[
                  _buildImagesSection(),
                  const SizedBox(height: 24),
                ],

                // Application Status
                _buildApplicationStatusSection(),
              ],
            ),
          ),
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
            color: shared.AppTheme.cardLight,
            borderRadius: BorderRadius.circular(8),
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

  Widget _buildServiceInfo(shared.Service service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: shared.AppTheme.backgroundDark,
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
          const SizedBox(height: 4),
          Text(
            'Price: \$${service.priceFrom} - \$${service.priceTo}',
            style: shared.AppTheme.bodyMedium.copyWith(
              color: shared.AppTheme.textSecondary,
            ),
          ),
          Text(
            'Duration: ${service.durationMin} minutes',
            style: shared.AppTheme.bodyMedium.copyWith(
              color: shared.AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection() {
    final documents = _provider!.documents;
    
    return _buildSection(
      'Submitted Documents',
      Icons.description,
      documents.entries.map((entry) {
        return _buildDocumentRow(entry.key, entry.value);
      }).toList(),
    );
  }

  Widget _buildDocumentRow(String docType, String url) {
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
      case 'certificatesUrl':
        icon = Icons.verified_user;
        label = 'Professional Certificates';
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
            color: shared.AppTheme.backgroundDark,
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

  Widget _buildImagesSection() {
    return _buildSection(
      'Business Images',
      Icons.image,
      [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _provider!.images.map((imageUrl) {
            return _buildImageThumbnail(imageUrl);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildImageThumbnail(String imageUrl) {
    return InkWell(
      onTap: () => _viewImage(imageUrl),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: shared.AppTheme.primaryPurple.withValues(alpha:0.3),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: shared.AppTheme.cardLight,
                child: Icon(
                  Icons.image,
                  color: shared.AppTheme.textTertiary,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildApplicationStatusSection() {
    final status = _application?['status'] ?? 'pending';
    final submittedAt = (_application?['submittedAt'] as Timestamp?)?.toDate();
    final reviewedAt = (_application?['reviewedAt'] as Timestamp?)?.toDate();
    final notes = _application?['notes'] as String?;

    return _buildSection(
      'Application Status',
      Icons.info,
      [
        _buildInfoRow('Status', status.toUpperCase()),
        _buildInfoRow('Submitted At', _formatDate(submittedAt)),
        if (reviewedAt != null)
          _buildInfoRow('Reviewed At', _formatDate(reviewedAt)),
        if (notes != null && notes.isNotEmpty)
          _buildInfoRow('Admin Notes', notes),
      ],
    );
  }

  void _viewDocument(String url) {
    // Extract document type from URL or use a generic type
    String docType = 'otherDocs';
    if (url.contains('nrc') || url.contains('NRC')) {
      docType = 'nrcUrl';
    } else if (url.contains('license') || url.contains('License')) {
      docType = 'businessLicenseUrl';
    } else if (url.contains('certificate') || url.contains('Certificate')) {
      docType = 'certificatesUrl';
    }
    
    showDialog(
      context: context,
      builder: (context) => DocumentViewerDialog(
        documentType: docType,
        documentUrl: url,
      ),
    );
  }

  void _viewImage(String imageUrl) {
    // TODO: Implement image viewer
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening image: $imageUrl'),
        backgroundColor: shared.AppTheme.info,
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
