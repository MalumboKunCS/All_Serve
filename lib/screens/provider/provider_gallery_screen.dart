import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import 'package:shared/shared.dart' as shared;
import '../../services/file_upload_service.dart';
import '../../models/provider.dart' as app_provider;

class ProviderGalleryScreen extends StatefulWidget {
  final app_provider.Provider? provider;

  const ProviderGalleryScreen({super.key, this.provider});

  @override
  State<ProviderGalleryScreen> createState() => _ProviderGalleryScreenState();
}

class _ProviderGalleryScreenState extends State<ProviderGalleryScreen> {
  List<String> _galleryImages = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadGalleryImages();
  }

  void _loadGalleryImages() {
    if (widget.provider?.galleryImages != null) {
      setState(() {
        _galleryImages = List<String>.from(widget.provider!.galleryImages);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Gallery'),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
          if (_galleryImages.length < 10)
            IconButton(
              onPressed: _isUploading ? null : _showUploadOptions,
              icon: const Icon(Icons.add_photo_alternate),
            ),
        ],
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.photo_library, color: AppTheme.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service Gallery',
                        style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                      ),
                      Text(
                        '${_galleryImages.length}/10 photos • Showcase your work',
                        style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Upload progress
          if (_isUploading) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    backgroundColor: AppTheme.textTertiary,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Uploading images...',
                    style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Gallery Grid
          Expanded(
            child: _galleryImages.isEmpty
                ? _buildEmptyState()
                : _buildGalleryGrid(),
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
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No photos yet',
            style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Add photos to showcase your work\nand attract more customers',
            style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isUploading ? null : _showUploadOptions,
            style: AppTheme.primaryButtonStyle,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Add Photos'),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: _galleryImages.length + (_galleryImages.length < 10 ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _galleryImages.length && _galleryImages.length < 10) {
          // Add photo button
          return _buildAddPhotoButton();
        }
        
        return _buildGalleryItem(_galleryImages[index], index);
      },
    );
  }

  Widget _buildAddPhotoButton() {
    return Card(
      color: AppTheme.surfaceDark,
      child: InkWell(
        onTap: _isUploading ? null : _showUploadOptions,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.accent.withValues(alpha:0.5),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate,
                size: 48,
                color: AppTheme.accent,
              ),
              const SizedBox(height: 8),
              Text(
                'Add Photo',
                style: AppTheme.bodyText.copyWith(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryItem(String imageUrl, int index) {
    return Card(
      color: AppTheme.surfaceDark,
      child: Stack(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: AppTheme.accent,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppTheme.backgroundDark,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: AppTheme.error, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load',
                          style: AppTheme.caption.copyWith(color: AppTheme.error),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Overlay buttons
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha:0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: PopupMenuButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                color: AppTheme.surfaceDark,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: Row(
                      children: [
                        Icon(Icons.visibility, color: AppTheme.textPrimary),
                        const SizedBox(width: 8),
                        Text('View', style: TextStyle(color: AppTheme.textPrimary)),
                      ],
                    ),
                    onTap: () => _viewImage(imageUrl),
                  ),
                  PopupMenuItem(
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: AppTheme.error),
                        const SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: AppTheme.error)),
                      ],
                    ),
                    onTap: () => _deleteImage(imageUrl, index),
                  ),
                ],
              ),
            ),
          ),

          // Image number badge
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha:0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${index + 1}',
                style: AppTheme.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Photos',
              style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppTheme.accent),
              title: Text(
                'Take Photo',
                style: AppTheme.bodyText.copyWith(color: AppTheme.textPrimary),
              ),
              subtitle: Text(
                'Use camera to take a new photo',
                style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
              ),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: AppTheme.accent),
              title: Text(
                'Choose from Gallery',
                style: AppTheme.bodyText.copyWith(color: AppTheme.textPrimary),
              ),
              subtitle: Text(
                'Select multiple photos from gallery',
                style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
              ),
              onTap: () {
                Navigator.pop(context);
                _selectFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    try {
      setState(() => _isUploading = true);

      final authService = Provider.of<shared.AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Find provider ID
      final providerId = await _getProviderId();
      if (providerId == null) {
        throw Exception('Provider not found');
      }

      final downloadUrl = await FileUploadService.uploadImageFromCamera(
        'gallery_photo_${DateTime.now().millisecondsSinceEpoch}',
        'gallery',
      );

      if (downloadUrl != null) {
        setState(() {
          _galleryImages.add(downloadUrl);
        });

        await _saveGalleryImages();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Photo added successfully'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add photo: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _selectFromGallery() async {
    try {
      setState(() => _isUploading = true);

      final authService = Provider.of<shared.AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Find provider ID
      final providerId = await _getProviderId();
      if (providerId == null) {
        throw Exception('Provider not found');
      }

      final remainingSlots = 10 - _galleryImages.length;
      final downloadUrls = await FileUploadService.uploadGalleryImages(
        providerId,
        maxImages: remainingSlots,
      );

      if (downloadUrls.isNotEmpty) {
        setState(() {
          _galleryImages.addAll(downloadUrls);
        });

        await _saveGalleryImages();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${downloadUrls.length} photo(s) added successfully'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add photos: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _deleteImage(String imageUrl, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(
          'Delete Photo',
          style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete this photo?',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete from Firebase Storage
      await FileUploadService.deleteFile(imageUrl);

      // Remove from local list
      setState(() {
        _galleryImages.removeAt(index);
      });

      // Update Firestore
      await _saveGalleryImages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Photo deleted successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete photo: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _viewImage(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ImageViewerScreen(imageUrl: imageUrl),
      ),
    );
  }

  Future<String?> _getProviderId() async {
    try {
      final authService = Provider.of<shared.AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) return null;

      final providerQuery = await FirebaseFirestore.instance
          .collection('providers')
          .where('ownerUid', isEqualTo: currentUser.uid)
          .get();

      if (providerQuery.docs.isNotEmpty) {
        return providerQuery.docs.first.id;
      }

      return null;
    } catch (e) {
      print('Error getting provider ID: $e');
      return null;
    }
  }

  Future<void> _saveGalleryImages() async {
    try {
      final providerId = await _getProviderId();
      if (providerId != null) {
        await FirebaseFirestore.instance
            .collection('providers')
            .doc(providerId)
            .update({'galleryImages': _galleryImages});
      }
    } catch (e) {
      print('Error saving gallery images: $e');
    }
  }
}

class _ImageViewerScreen extends StatelessWidget {
  final String imageUrl;

  const _ImageViewerScreen({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: AppTheme.accent,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: AppTheme.error, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load image',
                      style: AppTheme.bodyText.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

