import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/provider.dart' as app_provider;
import '../../models/service_category.dart';
import '../../services/cloudinary_storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/multi_image_picker.dart';
import '../../utils/app_logger.dart';

class EnhancedServiceDialog extends StatefulWidget {
  final app_provider.Service? service;
  final Function(app_provider.Service) onSave;

  const EnhancedServiceDialog({
    super.key,
    this.service,
    required this.onSave,
  });

  @override
  State<EnhancedServiceDialog> createState() => _EnhancedServiceDialogState();
}

class _EnhancedServiceDialogState extends State<EnhancedServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceFromController = TextEditingController();
  final _priceToController = TextEditingController();
  final _durationController = TextEditingController();

  String _selectedCategory = 'beauty';
  String _selectedServiceType = 'priced'; // 'priced', 'negotiable', 'free'
  String _selectedBookingType = 'bookable'; // NEW: 'bookable' or 'contact'
  String? _customCategory; // For "Other" category
  File? _selectedImage; // Deprecated - keeping for backward compatibility
  List<File> _selectedImages = []; // New: multiple images
  List<String> _selectedAvailability = [];
  bool _isLoading = false;
  bool _showPreview = false;
  Map<int, double> _uploadProgress = {}; // Track upload progress for each image

  // NEW: Contact info controllers (only needed for contact type)
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _websiteController = TextEditingController();

  final List<String> _daysOfWeek = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  // Service type suggestions based on category
  final Map<String, String> _categoryTypeSuggestions = {
    'cleaning': 'priced',
    'grooming': 'priced',
    'transport': 'priced',
    'business': 'negotiable',
    'loans': 'negotiable',
    'consultancy': 'negotiable',
    'volunteering': 'free',
    'community_help': 'free',
  };

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.service != null) {
      _titleController.text = widget.service!.title;
      _descriptionController.text = widget.service!.description ?? '';
      _priceFromController.text = widget.service!.priceFrom?.toString() ?? '';
      _priceToController.text = widget.service!.priceTo?.toString() ?? '';
      _durationController.text = widget.service!.duration ?? '';
      _selectedCategory = widget.service!.category;
      _selectedServiceType = widget.service!.type;
      _selectedBookingType = widget.service!.serviceType; // NEW: Load booking type
      _selectedAvailability = List.from(widget.service!.availability);
      
      // NEW: Load contact info if available
      if (widget.service!.contactInfo != null) {
        _phoneController.text = widget.service!.contactInfo!['phone'] ?? '';
        _emailController.text = widget.service!.contactInfo!['email'] ?? '';
        _whatsappController.text = widget.service!.contactInfo!['whatsapp'] ?? '';
        _websiteController.text = widget.service!.contactInfo!['website'] ?? '';
      }
      
      // Note: We can't load existing images as File objects, they'll remain as URLs
      // The service will use imageUrls field for existing images
    } else {
      // Auto-suggest service type based on category
      _suggestServiceType();
    }
  }

  void _suggestServiceType() {
    final suggestedType = _categoryTypeSuggestions[_selectedCategory];
    if (suggestedType != null) {
      setState(() {
        _selectedServiceType = suggestedType;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceFromController.dispose();
    _priceToController.dispose();
    _durationController.dispose();
    // NEW: Dispose contact info controllers
    _phoneController.dispose();
    _emailController.dispose();
    _whatsappController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  // Removed deprecated _pickImage and _uploadImage methods
  // Now using MultiImagePicker widget for handling multiple images

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Upload multiple images if selected
      List<String> uploadedImageUrls = [];
      
      if (_selectedImages.isNotEmpty) {
        // Upload each image with progress tracking
        for (int i = 0; i < _selectedImages.length; i++) {
          setState(() {
            _uploadProgress[i] = 0.0; // Initialize progress
          });
          
          try {
            final cloudinaryService = CloudinaryStorageService();
            final imageUrl = await cloudinaryService.uploadServiceImage(_selectedImages[i]);
            
            uploadedImageUrls.add(imageUrl);
            setState(() {
              _uploadProgress[i] = 1.0; // Mark as complete
            });
          } catch (e) {
            _showErrorSnackBar('Error uploading image ${i + 1}: $e');
            setState(() {
              _uploadProgress.remove(i);
            });
          }
        }
      }
      
      // Keep existing image URLs if editing and no new images were uploaded
      if (widget.service != null && uploadedImageUrls.isEmpty && widget.service!.imageUrls.isNotEmpty) {
        uploadedImageUrls = List.from(widget.service!.imageUrls);
      }

      final now = DateTime.now();
      // Use custom category if "other" is selected, otherwise use selected category
      final categoryToSave = _selectedCategory == 'other' 
          ? (_customCategory?.trim().toLowerCase() ?? 'other')
          : _selectedCategory;
      
      // Handle pricing based on service type
      double? priceFrom, priceTo;
      String? duration;
      
      if (_selectedServiceType == 'priced') {
        priceFrom = double.parse(_priceFromController.text);
        priceTo = double.parse(_priceToController.text);
        duration = _durationController.text.trim().isEmpty ? null : _durationController.text.trim();
      }

      // NEW: Build contact info only if contact service
      Map<String, dynamic>? contactInfo;
      if (_selectedBookingType == 'contact') {
        contactInfo = {
          'phone': _phoneController.text.trim(),
          if (_emailController.text.trim().isNotEmpty) 
            'email': _emailController.text.trim(),
          if (_whatsappController.text.trim().isNotEmpty) 
            'whatsapp': _whatsappController.text.trim(),
          if (_websiteController.text.trim().isNotEmpty) 
            'website': _websiteController.text.trim(),
        };
        
        AppLogger.debug('Contact info prepared: $contactInfo');
      }

      final service = app_provider.Service(
        serviceId: widget.service?.serviceId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        category: categoryToSave,
        type: _selectedServiceType,
        serviceType: _selectedBookingType, // NEW: Service booking type
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        priceFrom: priceFrom,
        priceTo: priceTo,
        duration: duration,
        imageUrl: uploadedImageUrls.isNotEmpty ? uploadedImageUrls.first : null, // For backward compatibility
        imageUrls: uploadedImageUrls, // New field
        availability: _selectedAvailability,
        isActive: true,
        createdAt: widget.service?.createdAt ?? now,
        updatedAt: now,
        contactInfo: contactInfo, // NEW: Contact information
      );

      widget.onSave(service);
      
      if (mounted) {
        Navigator.of(context).pop();
        _showSuccessSnackBar('✅ Service ${widget.service != null ? 'updated' : 'added'} successfully!');
      }
    } catch (e) {
      _showErrorSnackBar('Error saving service: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadProgress.clear();
        });
      }
    }
  }

  void _toggleAvailability(String day) {
    setState(() {
      if (_selectedAvailability.contains(day)) {
        _selectedAvailability.remove(day);
      } else {
        _selectedAvailability.add(day);
      }
    });
  }

  Widget _buildPreviewCard() {
    final category = ServiceCategories.getCategoryById(_selectedCategory);
    
    return Card(
      color: AppTheme.surfaceDark,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview',
              style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_selectedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.image,
                      color: AppTheme.primary,
                      size: 30,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _titleController.text.isEmpty ? 'Service Title' : _titleController.text,
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category?.name ?? 'Category',
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_descriptionController.text.isNotEmpty) ...[
              Text(
                _descriptionController.text,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                if (_selectedServiceType == 'priced') ...[
                  Icon(
                    Icons.attach_money,
                    size: 16,
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _priceFromController.text.isNotEmpty && _priceToController.text.isNotEmpty
                        ? 'K${_priceFromController.text} - K${_priceToController.text}'
                        : 'Set pricing',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _durationController.text.isNotEmpty ? _durationController.text : 'Set duration',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                  ),
                ] else if (_selectedServiceType == 'negotiable') ...[
                  Icon(
                    Icons.handshake,
                    size: 16,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Price negotiable',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else if (_selectedServiceType == 'free') ...[
                  Icon(
                    Icons.volunteer_activism,
                    size: 16,
                    color: AppTheme.info,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Free service',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24), // Issue 5: Add padding to prevent overflow
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Issue 5: Calculate appropriate width based on screen size
          final dialogWidth = constraints.maxWidth > 600 ? 600.0 : constraints.maxWidth;
          final dialogHeight = constraints.maxHeight * 0.9; // Use 90% of available height
          
          return Container(
            width: dialogWidth,
            constraints: BoxConstraints(maxHeight: dialogHeight),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(16),
            ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.service != null ? Icons.edit : Icons.add_circle,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.service != null ? 'Edit Service' : 'Add New Service',
                    style: AppTheme.heading2.copyWith(color: AppTheme.textPrimary),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service Title
                      Text(
                        'Service Title',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: AppTheme.inputDecoration.copyWith(
                          labelText: 'e.g., Haircut, House Cleaning, Car Repair',
                          hintText: 'Enter service title',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Service title is required';
                          }
                          if (value.trim().length < 3) {
                            return 'Title must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Category Selection
                      Text(
                        'Service Category',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: AppTheme.inputDecoration.copyWith(
                          labelText: 'Select category',
                        ),
                        items: ServiceCategories.getCategories().map((category) {
                          return DropdownMenuItem(
                            value: category.id,
                            child: Row(
                              children: [
                                Icon(
                                  _getCategoryIcon(category.icon),
                                  size: 20,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(category.name),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                            if (value != 'other') {
                              _customCategory = null; // Clear custom category when switching away from "Other"
                            }
                            // Auto-suggest service type based on category
                            _suggestServiceType();
                          });
                        },
                      ),
                      
                      // Show custom category input when "Other" is selected
                      if (_selectedCategory == 'other') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: AppTheme.inputDecoration.copyWith(
                            labelText: 'Specify Category',
                            hintText: 'e.g., Photography, Tutoring, etc.',
                            prefixIcon: Icon(Icons.edit, color: AppTheme.primary),
                          ),
                          style: const TextStyle(color: AppTheme.textPrimary),
                          onChanged: (value) {
                            setState(() {
                              _customCategory = value;
                            });
                          },
                          validator: (value) {
                            if (_selectedCategory == 'other' && (value == null || value.trim().isEmpty)) {
                              return 'Please specify the category';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Service Type Selection
                      Text(
                        'Service Type',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedServiceType,
                        decoration: AppTheme.inputDecoration.copyWith(
                          labelText: 'Select service type',
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'priced',
                            child: Row(
                              children: [
                                Icon(Icons.attach_money, size: 20, color: AppTheme.success),
                                const SizedBox(width: 8),
                                const Text('Priced Service'),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Set fixed prices',
                                    style: AppTheme.caption.copyWith(color: AppTheme.success),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'negotiable',
                            child: Row(
                              children: [
                                Icon(Icons.handshake, size: 20, color: AppTheme.warning),
                                const SizedBox(width: 8),
                                const Text('Negotiable Service'),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warning.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Price on contact',
                                    style: AppTheme.caption.copyWith(color: AppTheme.warning),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'free',
                            child: Row(
                              children: [
                                Icon(Icons.volunteer_activism, size: 20, color: AppTheme.info),
                                const SizedBox(width: 8),
                                const Text('Free Service'),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.info.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'No charge',
                                    style: AppTheme.caption.copyWith(color: AppTheme.info),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedServiceType = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // NEW: Booking Type Selection
                      Text(
                        'Booking Type',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        color: AppTheme.cardDark,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              RadioListTile<String>(
                                title: Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 20, color: AppTheme.success),
                                    const SizedBox(width: 8),
                                    const Text('Bookable Service'),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.success.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Schedule appointments',
                                        style: AppTheme.caption.copyWith(color: AppTheme.success),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: const Text('Customers can book appointments with date/time'),
                                value: 'bookable',
                                groupValue: _selectedBookingType,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedBookingType = value!;
                                    AppLogger.debug('Booking type changed to: $_selectedBookingType');
                                  });
                                },
                                activeColor: AppTheme.primaryPurple,
                              ),
                              RadioListTile<String>(
                                title: Row(
                                  children: [
                                    Icon(Icons.contact_phone, size: 20, color: AppTheme.warning),
                                    const SizedBox(width: 8),
                                    const Text('Contact-Only Service'),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warning.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Direct contact',
                                        style: AppTheme.caption.copyWith(color: AppTheme.warning),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: const Text('Customers will see your contact information'),
                                value: 'contact',
                                groupValue: _selectedBookingType,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedBookingType = value!;
                                    AppLogger.debug('Booking type changed to: $_selectedBookingType');
                                  });
                                },
                                activeColor: AppTheme.primaryPurple,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // NEW: Conditional Contact Info Fields
                      if (_selectedBookingType == 'contact') ...[
                        Card(
                          color: AppTheme.cardDark,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Contact Information',
                                  style: AppTheme.bodyLarge.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Provide contact details for customers to reach you directly',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _phoneController,
                                  decoration: AppTheme.inputDecoration.copyWith(
                                    labelText: 'Phone Number *',
                                    hintText: '+260970123456',
                                    prefixIcon: Icon(Icons.phone, color: AppTheme.textSecondary),
                                  ),
                                  keyboardType: TextInputType.phone,
                                  validator: (value) {
                                    if (_selectedBookingType == 'contact' && (value == null || value.trim().isEmpty)) {
                                      return 'Phone number is required for contact services';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _emailController,
                                  decoration: AppTheme.inputDecoration.copyWith(
                                    labelText: 'Email Address',
                                    hintText: 'support@provider.com',
                                    prefixIcon: Icon(Icons.email, color: AppTheme.textSecondary),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _whatsappController,
                                  decoration: AppTheme.inputDecoration.copyWith(
                                    labelText: 'WhatsApp Number',
                                    hintText: '+260970123456',
                                    prefixIcon: Icon(Icons.chat, color: AppTheme.textSecondary),
                                  ),
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _websiteController,
                                  decoration: AppTheme.inputDecoration.copyWith(
                                    labelText: 'Website',
                                    hintText: 'https://yourwebsite.com',
                                    prefixIcon: Icon(Icons.language, color: AppTheme.textSecondary),
                                  ),
                                  keyboardType: TextInputType.url,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Price Range (Conditional - only for priced services)
                      if (_selectedServiceType == 'priced') ...[
                        Text(
                          'Price Range',
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceFromController,
                              decoration: AppTheme.inputDecoration.copyWith(
                                labelText: 'From (K)',
                                hintText: 'e.g., 50',
                                prefixText: 'K',
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              validator: (value) {
                                if (_selectedServiceType == 'priced') {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  final price = double.tryParse(value);
                                  if (price == null) {
                                    return 'Invalid number';
                                  }
                                  if (price < 0) {
                                    return 'Cannot be negative';
                                  }
                                  if (price == 0) {
                                    return 'Must be > 0';
                                  }
                                  // Check if "To" price is already set and is less than "From" price
                                  final toPrice = double.tryParse(_priceToController.text);
                                  if (toPrice != null && price > toPrice) {
                                    return 'Must be ≤ To price';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _priceToController,
                              decoration: AppTheme.inputDecoration.copyWith(
                                labelText: 'To (K)',
                                hintText: 'e.g., 100',
                                prefixText: 'K',
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              validator: (value) {
                                if (_selectedServiceType == 'priced') {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  final price = double.tryParse(value);
                                  if (price == null) {
                                    return 'Invalid number';
                                  }
                                  if (price < 0) {
                                    return 'Cannot be negative';
                                  }
                                  if (price == 0) {
                                    return 'Must be > 0';
                                  }
                                  // Check if "From" price is already set and is greater than "To" price
                                  final fromPrice = double.tryParse(_priceFromController.text);
                                  if (fromPrice != null && price < fromPrice) {
                                    return 'Must be ≥ From price';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                        const SizedBox(height: 20),

                        // Duration (Conditional - only for priced services)
                        Text(
                          'Duration',
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _durationController,
                          decoration: AppTheme.inputDecoration.copyWith(
                            labelText: 'Duration (e.g., 60 minutes, 2 hours)',
                            hintText: 'e.g., 60 minutes',
                          ),
                          validator: (value) {
                            if (_selectedServiceType == 'priced' && (value == null || value.trim().isEmpty)) {
                              return 'Duration is required for priced services';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Description
                      Text(
                        'Description (Optional)',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: AppTheme.inputDecoration.copyWith(
                          labelText: 'Service details',
                          hintText: 'e.g., Includes beard trim, shampoo, and styling',
                        ),
                        maxLines: 3,
                        maxLength: 200,
                      ),
                      const SizedBox(height: 20),

                      // Multi-Image Upload
                      MultiImagePicker(
                        initialImages: _selectedImages,
                        maxImages: 5,
                        onImagesChanged: (images) {
                          setState(() {
                            _selectedImages = images;
                          });
                        },
                        isUploading: _isLoading,
                        uploadProgress: _uploadProgress,
                      ),
                      const SizedBox(height: 20),

                      // Availability
                      Text(
                        'Availability (Optional)',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _daysOfWeek.map((day) {
                          final isSelected = _selectedAvailability.contains(day);
                          return FilterChip(
                            label: Text(
                              day.isNotEmpty 
                                ? day.substring(0, 1).toUpperCase() + (day.length > 1 ? day.substring(1) : '')
                                : day,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (_) => _toggleAvailability(day),
                            selectedColor: AppTheme.primary,
                            checkmarkColor: Colors.white,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Preview Toggle
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _showPreview = !_showPreview;
                              });
                            },
                            icon: Icon(
                              _showPreview ? Icons.visibility_off : Icons.visibility,
                              color: AppTheme.primary,
                            ),
                          ),
                          Text(
                            _showPreview ? 'Hide Preview' : 'Show Preview',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      // Preview Card
                      if (_showPreview) _buildPreviewCard(),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: BorderSide(color: AppTheme.textTertiary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveService,
                      style: AppTheme.primaryButtonStyle.copyWith(
                        padding: MaterialStateProperty.all(
                          const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.service != null ? Icons.save : Icons.add,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.service != null ? 'Update Service' : 'Save Service',
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
          ); // Close LayoutBuilder container
        }, // Close LayoutBuilder builder
      ), // Close LayoutBuilder
    ); // Close Dialog
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'face':
        return Icons.face;
      case 'home':
        return Icons.home;
      case 'directions_car':
        return Icons.directions_car;
      case 'computer':
        return Icons.computer;
      case 'school':
        return Icons.school;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'event':
        return Icons.event;
      case 'business':
        return Icons.business;
      case 'local_taxi':
        return Icons.local_taxi;
      case 'more_horiz':
        return Icons.more_horiz;
      default:
        return Icons.build;
    }
  }
}
