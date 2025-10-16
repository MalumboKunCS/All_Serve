import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';

class ServiceImageWidget extends StatelessWidget {
  final List<String>? imageUrls;
  final String? imageUrl; // For backward compatibility
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ServiceImageWidget({
    super.key,
    this.imageUrls,
    this.imageUrl,
    this.width = 120,
    this.height = 120,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // Determine which image URL to use (prioritize imageUrls over imageUrl)
    String? urlToUse;
    if (imageUrls != null && imageUrls!.isNotEmpty) {
      urlToUse = imageUrls!.first;
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      urlToUse = imageUrl!;
    }

    // If no image URL, show fallback
    if (urlToUse == null || urlToUse.isEmpty) {
      return _buildFallback();
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: urlToUse,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: borderRadius ?? BorderRadius.circular(12),
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          AppLogger.warning('Failed to load service image: $url, Error: $error');
          return _buildFallback();
        },
        errorListener: (error) {
          AppLogger.error('Service image load error: $error');
        },
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image,
            size: width * 0.3,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 8),
          Text(
            'No Image',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceImageGallery extends StatelessWidget {
  final List<String>? imageUrls;
  final String? imageUrl; // For backward compatibility
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ServiceImageGallery({
    super.key,
    this.imageUrls,
    this.imageUrl,
    this.width = 120,
    this.height = 120,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // Combine imageUrls and imageUrl for backward compatibility
    List<String> allImages = [];
    if (imageUrls != null && imageUrls!.isNotEmpty) {
      allImages.addAll(imageUrls!);
    }
    if (imageUrl != null && imageUrl!.isNotEmpty && !allImages.contains(imageUrl)) {
      allImages.add(imageUrl!);
    }

    if (allImages.isEmpty) {
      return ServiceImageWidget(
        width: width,
        height: height,
        borderRadius: borderRadius,
      );
    }

    if (allImages.length == 1) {
      return ServiceImageWidget(
        imageUrls: allImages,
        width: width,
        height: height,
        borderRadius: borderRadius,
      );
    }

    // Multiple images - show carousel
    return Container(
      width: width,
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: allImages.length,
            itemBuilder: (context, index) {
              return ServiceImageWidget(
                imageUrls: [allImages[index]],
                width: width,
                height: height,
                borderRadius: borderRadius,
              );
            },
          ),
          // Image count indicator
          if (allImages.length > 1)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '1/${allImages.length}',
                  style: AppTheme.bodyMedium.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ProviderGalleryWidget extends StatelessWidget {
  final List<String> images;
  final List<String> galleryImages;
  final double width;
  final double height;

  const ProviderGalleryWidget({
    super.key,
    required this.images,
    required this.galleryImages,
    this.width = double.infinity,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    // Combine both image lists
    List<String> allImages = [];
    if (images.isNotEmpty) allImages.addAll(images);
    if (galleryImages.isNotEmpty) allImages.addAll(galleryImages);

    if (allImages.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library,
                size: 48,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                'No Images Available',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      child: PageView.builder(
        itemCount: allImages.length,
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: allImages[index],
              width: width,
              height: height,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
                  ),
                ),
              ),
              errorWidget: (context, url, error) {
                AppLogger.warning('Failed to load gallery image: $url, Error: $error');
                return Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 48,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
