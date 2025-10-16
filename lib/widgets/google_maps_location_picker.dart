import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../services/places_service.dart';

class GoogleMapsLocationPicker extends StatefulWidget {
  final LatLng? initialPosition;
  final String? initialAddress;
  final Function(LatLng position, String address) onLocationSelected;
  final bool enableSearch;
  final bool enableMultipleLocations;
  final List<LatLng>? existingLocations;
  final String? businessType;
  final bool showRoutes;

  const GoogleMapsLocationPicker({
    super.key,
    this.initialPosition,
    this.initialAddress,
    required this.onLocationSelected,
    this.enableSearch = true,
    this.enableMultipleLocations = false,
    this.existingLocations,
    this.businessType,
    this.showRoutes = false,
  });

  @override
  State<GoogleMapsLocationPicker> createState() => _GoogleMapsLocationPickerState();
}

class _GoogleMapsLocationPickerState extends State<GoogleMapsLocationPicker> {
  GoogleMapController? _mapController;
  LatLng _selectedPosition = const LatLng(-15.416667, 28.283333); // Default to Lusaka, Zambia
  String _selectedAddress = 'Loading address...';
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isLoadingAddress = false;
  List<LatLng> _selectedLocations = [];
  List<String> _locationAddresses = [];
  List<PlaceSearchResult> _searchSuggestions = [];
  bool _showSuggestions = false;
  bool _isGettingCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _selectedPosition = widget.initialPosition!;
    }
    if (widget.initialAddress != null) {
      _selectedAddress = widget.initialAddress!;
    } else {
      _getAddressFromLatLng(_selectedPosition);
    }
    if (widget.existingLocations != null) {
      _selectedLocations = List.from(widget.existingLocations!);
      _updateMultipleMarkers();
    } else {
      _updateMarker();
    }
    
    // Add focus listener to show suggestions when search bar is tapped
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        setState(() {
          _showSuggestions = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_selectedPosition, 15.0),
    );
  }

  void _onCameraMove(CameraPosition position) {
    if (!widget.enableMultipleLocations) {
      _selectedPosition = position.target;
    }
  }

  Future<void> _onCameraIdle() async {
    if (!widget.enableMultipleLocations) {
      setState(() => _isLoadingAddress = true);
      await _getAddressFromLatLng(_selectedPosition);
      _updateMarker();
      setState(() => _isLoadingAddress = false);
    }
  }

  void _onMapTap(LatLng position) {
    if (widget.enableMultipleLocations) {
      setState(() {
        _selectedLocations.add(position);
        _updateMultipleMarkers();
      });
      _getAddressFromLatLng(position);
      // Note: Address will be added to _locationAddresses in _getAddressFromLatLng
    } else {
      setState(() {
        _selectedPosition = position;
      });
      _getAddressFromLatLng(position);
      _updateMarker();
    }
  }

  Future<void> _onSearchChanged(String query) async {
    setState(() {
      _showSuggestions = query.isNotEmpty; // Show suggestions when user types
    });

    if (query.length < 3) {
      setState(() {
        _searchSuggestions = [];
      });
      return;
    }

    try {
      final suggestions = await PlacesService.searchPlaces(query);
      setState(() {
        _searchSuggestions = suggestions.take(5).toList(); // Limit to 5 suggestions
      });
    } catch (e) {
      debugPrint('Error getting search suggestions: $e');
      setState(() {
        _searchSuggestions = [];
      });
    }
  }

  void _selectSuggestion(PlaceSearchResult suggestion) {
    if (suggestion.location != null) {
      setState(() {
        _selectedPosition = suggestion.location!;
        _selectedAddress = suggestion.formattedAddress ?? suggestion.name;
        _searchController.text = suggestion.name;
        _showSuggestions = false;
      });
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(suggestion.location!, 15.0),
      );
      _updateMarker();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingCurrentLocation = true;
      _showSuggestions = false;
    });

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showPermissionDeniedDialog();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermissionDeniedForeverDialog();
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServicesDisabledDialog();
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final currentLocation = LatLng(position.latitude, position.longitude);
      
      // Get address for current location
      await _getAddressFromLatLng(currentLocation);
      
      // Update map position
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(currentLocation, 15.0),
      );

      setState(() {
        _selectedPosition = currentLocation;
        _searchController.text = _selectedAddress;
        if (widget.enableMultipleLocations) {
          _selectedLocations = [currentLocation];
          _locationAddresses = [_selectedAddress];
        }
      });

      // Update markers
      _updateMarker();
      
    } catch (e) {
      debugPrint('Error getting current location: $e');
      _showLocationErrorDialog(e.toString());
    } finally {
      setState(() {
        _isGettingCurrentLocation = false;
      });
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'This app needs location permission to find your current location. '
          'Please grant permission in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedForeverDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location permission has been permanently denied. '
          'Please enable it in app settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showLocationServicesDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text(
          'Please enable location services on your device to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLocationErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Error'),
        content: Text('Unable to get your current location: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (!mounted) return;
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          _selectedAddress = '${place.street}, ${place.subLocality}, ${place.locality}, ${place.country}';
        });
      } else {
        setState(() {
          _selectedAddress = 'No address found';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedAddress = 'Error getting address';
        });
      }
      debugPrint('Error getting address: $e');
    }
  }


  BitmapDescriptor _getBusinessMarker() {
    switch (widget.businessType?.toLowerCase()) {
      case 'restaurant':
      case 'food':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case 'hotel':
      case 'accommodation':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case 'transport':
      case 'taxi':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
      case 'retail':
      case 'shop':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case 'health':
      case 'medical':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      default:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    }
  }

  void _updateMarker() {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('selected-location'),
          position: _selectedPosition,
          infoWindow: InfoWindow(title: _selectedAddress),
          icon: _getBusinessMarker(),
        ),
      };
    });
  }

  void _updateMultipleMarkers() {
    setState(() {
      _markers = {};
      for (int i = 0; i < _selectedLocations.length; i++) {
        _markers.add(
          Marker(
            markerId: MarkerId('location-$i'),
            position: _selectedLocations[i],
            infoWindow: InfoWindow(
              title: i < _locationAddresses.length ? _locationAddresses[i] : 'Location ${i + 1}',
            ),
            icon: _getBusinessMarker(),
          ),
        );
      }
    });

    // Add polylines to connect locations if showRoutes is enabled
    if (widget.showRoutes && _selectedLocations.length > 1) {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: _selectedLocations,
          color: AppTheme.primary,
          width: 3,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      };
    }
  }

  void _removeLocation(int index) {
    setState(() {
      _selectedLocations.removeAt(index);
      if (index < _locationAddresses.length) {
        _locationAddresses.removeAt(index);
      }
      _updateMultipleMarkers();
    });
  }

  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) return;
    
    setState(() => _isLoadingAddress = true);
    
    try {
      // First try Places API search for better results
      final places = await PlacesService.searchPlaces(query);
      
      if (places.isNotEmpty) {
        // Use the first result from Places API
        final place = places.first;
        if (place.location != null) {
          final newPosition = place.location!;
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(newPosition, 15.0),
          );
          setState(() {
            _selectedPosition = newPosition;
          });
          
          // Use the formatted address from Places API if available
          if (place.formattedAddress != null) {
            setState(() {
              _selectedAddress = place.formattedAddress!;
            });
          } else {
            await _getAddressFromLatLng(newPosition);
          }
          _updateMarker();
        }
      } else {
        // Fallback to geocoding if Places API doesn't return results
        List<Location> locations = await locationFromAddress(query);
        if (locations.isNotEmpty) {
          final firstLocation = locations.first;
          final newPosition = LatLng(firstLocation.latitude, firstLocation.longitude);
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(newPosition, 15.0),
          );
          setState(() {
            _selectedPosition = newPosition;
          });
          await _getAddressFromLatLng(newPosition);
          _updateMarker();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No results found for "$query"')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching address: $e')),
        );
      }
      debugPrint('Error searching address: $e');
    } finally {
      setState(() => _isLoadingAddress = false);
    }
  }


  void _confirmLocation() {
    if (widget.enableMultipleLocations && _selectedLocations.isNotEmpty) {
      // For multiple locations, use the first one as primary
      widget.onLocationSelected(
        _selectedLocations.first, 
        _locationAddresses.isNotEmpty ? _locationAddresses.first : 'Multiple locations selected'
      );
    } else if (!widget.enableMultipleLocations) {
      widget.onLocationSelected(_selectedPosition, _selectedAddress);
    }
    
    Navigator.of(context).pop({
      'position': widget.enableMultipleLocations ? _selectedLocations : [_selectedPosition],
      'address': widget.enableMultipleLocations ? _locationAddresses : [_selectedAddress],
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(widget.enableMultipleLocations ? 'Select Business Locations' : 'Select Business Location'),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
          if (widget.enableMultipleLocations)
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: _getCurrentLocation,
              tooltip: 'My Location',
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _selectedPosition,
              zoom: 15.0,
            ),
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            onTap: _onMapTap,
            markers: _markers,
            polylines: _polylines,
            myLocationButtonEnabled: false,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            mapType: MapType.normal,
          ),
          
          // Search bar with suggestions
          if (widget.enableSearch)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        decoration: AppTheme.inputDecoration.copyWith(
                          hintText: 'Search for an address...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchSuggestions = [];
                                _showSuggestions = false;
                              });
                            },
                          ),
                        ),
                        onChanged: _onSearchChanged,
                        onSubmitted: _searchAddress,
                        style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                      ),
                    ),
                  ),
                  
                  // Search suggestions dropdown
                  if (_showSuggestions)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Current Location Option
                          ListTile(
                            leading: _isGettingCurrentLocation 
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
                                    ),
                                  )
                                : const Icon(Icons.my_location, color: AppTheme.primaryPurple),
                            title: Text(
                              'Use Current Location',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Detect your current position',
                              style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                            ),
                            onTap: _isGettingCurrentLocation ? null : _getCurrentLocation,
                            enabled: !_isGettingCurrentLocation,
                          ),
                          
                          // Divider if there are search suggestions
                          if (_searchSuggestions.isNotEmpty)
                            const Divider(
                              height: 1,
                              color: AppTheme.cardLight,
                            ),
                          
                          // Search Suggestions
                          if (_searchSuggestions.isNotEmpty)
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _searchSuggestions.length,
                              itemBuilder: (context, index) {
                                final suggestion = _searchSuggestions[index];
                                return ListTile(
                                  leading: const Icon(Icons.location_on, color: AppTheme.primaryPurple),
                                  title: Text(
                                    suggestion.name,
                                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                                  ),
                                  subtitle: suggestion.formattedAddress != null
                                      ? Text(
                                          suggestion.formattedAddress!,
                                          style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                                        )
                                      : null,
                                  onTap: () => _selectSuggestion(suggestion),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // Selected location info
          Positioned(
            top: widget.enableSearch ? 80 : 10,
            left: 10,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.cardLight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: AppTheme.primaryPurple, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          widget.enableMultipleLocations ? 'Selected Locations (${_selectedLocations.length})' : 'Selected Location',
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (widget.enableMultipleLocations) ...[
                      if (_selectedLocations.isEmpty)
                        Text(
                          'Tap on the map to add locations',
                          style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                        )
                      else
                        ...List.generate(_selectedLocations.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${index + 1}. ${index < _locationAddresses.length ? _locationAddresses[index] : "Loading address..."}',
                                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  onPressed: () => _removeLocation(index),
                                  iconSize: 20,
                                ),
                              ],
                            ),
                          );
                        }),
                    ] else ...[
                      if (_isLoadingAddress)
                        const LinearProgressIndicator()
                      else
                        Text(
                          _selectedAddress,
                          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Lat: ${_selectedPosition.latitude.toStringAsFixed(6)}, '
                        'Lng: ${_selectedPosition.longitude.toStringAsFixed(6)}',
                        style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Instructions
          Positioned(
            bottom: 100,
            left: 10,
            right: 10,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.cardLight,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.info,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.enableMultipleLocations 
                          ? 'Tap on the map to add multiple business locations'
                          : 'Tap on the map or drag to select your exact business location',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Confirm button
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: () {
                if (widget.enableMultipleLocations && _selectedLocations.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select at least one location')),
                  );
                  return;
                }
                _confirmLocation();
              },
              icon: const Icon(Icons.check),
              label: Text(widget.enableMultipleLocations ? 'Confirm Locations' : 'Confirm Location'),
              style: AppTheme.primaryButtonStyle,
            ),
          ),
        ],
      ),
    );
  }
}
