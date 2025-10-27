import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart' as shared;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../services/profile_service.dart';
import '../../utils/app_logger.dart';

class EditProfileScreen extends StatefulWidget {
  final shared.User user;

  const EditProfileScreen({
    super.key,
    required this.user,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _profileImage;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController.text = widget.user.name;
    _emailController.text = widget.user.email;
    _phoneController.text = widget.user.phone ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveProfile,
            tooltip: 'Save Changes',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              _buildProfileHeader(),
              
              const SizedBox(height: 24),
              
              // Profile Information Form
              Text(
                'Personal Information',
                style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              
              _buildInfoCard([
                _buildNameField(),
                _buildEmailField(),
                _buildPhoneField(),
              ]),
              
              const SizedBox(height: 24),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                  style: AppTheme.primaryButtonStyle,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel'),
                  style: AppTheme.outlineButtonStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardLight),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              // Profile Avatar
              CircleAvatar(
                radius: 50,
                backgroundColor: AppTheme.primaryPurple,
                backgroundImage: _profileImage != null
                    ? FileImage(_profileImage!)
                    : widget.user.profileImageUrl != null
                        ? NetworkImage(widget.user.profileImageUrl!)
                        : null,
                child: _profileImage == null && widget.user.profileImageUrl == null
                    ? Text(
                        _getInitials(_nameController.text),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              // Edit Icon
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.surfaceDark, width: 2),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                    onPressed: _pickImage,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Change Profile Photo',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.primaryPurple,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardLight),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildNameField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: _nameController,
        decoration: AppTheme.inputDecoration.copyWith(
          labelText: 'Full Name',
          prefixIcon: const Icon(Icons.person),
        ),
        style: AppTheme.bodyText.copyWith(color: AppTheme.textPrimary),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your full name';
          }
          if (value.trim().split(' ').length < 2) {
            return 'Please enter both first and last name';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildEmailField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: _emailController,
        decoration: AppTheme.inputDecoration.copyWith(
          labelText: 'Email Address',
          prefixIcon: const Icon(Icons.email),
        ),
        style: AppTheme.bodyText.copyWith(color: AppTheme.textPrimary),
        keyboardType: TextInputType.emailAddress,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your email address';
          }
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
            return 'Please enter a valid email address';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPhoneField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: _phoneController,
        decoration: AppTheme.inputDecoration.copyWith(
          labelText: 'Phone Number',
          prefixIcon: const Icon(Icons.phone),
        ),
        style: AppTheme.bodyText.copyWith(color: AppTheme.textPrimary),
        keyboardType: TextInputType.phone,
        validator: (value) {
          if (value != null && value.isNotEmpty) {
            // Simple phone validation - can be enhanced based on requirements
            if (value.length < 10) {
              return 'Please enter a valid phone number';
            }
          }
          return null;
        },
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      
      // Show options dialog
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Image Source'),
          content: const Text('Choose where to pick your profile image from'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.camera),
              child: const Text('Camera'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
              child: const Text('Gallery'),
            ),
          ],
        ),
      );
      
      if (source == null) return;
      
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final profileService = ProfileService();
      
      // Update user profile in Firestore
      final success = await profileService.updateUserProfile(
        uid: widget.user.uid,
        firstName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        profileImage: _profileImage,
      );
      
      if (success) {
        // Update user data in auth service
        final authService = context.read<shared.AuthService>();
        
        // Update auth service with new user data
        await authService.updateUserProfile(
          uid: widget.user.uid,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profile updated successfully!'),
              backgroundColor: AppTheme.success,
            ),
          );
          
          Navigator.of(context).pop(); // Return to profile screen
        }
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      AppLogger.error('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final names = name.trim().split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else {
      return names[0].substring(0, 1).toUpperCase();
    }
  }
}