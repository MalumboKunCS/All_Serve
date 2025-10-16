import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../theme/app_theme.dart';
import '../../services/location_service.dart';
import '../../utils/app_logger.dart';

class LocationPickerScreen extends StatefulWidget {
  final Map<String, dynamic>? initialLocation;
  final String? initialAddress;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
    this.initialAddress,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isLoading = false;
  bool _isLoadingAddress = false;
  final LocationService _locationService = LocationService();

  // Default location (Lusaka, Zambia)
  static const LatLng _defaultLocation = LatLng(-15.3875, 28.3228);

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    setState(() => _isLoading = true);

    try {
      // Check if we have an initial location
      if (widget.initialLocation != null) {
        final lat = widget.initialLocation!['lat'] as double?;
        final lng = widget.initialLocation!['lng'] as double?;
        if (lat != null && lng != null) {
          _selectedLocation = LatLng(lat, lng);
          _selectedAddress = widget.initialAddress ?? widget.initialLocation!['address'];
          AppLogger.debug('Initialized with provided location: $lat, $lng');
        }
      }

      // If no initial location, try to get current location
      if (_selectedLocation == null) {
        final hasPermission = await _locationService.checkAndRequestPermissions();
        if (hasPermission) {
          final position = await _locationService.getCurrentLocation();
          if (position != null) {
            _selectedLocation = LatLng(position.latitude, position.longitude);
            AppLogger.debug('Got current location: ${position.latitude}, ${position.longitude}');
          } else {
            _selectedLocation = _defaultLocation;
            AppLogger.warning('Could not get current location, using default');
          }
        } else {
          _selectedLocation = _defaultLocation;
          AppLogger.warning('Location permission denied, using default location');
        }
      }

      // Get address for the selected location
      if (_selectedLocation != null) {
        await _getAddressFromCoordinates(_selectedLocation!);
      }
    } catch (e) {
      AppLogger.error('Error initializing location: $e');
      _selectedLocation = _defaultLocation;
      _selectedAddress = 'Default Location';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      final hasPermission = await _locationService.checkAndRequestPermissions();
      if (!hasPermission) {
        _showLocationPermissionDialog();
        return;
      }

      final position = await _locationService.getCurrentLocation();
      if (position == null) {
        _showErrorSnackBar('Could not get current location. Please try again.');
        return;
      }
      final newLocation = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _selectedLocation = newLocation;
      });

      // Move camera to new location
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLng(newLocation),
        );
      }

      // Get address for the new location
      await _getAddressFromCoordinates(newLocation);
      
      AppLogger.info('Updated to current location: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      AppLogger.error('Error getting current location: $e');
      _showErrorSnackBar('Could not get current location. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getAddressFromCoordinates(LatLng location) async {
    if (!mounted) return;
    setState(() => _isLoadingAddress = true);
    
    try {
      // Add timeout to geocoding request
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Geocoding request timed out', const Duration(seconds: 5));
        },
      );

      if (!mounted) return;
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = _formatAddress(placemark);
        setState(() => _selectedAddress = address);
        AppLogger.debug('Got address: $address');
      } else {
        setState(() => _selectedAddress = 'Address not found');
      }
    } catch (e) {
      AppLogger.error('Error getting address: $e');
      if (mounted) {
        setState(() => _selectedAddress = 'Address not available');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingAddress = false);
      }
    }
  }

  String _formatAddress(Placemark placemark) {
    final parts = <String>[];
    
    if (placemark.name?.isNotEmpty == true) parts.add(placemark.name!);
    if (placemark.street?.isNotEmpty == true) parts.add(placemark.street!);
    if (placemark.locality?.isNotEmpty == true) parts.add(placemark.locality!);
    if (placemark.administrativeArea?.isNotEmpty == true) parts.add(placemark.administrativeArea!);
    if (placemark.country?.isNotEmpty == true) parts.add(placemark.country!);
    
    return parts.join(', ');
  }

  void _onMapTapped(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
    _getAddressFromCoordinates(location);
    AppLogger.debug('Map tapped at: ${location.latitude}, ${location.longitude}');
  }

  void _confirmLocation() {
    if (_selectedLocation != null) {
      final result = {
        'lat': _selectedLocation!.latitude,
        'lng': _selectedLocation!.longitude,
        'address': _selectedAddress ?? 'Selected Location',
      };
      
      AppLogger.info('Location confirmed: ${_selectedLocation!.latitude}, ${_selectedLocation!.longitude}');
      Navigator.of(context).pop(result);
    }
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(
          'Location Permission Required',
          style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
        ),
        content: Text(
          'To use your current location, please enable location permissions in your device settings.',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Geolocator.openLocationSettings();
            },
            style: AppTheme.primaryButtonStyle,
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Select Service Location',
          style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
        ),
        backgroundColor: AppTheme.surfaceDark,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        actions: [
          if (_selectedLocation != null)
            TextButton(
              onPressed: _confirmLocation,
              child: Text(
                'Confirm',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.primaryPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          if (_selectedLocation != null)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _selectedLocation!,
                zoom: 15.0,
              ),
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              onTap: _onMapTapped,
              markers: _selectedLocation != null
                  ? {
                      Marker(
                        markerId: const MarkerId('selected_location'),
                        position: _selectedLocation!,
                        draggable: true,
                        onDragEnd: (LatLng newPosition) {
                          setState(() {
                            _selectedLocation = newPosition;
                          });
                          _getAddressFromCoordinates(newPosition);
                        },
                        infoWindow: InfoWindow(
                          title: 'Service Location',
                          snippet: _selectedAddress,
                        ),
                      ),
                    }
                  : {},
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoading)
                    CircularProgressIndicator(color: AppTheme.primaryPurple)
                  else
                    Icon(
                      Icons.location_off,
                      size: 64,
                      color: AppTheme.textSecondary,
                    ),
                  const SizedBox(height: 16),
                  Text(
                    _isLoading ? 'Loading map...' : 'Unable to load map',
                    style: AppTheme.bodyLarge.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),

          // Address display
          if (_selectedAddress != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: AppTheme.primaryPurple,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Selected Location',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingAddress)
                      Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Getting address...',
                            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                          ),
                        ],
                      )
                    else
                      Text(
                        _selectedAddress!,
                        style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
            ),

          // Current location FAB
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              onPressed: _isLoading ? null : _getCurrentLocation,
              backgroundColor: AppTheme.primaryPurple,
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.my_location, color: Colors.white),
            ),
          ),

          // Instructions
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.info,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap on the map or drag the marker to select your service location',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                    ),
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
