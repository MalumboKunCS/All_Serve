import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math' as math;

class LocationService {
  static const double _earthRadiusKm = 6371.0;

  /// Check if location services are enabled and request permissions
  Future<bool> checkAndRequestPermissions() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) return null;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return position;
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Get address from coordinates (reverse geocoding)
  Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.locality}, ${place.country}';
      }
      
      return null;
    } catch (e) {
      print('Error getting address: $e');
      return null;
    }
  }

  /// Get coordinates from address (geocoding)
  Future<Map<String, double>?> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      
      if (locations.isNotEmpty) {
        Location location = locations[0];
        return {
          'latitude': location.latitude,
          'longitude': location.longitude,
        };
      }
      
      return null;
    } catch (e) {
      print('Error getting coordinates: $e');
      return null;
    }
  }

  /// Calculate distance between two points using Haversine formula
  double calculateDistance(
    double lat1, 
    double lon1, 
    double lat2, 
    double lon2,
  ) {
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return _earthRadiusKm * c;
  }

  /// Generate geohash for spatial indexing (simplified implementation)
  String generateGeohash(double latitude, double longitude, {int precision = 9}) {
    const String base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
    
    double latMin = -90.0, latMax = 90.0;
    double lonMin = -180.0, lonMax = 180.0;
    
    String geohash = '';
    int bit = 0;
    int ch = 0;
    bool isEven = true;
    
    while (geohash.length < precision) {
      double mid;
      
      if (isEven) {
        // Longitude
        mid = (lonMin + lonMax) / 2;
        if (longitude >= mid) {
          ch |= (1 << (4 - bit));
          lonMin = mid;
        } else {
          lonMax = mid;
        }
      } else {
        // Latitude
        mid = (latMin + latMax) / 2;
        if (latitude >= mid) {
          ch |= (1 << (4 - bit));
          latMin = mid;
        } else {
          latMax = mid;
        }
      }
      
      isEven = !isEven;
      
      if (bit < 4) {
        bit++;
      } else {
        geohash += base32[ch];
        bit = 0;
        ch = 0;
      }
    }
    
    return geohash;
  }

  /// Get geohash neighbors for radius search
  List<String> getGeohashNeighbors(String geohash, int radius) {
    // Simplified neighbor calculation
    // In production, use a proper geohash library
    List<String> neighbors = [geohash];
    
    // Add some basic neighbor patterns
    String baseHash = geohash.substring(0, math.max(1, geohash.length - 1));
    
    // This is a simplified implementation
    // For production, use geoflutterfire or similar library
    for (int i = 0; i < 32; i++) {
      String neighbor = baseHash + i.toRadixString(32);
      if (neighbor != geohash && neighbor.length == geohash.length) {
        neighbors.add(neighbor);
      }
    }
    
    return neighbors;
  }

  /// Check if point is within radius of center
  bool isWithinRadius(
    double centerLat,
    double centerLon,
    double pointLat,
    double pointLon,
    double radiusKm,
  ) {
    double distance = calculateDistance(centerLat, centerLon, pointLat, pointLon);
    return distance <= radiusKm;
  }

  /// Get bounding box for a given center point and radius
  Map<String, double> getBoundingBox(
    double centerLat,
    double centerLon,
    double radiusKm,
  ) {
    // Convert radius to degrees (approximate)
    double latChange = radiusKm / 111.0; // 1 degree lat ≈ 111 km
    double lonChange = radiusKm / (111.0 * math.cos(_degreesToRadians(centerLat)));
    
    return {
      'minLat': centerLat - latChange,
      'maxLat': centerLat + latChange,
      'minLon': centerLon - lonChange,
      'maxLon': centerLon + lonChange,
    };
  }

  /// Format distance for display
  String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).round()}m';
    } else if (distanceKm < 10.0) {
      return '${distanceKm.toStringAsFixed(1)}km';
    } else {
      return '${distanceKm.round()}km';
    }
  }

  /// Get location settings for opening device settings
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Get app settings for opening app-specific settings
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }
}

/// Location result model
class LocationResult {
  final double latitude;
  final double longitude;
  final String? address;
  final double? accuracy;

  LocationResult({
    required this.latitude,
    required this.longitude,
    this.address,
    this.accuracy,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'accuracy': accuracy,
    };
  }

  static LocationResult fromMap(Map<String, dynamic> map) {
    return LocationResult(
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      address: map['address'],
      accuracy: map['accuracy']?.toDouble(),
    );
  }
}

