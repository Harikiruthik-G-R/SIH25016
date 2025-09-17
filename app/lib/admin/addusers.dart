import 'package:GeoAt/services/biometricservices.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel_pkg;

class AddUsersScreen extends StatefulWidget {
  final Map<String, dynamic> groupData;

  const AddUsersScreen({super.key, required this.groupData});

  @override
  State<AddUsersScreen> createState() => _AddUsersScreenState();
}

class _AddUsersScreenState extends State<AddUsersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isLoading = true;
  bool _isRegistering = false;
  String? _registeringStudentId;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _checkInitialLoad();
  }

  void _checkInitialLoad() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.groupData['name']} Students',
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              '${widget.groupData['department']} Department',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _showBulkUploadDialog(),
            icon: const Icon(Icons.upload_file),
            tooltip: 'Bulk Upload CSV/Excel',
          ),
          IconButton(
            onPressed: () => _showAddStudentDialog(),
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Student',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF0F8F0)],
          ),
        ),
        child:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                )
                : Column(
                  children: [
                    _buildClassroomInfoCard(),
                    Expanded(child: _buildStudentsList()),
                  ],
                ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddStudentDialog(),
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildClassroomInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.school, color: Color(0xFF4CAF50)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.groupData['name'] ?? 'Classroom',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.groupData['department']} Department',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(
                Icons.people,
                'Max: ${widget.groupData['maxStudents']}',
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                Icons.access_time,
                '${widget.groupData['totalHours']}h',
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                Icons.coffee,
                '${widget.groupData['breakTime']}min',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF4CAF50)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF4CAF50),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('groups')
              .doc(widget.groupData['id'])
              .collection('students')
              .orderBy('rollNumber')
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
          );
        }

        final students = snapshot.data?.docs ?? [];

        if (students.isEmpty) {
          return _buildEmptyStudentsState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final studentDoc = students[index];
              final studentData = studentDoc.data() as Map<String, dynamic>;
              studentData['id'] = studentDoc.id;
              return _buildStudentCard(studentData);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyStudentsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Students Added',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add students with biometric registration to start managing this classroom.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showAddStudentDialog(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Student',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Error Loading Students',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    String getInitials(String name) {
      List<String> nameParts = name.trim().split(' ');
      if (nameParts.length >= 2) {
        return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
      } else {
        return name.isNotEmpty ? name[0].toUpperCase() : 'S';
      }
    }

    bool isRegistered = student['biometricRegistered'] == true;
    bool isThisStudentRegistering =
        _isRegistering && _registeringStudentId == student['id'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF2196F3).withOpacity(0.1),
              child: Text(
                getInitials(student['name'] ?? 'Student'),
                style: const TextStyle(
                  color: Color(0xFF2196F3),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          student['name'] ?? 'Unknown Student',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Roll: ${student['rollNumber'] ?? 'N/A'}',
                          style: const TextStyle(
                            color: Color(0xFF4CAF50),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    student['email'] ?? 'No email',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (student['phone'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      student['phone'],
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    student['department'] ?? 'Computer Science and Engineering',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  // Biometric status
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isRegistered ? Icons.check_circle : Icons.warning,
                        size: 14,
                        color: isRegistered ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isRegistered
                            ? 'Biometric Registered'
                            : 'Biometric Not Registered',
                        style: TextStyle(
                          fontSize: 12,
                          color: isRegistered ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                // Biometric status icon
                if (isThisStudentRegistering) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                  ),
                ] else ...[
                  GestureDetector(
                    onTap:
                        isRegistered ? null : () => _registerBiometric(student),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            isRegistered
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            !isRegistered
                                ? Border.all(color: Colors.orange, width: 1)
                                : null,
                      ),
                      child: Icon(
                        isRegistered
                            ? Icons.fingerprint
                            : Icons.fingerprint_outlined,
                        color: isRegistered ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // Action button for non-registered students
                if (!isRegistered && !isThisStudentRegistering) ...[
                  SizedBox(
                    width: 80,
                    height: 28,
                    child: ElevatedButton(
                      onPressed: () => _registerBiometric(student),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        'Register',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                // Menu button
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        if (isRegistered)
                          const PopupMenuItem(
                            value: 'reregister',
                            child: Text('Re-register Biometric'),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                  onSelected: (value) async {
                    switch (value) {
                      case 'edit':
                        _showEditStudentDialog(student);
                        break;
                      case 'reregister':
                        _registerBiometric(student, isReregistration: true);
                        break;
                      case 'delete':
                        _showDeleteStudentConfirmation(
                          student['id'],
                          student['name'],
                        );
                        break;
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Biometric registration method
  // Merged biometric registration method
  // Merged biometric registration method
  Future<void> _registerBiometric(
    Map<String, dynamic> student, {
    bool isReregistration = false,
  }) async {
    try {
      setState(() {
        _isRegistering = true;
        _registeringStudentId = student['id'];
      });

      // Show initial loading dialog
      _showLoadingDialog('Initializing...', 'Preparing biometric scanner');

      // Check if scanner is available
      bool isAvailable = await BiometricService.isScannerAvailable();
      if (!isAvailable) {
        Navigator.pop(context);
        _showErrorSnackBar("Biometric scanner not available on this device");
        return;
      }

      // Initialize scanner
      bool initialized = await BiometricService.initializeScanner();
      if (!initialized) {
        Navigator.pop(context);
        _showErrorSnackBar("Failed to initialize biometric scanner");
        return;
      }

      // Update dialog for fingerprint capture
      Navigator.pop(context);
      _showFingerprintCaptureDialog(student['name'] ?? 'Student');

      // Capture fingerprint using BiometricService
      final result = await BiometricService.captureFingerprint(
        student['name'] ?? 'Student',
      );

      // Close fingerprint dialog
      Navigator.pop(context);

      if (!(result['success'] ?? false)) {
        _showErrorSnackBar(result['error'] ?? "Fingerprint capture failed");
        return;
      }

      // Extract data from result
      final String template = result['template'] ?? '';
      final String fingerprintData = result['fingerprintData'] ?? '';
      final int quality = result['quality'] ?? 0;
      final String deviceId = await BiometricService.getDeviceId();

      // Show processing dialog
      _showLoadingDialog(
        'Processing fingerprint...',
        'Checking for duplicates',
      );

      // Check for duplicate fingerprints in Firestore (global check)
      final duplicateCheck =
          await FirebaseFirestore.instance
              .collection('students')
              .where('fingerprintTemplate', isEqualTo: template)
              .get();

      // If re-registration, exclude current student from duplicate check
      bool isDuplicate = false;
      if (duplicateCheck.docs.isNotEmpty) {
        if (isReregistration) {
          // For re-registration, check if any other student (not current) has this template
          isDuplicate = duplicateCheck.docs.any(
            (doc) => doc.id != student['id'],
          );
        } else {
          isDuplicate = true;
        }
      }

      if (isDuplicate) {
        Navigator.pop(context);
        _showErrorSnackBar(
          "Fingerprint already registered to another student!",
        );
        return;
      }

      // Update dialog for saving
      Navigator.pop(context);
      _showLoadingDialog(
        'Saving biometric data...',
        'Storing in cloud database',
      );

      // Save fingerprint template in Firestore
      // First, update the group's students subcollection (this should always exist)
      await _firestore
          .collection('groups')
          .doc(widget.groupData['id'])
          .collection('students')
          .doc(student['id'])
          .update({
            'biometricRegistered': true,
            'fingerprintTemplate': template,
            'fingerprintData': fingerprintData,
            'biometricQuality': quality,
            'registrationDeviceId': deviceId,
            'biometricRegisteredAt': FieldValue.serverTimestamp(),
            'biometricVersion': '1.0',
          });

      // Check if global student document exists, create or update accordingly
      final globalStudentDoc =
          await FirebaseFirestore.instance
              .collection('students')
              .doc(student['id'])
              .get();

      final biometricData = {
        'biometricRegistered': true,
        'fingerprintTemplate': template,
        'fingerprintData': fingerprintData,
        'biometricQuality': quality,
        'registrationDeviceId': deviceId,
        'biometricRegisteredAt': FieldValue.serverTimestamp(),
        'biometricVersion': '1.0',
      };

      if (globalStudentDoc.exists) {
        // Document exists, update it
        await FirebaseFirestore.instance
            .collection('students')
            .doc(student['id'])
            .update(biometricData);
      } else {
        // Document doesn't exist, create it with student data + biometric data
        await FirebaseFirestore.instance
            .collection('students')
            .doc(student['id'])
            .set({
              ...student, // Include all student data
              ...biometricData, // Add biometric data
              'createdAt': FieldValue.serverTimestamp(),
            });
      }

      Navigator.pop(context);

      // Show success message
      _showSuccessSnackBar(
        isReregistration
            ? "${student['name']} biometric re-registered successfully!"
            : "${student['name']} biometric registered successfully!",
      );
    } catch (e) {
      // Close any open dialogs
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showErrorSnackBar(
        "Error during biometric registration: ${e.toString()}",
      );
    } finally {
      setState(() {
        _isRegistering = false;
        _registeringStudentId = null;
      });
    }
  }

  // Enhanced loading dialog
  void _showLoadingDialog(String title, String subtitle) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF4CAF50)),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  // Fingerprint capture dialog
  void _showFingerprintCaptureDialog(String studentName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fingerprint,
                  size: 64,
                  color: Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Fingerprint Registration',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Registering fingerprint for $studentName',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Place finger on the sensor when prompted',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
  // Enhanced loading dialog

  // Fingerprint capture dialog

  // Generate a simulated fingerprint hash

  // Check for duplicate fingerprints
  Future<bool> _checkForDuplicateFingerprint(
    String fingerprintHash,
    String currentStudentId,
    bool isReregistration,
  ) async {
    try {
      // Query all students in the group to check for duplicate fingerprints
      final QuerySnapshot studentsSnapshot =
          await _firestore
              .collection('groups')
              .doc(widget.groupData['id'])
              .collection('students')
              .where('biometricRegistered', isEqualTo: true)
              .get();

      for (var doc in studentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Skip current student if it's a re-registration
        if (isReregistration && doc.id == currentStudentId) {
          continue;
        }

        // Check if fingerprint hash matches
        if (data['fingerprintHash'] == fingerprintHash) {
          return true; // Duplicate found
        }

        // Additional check for similar fingerprint patterns (simulated)
        if (data['fingerprintHash'] != null) {
          double similarity = _calculateFingerprintSimilarity(
            fingerprintHash,
            data['fingerprintHash'],
          );
          if (similarity > 0.85) {
            // 85% similarity threshold
            return true;
          }
        }
      }

      return false; // No duplicate found
    } catch (e) {
      print('Error checking for duplicate fingerprint: $e');
      return false;
    }
  }

  // Calculate fingerprint similarity (simulated)
  double _calculateFingerprintSimilarity(String hash1, String hash2) {
    if (hash1.length != hash2.length) return 0.0;

    int matches = 0;
    for (int i = 0; i < hash1.length; i++) {
      if (hash1[i] == hash2[i]) {
        matches++;
      }
    }

    return matches / hash1.length;
  }

  // Save biometric data to Firestore

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showBulkUploadDialog() {
    // Ensure we have valid group data
    final String groupId = widget.groupData['id'] ?? 'demo_group';
    final Map<String, dynamic> groupData =
        widget.groupData.isEmpty
            ? {'id': 'demo_group', 'name': 'Demo Classroom'}
            : widget.groupData;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // Force new instance creation
        return EnhancedBulkUploadDialog(
          key: ValueKey('bulk_upload_${DateTime.now().millisecondsSinceEpoch}'),
          groupId: groupId,
          groupData: groupData,
        );
      },
    );
  }

  void _showAddStudentDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AddStudentDialog(
            groupId: widget.groupData['id'],
            groupData: widget.groupData,
          ),
    );
  }

  void _showEditStudentDialog(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder:
          (context) => EditStudentDialog(
            groupId: widget.groupData['id'],
            groupData: widget.groupData,
            student: student,
          ),
    );
  }

  void _showDeleteStudentConfirmation(String studentId, String studentName) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Student'),
            content: Text(
              'Are you sure you want to remove $studentName from this classroom?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  _deleteStudent(studentId);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _deleteStudent(String studentId) async {
    try {
      await _firestore
          .collection('groups')
          .doc(widget.groupData['id'])
          .collection('students')
          .doc(studentId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student removed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error removing student: $e')));
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

// Placeholder classes for the dialogs (you mentioned you already have these)
class BulkUploadDialog extends StatefulWidget {
  final String groupId;
  final Map<String, dynamic> groupData;

  const BulkUploadDialog({
    super.key,
    required this.groupId,
    required this.groupData,
  });

  @override
  State<BulkUploadDialog> createState() => _BulkUploadDialogState();
}

class _BulkUploadDialogState extends State<BulkUploadDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bulk Upload'),
      content: const Text('Bulk upload dialog implementation goes here'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

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
  bool _isScannerAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await BiometricService.isScannerAvailable();
      setState(() {
        _isScannerAvailable = isAvailable;
      });

      if (!isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Biometric scanner is not available on this device',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking biometric availability: $e');
      setState(() {
        _isScannerAvailable = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Biometric features disabled. Students can still be added manually.',
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
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
                    validator:
                        (value) =>
                            value?.isEmpty ?? true
                                ? 'Please enter roll number'
                                : null,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person,
                    validator:
                        (value) =>
                            value?.isEmpty ?? true ? 'Please enter name' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Please enter email';
                      if (!value!.contains('@')) {
                        return 'Please enter valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone,
                    validator:
                        (value) =>
                            value?.isEmpty ?? true
                                ? 'Please enter phone'
                                : null,
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

                  // Biometric Section
                  _buildBiometricSection(),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed:
                            (_isLoading ||
                                    (_isScannerAvailable &&
                                        !_biometricCaptured))
                                ? null
                                : _addStudent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                        ),
                        child:
                            _isLoading
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

  Widget _buildBiometricSection() {
    if (!_isScannerAvailable) {
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
                Icon(Icons.warning, color: Colors.red.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Biometric Scanner Unavailable',
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
              'Biometric scanner is not available on this device. Students will be added without biometric registration.',
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
                color:
                    _biometricCaptured ? Colors.green : const Color(0xFF4CAF50),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Biometric Registration',
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
                ? 'Biometric data captured successfully! Quality: ${_biometricQuality ?? 0}%'
                : 'Capture fingerprint for secure student identification',
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
              child: Column(
                children: [
                  const CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  const SizedBox(height: 12),
                  const Text(
                    'Capturing fingerprint...\nPlease place finger on scanner when prompted',
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
                onPressed: _biometricCaptured ? null : _startBiometricCapture,
                icon: Icon(
                  _biometricCaptured ? Icons.check_circle : Icons.fingerprint,
                  color: Colors.white,
                ),
                label: Text(
                  _biometricCaptured
                      ? 'Biometric Registered'
                      : 'Capture Fingerprint',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _biometricCaptured
                          ? Colors.green
                          : const Color(0xFF4CAF50),
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
                      'Fingerprint captured with ${_biometricQuality ?? 0}% quality',
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

  Future<void> _startBiometricCapture() async {
    setState(() {
      _isCapturingBiometric = true;
    });

    try {
      // Initialize scanner
      bool initialized = await BiometricService.initializeScanner();
      if (!initialized) {
        _showErrorMessage('Failed to initialize biometric scanner');
        return;
      }

      // Capture fingerprint
      final result = await BiometricService.captureFingerprint(
        _nameController.text.isNotEmpty ? _nameController.text : 'Student',
      );

      if (!(result['success'] ?? false)) {
        _showErrorMessage(result['error'] ?? 'Fingerprint capture failed');
        return;
      }

      // Check for duplicates before accepting the fingerprint
      final String template = result['template'] ?? '';
      if (template.isNotEmpty) {
        bool isDuplicate = await _checkForDuplicateFingerprint(template);
        if (isDuplicate) {
          _showErrorMessage(
            'This fingerprint is already registered to another student!',
          );
          return;
        }
      }

      // Get device ID
      final deviceId = await BiometricService.getDeviceId();

      setState(() {
        _biometricTemplate = template;
        _fingerprintData = result['fingerprintData'] ?? '';
        _biometricQuality = result['quality'] ?? 0;
        _deviceId = deviceId;
        _biometricCaptured = true;
      });

      _showSuccessMessage('Biometric registration completed successfully!');
    } catch (e) {
      _showErrorMessage('Error during biometric capture: $e');
    } finally {
      setState(() {
        _isCapturingBiometric = false;
      });
    }
  }

  Future<bool> _checkForDuplicateFingerprint(String template) async {
    try {
      // Check in current group's students
      final groupStudents =
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .collection('students')
              .where('biometricRegistered', isEqualTo: true)
              .get();

      for (var doc in groupStudents.docs) {
        final data = doc.data();
        if (data['fingerprintTemplate'] == template) {
          return true;
        }

        // Additional similarity check using BiometricService if available
        if (data['fingerprintTemplate'] != null) {
          final verifyResult = await BiometricService.verifyFingerprint(
            data['fingerprintTemplate'],
            template,
          );

          double confidence = verifyResult['confidence'] ?? 0.0;
          if (confidence > 0.85) {
            return true;
          }
        }
      }

      // Check global students collection
      final globalStudents =
          await FirebaseFirestore.instance
              .collection('students')
              .where('fingerprintTemplate', isEqualTo: template)
              .get();

      return globalStudents.docs.isNotEmpty;
    } catch (e) {
      print('Error checking for duplicate fingerprint: $e');
      return false;
    }
  }

  void _addStudent() async {
    if (_formKey.currentState!.validate()) {
      if (_isScannerAvailable && !_biometricCaptured) {
        _showErrorMessage('Please complete biometric registration first');
        return;
      }

      setState(() => _isLoading = true);

      try {
        // Check if roll number already exists
        final existingStudents =
            await FirebaseFirestore.instance
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
        final existingEmails =
            await FirebaseFirestore.instance
                .collection('groups')
                .doc(widget.groupId)
                .collection('students')
                .where('email', isEqualTo: _emailController.text)
                .get();

        if (existingEmails.docs.isNotEmpty) {
          _showErrorMessage('Student with this email already exists');
          return;
        }

        // Prepare student data
        final studentData = {
          'rollNumber': _rollNumberController.text,
          'name': _nameController.text,
          'email': _emailController.text,
          'phone': _phoneController.text,
          'department': _departmentController.text,
          'biometricRegistered': _biometricCaptured,
          'createdAt': FieldValue.serverTimestamp(),
          'groupId': widget.groupId,
          'groupName': widget.groupData['name'],
        };

        // Add biometric data if captured
        if (_biometricCaptured && _biometricTemplate != null) {
          studentData.addAll({
            'fingerprintTemplate': _biometricTemplate!,
            'fingerprintData': _fingerprintData ?? '',
            'biometricQuality': _biometricQuality ?? 0,
            'registrationDeviceId': _deviceId ?? 'unknown',
            'biometricRegisteredAt': FieldValue.serverTimestamp(),
            'biometricVersion': '1.0',
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
                    ? 'Student added successfully with biometric registration!'
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

// Edit Student Dialog
class EditStudentDialog extends StatefulWidget {
  final String groupId;
  final Map<String, dynamic> groupData;
  final Map<String, dynamic> student;

  const EditStudentDialog({
    super.key,
    required this.groupId,
    required this.groupData,
    required this.student,
  });

  @override
  State<EditStudentDialog> createState() => _EditStudentDialogState();
}

class _EditStudentDialogState extends State<EditStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _rollNumberController;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _departmentController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _rollNumberController = TextEditingController(
      text: widget.student['rollNumber'],
    );
    _nameController = TextEditingController(text: widget.student['name']);
    _emailController = TextEditingController(text: widget.student['email']);
    _phoneController = TextEditingController(text: widget.student['phone']);
    _departmentController = TextEditingController(
      text: widget.student['department'] ?? 'Computer Science and Engineering',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
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
                        Icons.edit,
                        color: const Color(0xFF4CAF50),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Edit Student',
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
                    'Editing: ${widget.student['name']}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  _buildTextField(
                    controller: _rollNumberController,
                    label: 'Roll Number',
                    icon: Icons.numbers,
                    validator:
                        (value) =>
                            value?.isEmpty ?? true
                                ? 'Please enter roll number'
                                : null,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person,
                    validator:
                        (value) =>
                            value?.isEmpty ?? true ? 'Please enter name' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Please enter email';
                      if (!value!.contains('@')) {
                        return 'Please enter valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone,
                    validator:
                        (value) =>
                            value?.isEmpty ?? true
                                ? 'Please enter phone'
                                : null,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _departmentController,
                    label: 'Department',
                    icon: Icons.business,
                    enabled: false,
                    validator: (value) => null,
                  ),
                  const SizedBox(height: 16),

                  // Biometric Status
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.fingerprint, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text(
                          'Biometric Registered',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Registered',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _updateStudent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                        ),
                        child:
                            _isLoading
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text(
                                  'Update',
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

  void _updateStudent() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Check if roll number already exists (excluding current student)
        final existingRollNumbers =
            await FirebaseFirestore.instance
                .collection('groups')
                .doc(widget.groupId)
                .collection('students')
                .where('rollNumber', isEqualTo: _rollNumberController.text)
                .get();

        final conflictingRollNumber =
            existingRollNumbers.docs
                .where((doc) => doc.id != widget.student['id'])
                .isNotEmpty;

        if (conflictingRollNumber) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Another student with this roll number already exists',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Check if email already exists (excluding current student)
        final existingEmails =
            await FirebaseFirestore.instance
                .collection('groups')
                .doc(widget.groupId)
                .collection('students')
                .where('email', isEqualTo: _emailController.text)
                .get();

        final conflictingEmail =
            existingEmails.docs
                .where((doc) => doc.id != widget.student['id'])
                .isNotEmpty;

        if (conflictingEmail) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Another student with this email already exists'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Update student in Firestore
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('students')
            .doc(widget.student['id'])
            .update({
              'rollNumber': _rollNumberController.text,
              'name': _nameController.text,
              'email': _emailController.text,
              'phone': _phoneController.text,
              'department': _departmentController.text,
              'updatedAt': FieldValue.serverTimestamp(),
            });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Student updated successfully!'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating student: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
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

// Enhanced Bulk Upload Dialog with improved UI
class EnhancedBulkUploadDialog extends StatefulWidget {
  final String groupId;
  final Map<String, dynamic> groupData;

  const EnhancedBulkUploadDialog({
    super.key,
    required this.groupId,
    required this.groupData,
  });

  @override
  State<EnhancedBulkUploadDialog> createState() =>
      _EnhancedBulkUploadDialogState();
}

class _EnhancedBulkUploadDialogState extends State<EnhancedBulkUploadDialog>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _isUploading = false;
  String? _selectedFileName;
  List<Map<String, dynamic>> _parsedStudents = [];
  bool _fileProcessed = false;
  int _currentStep = 0;

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildStepIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _buildCurrentStepContent(),
                ),
              ),
              _buildActionBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.cloud_upload_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bulk Student Upload (Enhanced)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add multiple students to ${widget.groupData['name']}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _buildStepItem(0, 'Choose File', Icons.folder_open_rounded),
          _buildStepConnector(0),
          _buildStepItem(1, 'Preview', Icons.preview_rounded),
          _buildStepConnector(1),
          _buildStepItem(2, 'Upload', Icons.upload_rounded),
        ],
      ),
    );
  }

  Widget _buildStepItem(int step, String title, IconData icon) {
    final bool isActive = step == _currentStep;
    final bool isCompleted = step < _currentStep;

    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  isCompleted
                      ? const Color(0xFF4CAF50)
                      : isActive
                      ? const Color(0xFF4CAF50)
                      : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive ? const Color(0xFF4CAF50) : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(
              isCompleted ? Icons.check_rounded : icon,
              color: isActive || isCompleted ? Colors.white : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? const Color(0xFF4CAF50) : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int step) {
    final bool isCompleted = step < _currentStep;

    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 30),
        decoration: BoxDecoration(
          color: isCompleted ? const Color(0xFF4CAF50) : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildFileSelectionStep();
      case 1:
        return _buildPreviewStep();
      case 2:
        return _buildUploadStep();
      default:
        return _buildFileSelectionStep();
    }
  }

  Widget _buildFileSelectionStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFileFormatInfo(),
        const SizedBox(height: 24),
        Flexible(child: _buildFileDropZone()),
      ],
    );
  }

  Widget _buildFileFormatInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade50, Colors.indigo.shade50],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'File Format Requirements',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRequirementItem('Roll Number', true, 'Student identification'),
          _buildRequirementItem('Name', true, 'Full student name'),
          _buildRequirementItem('Email', true, 'Valid email address'),
          _buildRequirementItem('Phone', true, 'Contact number'),
          _buildRequirementItem('Department', false, 'Defaults to CSE'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber.shade700,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Students will be added without biometric registration',
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(
    String field,
    bool required,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: required ? Colors.red.shade400 : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              field,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          Chip(
            label: Text(
              required ? 'Required' : 'Optional',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: required ? Colors.red.shade700 : Colors.grey.shade600,
              ),
            ),
            backgroundColor:
                required ? Colors.red.shade50 : Colors.grey.shade100,
            side: BorderSide(
              color: required ? Colors.red.shade200 : Colors.grey.shade300,
              width: 1,
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileDropZone() {
    return GestureDetector(
      onTap: _isLoading ? null : _selectFile,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(
            color:
                _selectedFileName != null
                    ? const Color(0xFF4CAF50)
                    : Colors.grey.shade300,
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(16),
          color:
              _selectedFileName != null
                  ? const Color(0xFF4CAF50).withOpacity(0.05)
                  : Colors.grey.shade50,
        ),
        child:
            _isLoading
                ? _buildLoadingState()
                : _selectedFileName != null
                ? _buildSelectedFileState()
                : _buildEmptyState(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_upload_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Drag & Drop your file here',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'or click to browse',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Supports: CSV, XLSX, XLS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedFileState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _selectedFileName!.endsWith('.csv')
                  ? Icons.description_rounded
                  : Icons.table_chart_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _selectedFileName!,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          if (_fileProcessed) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_parsedStudents.length} students found',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _selectFile,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Choose Different File'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4CAF50),
              side: const BorderSide(color: Color(0xFF4CAF50)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.all(60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF4CAF50), strokeWidth: 3),
          SizedBox(height: 24),
          Text(
            'Processing file...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFileName = result.files.single.name;
          _isLoading = true;
          _fileProcessed = false;
          _parsedStudents = [];
        });

        await _processFile(result.files.single.path!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processFile(String filePath) async {
    try {
      List<Map<String, dynamic>> students = [];

      if (filePath.endsWith('.csv')) {
        students = await _parseCSV(filePath);
      } else if (filePath.endsWith('.xlsx') || filePath.endsWith('.xls')) {
        students = await _parseExcel(filePath);
      }

      setState(() {
        _parsedStudents = students;
        _fileProcessed = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _fileProcessed = true;
        _parsedStudents = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _parseCSV(String filePath) async {
    final file = File(filePath);
    final csvString = await file.readAsString();
    final csvData = const CsvToListConverter().convert(csvString);

    if (csvData.isEmpty) throw Exception('CSV file is empty');

    final headers =
        csvData[0].map((h) => h.toString().toLowerCase().trim()).toList();
    final students = <Map<String, dynamic>>[];

    for (int i = 1; i < csvData.length; i++) {
      final row = csvData[i];
      if (row.isEmpty) continue;

      final student = <String, dynamic>{};
      for (int j = 0; j < headers.length && j < row.length; j++) {
        final header = headers[j];
        final value = row[j]?.toString().trim() ?? '';

        if (header.contains('roll')) {
          student['rollNumber'] = value;
        } else if (header.contains('name')) {
          student['name'] = value;
        } else if (header.contains('email')) {
          student['email'] = value;
        } else if (header.contains('phone')) {
          student['phone'] = value;
        } else if (header.contains('department')) {
          student['department'] = value;
        }
      }

      // Validate required fields
      if (student['rollNumber']?.isNotEmpty == true &&
          student['name']?.isNotEmpty == true &&
          student['email']?.isNotEmpty == true &&
          student['phone']?.isNotEmpty == true) {
        student['department'] ??= 'Computer Science and Engineering';
        students.add(student);
      }
    }

    return students;
  }

  Future<List<Map<String, dynamic>>> _parseExcel(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    final excel = excel_pkg.Excel.decodeBytes(bytes);
    final students = <Map<String, dynamic>>[];

    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null || sheet.rows.isEmpty) continue;

      final headers =
          sheet.rows[0]
              .map((cell) => cell?.value?.toString().toLowerCase().trim() ?? '')
              .toList();

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty) continue;

        final student = <String, dynamic>{};
        for (int j = 0; j < headers.length && j < row.length; j++) {
          final header = headers[j];
          final value = row[j]?.value?.toString().trim() ?? '';

          if (header.contains('roll')) {
            student['rollNumber'] = value;
          } else if (header.contains('name')) {
            student['name'] = value;
          } else if (header.contains('email')) {
            student['email'] = value;
          } else if (header.contains('phone')) {
            student['phone'] = value;
          } else if (header.contains('department')) {
            student['department'] = value;
          }
        }

        // Validate required fields
        if (student['rollNumber']?.isNotEmpty == true &&
            student['name']?.isNotEmpty == true &&
            student['email']?.isNotEmpty == true &&
            student['phone']?.isNotEmpty == true) {
          student['department'] ??= 'Computer Science and Engineering';
          students.add(student);
        }
      }

      // Process only the first sheet
      break;
    }

    return students;
  }

  Widget _buildPreviewStep() {
    if (!_fileProcessed || _parsedStudents.isEmpty) {
      return _buildNoDataState();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPreviewHeader(),
        const SizedBox(height: 16),
        Flexible(child: _buildStudentTable()),
      ],
    );
  }

  Widget _buildPreviewHeader() {
    final validStudents =
        _parsedStudents
            .where((s) => s['errors'] == null || (s['errors'] as List).isEmpty)
            .length;
    final invalidStudents = _parsedStudents.length - validStudents;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.shade50, Colors.teal.shade50],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.preview_rounded,
                  color: Colors.green.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Preview Students',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Text(
                '${_parsedStudents.length} Total',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatChip(
                  'Valid',
                  validStudents.toString(),
                  Colors.green.shade600,
                  Colors.green.shade50,
                  Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatChip(
                  'Invalid',
                  invalidStudents.toString(),
                  Colors.red.shade600,
                  Colors.red.shade50,
                  Icons.error_outline_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
    String label,
    String value,
    Color textColor,
    Color bgColor,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 16),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTableHeader(),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _parsedStudents.length,
              itemBuilder: (context, index) {
                return _buildStudentRow(_parsedStudents[index], index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          _buildHeaderCell('Roll No', flex: 2),
          _buildHeaderCell('Name', flex: 3),
          _buildHeaderCell('Email', flex: 3),
          _buildHeaderCell('Phone', flex: 2),
          _buildHeaderCell('Department', flex: 2),
          _buildHeaderCell('Status', flex: 2),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String title, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildStudentRow(Map<String, dynamic> student, int index) {
    final errors = student['errors'] as List<String>? ?? [];
    final hasErrors = errors.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildDataCell(student['rollNumber']?.toString() ?? '', flex: 2),
              _buildDataCell(student['name']?.toString() ?? '', flex: 3),
              _buildDataCell(student['email']?.toString() ?? '', flex: 3),
              _buildDataCell(student['phone']?.toString() ?? '', flex: 2),
              _buildDataCell(
                student['department']?.toString() ?? 'CSE',
                flex: 2,
              ),
              Expanded(flex: 2, child: _buildStatusChip(hasErrors)),
            ],
          ),
          if (hasErrors) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      errors.join(', '),
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 11,
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

  Widget _buildDataCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.black87),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildStatusChip(bool hasErrors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasErrors ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasErrors ? Colors.red.shade200 : Colors.green.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasErrors
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 12,
            color: hasErrors ? Colors.red.shade700 : Colors.green.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            hasErrors ? 'Invalid' : 'Valid',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: hasErrors ? Colors.red.shade700 : Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.table_chart_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Data to Preview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please select and process a file first',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadStep() {
    return _isUploading ? _buildUploadProgress() : _buildUploadSummary();
  }

  Widget _buildUploadProgress() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade50, Colors.green.shade50],
              ),
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                color: const Color(0xFF4CAF50),
                strokeWidth: 6,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFF4CAF50),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Uploading Students',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Processing ${_parsedStudents.length} students...',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Text(
              'Please wait while we add students to your group',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSummary() {
    final validStudents =
        _parsedStudents
            .where((s) => s['errors'] == null || (s['errors'] as List).isEmpty)
            .length;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green.shade50, Colors.teal.shade50],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_upload_outlined,
              size: 64,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Ready to Upload',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$validStudents valid students will be added to the group',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.orange.shade50, Colors.amber.shade50],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Important Notes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildUploadNote(
                  Icons.fingerprint_outlined,
                  'Students will be added without biometric registration',
                ),
                _buildUploadNote(
                  Icons.security_outlined,
                  'Biometric setup can be done individually later',
                ),
                _buildUploadNote(
                  Icons.group_outlined,
                  'All students will be added to the selected group',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadNote(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.orange.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0 && !_isUploading) ...[
            OutlinedButton.icon(
              onPressed: _previousStep,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(child: _buildPrimaryAction()),
        ],
      ),
    );
  }

  Widget _buildPrimaryAction() {
    if (_isUploading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Uploading...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    switch (_currentStep) {
      case 0:
        return ElevatedButton.icon(
          onPressed: _fileProcessed ? _nextStep : null,
          icon: const Icon(Icons.preview_rounded, color: Colors.white),
          label: const Text(
            'Preview Students',
            style: TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 2,
          ),
        );
      case 1:
        final validStudents =
            _parsedStudents
                .where(
                  (s) => s['errors'] == null || (s['errors'] as List).isEmpty,
                )
                .length;
        return ElevatedButton.icon(
          onPressed: validStudents > 0 ? _nextStep : null,
          icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          label: const Text(
            'Continue to Upload',
            style: TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 2,
          ),
        );
      case 2:
        return ElevatedButton.icon(
          onPressed: _startUpload,
          icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
          label: const Text(
            'Upload Students',
            style: TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 2,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _startUpload() async {
    setState(() {
      _isUploading = true;
    });

    try {
      int successCount = 0;
      int errorCount = 0;
      List<String> errors = [];

      final validStudents =
          _parsedStudents
              .where(
                (s) => s['errors'] == null || (s['errors'] as List).isEmpty,
              )
              .toList();

      for (final studentData in validStudents) {
        try {
          // Check for duplicates
          final existingRollNumber =
              await FirebaseFirestore.instance
                  .collection('groups')
                  .doc(widget.groupId)
                  .collection('students')
                  .where('rollNumber', isEqualTo: studentData['rollNumber'])
                  .get();

          if (existingRollNumber.docs.isNotEmpty) {
            errors.add(
              'Roll number ${studentData['rollNumber']} already exists',
            );
            errorCount++;
            continue;
          }

          final existingEmail =
              await FirebaseFirestore.instance
                  .collection('groups')
                  .doc(widget.groupId)
                  .collection('students')
                  .where('email', isEqualTo: studentData['email'])
                  .get();

          if (existingEmail.docs.isNotEmpty) {
            errors.add('Email ${studentData['email']} already exists');
            errorCount++;
            continue;
          }

          // Add student to Firestore
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .collection('students')
              .add({
                'rollNumber': studentData['rollNumber'],
                'name': studentData['name'],
                'email': studentData['email'],
                'phone': studentData['phone'],
                'department': studentData['department'],
                'biometricRegistered': false,
                'createdAt': FieldValue.serverTimestamp(),
                'groupId': widget.groupId,
                'groupName': widget.groupData['name'],
                'bulkUploaded': true,
              });

          successCount++;
        } catch (e) {
          errors.add('Error adding ${studentData['name']}: $e');
          errorCount++;
        }
      }

      // Show results dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) =>
                  _buildResultsDialog(successCount, errorCount, errors),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during upload: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildResultsDialog(
    int successCount,
    int errorCount,
    List<String> errors,
  ) {
    final bool hasErrors = errorCount > 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasErrors ? Colors.orange.shade100 : Colors.green.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              hasErrors
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline_rounded,
              color: hasErrors ? Colors.orange.shade700 : Colors.green.shade700,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Upload Complete',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green.shade50, Colors.teal.shade50],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.green.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Successfully added: $successCount students',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (hasErrors) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.red.shade50, Colors.orange.shade50],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Errors: $errorCount',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      height: 120,
                      width: double.maxFinite,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          errors.join('\n'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context); // Close results dialog
            Navigator.pop(context); // Close bulk upload dialog
          },
          icon: const Icon(Icons.check_rounded, color: Colors.white),
          label: const Text('Done', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }
}
