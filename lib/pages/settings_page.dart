import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:all_server/auth.dart';
import 'package:all_server/models/user_profile.dart';
import 'package:all_server/services/profile_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _locationEnabled = false;
  double _searchRadius = 50.0;
  bool _preferPreviousProviders = true;
  bool _sortByLocation = false;
  String _currentLocation = 'Not set';
  
  final ProfileService _profileService = ProfileService();
  UserProfile? _userProfile;
  final TextEditingController _nameController = TextEditingController();
  bool _isUpdatingProfile = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _locationEnabled = prefs.getBool('locationEnabled') ?? false;
      _searchRadius = prefs.getDouble('searchRadius') ?? 50.0;
      _preferPreviousProviders = prefs.getBool('preferPreviousProviders') ?? true;
      _sortByLocation = prefs.getBool('sortByLocation') ?? false;
    });
    
    if (_locationEnabled) {
      _getCurrentLocation();
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('locationEnabled', _locationEnabled);
    await prefs.setDouble('searchRadius', _searchRadius);
    await prefs.setBool('preferPreviousProviders', _preferPreviousProviders);
    await prefs.setBool('sortByLocation', _sortByLocation);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully!')),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _locationEnabled = false;
            _currentLocation = 'Permission denied';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationEnabled = false;
          _currentLocation = 'Permission permanently denied';
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _currentLocation = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentLocation = 'Error: $e';
      });
    }
  }

  Future<void> _loadUserProfile() async {
    final user = Auth().currentUser;
    if (user != null) {
      final profile = await _profileService.getUserProfile(user.uid);
      setState(() {
        _userProfile = profile;
        _nameController.text = profile?.displayName ?? '';
      });
    }
  }

  Future<void> _updateProfile() async {
    final user = Auth().currentUser;
    if (user == null) return;

    setState(() {
      _isUpdatingProfile = true;
    });

    try {
      final success = await _profileService.updateUserProfile(
        uid: user.uid,
        firstName: _nameController.text.trim().isNotEmpty 
            ? _nameController.text.trim() 
            : null,
      );

      if (success) {
        await _loadUserProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
        }
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingProfile = false;
        });
      }
    }
  }

  Future<void> _updateProfileImage() async {
    final user = Auth().currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pick from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await _profileService.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null) {
                    await _updateProfileImageFile(image);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await _profileService.pickImage(
                    source: ImageSource.camera,
                  );
                  if (image != null) {
                    await _updateProfileImageFile(image);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateProfileImageFile(File imageFile) async {
    final user = Auth().currentUser;
    if (user == null) return;

    setState(() {
      _isUpdatingProfile = true;
    });

    try {
      final success = await _profileService.updateUserProfile(
        uid: user.uid,
        profileImage: imageFile,
      );

      if (success) {
        await _loadUserProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated successfully!')),
          );
        }
      } else {
        throw Exception('Failed to update profile picture');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingProfile = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save settings',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _updateProfileImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: _userProfile?.profileImageUrl != null
                                  ? NetworkImage(_userProfile!.profileImageUrl!)
                                  : null,
                              child: _userProfile?.profileImageUrl == null
                                  ? Icon(
                                      Icons.person,
                                      size: 30,
                                      color: Colors.grey[400],
                                    )
                                  : null,
                            ),
                            if (_isUpdatingProfile)
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black26,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Display Name',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _userProfile?.email ?? 'No email',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUpdatingProfile ? null : _updateProfile,
                      child: _isUpdatingProfile
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Update Profile'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Enable Location Services'),
                    subtitle: const Text('Allow app to access your location for nearby provider recommendations'),
                    value: _locationEnabled,
                    onChanged: (value) {
                      setState(() {
                        _locationEnabled = value;
                        if (value) {
                          _getCurrentLocation();
                        } else {
                          _currentLocation = 'Not set';
                        }
                      });
                    },
                  ),
                  if (_locationEnabled) ...[
                    const SizedBox(height: 16),
                    Text('Current Location: $_currentLocation'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Search Radius: '),
                        Expanded(
                          child: Slider(
                            value: _searchRadius,
                            min: 5.0,
                            max: 100.0,
                            divisions: 19,
                            label: '${_searchRadius.round()} km',
                            onChanged: (value) {
                              setState(() {
                                _searchRadius = value;
                              });
                            },
                          ),
                        ),
                        Text('${_searchRadius.round()} km'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Provider Preferences',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Prioritize Previous Providers'),
                    subtitle: const Text('Show previously used service providers first'),
                    value: _preferPreviousProviders,
                    onChanged: (value) {
                      setState(() {
                        _preferPreviousProviders = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Sort by Location'),
                    subtitle: const Text('Sort providers by distance when location is available'),
                    value: _sortByLocation,
                    onChanged: (value) {
                      setState(() {
                        _sortByLocation = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const ListTile(
                    leading: Icon(Icons.info),
                    title: Text('App Version'),
                    subtitle: Text('1.0.0'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.location_on),
                    title: Text('Location Services'),
                    subtitle: Text('Powered by device GPS'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.star),
                    title: Text('Provider Ratings'),
                    subtitle: Text('Based on user reviews and ratings'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

