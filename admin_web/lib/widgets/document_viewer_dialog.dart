import 'package:flutter/material.dart';
import 'package:shared/shared.dart' as shared;
// Add html import for web functionality
import 'dart:html' as html;

class DocumentViewerDialog extends StatefulWidget {
  final String documentType;
  final String documentUrl;

  const DocumentViewerDialog({
    super.key,
    required this.documentType,
    required this.documentUrl,
  });

  @override
  State<DocumentViewerDialog> createState() => _DocumentViewerDialogState();
}

class _DocumentViewerDialogState extends State<DocumentViewerDialog> {
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Simulate loading time for document
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
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
        child: Column(
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
                    _getDocumentIcon(),
                    color: shared.AppTheme.primaryPurple,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getDocumentTitle(),
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
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: shared.AppTheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load document',
              style: shared.AppTheme.heading3.copyWith(
                color: shared.AppTheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The document could not be displayed',
              style: shared.AppTheme.bodyMedium.copyWith(
                color: shared.AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openInNewTab(),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in New Tab'),
              style: shared.AppTheme.primaryButtonStyle,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Document info
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: shared.AppTheme.cardLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _getDocumentIcon(),
                color: shared.AppTheme.primaryPurple,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getDocumentTitle(),
                      style: shared.AppTheme.bodyLarge.copyWith(
                        color: shared.AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'URL: ${widget.documentUrl}',
                      style: shared.AppTheme.caption.copyWith(
                        color: shared.AppTheme.textTertiary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Document preview area - FIXED: Actually display the document
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: shared.AppTheme.backgroundDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: shared.AppTheme.primaryPurple.withValues(alpha:0.3),
              ),
            ),
            child: _buildDocumentPreview(),
          ),
        ),

        // Action buttons
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _downloadDocument(),
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: shared.AppTheme.primaryPurple,
                    side: BorderSide(color: shared.AppTheme.primaryPurple),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openInNewTab(),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open in New Tab'),
                  style: shared.AppTheme.primaryButtonStyle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentPreview() {
    // FIXED: Actually display the document based on its type
    final isPdf = widget.documentUrl.toLowerCase().contains('.pdf');
    final isImage = widget.documentUrl.toLowerCase().contains('.jpg') || 
                   widget.documentUrl.toLowerCase().contains('.jpeg') || 
                   widget.documentUrl.toLowerCase().contains('.png') ||
                   widget.documentUrl.toLowerCase().contains('.gif');
    
    if (isImage) {
      // Display image directly
      return Image.network(
        widget.documentUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: shared.AppTheme.error,
                ),
                const SizedBox(height: 8),
                Text(
                  'Failed to load image',
                  style: shared.AppTheme.bodyMedium.copyWith(
                    color: shared.AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else if (isPdf) {
      // For PDF, provide a message that it will open in a new tab
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf,
              size: 64,
              color: shared.AppTheme.primaryPurple,
            ),
            const SizedBox(height: 16),
            Text(
              'PDF Document',
              style: shared.AppTheme.heading3.copyWith(
                color: shared.AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Click "Open in New Tab" to view this PDF document',
              style: shared.AppTheme.bodyMedium.copyWith(
                color: shared.AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      // For other document types
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getDocumentIcon(),
              size: 64,
              color: shared.AppTheme.primaryPurple,
            ),
            const SizedBox(height: 16),
            Text(
              _getDocumentTitle(),
              style: shared.AppTheme.heading3.copyWith(
                color: shared.AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Document preview not available for this file type',
              style: shared.AppTheme.bodyMedium.copyWith(
                color: shared.AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Click "Open in New Tab" or "Download" to access the document',
              style: shared.AppTheme.caption.copyWith(
                color: shared.AppTheme.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  IconData _getDocumentIcon() {
    switch (widget.documentType) {
      case 'nrcUrl':
        return Icons.badge;
      case 'businessLicenseUrl':
        return Icons.business;
      case 'certificatesUrl':
        return Icons.verified_user;
      case 'otherDocs':
        return Icons.description;
      default:
        return Icons.attach_file;
    }
  }

  String _getDocumentTitle() {
    switch (widget.documentType) {
      case 'nrcUrl':
        return 'National Registration Card (NRC)';
      case 'businessLicenseUrl':
        return 'Business License';
      case 'certificatesUrl':
        return 'Professional Certificates';
      case 'otherDocs':
        return 'Other Documents';
      default:
        return 'Document';
    }
  }

  void _downloadDocument() {
    // Use HTML to trigger download
    try {
      html.window.open(widget.documentUrl, '_blank');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening ${_getDocumentTitle()} for download...'),
          backgroundColor: shared.AppTheme.info,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download document: $e'),
          backgroundColor: shared.AppTheme.error,
        ),
      );
    }
  }

  void _openInNewTab() {
    // Open document URL in new tab using HTML
    try {
      html.window.open(widget.documentUrl, '_blank');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening ${_getDocumentTitle()} in new tab...'),
          backgroundColor: shared.AppTheme.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open document: $e'),
          backgroundColor: shared.AppTheme.error,
        ),
      );
    }
  }
}