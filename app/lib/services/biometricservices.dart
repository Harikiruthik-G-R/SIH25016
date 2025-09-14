// Create this as lib/services/biometric_service.dart
import 'package:flutter/services.dart';

class BiometricService {
  static const MethodChannel _channel = MethodChannel('biometric_scanner');

  /// Check if fingerprint scanner is available
  static Future<bool> isScannerAvailable() async {
    try {
      return await _channel.invokeMethod('isScannerAvailable') ?? false;
    } catch (e) {
      print('Error checking scanner availability: $e');
      return false;
    }
  }

  /// Initialize scanner
  static Future<bool> initializeScanner() async {
    try {
      return await _channel.invokeMethod('initializeScanner') ?? false;
    } catch (e) {
      print('Error initializing scanner: $e');
      return false;
    }
  }

  /// Capture fingerprint for a student
  static Future<Map<String, dynamic>> captureFingerprint(String studentName) async {
    try {
      final result = await _channel.invokeMethod<Map>(
        'captureFingerprint',
        {
          "instruction": "Place finger to register for $studentName",
          "timeout": 30,
        },
      );
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      print('Error capturing fingerprint: $e');
      return {"success": false, "error": e.toString()};
    }
  }

  /// Verify fingerprint with stored template
  static Future<Map<String, dynamic>> verifyFingerprint(
    String storedTemplate,
    String capturedTemplate,
  ) async {
    try {
      final result = await _channel.invokeMethod<Map>(
        'verifyFingerprint',
        {
          "storedTemplate": storedTemplate,
          "capturedTemplate": capturedTemplate,
        },
      );
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      print('Error verifying fingerprint: $e');
      return {"isMatch": false, "confidence": 0.0, "error": e.toString()};
    }
  }

  /// Get unique device ID
  static Future<String> getDeviceId() async {
    try {
      return await _channel.invokeMethod('getDeviceId') ?? "unknown_device";
    } catch (e) {
      print('Error getting device ID: $e');
      return "unknown_device";
    }
  }
}