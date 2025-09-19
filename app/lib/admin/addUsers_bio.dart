import 'dart:convert';
import 'package:GeoAt/services/biometricservices.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

class AddStudentDialog extends StatefulWidget {
  final String groupId;
  final Map<String, dynamic> groupData;

  const AddStudentDialog({
    super.key,
    required this.groupId,
    required this.groupData,
  });

  @override
  State<AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<AddStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _rollNumberController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _departmentController = TextEditingController(
    text: 'Computer Science and Engineering',
  );

  bool _isLoading = false;
  bool _isCapturingBiometric = false;
  bool _biometricCaptured = false;
  String? _biometricTemplate;
  String? _fingerprintData;
  int? _biometricQuality;
  String? _deviceId;
  bool _isFingerprintSensorAvailable = false;
  String _biometricHash = '';
  String _fingerprintHash = '';
  String _fingerprintDataHash = '';

  @override
  void initState() {
    super.initState();
    _checkFingerprintSensorAvailability();
  }

  Future<void> _checkFingerprintSensorAvailability() async {
    try {
      debugPrint("🔍 Checking fingerprint sensor availability...");
      final isAvailable = await BiometricService.isScannerAvailable();
      setState(() {
        _isFingerprintSensorAvailable = isAvailable;
      });

      if (!isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Fingerprint sensor is not available. Students can only be added manually.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        debugPrint("⚠️ Fingerprint sensor not available");
      } else {
        debugPrint("✅ Fingerprint sensor available");
      }
    } catch (e) {
      debugPrint('❌ Error checking fingerprint sensor availability: $e');
      setState(() {
        _isFingerprintSensorAvailable = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Fingerprint sensor check failed. Students can be added without biometric registration.',
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Comprehensive duplicate check for fingerprint enrollments
  Future<bool> _isFingerprintDuplicate(String template, String templateHash, String biometricHash) async {
    if (template.isEmpty && templateHash.isEmpty && biometricHash.isEmpty) {
      return false;
    }
    
    debugPrint("🔍 Starting comprehensive duplicate check for fingerprint enrollment...");
    
    return await _checkForDuplicateFingerprint(template, templateHash, biometricHash);
  }

  Future<bool> _checkForDuplicateFingerprint(String template, String templateHash, String biometricHash) async {
    try {
      List<Map<String, dynamic>> duplicates = [];
      
      // Check 1: Current group's students
      debugPrint("🔍 Checking group students for fingerprint enrollments...");
      final groupStudents = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('students')
          .where('biometricRegistered', isEqualTo: true)
          .where('enrollmentMode', isEqualTo: 'external_scanner')
          .get();

      for (var doc in groupStudents.docs) {
        final data = doc.data();
        final docTemplate = data['fingerprintTemplate'] as String?;
        final docBiometricHash = data['biometricHash'] as String?;
        final docFingerprintHash = data['fingerprintHash'] as String?;
        final studentName = data['name'] ?? 'Unknown';
        
        // Direct template match
        if (docTemplate != null && docTemplate == template) {
          debugPrint("❌ Fingerprint template match found: $studentName");
          duplicates.add({
            'type': 'template_exact',
            'student': studentName,
            'docId': doc.id,
          });
        }
        
        // Hash-based matches
        if (docBiometricHash != null && docBiometricHash == biometricHash) {
          debugPrint("❌ Fingerprint biometric hash match found: $studentName");
          duplicates.add({
            'type': 'biometric_hash',
            'student': studentName,
            'docId': doc.id,
          });
        }
        
        if (docFingerprintHash != null && docFingerprintHash == templateHash) {
          debugPrint("❌ Fingerprint hash match found: $studentName");
          duplicates.add({
            'type': 'fingerprint_hash',
            'student': studentName,
            'docId': doc.id,
          });
        }

        // Similarity-based check using BiometricService
        if (docTemplate != null && docTemplate.isNotEmpty && template.isNotEmpty) {
          try {
            final verifyResult = await BiometricService.verifyFingerprint(
              docTemplate,
              template,
            );
            
            double confidence = verifyResult['confidence'] ?? 0.0;
            debugPrint("📊 Fingerprint similarity check with ${studentName}: ${(confidence * 100).toStringAsFixed(1)}%");
            
            if (confidence > 0.85) {
              debugPrint("❌ High similarity fingerprint match found: $studentName (${(confidence * 100).toStringAsFixed(1)}%)");
              duplicates.add({
                'type': 'similarity',
                'student': studentName,
                'docId': doc.id,
                'confidence': confidence,
              });
            }
          } catch (e) {
            debugPrint("⚠️ Fingerprint similarity check failed for $studentName: $e");
          }
        }
      }

      // Check 2: Global students collection
      debugPrint("🔍 Checking global students for fingerprint enrollments...");
      if (template.isNotEmpty) {
        final globalTemplateQuery = await FirebaseFirestore.instance
            .collection('students')
            .where('fingerprintTemplate', isEqualTo: template)
            .where('enrollmentMode', isEqualTo: 'external_scanner')
            .get();

        for (var doc in globalTemplateQuery.docs) {
          final data = doc.data();
          final studentName = data['name'] ?? 'Unknown';
          debugPrint("❌ Global fingerprint template match found: $studentName");
          duplicates.add({
            'type': 'global_template',
            'student': studentName,
            'docId': doc.id,
          });
        }
      }

      // Check 3: Collection group queries for hash matches
      debugPrint("🔍 Checking collection groups for fingerprint hash matches...");
      
      if (biometricHash.isNotEmpty) {
        final biometricHashQuery = await FirebaseFirestore.instance
            .collectionGroup('students')
            .where('biometricHash', isEqualTo: biometricHash)
            .where('enrollmentMode', isEqualTo: 'external_scanner')
            .get();

        for (var doc in biometricHashQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final studentName = data['name'] ?? 'Unknown';
          debugPrint("❌ Collection group biometric hash match found: $studentName");
          duplicates.add({
            'type': 'collectiongroup_biometric_hash',
            'student': studentName,
            'docId': doc.id,
            'path': doc.reference.path,
          });
        }
      }

      if (templateHash.isNotEmpty) {
        final fingerprintHashQuery = await FirebaseFirestore.instance
            .collectionGroup('students')
            .where('fingerprintHash', isEqualTo: templateHash)
            .where('enrollmentMode', isEqualTo: 'external_scanner')
            .get();

        for (var doc in fingerprintHashQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final studentName = data['name'] ?? 'Unknown';
          debugPrint("❌ Collection group fingerprint hash match found: $studentName");
          duplicates.add({
            'type': 'collectiongroup_fingerprint_hash',
            'student': studentName,
            'docId': doc.id,
            'path': doc.reference.path,
          });
        }
      }

      // Remove duplicates based on document ID
      final uniqueDuplicates = <String, Map<String, dynamic>>{};
      for (final duplicate in duplicates) {
        final docId = duplicate['docId'] as String;
        if (!uniqueDuplicates.containsKey(docId)) {
          uniqueDuplicates[docId] = duplicate;
        }
      }

      debugPrint("📊 Fingerprint duplicate check summary:");
      debugPrint("   Total duplicate findings: ${duplicates.length}");
      debugPrint("   Unique students with duplicates: ${uniqueDuplicates.length}");

      if (uniqueDuplicates.isNotEmpty) {
        debugPrint("❌ Duplicate fingerprint enrollments found:");
        uniqueDuplicates.values.forEach((duplicate) {
          debugPrint("   - ${duplicate['student']} (${duplicate['type']})");
        });
        return true;
      }

      debugPrint("✅ No fingerprint duplicates found - fingerprint is unique");
      return false;

    } catch (e) {
      debugPrint("❌ Error during fingerprint duplicate check: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.school,
                        color: const Color(0xFF4CAF50),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Add New Student',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Adding to: ${widget.groupData['name']}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  _buildTextField(
                    controller: _rollNumberController,
                    label: 'Roll Number',
                    icon: Icons.numbers,
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter roll number' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person,
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter name' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Please enter email';
                      if (!value!.contains('@')) return 'Please enter valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone,
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter phone' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _departmentController,
                    label: 'Department',
                    icon: Icons.business,
                    enabled: false,
                    validator: (value) => null,
                  ),
                  const SizedBox(height: 24),

                  // Fingerprint Sensor Section
                  _buildFingerprintSensorSection(),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: (_isLoading || _isCapturingBiometric)
                            ? null
                            : _addStudent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Add Student',
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF4CAF50)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  Widget _buildFingerprintSensorSection() {
    if (!_isFingerprintSensorAvailable) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fingerprint, color: Colors.red.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fingerprint Sensor Unavailable',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Fingerprint sensor is not available. Students will be added without biometric enrollment.',
              style: TextStyle(color: Colors.red.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.fingerprint,
                color: _biometricCaptured ? Colors.green : const Color(0xFF4CAF50),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Fingerprint Enrollment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _biometricCaptured ? Colors.green : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _biometricCaptured
                ? 'Fingerprint enrollment completed! Quality: ${_biometricQuality ?? 0}%'
                : 'Use fingerprint sensor to enroll student biometric data for secure authentication',
            style: TextStyle(
              color: _biometricCaptured ? Colors.green : Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),

          if (_isCapturingBiometric) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  SizedBox(height: 12),
                  Text(
                    'Fingerprint enrollment in progress...\nPlease place finger on sensor',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _biometricCaptured ? null : _startFingerprintEnrollment,
                icon: Icon(
                  _biometricCaptured ? Icons.check_circle : Icons.fingerprint,
                  color: Colors.white,
                ),
                label: Text(
                  _biometricCaptured
                      ? 'Enrollment Completed'
                      : 'Start Fingerprint Enrollment',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _biometricCaptured ? Colors.green : const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],

          if (_biometricCaptured) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fingerprint enrollment successful with ${_biometricQuality ?? 0}% quality',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startFingerprintEnrollment() async {
    setState(() => _isCapturingBiometric = true);
    
    try {
      debugPrint("🔄 Starting fingerprint enrollment process...");
      
      // Initialize fingerprint sensor for enrollment
      final initialized = await BiometricService.initializeScannerForCapture();
      if (!initialized) {
        _showErrorMessage('Failed to initialize fingerprint sensor');
        return;
      }
      
      debugPrint("✅ Fingerprint sensor initialized for enrollment");

      final studentName = _nameController.text.isNotEmpty ? _nameController.text : 'Student';

      // Use fingerprint sensor enrollment with quality checking
      final result = await BiometricService.captureForEnrollment(studentName);
      
      if (!(result['success'] ?? false)) {
        _showErrorMessage(result['error'] ?? 'Fingerprint enrollment failed');
        return;
      }

      // Extract enrollment data
      final template = (result['template'] as String?) ?? '';
      final fingerprintData = (result['fingerprintData'] as String?) ?? '';
      final quality = (result['quality'] as int?) ?? 0;

      debugPrint("📊 Fingerprint Enrollment Results:");
      debugPrint("   Template length: ${template.length}");
      debugPrint("   FingerprintData length: ${fingerprintData.length}");
      debugPrint("   Quality: $quality%");

      // Generate consistent hashes for fingerprint data
      final templateBytes = utf8.encode(template);
      final templateHash = sha256.convert(templateBytes).toString();
      
      final dataBytes = utf8.encode(fingerprintData);
      final dataHash = sha256.convert(dataBytes).toString();
      
      final biometricHash = templateHash; // Primary hash for fingerprint matching

      debugPrint("🔐 Generated Hashes for Fingerprint:");
      debugPrint("   Template Hash: $templateHash");
      debugPrint("   Data Hash: $dataHash");
      debugPrint("   Biometric Hash: $biometricHash");

      // Comprehensive duplicate check for fingerprint enrollments
      if (await _isFingerprintDuplicate(template, templateHash, biometricHash)) {
        _showErrorMessage('This fingerprint is already enrolled with another student!');
        return;
      }

      // Quality validation for fingerprint sensor
      if (quality < 40) {
        _showErrorMessage('Fingerprint enrollment quality too low ($quality%), please try again');
        return;
      }

      // Device ID
      final deviceId = await BiometricService.getDeviceId();

      debugPrint("🔧 Device ID: $deviceId");

      setState(() {
        _biometricTemplate = template;
        _fingerprintData = fingerprintData;
        _biometricQuality = quality;
        _deviceId = deviceId;
        _biometricCaptured = true;
        
        // Store fingerprint hash data
        _biometricHash = biometricHash;
        _fingerprintHash = templateHash;
        _fingerprintDataHash = dataHash;
      });

      _showSuccessMessage('Fingerprint enrollment completed successfully! Quality: $quality%');
      debugPrint("🎉 Fingerprint enrollment completed successfully");
      
    } catch (e) {
      debugPrint("❌ Error during fingerprint enrollment: $e");
      _showErrorMessage('Error during fingerprint enrollment: $e');
      setState(() => _biometricCaptured = false);
    } finally {
      setState(() => _isCapturingBiometric = false);
    }
  }

  void _addStudent() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Check if roll number already exists
        final existingStudents = await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('students')
            .where('rollNumber', isEqualTo: _rollNumberController.text)
            .get();

        if (existingStudents.docs.isNotEmpty) {
          _showErrorMessage('Student with this roll number already exists');
          return;
        }

        // Check if email already exists
        final existingEmails = await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('students')
            .where('email', isEqualTo: _emailController.text)
            .get();

        if (existingEmails.docs.isNotEmpty) {
          _showErrorMessage('Student with this email already exists');
          return;
        }

        // Prepare student data with fingerprint information
        final studentData = {
          'rollNumber': _rollNumberController.text,
          'name': _nameController.text,
          'email': _emailController.text,
          'phone': _phoneController.text,
          'department': _departmentController.text,
          'biometricRegistered': _biometricCaptured,
          'enrollmentMode': _biometricCaptured ? 'external_scanner' : 'manual',
          'createdAt': FieldValue.serverTimestamp(),
          'groupId': widget.groupId,
          'groupName': widget.groupData['name'],
        };

        // Add fingerprint enrollment data if captured
        if (_biometricCaptured && _biometricTemplate != null) {
          studentData.addAll({
            'fingerprintTemplate': _biometricTemplate!,
            'fingerprintData': _fingerprintData ?? '',
            'biometricQuality': _biometricQuality ?? 0,
            'registrationDeviceId': _deviceId ?? 'unknown',
            'biometricRegisteredAt': FieldValue.serverTimestamp(),
            'biometricVersion': '3.0',
            'hashingMethod': 'SHA-256',
            'biometricHash': _biometricHash,
            'fingerprintHash': _fingerprintHash,
            'fingerprintDataHash': _fingerprintDataHash,
            'templateLength': _biometricTemplate!.length,
            'dataLength': (_fingerprintData ?? '').length,
            'enrollmentMode': 'external_scanner',
            'scannerType': 'built_in_fingerprint_sensor',
          });
        }

        // Add student to group's students collection
        final docRef = await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('students')
            .add(studentData);

        // Also add to global students collection with the same document ID
        studentData['id'] = docRef.id;
        await FirebaseFirestore.instance
            .collection('students')
            .doc(docRef.id)
            .set(studentData);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _biometricCaptured
                    ? 'Student added successfully with fingerprint enrollment!'
                    : 'Student added successfully!',
              ),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
        }
      } catch (e) {
        _showErrorMessage('Error adding student: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _rollNumberController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    super.dispose();
  }
}