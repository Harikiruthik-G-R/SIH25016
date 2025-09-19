// lib/services/biometric_service.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BiometricService {
  static const MethodChannel _channel = MethodChannel('biometric_scanner');

  /// Check if fingerprint sensor hardware is available
  static Future<bool> isScannerAvailable() async {
    try {
      final result = await _channel.invokeMethod('isScannerAvailable');
      developer.log("Fingerprint sensor availability: $result", name: 'BiometricService');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking fingerprint sensor availability: $e');
      developer.log("Error checking fingerprint sensor availability: $e", name: 'BiometricService');
      return false;
    }
  }

  /// Initialize fingerprint sensor for enrollment/capture mode
  static Future<bool> initializeScannerForCapture() async {
    try {
      final result = await _channel.invokeMethod('initializeForEnrollment');
      developer.log("Fingerprint sensor initialization for enrollment: $result", name: 'BiometricService');
      return result ?? false;
    } catch (e) {
      debugPrint("Failed to initialize fingerprint sensor for enrollment: $e");
      developer.log("Error initializing fingerprint sensor for enrollment: $e", name: 'BiometricService');
      return false;
    }
  }

  /// Get the type of fingerprint sensor available
  static Future<String> getScannerType() async {
    try {
      final result = await _channel.invokeMethod('getScannerType');
      final scannerType = result as String? ?? 'unknown';
      developer.log("Fingerprint sensor type: $scannerType", name: 'BiometricService');
      return scannerType;
    } catch (e) {
      debugPrint("Error getting fingerprint sensor type: $e");
      developer.log("Error getting fingerprint sensor type: $e", name: 'BiometricService');
      return 'unknown';
    }
  }

  /// Capture fingerprint using sensor (enrollment mode)
  static Future<Map<String, dynamic>> captureForEnrollment(String studentName) async {
    try {
      developer.log("Starting fingerprint enrollment for: $studentName", name: 'BiometricService');
      
      final result = await _channel.invokeMethod<Map>(
        'captureForEnrollment',
        {
          "studentName": studentName,
          "instruction": "Place finger on sensor for enrollment",
        },
      );
      
      final captureResult = Map<String, dynamic>.from(result ?? {});
      developer.log("Fingerprint enrollment result: ${captureResult['success']}", name: 'BiometricService');
      
      if (captureResult['success'] == true) {
        developer.log("Enrollment successful - Template length: ${(captureResult['template'] as String?)?.length ?? 0}, Quality: ${captureResult['quality']}%", name: 'BiometricService');
      }
      
      return captureResult;
    } catch (e) {
      debugPrint('Error in fingerprint enrollment: $e');
      developer.log("Error in fingerprint enrollment: $e", name: 'BiometricService');
      return {"success": false, "error": "Fingerprint sensor enrollment failed: $e"};
    }
  }

  /// Enhanced capture with quality validation and retries
  static Future<Map<String, dynamic>> captureWithQualityCheck(
    String studentName, {
    int minQuality = 40,
    int maxRetries = 3,
  }) async {
    try {
      developer.log("Starting quality-checked enrollment for: $studentName, minQuality: $minQuality", 
                   name: 'BiometricService');
      
      Map<String, dynamic>? bestResult;
      int bestQuality = 0;
      
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        developer.log("Enrollment attempt $attempt of $maxRetries", name: 'BiometricService');
        
        final result = await captureForEnrollment(studentName);
        
        if (!(result['success'] ?? false)) {
          developer.log("Attempt $attempt failed: ${result['error']}", name: 'BiometricService');
          if (attempt == maxRetries) {
            return bestResult ?? result; // Return best result or last error
          }
          continue;
        }
        
        // Check quality
        final quality = result['quality'] as int? ?? 0;
        
        // Keep track of best result
        if (quality > bestQuality) {
          bestQuality = quality;
          bestResult = result;
        }
        
        if (quality >= minQuality) {
          developer.log("Enrollment quality check passed: $quality% >= $minQuality%", name: 'BiometricService');
          return result;
        } else {
          developer.log("Quality too low: $quality% < $minQuality%, attempt $attempt", name: 'BiometricService');
        }
      }
      
      // If we get here, all attempts had quality below threshold
      return {
        'success': false,
        'error': 'Fingerprint quality too low after $maxRetries attempts. Best quality: $bestQuality%. Please clean finger and try again.',
        'quality': bestQuality,
        'bestResult': bestResult,
      };
      
    } catch (e) {
      debugPrint("Error in quality-checked enrollment: $e");
      developer.log("Error in quality-checked enrollment: $e", name: 'BiometricService');
      return {'success': false, 'error': 'Enrollment with quality check failed: $e'};
    }
  }

  /// Verify fingerprint template against stored template (for authentication)
  static Future<Map<String, dynamic>> verifyFingerprint(
    String storedTemplate,
    String capturedTemplate,
  ) async {
    try {
      developer.log("Starting fingerprint verification", name: 'BiometricService');
      
      final result = await _channel.invokeMethod<Map>(
        'verifyFingerprint',
        {
          "storedTemplate": storedTemplate,
          "capturedTemplate": capturedTemplate,
        },
      );
      
      final verificationResult = Map<String, dynamic>.from(result ?? {});
      developer.log("Fingerprint verification result: ${verificationResult['isMatch']}, confidence: ${verificationResult['confidence']}", name: 'BiometricService');
      return verificationResult;
    } catch (e) {
      debugPrint('Error verifying fingerprint: $e');
      developer.log("Error verifying fingerprint: $e", name: 'BiometricService');
      return {"isMatch": false, "confidence": 0.0, "error": "Verification failed: $e"};
    }
  }

  /// Authenticate user using stored fingerprint data
  static Future<Map<String, dynamic>> authenticateUser(String rollNumber, String groupId) async {
    try {
      developer.log("Starting fingerprint authentication for roll number: $rollNumber", name: 'BiometricService');
      
      // First, get the stored fingerprint template from Firestore
      final storedData = await getStoredFingerprintData(rollNumber, groupId);
      
      if (!storedData['found']) {
        return {
          'success': false,
          'error': 'User not found or biometric not registered',
          'errorType': 'user_not_found'
        };
      }

      final storedTemplate = storedData['template'] as String;
      final storedHash = storedData['biometricHash'] as String;
      
      // Capture new fingerprint for authentication
      final captureResult = await captureForAuthentication("Login Authentication");
      
      if (!(captureResult['success'] ?? false)) {
        return {
          'success': false,
          'error': captureResult['error'] ?? 'Failed to capture fingerprint',
          'errorType': 'capture_failed'
        };
      }

      final capturedTemplate = captureResult['template'] as String;
      
      // Generate hash from captured template for comparison
      final capturedHash = _generateTemplateHash(capturedTemplate);
      
      // First check: Hash comparison (faster)
      if (storedHash == capturedHash) {
        developer.log("Hash match found - authentication successful", name: 'BiometricService');
        return {
          'success': true,
          'method': 'hash_match',
          'confidence': 1.0,
          'student': storedData['student'],
        };
      }
      
      // Second check: Template similarity verification
      final verificationResult = await verifyFingerprint(storedTemplate, capturedTemplate);
      
      final isMatch = verificationResult['isMatch'] ?? false;
      final confidence = verificationResult['confidence'] ?? 0.0;
      
      if (isMatch && confidence >= 0.85) {
        developer.log("Template verification successful - confidence: ${(confidence * 100).toStringAsFixed(1)}%", name: 'BiometricService');
        return {
          'success': true,
          'method': 'template_match',
          'confidence': confidence,
          'student': storedData['student'],
        };
      } else {
        developer.log("Authentication failed - confidence: ${(confidence * 100).toStringAsFixed(1)}%", name: 'BiometricService');
        return {
          'success': false,
          'error': 'Fingerprint does not match',
          'errorType': 'authentication_failed',
          'confidence': confidence,
        };
      }
      
    } catch (e) {
      debugPrint("Error in user authentication: $e");
      developer.log("Error in user authentication: $e", name: 'BiometricService');
      return {
        'success': false,
        'error': 'Authentication error: $e',
        'errorType': 'system_error'
      };
    }
  }

  /// Get stored fingerprint data from Firestore
  static Future<Map<String, dynamic>> getStoredFingerprintData(String rollNumber, String groupId) async {
    try {
      developer.log("Retrieving stored fingerprint data for roll: $rollNumber, group: $groupId", name: 'BiometricService');
      
      // Query the specific group's students collection
      final querySnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('students')
          .where('rollNumber', isEqualTo: rollNumber)
          .where('biometricRegistered', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        developer.log("No biometric data found for roll number: $rollNumber", name: 'BiometricService');
        return {'found': false};
      }

      final studentDoc = querySnapshot.docs.first;
      final studentData = studentDoc.data();
      
      final template = studentData['fingerprintTemplate'] as String?;
      final biometricHash = studentData['biometricHash'] as String?;
      
      if (template == null || template.isEmpty) {
        developer.log("Fingerprint template is empty for roll number: $rollNumber", name: 'BiometricService');
        return {'found': false};
      }

      developer.log("Found stored biometric data for: ${studentData['name']}", name: 'BiometricService');
      
      return {
        'found': true,
        'template': template,
        'biometricHash': biometricHash ?? '',
        'student': {
          'id': studentDoc.id,
          'name': studentData['name'],
          'rollNumber': studentData['rollNumber'],
          'email': studentData['email'],
          'department': studentData['department'],
          'groupId': studentData['groupId'],
          'groupName': studentData['groupName'],
        }
      };
      
    } catch (e) {
      debugPrint("Error retrieving stored fingerprint data: $e");
      developer.log("Error retrieving stored fingerprint data: $e", name: 'BiometricService');
      return {'found': false, 'error': e.toString()};
    }
  }

  /// Generate SHA-256 hash from template
  static String _generateTemplateHash(String template) {
    final bytes = utf8.encode(template);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Store enrollment data to Firestore with proper hashing
  static Future<Map<String, dynamic>> storeEnrollmentData({
    required String studentId,
    required String groupId,
    required Map<String, dynamic> enrollmentResult,
    required Map<String, dynamic> studentData,
  }) async {
    try {
      developer.log("Storing enrollment data for student: ${studentData['name']}", name: 'BiometricService');
      
      final template = enrollmentResult['template'] as String;
      final fingerprintData = enrollmentResult['fingerprintData'] as String;
      final quality = enrollmentResult['quality'] as int;
      
      // Generate hashes for storage
      final templateHash = _generateTemplateHash(template);
      final dataHash = _generateTemplateHash(fingerprintData);
      final biometricHash = templateHash; // Primary hash for matching
      
      developer.log("Generated hashes - Template: ${templateHash.substring(0, 16)}...", name: 'BiometricService');
      
      // Prepare biometric data for storage
      final biometricData = {
        'fingerprintTemplate': template,
        'fingerprintData': fingerprintData,
        'biometricQuality': quality,
        'biometricHash': biometricHash,
        'fingerprintHash': templateHash,
        'fingerprintDataHash': dataHash,
        'biometricRegistered': true,
        'biometricRegisteredAt': FieldValue.serverTimestamp(),
        'enrollmentMode': 'external_scanner',
        'registrationDeviceId': enrollmentResult['deviceId'] ?? 'unknown',
        'biometricVersion': '3.0',
        'hashingMethod': 'SHA-256',
        'templateLength': template.length,
        'dataLength': fingerprintData.length,
        'scannerType': enrollmentResult['scannerType'] ?? 'built_in_fingerprint_sensor',
      };

      // Update student document in group collection
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('students')
          .doc(studentId)
          .update(biometricData);

      // Also update in global students collection
      await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .update(biometricData);

      developer.log("Enrollment data stored successfully", name: 'BiometricService');
      
      return {
        'success': true,
        'biometricHash': biometricHash,
        'quality': quality,
      };
      
    } catch (e) {
      debugPrint("Error storing enrollment data: $e");
      developer.log("Error storing enrollment data: $e", name: 'BiometricService');
      return {
        'success': false,
        'error': 'Failed to store enrollment data: $e'
      };
    }
  }

  /// Get unique device ID for tracking enrollments
  static Future<String> getDeviceId() async {
    try {
      final result = await _channel.invokeMethod('getDeviceId');
      final deviceId = result as String? ?? "unknown_device";
      developer.log("Device ID: $deviceId", name: 'BiometricService');
      return deviceId;
    } catch (e) {
      debugPrint('Error getting device ID: $e');
      developer.log("Error getting device ID: $e", name: 'BiometricService');
      return "unknown_device_${DateTime.now().millisecondsSinceEpoch}";
    }
  }

  /// Cancel any ongoing fingerprint sensor operation
  static Future<void> cancelCapture() async {
    try {
      await _channel.invokeMethod('cancelCapture');
      developer.log("Fingerprint sensor operation cancelled", name: 'BiometricService');
    } catch (e) {
      debugPrint("Error cancelling fingerprint sensor operation: $e");
      developer.log("Error cancelling fingerprint sensor operation: $e", name: 'BiometricService');
    }
  }

  /// Get detailed fingerprint sensor information
  static Future<Map<String, dynamic>> getScannerInfo() async {
    try {
      final result = await _channel.invokeMethod('getScannerInfo');
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      } else {
        return {
          'available': await isScannerAvailable(),
          'type': await getScannerType(),
          'deviceId': await getDeviceId(),
          'mode': 'enrollment_and_authentication',
        };
      }
    } catch (e) {
      debugPrint("Error getting fingerprint sensor info: $e");
      developer.log("Error getting fingerprint sensor info: $e", name: 'BiometricService');
      return {
        'available': false,
        'type': 'unknown',
        'error': e.toString(),
      };
    }
  }

  /// Test fingerprint sensor enrollment capability
  static Future<Map<String, dynamic>> testEnrollmentCapability() async {
    try {
      developer.log("Testing fingerprint sensor enrollment capability", name: 'BiometricService');
      
      final testResults = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'scannerAvailable': await isScannerAvailable(),
        'scannerType': await getScannerType(),
        'deviceId': await getDeviceId(),
        'canInitialize': false,
      };

      if (testResults['scannerAvailable'] == true) {
        testResults['canInitialize'] = await initializeScannerForCapture();
      }

      developer.log("Fingerprint sensor enrollment test completed", name: 'BiometricService');
      return testResults;

    } catch (e) {
      debugPrint("Error testing fingerprint sensor enrollment: $e");
      return {
        'success': false,
        'error': 'Fingerprint sensor test failed: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Validate captured fingerprint data
  static Map<String, dynamic> validateCapturedData(Map<String, dynamic> captureResult) {
    final validation = <String, dynamic>{
      'isValid': false,
      'issues': <String>[],
      'quality': captureResult['quality'] ?? 0,
    };

    // Check if capture was successful
    if (captureResult['success'] != true) {
      validation['issues'].add('Capture failed: ${captureResult['error'] ?? 'Unknown error'}');
      return validation;
    }

    // Check for required fields
    final template = captureResult['template'] as String?;
    final fingerprintData = captureResult['fingerprintData'] as String?;
    final quality = captureResult['quality'] as int?;

    if (template == null || template.isEmpty) {
      validation['issues'].add('Missing fingerprint template');
    }

    if (fingerprintData == null || fingerprintData.isEmpty) {
      validation['issues'].add('Missing fingerprint data');
    }

    if (quality == null || quality < 30) {
      validation['issues'].add('Quality too low: ${quality ?? 0}%');
    }

    // Check template length (should be reasonable for a hash)
    if (template != null && template.length < 32) {
      validation['issues'].add('Template appears too short');
    }

    validation['isValid'] = (validation['issues'] as List).isEmpty;
    
    developer.log("Validation result: ${validation['isValid']}, issues: ${validation['issues']}", name: 'BiometricService');
    return validation;
  }

  /// Capture fingerprint for authentication (separate from enrollment)
  static Future<Map<String, dynamic>> captureForAuthentication(String purpose) async {
    try {
      developer.log("Starting fingerprint authentication capture for: $purpose", name: 'BiometricService');
      
      final result = await _channel.invokeMethod<Map>(
        'captureForAuthentication',
        {
          "purpose": purpose,
          "instruction": "Place finger on sensor for authentication",
        },
      );
      
      final captureResult = Map<String, dynamic>.from(result ?? {});
      developer.log("Fingerprint authentication result: ${captureResult['success']}", name: 'BiometricService');
      
      return captureResult;
    } catch (e) {
      debugPrint('Error in fingerprint authentication: $e');
      developer.log("Error in fingerprint authentication: $e", name: 'BiometricService');
      return {"success": false, "error": "Fingerprint authentication failed: $e"};
    }
  }

  /// Format enrollment result for storage
  static Map<String, dynamic> formatForStorage(Map<String, dynamic> captureResult, String studentName) {
    final formatted = <String, dynamic>{
      'template': captureResult['template'] ?? '',
      'fingerprintData': captureResult['fingerprintData'] ?? '',
      'quality': captureResult['quality'] ?? 0,
      'studentName': studentName,
      'enrolledAt': DateTime.now().toIso8601String(),
      'deviceId': captureResult['deviceId'] ?? 'unknown',
      'scannerType': captureResult['scannerType'] ?? 'built_in_fingerprint_sensor',
      'enrollmentMode': 'external_scanner',
    };

    developer.log("Formatted enrollment data for storage - Student: $studentName, Quality: ${formatted['quality']}%", name: 'BiometricService');
    return formatted;
  }

  /// Check for duplicate fingerprint templates in database
  static Future<bool> checkForDuplicates(String template, String templateHash, String biometricHash, String groupId) async {
    try {
      developer.log("Checking for duplicate fingerprints", name: 'BiometricService');
      
      // Check current group students
      final groupStudents = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('students')
          .where('biometricRegistered', isEqualTo: true)
          .where('enrollmentMode', isEqualTo: 'external_scanner')
          .get();

      for (var doc in groupStudents.docs) {
        final data = doc.data();
        final docTemplate = data['fingerprintTemplate'] as String?;
        final docBiometricHash = data['biometricHash'] as String?;
        final docFingerprintHash = data['fingerprintHash'] as String?;
        
        // Check direct template match
        if (docTemplate != null && docTemplate == template) {
          developer.log("Duplicate template found: ${data['name']}", name: 'BiometricService');
          return true;
        }
        
        // Check hash matches
        if (docBiometricHash != null && docBiometricHash == biometricHash) {
          developer.log("Duplicate biometric hash found: ${data['name']}", name: 'BiometricService');
          return true;
        }
        
        if (docFingerprintHash != null && docFingerprintHash == templateHash) {
          developer.log("Duplicate fingerprint hash found: ${data['name']}", name: 'BiometricService');
          return true;
        }

        // Check similarity
        if (docTemplate != null && docTemplate.isNotEmpty && template.isNotEmpty) {
          try {
            final verifyResult = await verifyFingerprint(docTemplate, template);
            double confidence = verifyResult['confidence'] ?? 0.0;
            
            if (confidence > 0.85) {
              developer.log("High similarity duplicate found: ${data['name']} (${(confidence * 100).toStringAsFixed(1)}%)", name: 'BiometricService');
              return true;
            }
          } catch (e) {
            developer.log("Similarity check failed: $e", name: 'BiometricService');
          }
        }
      }

      // Check global collection
      final globalQuery = await FirebaseFirestore.instance
          .collectionGroup('students')
          .where('biometricHash', isEqualTo: biometricHash)
          .where('enrollmentMode', isEqualTo: 'external_scanner')
          .limit(1)
          .get();

      if (globalQuery.docs.isNotEmpty) {
        developer.log("Global duplicate found", name: 'BiometricService');
        return true;
      }

      developer.log("No duplicates found - fingerprint is unique", name: 'BiometricService');
      return false;
      
    } catch (e) {
      debugPrint("Error checking for duplicates: $e");
      developer.log("Error checking for duplicates: $e", name: 'BiometricService');
      return false;
    }
  }
}