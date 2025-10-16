import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../models/category.dart';
import '../../services/search_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/responsive_utils.dart';
import 'category_providers_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await SearchService.getCategories();
      if (mounted) {
        setState(() {
          _categories = List<Category>.from(categories);
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error loading categories: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load categories: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  /// Calculate optimal aspect ratio for category cards based on screen size
  double _getOptimalAspectRatio(BuildContext context) {
    final screenType = ResponsiveUtils.getScreenType(context);
    
    // Adjust aspect ratio to prevent overflow
    // Smaller aspect ratio = taller cards = more space for content
    switch (screenType) {
      case ScreenType.mobile:
        return 0.85; // Increased from 1.2 to give more height
      case ScreenType.tablet:
        return 0.9;
      case ScreenType.desktop:
        return 0.95;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Service Categories'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveGridView(
              crossAxisSpacing: ResponsiveUtils.getResponsiveGridSpacing(context),
              mainAxisSpacing: ResponsiveUtils.getResponsiveGridSpacing(context),
              childAspectRatio: _getOptimalAspectRatio(context),
              padding: ResponsiveUtils.getResponsivePadding(context),
              children: _categories.map((category) => _buildCategoryCard(category)).toList(),
            ),
    );
  }

  Widget _buildCategoryCard(Category category) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryPurple.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          try {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CategoryProvidersScreen(category: category),
              ),
            );
          } catch (e) {
            AppLogger.error('Error navigating to category providers: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Unable to open category'),
                backgroundColor: AppTheme.error,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: ResponsiveUtils.getResponsivePadding(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: ResponsiveUtils.getResponsiveIconSize(
                  context,
                  mobile: 60,
                  tablet: 70,
                  desktop: 80,
                ),
                height: ResponsiveUtils.getResponsiveIconSize(
                  context,
                  mobile: 60,
                  tablet: 70,
                  desktop: 80,
                ),
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.category,
                  color: Colors.white,
                  size: ResponsiveUtils.getResponsiveIconSize(
                    context,
                    mobile: 30,
                    tablet: 35,
                    desktop: 40,
                  ),
                ),
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: 12,
                tablet: 14,
                desktop: 16,
              )),
              Text(
                category.name,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    mobile: 14,
                    tablet: 16,
                    desktop: 18,
                  ),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: 4,
                tablet: 6,
                desktop: 8,
              )),
              Expanded(
                child: Text(
                  category.description,
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      mobile: 12,
                      tablet: 13,
                      desktop: 14,
                    ),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

