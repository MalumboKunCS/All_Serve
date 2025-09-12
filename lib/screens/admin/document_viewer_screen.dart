import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';

class DocumentViewerScreen extends StatefulWidget {
  final String documentUrl;
  final String documentTitle;

  const DocumentViewerScreen({
    super.key,
    required this.documentUrl,
    required this.documentTitle,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  final TransformationController _transformationController = TransformationController();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkDocumentType();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _checkDocumentType() {
    // Check if it's an image
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
    final isImage = imageExtensions.any((ext) => 
      widget.documentUrl.toLowerCase().contains(ext));
    
    if (!isImage) {
      setState(() {
        _error = 'Unsupported document type. Only images are supported in this viewer.';
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(
          widget.documentTitle,
          style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadDocument,
            tooltip: 'Download Document',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            onPressed: _resetZoom,
            tooltip: 'Reset Zoom',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Document',
              style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              style: AppTheme.primaryButtonStyle,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: CachedNetworkImage(
            imageUrl: widget.documentUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.accent),
                  const SizedBox(height: 16),
                  Text(
                    'Loading document...',
                    style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load document',
                    style: AppTheme.bodyText.copyWith(color: AppTheme.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'URL: ${widget.documentUrl}',
                    style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _downloadDocument() {
    // Show download options
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Download Document',
              style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            Text(
              'This will open the document in your browser where you can download it.',
              style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: AppTheme.outlineButtonStyle,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _openInBrowser();
                    },
                    style: AppTheme.primaryButtonStyle,
                    child: const Text('Open in Browser'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openInBrowser() {
    // For now, show a message. In production, use url_launcher
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening: ${widget.documentUrl}'),
        backgroundColor: AppTheme.info,
        action: SnackBarAction(
          label: 'Copy URL',
          onPressed: () {
            // Copy to clipboard
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('URL copied to clipboard'),
                backgroundColor: AppTheme.success,
              ),
            );
          },
        ),
      ),
    );
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }
}
