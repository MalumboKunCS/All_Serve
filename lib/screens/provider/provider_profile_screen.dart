import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_theme.dart';
import '../../models/provider.dart' as app_provider;
import '../../models/category.dart';
import '../../services/location_service.dart';
import '../../services/search_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/responsive_utils.dart';

class ProviderProfileScreen extends StatefulWidget {
  final app_provider.Provider? provider;

  const ProviderProfileScreen({
    super.key,
    this.provider,
  });

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _websiteController = TextEditingController();
  final _serviceAreaController = TextEditingController();
  
  String? _selectedCategoryId;
  List<Category> _categories = [];
  Position? _selectedLocation;
  bool _isLoading = false;
  bool _isLoadingLocation = false;
  final LocationService _locationService = LocationService();
  
  // Custom category support
  bool _isCustomCategory = false;
  final _customCategoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProviderData();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _serviceAreaController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await SearchService.getCategories();
      if (mounted) {
        setState(() => _categories = List<Category>.from(categories));
      }
    } catch (e) {
      AppLogger.error('Error loading categories: $e');
    }
  }

  void _loadProviderData() {
    if (widget.provider != null) {
      _businessNameController.text = widget.provider!.businessName;
      _descriptionController.text = widget.provider!.description;
      _websiteController.text = widget.provider!.websiteUrl ?? '';
      _serviceAreaController.text = widget.provider!.serviceAreaKm.toString();
      _selectedCategoryId = widget.provider!.categoryId;
      _selectedLocation = Position(
        latitude: widget.provider!.lat,
        longitude: widget.provider!.lng,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    
    try {
      final hasPermission = await _locationService.checkAndRequestPermissions();
      if (!hasPermission) {
        throw Exception('Location permission denied');
      }

      final position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() => _selectedLocation = position);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location updated successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate category selection
    if (!_isCustomCategory && _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a category or enter a custom category'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    
    if (_isCustomCategory && _customCategoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a custom category name'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please set your business location'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final geohash = _locationService.generateGeohash(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      );

      final keywords = _generateKeywords();

      final profileData = {
        'businessName': _businessNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'categoryId': _isCustomCategory ? 'pending' : _selectedCategoryId!,
        'customCategoryName': _isCustomCategory ? _customCategoryController.text.trim() : null,
        'isCustomCategory': _isCustomCategory,
        'websiteUrl': _websiteController.text.trim().isNotEmpty 
          ? _websiteController.text.trim() 
          : null,
        'lat': _selectedLocation!.latitude,
        'lng': _selectedLocation!.longitude,
        'geohash': geohash,
        'serviceAreaKm': double.tryParse(_serviceAreaController.text) ?? 10.0,
        'keywords': keywords,
      };

      if (widget.provider != null) {
        // Update existing provider
        await FirebaseFirestore.instance
            .collection('providers')
            .doc(widget.provider!.providerId)
            .update(profileData);
      } else {
        // Create new provider - this would be done during registration
        // For now, we'll just show an error
        throw Exception('Cannot create provider from profile screen');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<String> _generateKeywords() {
    final keywords = <String>{};
    
    // Add business name words
    keywords.addAll(_extractWords(_businessNameController.text));
    
    // Add description words
    keywords.addAll(_extractWords(_descriptionController.text));
    
    // Add category name
    final category = _categories.firstWhere(
      (cat) => cat.categoryId == _selectedCategoryId,
      orElse: () => Category(
        categoryId: '', 
        name: '', 
        description: '', 
        createdAt: DateTime.now(),
      ),
    );
    keywords.addAll(_extractWords(category.name));
    
    return keywords.toList();
  }

  List<String> _extractWords(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: Text(
              'Save',
              style: TextStyle(
                color: _isLoading ? AppTheme.textSecondary : AppTheme.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: ResponsiveUtils.getResponsivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Business Information Section
              _buildSectionHeader('Business Information'),
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: AppTheme.spacingMd,
                tablet: AppTheme.spacingLg,
                desktop: AppTheme.spacingXl,
              )),
              
              TextFormField(
                controller: _businessNameController,
                decoration: AppTheme.inputDecoration.copyWith(
                  labelText: 'Business Name',
                  prefixIcon: const Icon(Icons.business),
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your business name';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: AppTheme.spacingMd,
                tablet: AppTheme.spacingLg,
                desktop: AppTheme.spacingXl,
              )),
              
              TextFormField(
                controller: _descriptionController,
                decoration: AppTheme.inputDecoration.copyWith(
                  labelText: 'Business Description',
                  prefixIcon: const Icon(Icons.description),
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a business description';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: AppTheme.spacingMd,
                tablet: AppTheme.spacingLg,
                desktop: AppTheme.spacingXl,
              )),
              
              // Category Selection
              _buildCategorySelection(),
              
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: AppTheme.spacingMd,
                tablet: AppTheme.spacingLg,
                desktop: AppTheme.spacingXl,
              )),
              
              TextFormField(
                controller: _websiteController,
                decoration: AppTheme.inputDecoration.copyWith(
                  labelText: 'Website URL (Optional)',
                  prefixIcon: const Icon(Icons.language),
                  hintText: 'https://your-website.com',
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
                keyboardType: TextInputType.url,
              ),
              
              const SizedBox(height: 32),
              
              // Location Section
              _buildSectionHeader('Business Location'),
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: AppTheme.spacingMd,
                tablet: AppTheme.spacingLg,
                desktop: AppTheme.spacingXl,
              )),
              
              Card(
                color: AppTheme.surfaceDark,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: AppTheme.accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedLocation != null
                                ? 'Location set: ${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}'
                                : 'No location set',
                              style: AppTheme.bodyText.copyWith(
                                color: _selectedLocation != null 
                                  ? AppTheme.textPrimary 
                                  : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                        style: AppTheme.secondaryButtonStyle,
                        icon: _isLoadingLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                        label: Text(_isLoadingLocation ? 'Getting Location...' : 'Use Current Location'),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: AppTheme.spacingMd,
                tablet: AppTheme.spacingLg,
                desktop: AppTheme.spacingXl,
              )),
              
              TextFormField(
                controller: _serviceAreaController,
                decoration: AppTheme.inputDecoration.copyWith(
                  labelText: 'Service Area (km)',
                  prefixIcon: Icon(Icons.location_on),
                  suffixText: 'km',
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter service area';
                  }
                  final area = double.tryParse(value);
                  if (area == null || area <= 0) {
                    return 'Please enter a valid service area';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 32),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: AppTheme.primaryButtonStyle,
                  child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Saving...'),
                        ],
                      )
                    : const Text('Save Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTheme.heading3.copyWith(
        color: AppTheme.textPrimary,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Category',
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        // Category Type Selection
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('Existing Category'),
                value: false,
                groupValue: _isCustomCategory,
                onChanged: (value) {
                  setState(() {
                    _isCustomCategory = value!;
                    if (!_isCustomCategory) {
                      _customCategoryController.clear();
                    }
                  });
                },
                activeColor: AppTheme.primary,
              ),
            ),
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('Custom Category'),
                value: true,
                groupValue: _isCustomCategory,
                onChanged: (value) {
                  setState(() {
                    _isCustomCategory = value!;
                    if (_isCustomCategory) {
                      _selectedCategoryId = null;
                    }
                  });
                },
                activeColor: AppTheme.primary,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Category Input
        if (!_isCustomCategory) ...[
          DropdownButtonFormField<String>(
            value: _selectedCategoryId,
            decoration: AppTheme.inputDecoration.copyWith(
              labelText: 'Select Category',
              prefixIcon: const Icon(Icons.category),
            ),
            style: const TextStyle(color: AppTheme.textPrimary),
            dropdownColor: AppTheme.surfaceDark,
            items: _categories.map((category) {
              return DropdownMenuItem(
                value: category.categoryId,
                child: Text(
                  category.name,
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedCategoryId = value);
            },
          ),
        ] else ...[
          TextFormField(
            controller: _customCategoryController,
            decoration: AppTheme.inputDecoration.copyWith(
              labelText: 'Custom Category Name',
              prefixIcon: const Icon(Icons.add_circle_outline),
              hintText: 'e.g., Wedding Photography, Pet Grooming',
            ),
            style: const TextStyle(color: AppTheme.textPrimary),
            validator: (value) {
              if (_isCustomCategory && (value == null || value.trim().isEmpty)) {
                return 'Please enter a custom category name';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.info, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Custom categories require admin approval before becoming active.',
                    style: AppTheme.caption.copyWith(color: AppTheme.info),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
