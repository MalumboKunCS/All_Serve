import 'package:flutter/material.dart';

class IconHelper {
  static IconData getIconFromString(String iconString) {
    switch (iconString.toLowerCase()) {
      case 'plumbing':
        return Icons.plumbing;
      case 'car_repair':
        return Icons.car_repair;
      case 'cleaning_services':
        return Icons.cleaning_services;
      case 'electrical':
        return Icons.electrical_services;
      case 'carpentry':
        return Icons.handyman;
      case 'gardening':
        return Icons.eco;
      case 'painting':
        return Icons.brush;
      case 'hvac':
        return Icons.ac_unit;
      case 'build':
      default:
        return Icons.build;
    }
  }
}
