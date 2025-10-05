import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/provider.dart' as app_provider;
import '../../models/service_category.dart';
import '../../services/cloudinary_storage_service.dart';
import '../../theme/app_theme.dart';

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
  File? _selectedImage;
  List<String> _selectedAvailability = [];
  bool _isLoading = false;
  bool _showPreview = false;

  final List<String> _daysOfWeek = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.service != null) {
      _titleController.text = widget.service!.title;
      _descriptionController.text = widget.service!.description ?? '';
      _priceFromController.text = widget.service!.priceFrom.toString();
      _priceToController.text = widget.service!.priceTo.toString();
      _durationController.text = widget.service!.durationMin.toString();
      _selectedCategory = widget.service!.category;
      _selectedAvailability = List.from(widget.service!.availability);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceFromController.dispose();
    _priceToController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedImage = File(result.files.first.path!);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      final cloudinaryService = CloudinaryStorageService();
      return await cloudinaryService.uploadServiceImage(_selectedImage!);
    } catch (e) {
      _showErrorSnackBar('Error uploading image: $e');
      return null;
    }
  }

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
      // Upload image if selected
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage();
        if (imageUrl == null) {
          setState(() => _isLoading = false);
          return;
        }
      } else if (widget.service?.imageUrl != null) {
        imageUrl = widget.service!.imageUrl;
      }

      final now = DateTime.now();
      final service = app_provider.Service(
        serviceId: widget.service?.serviceId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        category: _selectedCategory,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        priceFrom: double.parse(_priceFromController.text),
        priceTo: double.parse(_priceToController.text),
        durationMin: int.parse(_durationController.text),
        imageUrl: imageUrl,
        availability: _selectedAvailability,
        isActive: true,
        createdAt: widget.service?.createdAt ?? now,
        updatedAt: now,
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
        setState(() => _isLoading = false);
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
                Icon(
                  Icons.attach_money,
                  size: 16,
                  color: AppTheme.success,
                ),
                const SizedBox(width: 4),
                Text(
                  'K${_priceFromController.text} - K${_priceToController.text}',
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
                  '${_durationController.text} min',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                ),
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
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
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
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Price Range (Side by Side)
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
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                final price = double.tryParse(value);
                                if (price == null || price <= 0) {
                                  return 'Must be > 0';
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
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                final price = double.tryParse(value);
                                if (price == null || price <= 0) {
                                  return 'Must be > 0';
                                }
                                final fromPrice = double.tryParse(_priceFromController.text);
                                if (fromPrice != null && price < fromPrice) {
                                  return 'Must be ≥ from price';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Duration
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
                          labelText: 'Duration (minutes)',
                          hintText: 'e.g., 60',
                          suffixText: 'min',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Duration is required';
                          }
                          final duration = int.tryParse(value);
                          if (duration == null || duration <= 0) {
                            return 'Must be > 0 minutes';
                          }
                          if (duration > 1440) {
                            return 'Cannot exceed 24 hours';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

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

                      // Image Upload
                      Text(
                        'Service Image (Optional)',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickImage,
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.3),
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _selectedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _selectedImage!,
                                    width: double.infinity,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate,
                                      size: 40,
                                      color: AppTheme.primary,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap to add image',
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
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
      ),
    );
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
