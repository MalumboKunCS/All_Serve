import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';

class ProfileImageWidget extends StatelessWidget {
  final String? imageUrl;
  final String? fallbackText;
  final double radius;
  final Color? backgroundColor;
  final IconData? fallbackIcon;

  const ProfileImageWidget({
    super.key,
    this.imageUrl,
    this.fallbackText,
    this.radius = 20,
    this.backgroundColor,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    // If no image URL, show fallback
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallback();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundImage: imageProvider,
        backgroundColor: backgroundColor ?? AppTheme.primaryPurple,
      ),
      placeholder: (context, url) => CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? AppTheme.primaryPurple,
        child: SizedBox(
          width: radius,
          height: radius,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        AppLogger.warning('Failed to load profile image: $url, Error: $error');
        return _buildFallback();
      },
      errorListener: (error) {
        AppLogger.error('Profile image load error: $error');
      },
    );
  }

  Widget _buildFallback() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppTheme.primaryPurple,
      child: fallbackIcon != null
          ? Icon(
              fallbackIcon!,
              size: radius * 0.6,
              color: Colors.white,
            )
          : fallbackText != null && fallbackText!.isNotEmpty
              ? Text(
                  fallbackText!.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: radius * 0.5,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Icon(
                  Icons.person,
                  size: radius * 0.6,
                  color: Colors.white,
                ),
    );
  }
}

class BusinessImageWidget extends StatelessWidget {
  final String? imageUrl;
  final String? businessName;
  final double radius;
  final Color? backgroundColor;

  const BusinessImageWidget({
    super.key,
    this.imageUrl,
    this.businessName,
    this.radius = 20,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // If no image URL, show fallback
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallback();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundImage: imageProvider,
        backgroundColor: backgroundColor ?? AppTheme.primaryPurple,
      ),
      placeholder: (context, url) => CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? AppTheme.primaryPurple,
        child: SizedBox(
          width: radius,
          height: radius,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        AppLogger.warning('Failed to load business image: $url, Error: $error');
        return _buildFallback();
      },
      errorListener: (error) {
        AppLogger.error('Business image load error: $error');
      },
    );
  }

  Widget _buildFallback() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppTheme.primaryPurple,
      child: businessName != null && businessName!.isNotEmpty
          ? Text(
              businessName!.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.5,
                fontWeight: FontWeight.bold,
              ),
            )
          : Icon(
              Icons.business,
              size: radius * 0.6,
              color: Colors.white,
            ),
    );
  }
}
