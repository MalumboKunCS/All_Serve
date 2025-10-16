import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

/// A reusable widget for picking and managing multiple images
/// 
/// Features:
/// - Pick up to [maxImages] images
/// - Display thumbnails in a horizontal scrollable list
/// - Remove images before saving
/// - Show upload progress for each image
/// - Dark mode compatible
class MultiImagePicker extends StatefulWidget {
  final List<File> initialImages;
  final int maxImages;
  final Function(List<File>) onImagesChanged;
  final Function(File, int)? onImageRemoved;
  final bool isUploading;
  final Map<int, double> uploadProgress; // Image index -> upload progress (0.0 to 1.0)

  const MultiImagePicker({
    super.key,
    this.initialImages = const [],
    this.maxImages = 5,
    required this.onImagesChanged,
    this.onImageRemoved,
    this.isUploading = false,
    this.uploadProgress = const {},
  });

  @override
  State<MultiImagePicker> createState() => _MultiImagePickerState();
}

class _MultiImagePickerState extends State<MultiImagePicker> {
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _selectedImages = List.from(widget.initialImages);
  }

  @override
  void didUpdateWidget(MultiImagePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImages != oldWidget.initialImages) {
      _selectedImages = List.from(widget.initialImages);
    }
  }

  Future<void> _pickImage() async {
    try {
      // Check if we've reached the maximum number of images
      if (_selectedImages.length >= widget.maxImages) {
        _showSnackBar(
          'You can only add up to ${widget.maxImages} images',
          AppTheme.error,
        );
        return;
      }

      // Show image source options
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppTheme.surfaceDark,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: AppTheme.primary),
                title: Text(
                  'Camera',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: AppTheme.primary),
                title: Text(
                  'Gallery',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      // Pick the image
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85, // Compress to 85% quality for better performance
        maxWidth: 1920, // Limit max width
        maxHeight: 1920, // Limit max height
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImages.add(File(pickedFile.path));
        });
        widget.onImagesChanged(_selectedImages);
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', AppTheme.error);
    }
  }

  void _removeImage(int index) {
    setState(() {
      final removedImage = _selectedImages.removeAt(index);
      if (widget.onImageRemoved != null) {
        widget.onImageRemoved!(removedImage, index);
      }
      widget.onImagesChanged(_selectedImages);
    });
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title and add button
        Row(
          children: [
            Text(
              'Service Images (${_selectedImages.length}/${widget.maxImages})',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (_selectedImages.length < widget.maxImages)
              TextButton.icon(
                onPressed: widget.isUploading ? null : _pickImage,
                icon: Icon(
                  Icons.add_photo_alternate,
                  size: 20,
                  color: AppTheme.primary,
                ),
                label: Text(
                  'Add Image',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Image thumbnails list
        if (_selectedImages.isEmpty)
          _buildEmptyState()
        else
          _buildImageList(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return GestureDetector(
      onTap: widget.isUploading ? null : _pickImage,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 40,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to add images',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
                    Text(
                      'Up to ${widget.maxImages} images',
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 12,
                      ),
                    ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageList() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length,
        itemBuilder: (context, index) {
          return _buildImageThumbnail(index);
        },
      ),
    );
  }

  Widget _buildImageThumbnail(int index) {
    final image = _selectedImages[index];
    final uploadProgress = widget.uploadProgress[index] ?? 0.0;
    final isUploading = widget.isUploading && uploadProgress > 0 && uploadProgress < 1.0;

    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Image thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              image,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          
          // Upload progress overlay
          if (isUploading)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(uploadProgress * 100).toInt()}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Remove button
          if (!isUploading)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removeImage(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

