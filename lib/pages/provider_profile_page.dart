import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:all_server/models/provider.dart';
import 'package:all_server/services/provider_service.dart';

class ProviderProfilePage extends StatefulWidget {
  final Provider provider;

  const ProviderProfilePage({super.key, required this.provider});

  @override
  State<ProviderProfilePage> createState() => _ProviderProfilePageState();
}

class _ProviderProfilePageState extends State<ProviderProfilePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ProviderService _providerService = ProviderService();
  
  late TextEditingController _businessNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _phoneController;
  late TextEditingController _descriptionController;
  late TextEditingController _addressController;
  late TextEditingController _serviceRadiusController;
  
  String? _selectedCategory;
  bool _isLoading = false;
  
  final List<String> _categories = [
    'Plumbing',
    'Electrical',
    'Cleaning',
    'Auto Repair',
    'Landscaping',
    'HVAC',
    'Carpentry',
    'Painting',
    'Security',
    'Catering',
    'Other',
  ];

  // Working hours
  Map<String, String> _workingHours = {
    'monday': '09:00 - 17:00',
    'tuesday': '09:00 - 17:00',
    'wednesday': '09:00 - 17:00',
    'thursday': '09:00 - 17:00',
    'friday': '09:00 - 17:00',
    'saturday': '09:00 - 15:00',
    'sunday': 'Closed',
  };

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _businessNameController = TextEditingController(text: widget.provider.businessName);
    _ownerNameController = TextEditingController(text: widget.provider.ownerName ?? '');
    _phoneController = TextEditingController(text: widget.provider.phone ?? '');
    _descriptionController = TextEditingController(text: widget.provider.description);
    _addressController = TextEditingController(text: widget.provider.address ?? '');
    _serviceRadiusController = TextEditingController(
      text: widget.provider.serviceRadius?.toString() ?? '50',
    );
    
    _selectedCategory = widget.provider.category;
    _workingHours = widget.provider.workingHours ?? _workingHours;
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _serviceRadiusController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _providerService.updateProvider(
        providerId: widget.provider.id,
        businessName: _businessNameController.text.trim(),
        ownerName: _ownerNameController.text.trim().isNotEmpty 
            ? _ownerNameController.text.trim() 
            : null,
        category: _selectedCategory!,
        description: _descriptionController.text.trim(),
        phone: _phoneController.text.trim().isNotEmpty 
            ? _phoneController.text.trim() 
            : null,
        address: _addressController.text.trim().isNotEmpty 
            ? _addressController.text.trim() 
            : null,
        serviceRadius: double.tryParse(_serviceRadiusController.text.trim()),
        workingHours: _workingHours,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateImage(bool isLogo) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );

    if (image != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final success = await _providerService.updateProvider(
          providerId: widget.provider.id,
          profileImage: isLogo ? null : File(image.path),
          businessLogo: isLogo ? File(image.path) : null,
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${isLogo ? 'Logo' : 'Profile image'} updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Failed to update image');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Business Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _updateProfile,
              icon: _isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save Changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column - Basic Info
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Images Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Profile Images',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                // Profile Image
                                Column(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _updateImage(false),
                                      child: Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(50),
                                          border: Border.all(
                                            color: Colors.blue.shade200,
                                            width: 2,
                                          ),
                                        ),
                                        child: widget.provider.profileImageUrl != null
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(50),
                                                child: Image.network(
                                                  widget.provider.profileImageUrl!,
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : Icon(
                                                Icons.person,
                                                size: 40,
                                                color: Colors.grey[400],
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text('Profile Photo'),
                                  ],
                                ),
                                const SizedBox(width: 40),
                                // Business Logo
                                Column(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _updateImage(true),
                                      child: Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.blue.shade200,
                                            width: 2,
                                          ),
                                        ),
                                        child: widget.provider.businessLogoUrl != null
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(
                                                  widget.provider.businessLogoUrl!,
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : Icon(
                                                Icons.business,
                                                size: 40,
                                                color: Colors.grey[400],
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text('Business Logo'),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Basic Information
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Basic Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _businessNameController,
                              decoration: const InputDecoration(
                                labelText: 'Business Name *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter business name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'Category *',
                                border: OutlineInputBorder(),
                              ),
                              items: _categories.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Please select a category';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _ownerNameController,
                              decoration: const InputDecoration(
                                labelText: 'Owner Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Business Description *',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter business description';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // Right Column - Location & Hours
              Expanded(
                child: Column(
                  children: [
                    // Location Information
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Location & Service Area',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: 'Business Address',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _serviceRadiusController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Service Radius (km)',
                                border: OutlineInputBorder(),
                                suffixText: 'km',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Working Hours
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Working Hours',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ..._workingHours.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        entry.key.substring(0, 1).toUpperCase() +
                                            entry.key.substring(1),
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: entry.value,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (value) {
                                          _workingHours[entry.key] = value;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
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
      ),
    );
  }
}



