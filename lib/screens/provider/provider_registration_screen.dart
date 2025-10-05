import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import 'package:shared/shared.dart' as shared;
import '../../models/category.dart';
import '../../services/location_service.dart';
import '../../services/search_service.dart';
import '../../services/cloudinary_storage_service.dart';
import '../../services/admin_notification_service.dart';
import '../../services/provider_registration_service.dart';
import '../../services/category_setup_service.dart';
import 'provider_dashboard_screen.dart';
import '../auth/login_screen.dart';

class ProviderRegistrationScreen extends StatefulWidget {
  const ProviderRegistrationScreen({super.key});

  @override
  State<ProviderRegistrationScreen> createState() => _ProviderRegistrationScreenState();
}

class _ProviderRegistrationScreenState extends State<ProviderRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  
  // Form controllers
  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _websiteController = TextEditingController();
  final _serviceAreaController = TextEditingController();
  
  // State variables
  int _currentPage = 0;
  String? _selectedCategoryId;
  List<Category> _categories = [];
  bool _isOtherCategory = false;
  final _customCategoryController = TextEditingController();
  Position? _selectedLocation;
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;
  
  // Document upload state
  Map<String, String> _uploadedDocuments = {};
  Map<String, double> _uploadProgress = {};
  
  // Image upload state
  File? _profileImage;
  File? _businessLogo;
  String? _profileImageUrl;
  String? _businessLogoUrl;
  
  // Required documents
  final Map<String, String> _requiredDocuments = {
    'nrcUrl': 'National Registration Card',
    'businessLicenseUrl': 'Business License',
    'certificatesUrl': 'Professional Certificates',
  };

  final LocationService _locationService = LocationService();
  final CloudinaryStorageService _cloudinaryService = CloudinaryStorageService();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _markRegistrationStarted();
  }

  Future<void> _markRegistrationStarted() async {
    try {
      final authService = Provider.of<shared.AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      if (currentUser != null) {
        await ProviderRegistrationService.markRegistrationStarted(currentUser.uid);
      }
    } catch (e) {
      print('Error marking registration as started: $e');
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _serviceAreaController.dispose();
    _customCategoryController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      print('Loading categories...');
      
      // First, ensure default categories exist in database
      await CategorySetupService.initializeDefaultCategories();
      
      // Then load categories from database
      final categories = await SearchService.getCategories();
      print('Loaded ${categories.length} categories from SearchService');
      
      if (categories.isEmpty) {
        print('No categories found, using default categories');
        _categories = _getDefaultCategories();
      } else {
        _categories = List<Category>.from(categories);
      }
      
      if (mounted) {
        setState(() {});
        print('Categories loaded successfully: ${_categories.length} items');
      }
    } catch (e) {
      print('Error loading categories: $e');
      // Use default categories as fallback
      _categories = _getDefaultCategories();
      if (mounted) {
        setState(() {});
      }
    }
  }

  List<Category> _getDefaultCategories() {
    return [
      Category(
        categoryId: 'plumbing',
        name: 'Plumbing',
        description: 'Plumbing services and repairs',
        isFeatured: true,
        createdAt: DateTime.now(),
      ),
      Category(
        categoryId: 'electrical',
        name: 'Electrical',
        description: 'Electrical services and repairs',
        isFeatured: true,
        createdAt: DateTime.now(),
      ),
      Category(
        categoryId: 'carpentry',
        name: 'Carpentry',
        description: 'Carpentry and woodworking services',
        isFeatured: false,
        createdAt: DateTime.now(),
      ),
      Category(
        categoryId: 'cleaning',
        name: 'Cleaning Services',
        description: 'House and office cleaning services',
        isFeatured: true,
        createdAt: DateTime.now(),
      ),
      Category(
        categoryId: 'painting',
        name: 'Painting',
        description: 'Interior and exterior painting services',
        isFeatured: false,
        createdAt: DateTime.now(),
      ),
      Category(
        categoryId: 'hvac',
        name: 'HVAC',
        description: 'Heating, ventilation, and air conditioning',
        isFeatured: false,
        createdAt: DateTime.now(),
      ),
      Category(
        categoryId: 'gardening',
        name: 'Gardening',
        description: 'Landscaping and garden maintenance',
        isFeatured: false,
        createdAt: DateTime.now(),
      ),
      Category(
        categoryId: 'auto_repair',
        name: 'Auto Repair',
        description: 'Automotive repair and maintenance',
        isFeatured: false,
        createdAt: DateTime.now(),
      ),
    ];
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    
    try {
      final position = await _locationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _selectedLocation = position;
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _pickImage(String type) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        if (type == 'profile') {
          _profileImage = File(image.path);
        } else {
          _businessLogo = File(image.path);
        }
      });
    }
  }

  Future<void> _uploadDocument(String docKey, String docName) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;

    setState(() {
      _uploadProgress[docKey] = 0.0;
    });

    try {
      final file = File(image.path);
      final downloadUrl = await _cloudinaryService.uploadDocument(file);

      if (mounted) {
        setState(() {
          _uploadedDocuments[docKey] = downloadUrl;
          _uploadProgress.remove(docKey);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$docName uploaded successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadProgress.remove(docKey));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading $docName: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  bool _canProceedToNextPage() {
    switch (_currentPage) {
      case 0: // Basic Info
        return _businessNameController.text.isNotEmpty &&
               _descriptionController.text.isNotEmpty &&
               _selectedCategoryId != null &&
               (!_isOtherCategory || _customCategoryController.text.trim().isNotEmpty);
      case 1: // Location
        return _selectedLocation != null &&
               _serviceAreaController.text.isNotEmpty;
      case 2: // Documents
        return _hasAllDocuments();
      case 3: // Images
        return _profileImage != null || _businessLogo != null;
      default:
        return false;
    }
  }

  bool _hasAllDocuments() {
    return _requiredDocuments.keys.every((key) => 
      _uploadedDocuments[key]?.isNotEmpty ?? false
    );
  }

  void _nextPage() {
    print('Next page called. Current page: $_currentPage');
    print('Can proceed: ${_canProceedToNextPage()}');
    print('Is submitting: $_isSubmitting');
    
    if (_canProceedToNextPage()) {
      if (_currentPage < 3) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        print('Calling _submitRegistration()');
        _submitRegistration();
      }
    } else {
      print('Cannot proceed to next page. Validation failed.');
      _showValidationErrors();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitRegistration() async {
    // Validate form state
    if (_formKey.currentState == null) {
      _showErrorDialog('Form Error', 'Form is not properly initialized. Please try again.');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showErrorDialog('Validation Error', 'Please fill in all required fields correctly.');
      return;
    }

    if (!_canProceedToNextPage()) {
      _showErrorDialog('Incomplete Information', 'Please complete all required fields before submitting.');
      return;
    }

    // Validate required documents
    if (!_hasAllDocuments()) {
      _showErrorDialog('Missing Documents', 'Please upload all required documents (NRC, Business License, Certificates).');
      return;
    }

    // Validate location
    if (_selectedLocation == null) {
      _showErrorDialog('Location Required', 'Please select your business location.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authService = Provider.of<shared.AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated. Please log in again.');
      }

      // Upload images first with error handling
      if (_profileImage != null) {
        try {
          _profileImageUrl = await _cloudinaryService.uploadProfileImage(_profileImage!);
        } catch (e) {
          throw Exception('Failed to upload profile image: $e');
        }
      }
      
      if (_businessLogo != null) {
        try {
          _businessLogoUrl = await _cloudinaryService.uploadProviderLogo(_businessLogo!);
        } catch (e) {
          throw Exception('Failed to upload business logo: $e');
        }
      }

      // Generate geohash and keywords
      final geohash = _locationService.generateGeohash(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      );

      final keywords = _generateKeywords();

      // Update provider record with complete information
      final providerData = {
        'businessName': _businessNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'categoryId': _selectedCategoryId!,
        'customCategory': _isOtherCategory ? _customCategoryController.text.trim() : null,
        'websiteUrl': _websiteController.text.trim().isNotEmpty 
          ? _websiteController.text.trim() 
          : null,
        'lat': _selectedLocation!.latitude,
        'lng': _selectedLocation!.longitude,
        'geohash': geohash,
        'serviceAreaKm': double.tryParse(_serviceAreaController.text) ?? 10.0,
        'keywords': keywords,
        'profileImageUrl': _profileImageUrl,
        'businessLogoUrl': _businessLogoUrl,
        'nrcUrl': _uploadedDocuments['nrcUrl'],
        'businessLicenseUrl': _uploadedDocuments['businessLicenseUrl'],
        'certificatesUrl': _uploadedDocuments['certificatesUrl'],
        'verificationStatus': 'pending',
        'status': 'pending', // Changed to pending for admin review
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Create or update provider record with error handling
      try {
        await FirebaseFirestore.instance
            .collection('providers')
            .doc(currentUser.uid)
            .set(providerData, SetOptions(merge: true));
      } catch (e) {
        throw Exception('Failed to save provider information: $e');
      }

      // Create verification queue entry for admin
      try {
        await _createVerificationQueueEntry(currentUser.uid);
      } catch (e) {
        throw Exception('Failed to create verification queue entry: $e');
      }

      // Send notification to admin (non-critical, don't fail if this fails)
      try {
        await AdminNotificationService.notifyNewProviderRegistration(
          providerId: currentUser.uid,
          providerName: currentUser.name,
          businessName: _businessNameController.text.trim(),
        );
      } catch (e) {
        print('Warning: Failed to send admin notification: $e');
        // Don't throw here as notification failure shouldn't block registration
      }

      if (mounted) {
        setState(() => _isSubmitting = false);
        
        // Show success dialog with more details
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        
        // Show detailed error dialog
        _showErrorDialog(
          'Registration Failed',
          _getErrorMessage(e.toString()),
        );
      }
    }
  }

  Future<void> _createVerificationQueueEntry(String providerId) async {
    try {
      print('Creating verification queue entry for provider: $providerId');
      final docRef = await FirebaseFirestore.instance.collection('verification_queue').add({
        'providerId': providerId,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'reviewedBy': null,
        'notes': null,
      });
      print('Verification queue entry created with ID: ${docRef.id}');
    } catch (e) {
      print('Error creating verification queue entry: $e');
      throw Exception('Failed to create verification queue entry: $e');
    }
  }


  List<String> _generateKeywords() {
    final keywords = <String>[];
    
    // Add business name words
    final businessName = _businessNameController.text.trim();
    if (businessName.isNotEmpty) {
      keywords.addAll(businessName.toLowerCase().split(' '));
    }
    
    // Add category name
    if (_isOtherCategory && _customCategoryController.text.trim().isNotEmpty) {
      // Use custom category
      keywords.addAll(_customCategoryController.text.trim().toLowerCase().split(' '));
    } else {
      // Use predefined category
      final category = _categories.firstWhere(
        (cat) => cat.categoryId == _selectedCategoryId,
        orElse: () => Category(
          categoryId: '',
          name: '',
          description: '',
          createdAt: DateTime.now(),
        ),
      );
      if (category.name.isNotEmpty) {
        keywords.addAll(category.name.toLowerCase().split(' '));
      }
    }
    
    // Add description words
    final description = _descriptionController.text.trim();
    if (description.isNotEmpty) {
      keywords.addAll(description.toLowerCase().split(' '));
    }
    
    // Remove duplicates and empty strings
    return keywords.where((word) => word.length > 2).toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text('Provider Registration (${_currentPage + 1}/4)'),
        backgroundColor: AppTheme.surfaceDark,
        leading: _currentPage > 0 
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _previousPage,
            )
          : null,
        actions: [
          // Add explore app button
          IconButton(
            icon: const Icon(Icons.explore),
            onPressed: () => _showExploreOptions(),
            tooltip: 'Explore App',
          ),
          // Add logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            child: LinearProgressIndicator(
              value: (_currentPage + 1) / 4,
              backgroundColor: AppTheme.cardDark,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
            ),
          ),
          
          // Page content
          Expanded(
            child: Form(
              key: _formKey,
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                children: [
                  _buildBasicInfoPage(),
                  _buildLocationPage(),
                  _buildDocumentsPage(),
                  _buildImagesPage(),
                ],
              ),
            ),
          ),
          
          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousPage,
                      style: AppTheme.outlineButtonStyle,
                      child: const Text('Previous'),
                    ),
                  ),
                if (_currentPage > 0) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canProceedToNextPage() && !_isSubmitting
                        ? _nextPage
                        : null,
                    style: AppTheme.primaryButtonStyle.copyWith(
                      backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                        if (states.contains(MaterialState.disabled)) {
                          return AppTheme.textTertiary;
                        }
                        return _currentPage == 3 ? AppTheme.success : AppTheme.primaryPurple;
                      }),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_currentPage == 3) ...[
                                const Icon(Icons.send, size: 18),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Text(
                                  _currentPage == 3 ? 'Submit Registration' : 'Next',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Business Information',
              style: AppTheme.heading2.copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Tell us about your business and services',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            
            // Business Name
            TextFormField(
              controller: _businessNameController,
              decoration: AppTheme.inputDecoration.copyWith(
                labelText: 'Business Name *',
                prefixIcon: const Icon(Icons.business),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your business name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Category
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              decoration: AppTheme.inputDecoration.copyWith(
                labelText: 'Service Category *',
                prefixIcon: const Icon(Icons.category),
                suffixIcon: _categories.isEmpty 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              ),
              items: [
                ..._categories.map((category) {
                  return DropdownMenuItem(
                    value: category.categoryId,
                    child: Text(category.name),
                  );
                }).toList(),
                const DropdownMenuItem(
                  value: 'other',
                  child: Text('Other (Specify)'),
                ),
              ],
              onChanged: _categories.isEmpty ? null : (value) {
                setState(() {
                  _selectedCategoryId = value;
                  _isOtherCategory = (value == 'other');
                  if (!_isOtherCategory) {
                    _customCategoryController.clear();
                  }
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a category';
                }
                return null;
              },
            ),
            
            // Custom category input (shown when "Other" is selected)
            if (_isOtherCategory) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _customCategoryController,
                decoration: AppTheme.inputDecoration.copyWith(
                  labelText: 'Specify Your Category *',
                  prefixIcon: const Icon(Icons.edit),
                  hintText: 'e.g., Pet Grooming, Event Planning, etc.',
                ),
                validator: (value) {
                  if (_isOtherCategory && (value == null || value.trim().isEmpty)) {
                    return 'Please specify your category';
                  }
                  return null;
                },
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: AppTheme.inputDecoration.copyWith(
                labelText: 'Business Description *',
                prefixIcon: const Icon(Icons.description),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a business description';
                }
                if (value.length < 50) {
                  return 'Description must be at least 50 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Website (optional)
            TextFormField(
              controller: _websiteController,
              decoration: AppTheme.inputDecoration.copyWith(
                labelText: 'Website (Optional)',
                prefixIcon: const Icon(Icons.web),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
      );
  }

  Widget _buildLocationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business Location',
            style: AppTheme.heading2.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Set your business location and service area',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          
          // Location Card
          Card(
            color: AppTheme.cardDark,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: AppTheme.primaryPurple),
                      const SizedBox(width: 8),
                      Text(
                        'Current Location',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (_selectedLocation == null)
                    ElevatedButton.icon(
                      onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                      icon: _isLoadingLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                      label: Text(_isLoadingLocation ? 'Getting Location...' : 'Get Current Location'),
                      style: AppTheme.primaryButtonStyle,
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Latitude: ${_selectedLocation!.latitude.toStringAsFixed(6)}',
                          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                        ),
                        Text(
                          'Longitude: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _getCurrentLocation,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Update Location'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Service Area
          TextFormField(
            controller: _serviceAreaController,
            decoration: AppTheme.inputDecoration.copyWith(
              labelText: 'Service Area (km) *',
              prefixIcon: const Icon(Icons.radio_button_checked),
              suffixText: 'km',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your service area';
              }
              final radius = double.tryParse(value);
              if (radius == null || radius <= 0) {
                return 'Please enter a valid service area';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Required Documents',
            style: AppTheme.heading2.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload clear photos or scans of your documents',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          
          // Document Upload Cards
          ...(_requiredDocuments.entries.map((entry) {
            return _buildDocumentCard(entry.key, entry.value);
          }).toList()),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(String docKey, String docName) {
    final hasDocument = _uploadedDocuments[docKey]?.isNotEmpty ?? false;
    final isUploading = _uploadProgress.containsKey(docKey);
    final progress = _uploadProgress[docKey] ?? 0.0;

    return Card(
      color: AppTheme.cardDark,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasDocument ? Icons.check_circle : Icons.upload_file,
                  color: hasDocument ? AppTheme.success : AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    docName,
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (hasDocument)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Uploaded',
                      style: AppTheme.caption.copyWith(color: AppTheme.success),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (isUploading)
              Column(
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text(
                    'Uploading... ${(progress * 100).toInt()}%',
                    style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: () => _uploadDocument(docKey, docName),
                icon: const Icon(Icons.upload),
                label: Text(hasDocument ? 'Replace Document' : 'Upload Document'),
                style: AppTheme.outlineButtonStyle,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business Images',
            style: AppTheme.heading2.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload your business logo and profile image',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          
          // Profile Image
          Card(
            color: AppTheme.cardDark,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile Image',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_profileImage != null)
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(_profileImage!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.textTertiary),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 48, color: AppTheme.textTertiary),
                          const SizedBox(height: 8),
                          Text(
                            'No image selected',
                            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _pickImage('profile'),
                    icon: const Icon(Icons.photo_library),
                    label: Text(_profileImage != null ? 'Change Image' : 'Select Image'),
                    style: AppTheme.outlineButtonStyle,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Business Logo
          Card(
            color: AppTheme.cardDark,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Business Logo',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_businessLogo != null)
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(_businessLogo!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.textTertiary),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 48, color: AppTheme.textTertiary),
                          const SizedBox(height: 8),
                          Text(
                            'No logo selected',
                            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _pickImage('logo'),
                    icon: const Icon(Icons.photo_library),
                    label: Text(_businessLogo != null ? 'Change Logo' : 'Select Logo'),
                    style: AppTheme.outlineButtonStyle,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Show logout confirmation dialog
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout? Your registration progress will be saved.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _logout();
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  // Show explore options dialog
  void _showExploreOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Explore All-Serve'),
          content: const Text('You can explore the app features, but you\'ll need to complete registration to access all provider features.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue Registration'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _exploreApp();
              },
              child: const Text('Explore Now'),
            ),
          ],
        );
      },
    );
  }

  // Logout functionality
  Future<void> _logout() async {
    try {
      final authService = Provider.of<shared.AuthService>(context, listen: false);
      await authService.signOut();
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Explore app functionality - navigate to a limited dashboard
  void _exploreApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const ProviderDashboardScreen(),
      ),
    );
  }

  // Show error dialog
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Show success dialog
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.success, size: 28),
              const SizedBox(width: 12),
              const Text('Registration Submitted!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your registration has been submitted successfully!'),
              const SizedBox(height: 16),
              const Text('What happens next:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('• Admin will review your application'),
              const Text('• You\'ll receive a notification when reviewed'),
              const Text('• You can explore the app while waiting'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const ProviderDashboardScreen(),
                  ),
                );
              },
              child: const Text('Go to Dashboard'),
            ),
          ],
        );
      },
    );
  }

  // Show validation errors
  void _showValidationErrors() {
    final errors = <String>[];
    
    switch (_currentPage) {
      case 0:
        if (_businessNameController.text.trim().isEmpty) {
          errors.add('Business name is required');
        }
        if (_descriptionController.text.trim().isEmpty) {
          errors.add('Description is required');
        }
        if (_selectedCategoryId == null) {
          errors.add('Category selection is required');
        }
        if (_isOtherCategory && _customCategoryController.text.trim().isEmpty) {
          errors.add('Custom category specification is required');
        }
        break;
      case 1:
        if (_selectedLocation == null) {
          errors.add('Location selection is required');
        }
        if (_serviceAreaController.text.trim().isEmpty) {
          errors.add('Service area is required');
        }
        break;
      case 2:
        if (!_hasAllDocuments()) {
          errors.add('All required documents must be uploaded');
        }
        break;
      case 3:
        if (_profileImage == null && _businessLogo == null) {
          errors.add('At least one image (profile or business logo) is required');
        }
        break;
    }
    
    if (errors.isNotEmpty) {
      _showErrorDialog(
        'Missing Information',
        'Please complete the following:\n\n• ${errors.join('\n• ')}',
      );
    }
  }

  // Get user-friendly error message
  String _getErrorMessage(String error) {
    if (error.contains('permission-denied')) {
      return 'Permission denied. Please check your internet connection and try again.';
    } else if (error.contains('network')) {
      return 'Network error. Please check your internet connection and try again.';
    } else if (error.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (error.contains('authentication')) {
      return 'Authentication error. Please log in again.';
    } else if (error.contains('upload')) {
      return 'Failed to upload files. Please check your internet connection and try again.';
    } else {
      return 'An unexpected error occurred. Please try again or contact support if the problem persists.';
    }
  }
}
