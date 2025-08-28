import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/file_upload_service.dart';
import '../../models/provider.dart' as app_provider;

class ProviderDocumentsScreen extends StatefulWidget {
  final app_provider.Provider? provider;

  const ProviderDocumentsScreen({super.key, this.provider});

  @override
  State<ProviderDocumentsScreen> createState() => _ProviderDocumentsScreenState();
}

class _ProviderDocumentsScreenState extends State<ProviderDocumentsScreen> {
  Map<String, String> _uploadedDocuments = {};
  Map<String, double> _uploadProgress = {};

  // Required documents
  final Map<String, String> _requiredDocuments = {
    'nrcUrl': 'National Registration Card',
    'businessLicenseUrl': 'Business License',
    'certificatesUrl': 'Professional Certificates',
  };

  @override
  void initState() {
    super.initState();
    _loadExistingDocuments();
  }

  void _loadExistingDocuments() {
    if (widget.provider != null) {
      setState(() {
        _uploadedDocuments = {
          'nrcUrl': widget.provider!.nrcUrl ?? '',
          'businessLicenseUrl': widget.provider!.businessLicenseUrl ?? '',
          'certificatesUrl': widget.provider!.certificatesUrl ?? '',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Verification Documents'),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
          if (_hasAllDocuments())
            TextButton(
              onPressed: _submitForVerification,
              child: Text(
                'Submit for Verification',
                style: TextStyle(color: AppTheme.accent),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.info.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: AppTheme.info, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Document Requirements',
                        style: AppTheme.bodyText.copyWith(
                          color: AppTheme.info,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload clear, readable photos or scans of your documents. All documents are required for verification.',
                    style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Document Upload Cards
            ...(_requiredDocuments.entries.map((entry) {
              return _buildDocumentCard(entry.key, entry.value);
            }).toList()),

            const SizedBox(height: 24),

            // Verification Status
            if (widget.provider != null) _buildVerificationStatus(),

            const SizedBox(height: 24),

            // Guidelines
            _buildGuidelines(),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(String docKey, String docName) {
    final hasDocument = _uploadedDocuments[docKey]?.isNotEmpty ?? false;
    final isUploading = _uploadProgress.containsKey(docKey);
    final progress = _uploadProgress[docKey] ?? 0.0;

    return Card(
      color: AppTheme.surfaceDark,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document header
            Row(
              children: [
                Icon(
                  hasDocument ? Icons.check_circle : Icons.upload_file,
                  color: hasDocument ? AppTheme.success : AppTheme.textSecondary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        docName,
                        style: AppTheme.bodyText.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        hasDocument ? 'Uploaded' : 'Required',
                        style: AppTheme.caption.copyWith(
                          color: hasDocument ? AppTheme.success : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasDocument)
                  IconButton(
                    onPressed: () => _viewDocument(_uploadedDocuments[docKey]!),
                    icon: Icon(Icons.visibility, color: AppTheme.accent),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Upload progress
            if (isUploading) ...[
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AppTheme.textTertiary,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
              ),
              const SizedBox(height: 8),
              Text(
                'Uploading... ${(progress * 100).toStringAsFixed(0)}%',
                style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isUploading ? null : () => _uploadDocument(docKey, docName),
                    style: AppTheme.outlineButtonStyle,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(hasDocument ? 'Replace Photo' : 'Take Photo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isUploading ? null : () => _uploadDocumentFile(docKey, docName),
                    style: AppTheme.outlineButtonStyle,
                    icon: const Icon(Icons.file_upload),
                    label: Text(hasDocument ? 'Replace File' : 'Upload File'),
                  ),
                ),
              ],
            ),

            // Document preview
            if (hasDocument && !isUploading) ...[
              const SizedBox(height: 16),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.textTertiary),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _uploadedDocuments[docKey]!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description, size: 48, color: AppTheme.textSecondary),
                            const SizedBox(height: 8),
                            Text(
                              'Document Uploaded',
                              style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationStatus() {
    final provider = widget.provider!;
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String statusDescription;

    switch (provider.verificationStatus) {
      case 'pending':
        statusColor = AppTheme.warning;
        statusIcon = Icons.pending;
        statusText = 'Verification Pending';
        statusDescription = 'Your documents are being reviewed by our team.';
        break;
      case 'approved':
        statusColor = AppTheme.success;
        statusIcon = Icons.check_circle;
        statusText = 'Verified Provider';
        statusDescription = 'Your account has been verified and approved.';
        break;
      case 'rejected':
        statusColor = AppTheme.error;
        statusIcon = Icons.cancel;
        statusText = 'Verification Rejected';
        statusDescription = provider.adminNotes ?? 'Please review and resubmit your documents.';
        break;
      default:
        statusColor = AppTheme.textSecondary;
        statusIcon = Icons.help;
        statusText = 'Not Submitted';
        statusDescription = 'Submit all required documents for verification.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 12),
              Text(
                statusText,
                style: AppTheme.bodyText.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusDescription,
            style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelines() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Document Guidelines',
            style: AppTheme.bodyText.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...[
            'Ensure documents are clear and readable',
            'All text should be visible and not cut off',
            'Documents should be recent and valid',
            'File size should not exceed 10MB',
            'Accepted formats: PDF, JPG, PNG, DOC, DOCX',
          ].map((guideline) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: AppTheme.caption.copyWith(color: AppTheme.accent)),
                Expanded(
                  child: Text(
                    guideline,
                    style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Future<void> _uploadDocument(String docKey, String docName) async {
    try {
      setState(() {
        _uploadProgress[docKey] = 0.0;
      });

      final downloadUrl = await FileUploadService.uploadImageFromCamera(
        docName,
        'verification_documents',
      );

      if (downloadUrl != null) {
        setState(() {
          _uploadedDocuments[docKey] = downloadUrl;
          _uploadProgress.remove(docKey);
        });

        await _saveDocumentUrl(docKey, downloadUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$docName uploaded successfully'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } else {
        setState(() => _uploadProgress.remove(docKey));
      }
    } catch (e) {
      setState(() => _uploadProgress.remove(docKey));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload $docName: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _uploadDocumentFile(String docKey, String docName) async {
    try {
      setState(() {
        _uploadProgress[docKey] = 0.0;
      });

      final downloadUrl = await FileUploadService.uploadDocument(
        docName,
        'verification_documents',
      );

      if (downloadUrl != null) {
        setState(() {
          _uploadedDocuments[docKey] = downloadUrl;
          _uploadProgress.remove(docKey);
        });

        await _saveDocumentUrl(docKey, downloadUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$docName uploaded successfully'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } else {
        setState(() => _uploadProgress.remove(docKey));
      }
    } catch (e) {
      setState(() => _uploadProgress.remove(docKey));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload $docName: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _saveDocumentUrl(String docKey, String downloadUrl) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) return;

      // Find provider document
      final providerQuery = await FirebaseFirestore.instance
          .collection('providers')
          .where('ownerUid', isEqualTo: currentUser.uid)
          .get();

      if (providerQuery.docs.isNotEmpty) {
        final providerDoc = providerQuery.docs.first;
        await providerDoc.reference.update({docKey: downloadUrl});
      }
    } catch (e) {
      print('Error saving document URL: $e');
    }
  }

  bool _hasAllDocuments() {
    return _requiredDocuments.keys.every((key) => 
      _uploadedDocuments[key]?.isNotEmpty ?? false
    );
  }

  Future<void> _submitForVerification() async {
    if (!_hasAllDocuments()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please upload all required documents'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Show loading state

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) throw Exception('User not authenticated');

      // Find provider
      final providerQuery = await FirebaseFirestore.instance
          .collection('providers')
          .where('ownerUid', isEqualTo: currentUser.uid)
          .get();

      if (providerQuery.docs.isNotEmpty) {
        final providerDoc = providerQuery.docs.first;
        final providerId = providerDoc.id;

        // Update provider verification status
        await providerDoc.reference.update({
          'verificationStatus': 'pending',
          'submittedAt': FieldValue.serverTimestamp(),
        });

        // Create verification queue entry
        await FirebaseFirestore.instance.collection('verificationQueue').add({
          'providerId': providerId,
          'ownerUid': currentUser.uid,
          'submittedAt': FieldValue.serverTimestamp(),
          'status': 'pending',
          'docs': _uploadedDocuments,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Documents submitted for verification!'),
              backgroundColor: AppTheme.success,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit for verification: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        // Hide loading state
      }
    }
  }

  void _viewDocument(String url) {
    // TODO: Implement document viewer
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Document viewer: $url'),
        backgroundColor: AppTheme.info,
      ),
    );
  }
}

