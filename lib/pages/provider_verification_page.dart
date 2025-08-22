import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:all_server/models/provider.dart';
import 'package:all_server/services/provider_service.dart';

class ProviderVerificationPage extends StatefulWidget {
  final Provider provider;

  const ProviderVerificationPage({super.key, required this.provider});

  @override
  State<ProviderVerificationPage> createState() => _ProviderVerificationPageState();
}

class _ProviderVerificationPageState extends State<ProviderVerificationPage> {
  final ProviderService _providerService = ProviderService();
  final ImagePicker _imagePicker = ImagePicker();
  
  File? _businessLicense;
  File? _pacraRegistration;
  File? _identityDocument;
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification & Security'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verification Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verification Status',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatusItem(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Document Upload Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Required Documents',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upload the following documents for verification. All documents will be reviewed manually by our admin team.',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Business License
                    _buildDocumentUpload(
                      title: 'Business License',
                      description: 'Upload your valid business operating license',
                      currentFile: _businessLicense,
                      existingUrl: widget.provider.businessLicense,
                      onPickFile: () => _pickDocument('business_license'),
                      required: true,
                    ),
                    const SizedBox(height: 20),

                    // PACRA Registration (for Zambian businesses)
                    _buildDocumentUpload(
                      title: 'PACRA Registration Certificate',
                      description: 'Upload your PACRA (Patents and Companies Registration Agency) certificate for Zambian businesses',
                      currentFile: _pacraRegistration,
                      existingUrl: widget.provider.pacraRegistration,
                      onPickFile: () => _pickDocument('pacra_registration'),
                      required: true,
                    ),
                    const SizedBox(height: 20),

                    // Identity Document
                    _buildDocumentUpload(
                      title: 'Identity Document',
                      description: 'Upload a clear photo of your National ID or Passport',
                      currentFile: _identityDocument,
                      existingUrl: null, // Not stored in provider model
                      onPickFile: () => _pickDocument('identity'),
                      required: true,
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _canSubmit() && !_isUploading 
                            ? _submitDocuments 
                            : null,
                        icon: _isUploading 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload),
                        label: Text(_isUploading ? 'Uploading...' : 'Submit for Verification'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Information Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Verification Process',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• All documents are reviewed manually by our admin team\n'
                      '• Verification typically takes 2-3 business days\n'
                      '• You will receive notifications about your verification status\n'
                      '• Ensure all documents are clear and valid\n'
                      '• Only verified providers can receive bookings',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        height: 1.5,
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

  Widget _buildStatusItem() {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String statusDescription;

    switch (widget.provider.verificationStatus) {
      case VerificationStatus.approved:
        statusColor = Colors.green;
        statusIcon = Icons.verified;
        statusText = 'Verified';
        statusDescription = 'Your account has been successfully verified';
        break;
      case VerificationStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'Pending Review';
        statusDescription = 'Your documents are under review by our admin team';
        break;
      case VerificationStatus.rejected:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Verification Rejected';
        statusDescription = 'Your verification was rejected. Please upload valid documents';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.upload_file;
        statusText = 'Not Submitted';
        statusDescription = 'Upload your documents to start the verification process';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusDescription,
                  style: TextStyle(
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentUpload({
    required String title,
    required String description,
    required File? currentFile,
    required String? existingUrl,
    required VoidCallback onPickFile,
    required bool required,
  }) {
    final hasDocument = currentFile != null || existingUrl != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: hasDocument ? Colors.green.shade300 : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (required) ...[
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(color: Colors.red),
                ),
              ],
              const Spacer(),
              if (hasDocument)
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: onPickFile,
                icon: Icon(currentFile != null ? Icons.edit : Icons.upload),
                label: Text(currentFile != null ? 'Change File' : 'Upload File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasDocument ? Colors.grey.shade600 : Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
              if (currentFile != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'New file selected: ${currentFile.path.split('/').last}',
                    style: TextStyle(
                      color: Colors.green.shade600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ] else if (existingUrl != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Document already uploaded',
                    style: TextStyle(
                      color: Colors.green.shade600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDocument(String type) async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (file != null) {
        setState(() {
          switch (type) {
            case 'business_license':
              _businessLicense = File(file.path);
              break;
            case 'pacra_registration':
              _pacraRegistration = File(file.path);
              break;
            case 'identity':
              _identityDocument = File(file.path);
              break;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  bool _canSubmit() {
    return (_businessLicense != null || widget.provider.businessLicense != null) &&
           (_pacraRegistration != null || widget.provider.pacraRegistration != null) &&
           _identityDocument != null;
  }

  Future<void> _submitDocuments() async {
    setState(() {
      _isUploading = true;
    });

    try {
      final success = await _providerService.uploadVerificationDocuments(
        providerId: widget.provider.id,
        businessLicense: _businessLicense,
        pacraRegistration: _pacraRegistration,
        additionalDocs: _identityDocument != null ? [_identityDocument!] : null,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documents submitted successfully! They will be reviewed by our admin team.'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear selected files
        setState(() {
          _businessLicense = null;
          _pacraRegistration = null;
          _identityDocument = null;
        });
      } else {
        throw Exception('Failed to upload documents');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }
}



