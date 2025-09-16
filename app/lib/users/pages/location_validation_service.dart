// Create/update: lib/services/location_validation_service.dart

import 'package:flutter/services.dart';
import 'package:location/location.dart' as loc;

class LocationValidationService {
  static const MethodChannel _channel = MethodChannel('location_validation');
  
  /// Comprehensive mock location detection
  /// Returns {isMocked: bool, reason: String}
  static Future<Map<String, dynamic>> validateLocation(loc.LocationData locationData) async {
    try {
      // Check 1: Flutter-level isMock flag
      if (locationData.isMock == true) {
        return {
          'isMocked': true,
          'reason': 'mock_location_flutter'
        };
      }
      
      // Check 2: Android system-level mock location setting
      bool systemMockEnabled = false;
      try {
        systemMockEnabled = await _channel.invokeMethod('isMockSettingEnabled') ?? false;
      } catch (e) {
        // If native call fails, log but don't block attendance
        print('Failed to check system mock setting: $e');
        // Continue with Flutter-only validation
      }
      
      if (systemMockEnabled) {
        return {
          'isMocked': true,
          'reason': 'mock_location_system'
        };
      }
      
      // Additional checks could go here:
      // - GPS accuracy thresholds
      // - Location provider verification  
      // - Timestamp validation
      
      // Check 3: Suspicious accuracy values (optional additional validation)
      if (locationData.accuracy != null && locationData.accuracy! < 1.0) {
        // Extremely high accuracy might indicate mocking
        return {
          'isMocked': true,
          'reason': 'suspicious_accuracy'
        };
      }
      
      return {
        'isMocked': false,
        'reason': 'location_valid'
      };
      
    } catch (e) {
      // If validation fails, err on the side of caution
      print('Location validation error: $e');
      return {
        'isMocked': true,
        'reason': 'validation_error'
      };
    }
  }
  
  /// Get user-friendly error message for mock location detection
  static String getMockLocationMessage(String reason) {
    switch (reason) {
      case 'mock_location_flutter':
        return 'Mock location detected by the app. Please disable location spoofing apps and try again.';
      case 'mock_location_system':
        return 'Mock location setting is enabled in system settings. Please disable "Allow mock locations" in Developer Options.';
      case 'suspicious_accuracy':
        return 'Location accuracy appears artificial. Please ensure you are using genuine GPS and try again.';
      case 'validation_error':
        return 'Unable to verify location authenticity. Please check your location settings and try again.';
      default:
        return 'Location validation failed. Please ensure you are using genuine GPS location.';
    }
  }
}