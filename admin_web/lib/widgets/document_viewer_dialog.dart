import 'package:flutter/material.dart';
import 'package:shared/shared.dart' as shared;

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

        // Document preview area
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: shared.AppTheme.backgroundDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: shared.AppTheme.primaryPurple.withOpacity(0.3),
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
    // For now, show a placeholder since we can't directly display PDFs or images in Flutter web
    // In a real implementation, you might use a PDF viewer package or image viewer
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
            'Document preview not available',
            style: shared.AppTheme.bodyMedium.copyWith(
              color: shared.AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Click "Open in New Tab" to view the document',
            style: shared.AppTheme.caption.copyWith(
              color: shared.AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDocumentIcon() {
    switch (widget.documentType) {
      case 'nrcUrl':
        return Icons.badge;
      case 'businessLicenseUrl':
        return Icons.business;
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
      case 'otherDocs':
        return 'Other Documents';
      default:
        return 'Document';
    }
  }

  void _downloadDocument() {
    // In a web environment, this would trigger a download
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${_getDocumentTitle()}...'),
        backgroundColor: shared.AppTheme.info,
      ),
    );
  }

  void _openInNewTab() {
    // Open document URL in new tab
    // In Flutter web, this would use html.window.open()
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${_getDocumentTitle()} in new tab...'),
        backgroundColor: shared.AppTheme.success,
      ),
    );
  }
}
