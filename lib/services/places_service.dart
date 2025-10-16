import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlacesService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';
  static const String _apiKey = 'AIzaSyDB0_iUHMZwpz6PZfMQfpQAxsRpGJXowHU'; // Replace with your actual API key

  /// Search for places using Google Places API
  static Future<List<PlaceSearchResult>> searchPlaces(String query) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/textsearch/json?query=$query&key=$_apiKey',
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return (data['results'] as List)
              .map((result) => PlaceSearchResult.fromJson(result))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error searching places: $e');
      return [];
    }
  }

  /// Get place details by place ID
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/details/json?place_id=$placeId&fields=formatted_address,geometry,name,place_id,types&key=$_apiKey',
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data['result']);
        }
      }
      return null;
    } catch (e) {
      print('Error getting place details: $e');
      return null;
    }
  }

  /// Search for nearby places by location and type
  static Future<List<PlaceSearchResult>> searchNearby(
    LatLng location,
    String type, {
    int radius = 5000,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/nearbysearch/json?location=${location.latitude},${location.longitude}&radius=$radius&type=$type&key=$_apiKey',
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return (data['results'] as List)
              .map((result) => PlaceSearchResult.fromJson(result))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error searching nearby places: $e');
      return [];
    }
  }
}

class PlaceSearchResult {
  final String placeId;
  final String name;
  final String? formattedAddress;
  final LatLng? location;
  final double? rating;
  final List<String>? types;

  PlaceSearchResult({
    required this.placeId,
    required this.name,
    this.formattedAddress,
    this.location,
    this.rating,
    this.types,
  });

  factory PlaceSearchResult.fromJson(Map<String, dynamic> json) {
    LatLng? location;
    if (json['geometry'] != null && json['geometry']['location'] != null) {
      final lat = json['geometry']['location']['lat'];
      final lng = json['geometry']['location']['lng'];
      location = LatLng(lat, lng);
    }

    return PlaceSearchResult(
      placeId: json['place_id'],
      name: json['name'],
      formattedAddress: json['formatted_address'],
      location: location,
      rating: json['rating']?.toDouble(),
      types: json['types']?.cast<String>(),
    );
  }
}

class PlaceDetails {
  final String placeId;
  final String name;
  final String? formattedAddress;
  final LatLng? location;
  final List<String>? types;

  PlaceDetails({
    required this.placeId,
    required this.name,
    this.formattedAddress,
    this.location,
    this.types,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    LatLng? location;
    if (json['geometry'] != null && json['geometry']['location'] != null) {
      final lat = json['geometry']['location']['lat'];
      final lng = json['geometry']['location']['lng'];
      location = LatLng(lat, lng);
    }

    return PlaceDetails(
      placeId: json['place_id'],
      name: json['name'],
      formattedAddress: json['formatted_address'],
      location: location,
      types: json['types']?.cast<String>(),
    );
  }
}

