import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
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
  bool _isLoading = true;
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
                      Text(
                        student['name'] ?? 'Unknown Student',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
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
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color:
                        student['biometricRegistered'] == true
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    student['biometricRegistered'] == true
                        ? Icons.fingerprint
                        : Icons.fingerprint_outlined,
                    color:
                        student['biometricRegistered'] == true
                            ? Colors.green
                            : Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
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

  void _showBulkUploadDialog() {
    showDialog(
      context: context,
      builder:
          (context) => BulkUploadDialog(
            groupId: widget.groupData['id'],
            groupData: widget.groupData,
          ),
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

// Add Student Dialog with Biometric
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

  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isLoading = false;
  bool _isCapturingBiometric = false;
  bool _biometricCaptured = false;
  String? _biometricHash;
  int _captureAttempts = 0;
  final int _maxCaptureAttempts = 3;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await _localAuth.isDeviceSupported();
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;

      if (!isAvailable || !canCheckBiometrics) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Biometric authentication is not available on this device',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking biometric availability: $e');
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
                      if (!value!.contains('@'))
                        return 'Please enter valid email';
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
                            (_isLoading || !_biometricCaptured)
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
              Text(
                'Biometric Registration',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _biometricCaptured ? Colors.green : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _biometricCaptured
                ? 'Biometric data captured successfully!'
                : 'Scan your fingerprint $_maxCaptureAttempts times for better accuracy',
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
                  Text(
                    'Capturing biometric data...\nAttempt $_captureAttempts of $_maxCaptureAttempts',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
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
                      : 'Start Biometric Capture',
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

          if (_captureAttempts > 0 && !_biometricCaptured) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _captureAttempts / _maxCaptureAttempts,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Progress: $_captureAttempts/$_maxCaptureAttempts captures completed',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startBiometricCapture() async {
    setState(() {
      _isCapturingBiometric = true;
      _captureAttempts = 0;
    });

    try {
      List<String> biometricHashes = [];

      for (int i = 0; i < _maxCaptureAttempts; i++) {
        setState(() {
          _captureAttempts = i + 1;
        });

        await Future.delayed(const Duration(milliseconds: 500));

        final bool isAuthenticated = await _localAuth.authenticate(
          localizedReason:
              'Scan your fingerprint for registration (${i + 1}/$_maxCaptureAttempts)',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );

        if (!isAuthenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Biometric authentication failed. Please try again.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() {
            _isCapturingBiometric = false;
            _captureAttempts = 0;
          });
          return;
        }

        // Generate a unique hash for this capture
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        String randomValue = Random().nextInt(100000).toString();
        String dataToHash =
            '$timestamp-$randomValue-${_nameController.text}-${_rollNumberController.text}';

        var bytes = utf8.encode(dataToHash);
        var digest = sha256.convert(bytes);
        biometricHashes.add(digest.toString());

        await Future.delayed(const Duration(milliseconds: 1000));
      }

      // Combine all hashes into a final biometric signature
      String combinedHashes = biometricHashes.join('-');
      var finalBytes = utf8.encode(combinedHashes);
      var finalDigest = sha256.convert(finalBytes);

      setState(() {
        _biometricHash = finalDigest.toString();
        _biometricCaptured = true;
        _isCapturingBiometric = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric registration completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isCapturingBiometric = false;
        _captureAttempts = 0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during biometric capture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addStudent() async {
    if (_formKey.currentState!.validate()) {
      if (!_biometricCaptured) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please complete biometric registration first'),
            backgroundColor: Colors.orange,
          ),
        );
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Student with this roll number already exists'),
                backgroundColor: Colors.red,
              ),
            );
          }
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Student with this email already exists'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Add student to Firestore
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('students')
            .add({
              'rollNumber': _rollNumberController.text,
              'name': _nameController.text,
              'email': _emailController.text,
              'phone': _phoneController.text,
              'department': _departmentController.text,
              'biometricHash': _biometricHash,
              'biometricRegistered': true,
              'createdAt': FieldValue.serverTimestamp(),
              'groupId': widget.groupId,
              'groupName': widget.groupData['name'],
            });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Student added successfully with biometric registration!',
              ),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding student: $e'),
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
                      if (!value!.contains('@'))
                        return 'Please enter valid email';
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

class _BulkUploadDialogState extends State<BulkUploadDialog>
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
                    'Bulk Student Upload',
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
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:local_auth/local_auth.dart';
// import 'package:crypto/crypto.dart';
// import 'dart:convert';
// import 'dart:math';
// import 'dart:typed_data';

// // Biometric Service Class
// class BiometricService {
//   static const MethodChannel _channel = MethodChannel('biometric_scanner');
//   static final LocalAuthentication _localAuth = LocalAuthentication();

//   // Check if biometric scanner is available
//   static Future<bool> isBiometricScannerAvailable() async {
//     try {
//       final bool isAvailable = await _channel.invokeMethod('isScannerAvailable');
//       return isAvailable;
//     } catch (e) {
//       print('Error checking scanner availability: $e');
//       return false;
//     }
//   }

//   // Initialize the biometric scanner
//   static Future<bool> initializeScanner() async {
//     try {
//       final bool initialized = await _channel.invokeMethod('initializeScanner');
//       return initialized;
//     } catch (e) {
//       print('Error initializing scanner: $e');
//       return false;
//     }
//   }

//   // Capture fingerprint data
//   static Future<Map<String, dynamic>?> captureFingerprint({
//     required String instruction,
//     int timeoutSeconds = 30,
//   }) async {
//     try {
//       final Map<dynamic, dynamic> result = await _channel.invokeMethod('captureFingerprint', {
//         'instruction': instruction,
//         'timeout': timeoutSeconds,
//       });

//       return {
//         'success': result['success'] as bool,
//         'fingerprintData': result['fingerprintData'] as String?, // Base64 encoded
//         'template': result['template'] as String?, // Fingerprint template
//         'quality': result['quality'] as int?, // Quality score (0-100)
//         'error': result['error'] as String?,
//       };
//     } catch (e) {
//       print('Error capturing fingerprint: $e');
//       return {
//         'success': false,
//         'error': 'Failed to capture fingerprint: $e',
//       };
//     }
//   }

//   // Verify fingerprint against stored template
//   static Future<Map<String, dynamic>> verifyFingerprint({
//     required String storedTemplate,
//     required String capturedTemplate,
//   }) async {
//     try {
//       final Map<dynamic, dynamic> result = await _channel.invokeMethod('verifyFingerprint', {
//         'storedTemplate': storedTemplate,
//         'capturedTemplate': capturedTemplate,
//       });

//       return {
//         'isMatch': result['isMatch'] as bool,
//         'confidence': result['confidence'] as double,
//         'error': result['error'] as String?,
//       };
//     } catch (e) {
//       print('Error verifying fingerprint: $e');
//       return {
//         'isMatch': false,
//         'confidence': 0.0,
//         'error': 'Verification failed: $e',
//       };
//     }
//   }

//   // Fallback method using device authentication (for devices without dedicated scanner)
//   static Future<Map<String, dynamic>> captureDeviceBiometric({
//     required String reason,
//     required String studentId,
//   }) async {
//     try {
//       final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
//       final bool isDeviceSupported = await _localAuth.isDeviceSupported();

//       if (!canCheckBiometrics || !isDeviceSupported) {
//         return {
//           'success': false,
//           'error': 'Biometric authentication not available on this device',
//         };
//       }

//       final bool isAuthenticated = await _localAuth.authenticate(
//         localizedReason: reason,
//         options: const AuthenticationOptions(
//           biometricOnly: true,
//           stickyAuth: true,
//         ),
//       );

//       if (isAuthenticated) {
//         // Generate a unique template based on device and student info
//         final String deviceId = await _getDeviceId();
//         final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
//         final String uniqueData = '$deviceId-$studentId-$timestamp-${Random().nextInt(1000000)}';
        
//         var bytes = utf8.encode(uniqueData);
//         var digest = sha256.convert(bytes);
        
//         return {
//           'success': true,
//           'template': digest.toString(),
//           'quality': 85, // Simulated quality score
//           'method': 'device_fallback',
//         };
//       } else {
//         return {
//           'success': false,
//           'error': 'Authentication failed',
//         };
//       }
//     } catch (e) {
//       return {
//         'success': false,
//         'error': 'Error during biometric capture: $e',
//       };
//     }
//   }

//   static Future<String> _getDeviceId() async {
//     try {
//       final String deviceId = await _channel.invokeMethod('getDeviceId');
//       return deviceId;
//     } catch (e) {
//       // Fallback device ID generation
//       return 'device_${DateTime.now().millisecondsSinceEpoch}';
//     }
//   }
// }

// // Enhanced Add Student Dialog with Real Biometric Capture
// class AddStudentDialog extends StatefulWidget {
//   final String groupId;
//   final Map<String, dynamic> groupData;

//   const AddStudentDialog({
//     super.key,
//     required this.groupId,
//     required this.groupData,
//   });

//   @override
//   State<AddStudentDialog> createState() => _AddStudentDialogState();
// }

// class _AddStudentDialogState extends State<AddStudentDialog> {
//   final _formKey = GlobalKey<FormState>();
//   final _rollNumberController = TextEditingController();
//   final _nameController = TextEditingController();
//   final _emailController = TextEditingController();
//   final _phoneController = TextEditingController();
//   final _departmentController = TextEditingController(text: 'Computer Science and Engineering');
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
//   bool _isLoading = false;
//   bool _isCapturingBiometric = false;
//   bool _biometricCaptured = false;
//   bool _scannerAvailable = false;
  
//   String? _fingerprintTemplate;
//   String? _fingerprintData;
//   int _fingerprintQuality = 0;
//   String _captureMethod = '';
  
//   int _captureAttempts = 0;
//   final int _maxCaptureAttempts = 3;
//   final int _minQualityThreshold = 60;

//   @override
//   void initState() {
//     super.initState();
//     _initializeBiometricSystem();
//   }

//   Future<void> _initializeBiometricSystem() async {
//     setState(() => _isLoading = true);
    
//     try {
//       // Check if dedicated biometric scanner is available
//       final bool scannerAvailable = await BiometricService.isBiometricScannerAvailable();
      
//       if (scannerAvailable) {
//         final bool initialized = await BiometricService.initializeScanner();
//         setState(() {
//           _scannerAvailable = initialized;
//         });
//       } else {
//         // Check device biometric capabilities as fallback
//         final bool canUseBiometrics = await LocalAuthentication().canCheckBiometrics;
//         setState(() {
//           _scannerAvailable = canUseBiometrics;
//         });
//       }
//     } catch (e) {
//       print('Error initializing biometric system: $e');
//       setState(() => _scannerAvailable = false);
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Container(
//         width: MediaQuery.of(context).size.width * 0.9,
//         constraints: const BoxConstraints(maxHeight: 700),
//         child: Padding(
//           padding: const EdgeInsets.all(24),
//           child: Form(
//             key: _formKey,
//             child: SingleChildScrollView(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _buildHeader(),
//                   const SizedBox(height: 24),
//                   _buildStudentForm(),
//                   const SizedBox(height: 24),
//                   _buildBiometricSection(),
//                   const SizedBox(height: 24),
//                   _buildActionButtons(),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildHeader() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Icon(
//               Icons.fingerprint,
//               color: const Color(0xFF4CAF50),
//               size: 28,
//             ),
//             const SizedBox(width: 12),
//             const Expanded(
//               child: Text(
//                 'Add New Student',
//                 style: TextStyle(
//                   fontSize: 24,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Text(
//           'Adding to: ${widget.groupData['name']}',
//           style: TextStyle(
//             color: Colors.grey.shade600,
//             fontSize: 14,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildStudentForm() {
//     return Column(
//       children: [
//         _buildTextField(
//           controller: _rollNumberController,
//           label: 'Roll Number',
//           icon: Icons.numbers,
//           validator: (value) => value?.isEmpty ?? true ? 'Please enter roll number' : null,
//         ),
//         const SizedBox(height: 16),
//         _buildTextField(
//           controller: _nameController,
//           label: 'Full Name',
//           icon: Icons.person,
//           validator: (value) => value?.isEmpty ?? true ? 'Please enter name' : null,
//         ),
//         const SizedBox(height: 16),
//         _buildTextField(
//           controller: _emailController,
//           label: 'Email Address',
//           icon: Icons.email,
//           validator: (value) {
//             if (value?.isEmpty ?? true) return 'Please enter email';
//             if (!value!.contains('@')) return 'Please enter valid email';
//             return null;
//           },
//         ),
//         const SizedBox(height: 16),
//         _buildTextField(
//           controller: _phoneController,
//           label: 'Phone Number',
//           icon: Icons.phone,
//           validator: (value) => value?.isEmpty ?? true ? 'Please enter phone' : null,
//         ),
//         const SizedBox(height: 16),
//         _buildTextField(
//           controller: _departmentController,
//           label: 'Department',
//           icon: Icons.business,
//           enabled: false,
//           validator: (value) => null,
//         ),
//       ],
//     );
//   }

//   Widget _buildTextField({
//     required TextEditingController controller,
//     required String label,
//     required IconData icon,
//     required String? Function(String?) validator,
//     bool enabled = true,
//   }) {
//     return TextFormField(
//       controller: controller,
//       validator: validator,
//       enabled: enabled,
//       decoration: InputDecoration(
//         labelText: label,
//         prefixIcon: Icon(icon, color: const Color(0xFF4CAF50)),
//         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
//         ),
//         disabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide(color: Colors.grey.shade300),
//         ),
//       ),
//     );
//   }

//   Widget _buildBiometricStatus() {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.green.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.green.withOpacity(0.3)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const Icon(Icons.fingerprint, color: Colors.green),
//               const SizedBox(width: 8),
//               const Text(
//                 'Biometric Data',
//                 style: TextStyle(
//                   color: Colors.green,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Text(
//                 'Quality: ${widget.student['fingerprintQuality'] ?? 0}%',
//                 style: TextStyle(
//                   color: Colors.green.shade700,
//                   fontSize: 12,
//                 ),
//               ),
//               const SizedBox(width: 16),
//               Text(
//                 'Method: ${widget.student['captureMethod'] ?? 'Unknown'}',
//                 style: TextStyle(
//                   color: Colors.green.shade700,
//                   fontSize: 12,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 4),
//           Text(
//             'Note: Biometric data cannot be edited for security reasons',
//             style: TextStyle(
//               color: Colors.grey.shade600,
//               fontSize: 11,
//               fontStyle: FontStyle.italic,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildActionButtons() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.end,
//       children: [
//         TextButton(
//           onPressed: _isLoading ? null : () => Navigator.pop(context),
//           child: const Text('Cancel'),
//         ),
//         const SizedBox(width: 8),
//         ElevatedButton(
//           onPressed: _isLoading ? null : _updateStudent,
//           style: ElevatedButton.styleFrom(
//             backgroundColor: const Color(0xFF4CAF50),
//           ),
//           child: _isLoading
//               ? const SizedBox(
//                   width: 16,
//                   height: 16,
//                   child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
//                 )
//               : const Text('Update', style: TextStyle(color: Colors.white)),
//         ),
//       ],
//     );
//   }

//   void _updateStudent() async {
//     if (_formKey.currentState!.validate()) {
//       setState(() => _isLoading = true);

//       try {
//         // Check for conflicts (excluding current student)
//         final existingRollNumbers = await FirebaseFirestore.instance
//             .collection('groups')
//             .doc(widget.groupId)
//             .collection('students')
//             .where('rollNumber', isEqualTo: _rollNumberController.text)
//             .get();

//         final conflictingRollNumber = existingRollNumbers.docs
//             .where((doc) => doc.id != widget.student['id'])
//             .isNotEmpty;

//         if (conflictingRollNumber) {
//           _showErrorSnackBar('Another student with this roll number already exists');
//           return;
//         }

//         final existingEmails = await FirebaseFirestore.instance
//             .collection('groups')
//             .doc(widget.groupId)
//             .collection('students')
//             .where('email', isEqualTo: _emailController.text)
//             .get();

//         final conflictingEmail = existingEmails.docs
//             .where((doc) => doc.id != widget.student['id'])
//             .isNotEmpty;

//         if (conflictingEmail) {
//           _showErrorSnackBar('Another student with this email already exists');
//           return;
//         }

//         // Update student (preserving biometric data)
//         await FirebaseFirestore.instance
//             .collection('groups')
//             .doc(widget.groupId)
//             .collection('students')
//             .doc(widget.student['id'])
//             .update({
//           'rollNumber': _rollNumberController.text,
//           'name': _nameController.text,
//           'email': _emailController.text,
//           'phone': _phoneController.text,
//           'department': _departmentController.text,
//           'updatedAt': FieldValue.serverTimestamp(),
//           // Note: Biometric data is preserved and not updated
//         });

//         if (mounted) {
//           Navigator.pop(context);
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('Student updated successfully! Biometric data preserved.'),
//               backgroundColor: Color(0xFF4CAF50),
//             ),
//           );
//         }
//       } catch (e) {
//         _showErrorSnackBar('Error updating student: $e');
//       } finally {
//         if (mounted) setState(() => _isLoading = false);
//       }
//     }
//   }

//   void _showErrorSnackBar(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(message), backgroundColor: Colors.red),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _rollNumberController.dispose();
//     _nameController.dispose();
//     _emailController.dispose();
//     _phoneController.dispose();
//     _departmentController.dispose();
//     super.dispose();
//   }
// }

// // Main AddUsersScreen remains the same with updated dialog
// class AddUsersScreen extends StatefulWidget {
//   final Map<String, dynamic> groupData;

//   const AddUsersScreen({super.key, required this.groupData});

//   @override
//   State<AddUsersScreen> createState() => _AddUsersScreenState();
// }

// class _AddUsersScreenState extends State<AddUsersScreen> {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _checkInitialLoad();
//   }

//   void _checkInitialLoad() {
//     Future.delayed(const Duration(milliseconds: 300), () {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               '${widget.groupData['name']} Students',
//               style: const TextStyle(fontSize: 18),
//             ),
//             Text(
//               '${widget.groupData['department']} Department',
//               style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
//             ),
//           ],
//         ),
//         backgroundColor: const Color(0xFF4CAF50),
//         foregroundColor: Colors.white,
//         elevation: 0,
//         actions: [
//           IconButton(
//             onPressed: () => _showAddStudentDialog(),
//             icon: const Icon(Icons.fingerprint),
//             tooltip: 'Add Student with Biometric',
//           ),
//         ],
//       ),
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [Colors.white, Color(0xFFF0F8F0)],
//           ),
//         ),
//         child: _isLoading
//             ? const Center(
//                 child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
//               )
//             : Column(
//                 children: [
//                   _buildClassroomInfoCard(),
//                   Expanded(child: _buildStudentsList()),
//                 ],
//               ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () => _showAddStudentDialog(),
//         backgroundColor: const Color(0xFF4CAF50),
//         child: const Icon(Icons.fingerprint, color: Colors.white),
//       ),
//     );
//   }

//   Widget _buildClassroomInfoCard() {
//     return Container(
//       margin: const EdgeInsets.all(16),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.1),
//             spreadRadius: 1,
//             blurRadius: 5,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFF4CAF50).withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: const Icon(Icons.fingerprint, color: Color(0xFF4CAF50)),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       widget.groupData['name'] ?? 'Classroom',
//                       style: const TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     Text(
//                       '${widget.groupData['department']} Department',
//                       style: TextStyle(
//                         color: Colors.grey.shade600,
//                         fontSize: 14,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: Colors.blue.shade50,
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Row(
//               children: [
//                 Icon(Icons.security, color: Colors.blue.shade600, size: 16),
//                 const SizedBox(width: 8),
//                 Text(
//                   'Biometric Security Enabled',
//                   style: TextStyle(
//                     color: Colors.blue.shade700,
//                     fontWeight: FontWeight.w500,
//                     fontSize: 12,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStudentsList() {
//     return StreamBuilder<QuerySnapshot>(
//       stream: _firestore
//           .collection('groups')
//           .doc(widget.groupData['id'])
//           .collection('students')
//           .orderBy('rollNumber')
//           .snapshots(),
//       builder: (context, snapshot) {
//         if (snapshot.hasError) {
//           return _buildErrorWidget(snapshot.error.toString());
//         }

//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(
//             child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
//           );
//         }

//         final students = snapshot.data?.docs ?? [];

//         if (students.isEmpty) {
//           return _buildEmptyStudentsState();
//         }

//         return RefreshIndicator(
//           onRefresh: () async {
//             await Future.delayed(const Duration(milliseconds: 500));
//           },
//           child: ListView.builder(
//             padding: const EdgeInsets.all(16),
//             itemCount: students.length,
//             itemBuilder: (context, index) {
//               final studentDoc = students[index];
//               final studentData = studentDoc.data() as Map<String, dynamic>;
//               studentData['id'] = studentDoc.id;
//               return _buildEnhancedStudentCard(studentData);
//             },
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildEmptyStudentsState() {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(32),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.fingerprint,
//               size: 64,
//               color: Colors.grey.shade400,
//             ),
//             const SizedBox(height: 16),
//             Text(
//               'No Students Registered',
//               style: TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.grey.shade600,
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Add students with biometric fingerprint registration to start managing this classroom.',
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: 14,
//                 color: Colors.grey.shade500,
//               ),
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton.icon(
//               onPressed: () => _showAddStudentDialog(),
//               icon: const Icon(Icons.fingerprint, color: Colors.white),
//               label: const Text(
//                 'Add Student',
//                 style: TextStyle(color: Colors.white),
//               ),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFF4CAF50),
//                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildErrorWidget(String error) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(32),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.error_outline,
//               size: 64,
//               color: Colors.red.shade400,
//             ),
//             const SizedBox(height: 16),
//             Text(
//               'Error Loading Students',
//               style: TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.red.shade600,
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               error,
//               textAlign: TextAlign.center,
//               style: TextStyle(color: Colors.grey.shade600),
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () => setState(() {}),
//               child: const Text('Retry'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildEnhancedStudentCard(Map<String, dynamic> student) {
//     String getInitials(String name) {
//       List<String> nameParts = name.trim().split(' ');
//       if (nameParts.length >= 2) {
//         return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
//       } else {
//         return name.isNotEmpty ? name[0].toUpperCase() : 'S';
//       }
//     }

//     return Card(
//       margin: const EdgeInsets.only(bottom: 12),
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Row(
//           children: [
//             CircleAvatar(
//               radius: 24,
//               backgroundColor: const Color(0xFF2196F3).withOpacity(0.1),
//               child: Text(
//                 getInitials(student['name'] ?? 'Student'),
//                 style: const TextStyle(
//                   color: Color(0xFF2196F3),
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//               ),
//             ),
//             const SizedBox(width: 16),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           student['name'] ?? 'Unknown Student',
//                           style: const TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                           ),
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                       const SizedBox(width: 8),
//                       Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                         decoration: BoxDecoration(
//                           color: const Color(0xFF4CAF50).withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Text(
//                           'Roll: ${student['rollNumber'] ?? 'N/A'}',
//                           style: const TextStyle(
//                             color: Color(0xFF4CAF50),
//                             fontSize: 10,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     student['email'] ?? 'No email',
//                     style: TextStyle(
//                       color: Colors.grey.shade600,
//                       fontSize: 14,
//                     ),
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                   if (student['phone'] != null) ...[
//                     const SizedBox(height: 2),
//                     Text(
//                       student['phone'],
//                       style: TextStyle(
//                         color: Colors.grey.shade500,
//                         fontSize: 12,
//                       ),
//                     ),
//                   ],
//                   const SizedBox(height: 2),
//                   Text(
//                     student['department'] ?? 'Computer Science and Engineering',
//                     style: TextStyle(
//                       color: Colors.grey.shade500,
//                       fontSize: 12,
//                     ),
//                   ),
//                   // Enhanced biometric info
//                   if (student['biometricRegistered'] == true) ...[
//                     const SizedBox(height: 4),
//                     Row(
//                       children: [
//                         Icon(Icons.security, size: 12, color: Colors.green.shade600),
//                         const SizedBox(width: 4),
//                         Text(
//                           'Quality: ${student['fingerprintQuality'] ?? 0}%',
//                           style: TextStyle(
//                             color: Colors.green.shade700,
//                             fontSize: 10,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         Text(
//                           '${student['captureMethod'] ?? 'scanner'}',
//                           style: TextStyle(
//                             color: Colors.grey.shade500,
//                             fontSize: 10,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//             Column(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(4),
//                   decoration: BoxDecoration(
//                     color: student['biometricRegistered'] == true
//                         ? Colors.green.withOpacity(0.1)
//                         : Colors.orange.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Icon(
//                     student['biometricRegistered'] == true
//                         ? Icons.fingerprint
//                         : Icons.fingerprint_outlined,
//                     color: student['biometricRegistered'] == true
//                         ? Colors.green
//                         : Colors.orange,
//                     size: 20,
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 PopupMenuButton(
//                   icon: const Icon(Icons.more_vert),
//                   itemBuilder: (context) => [
//                     const PopupMenuItem(
//                       value: 'view_biometric',
//                       child: Row(
//                         children: [
//                           Icon(Icons.fingerprint, size: 16),
//                           SizedBox(width: 8),
//                           Text('View Biometric'),
//                         ],
//                       ),
//                     ),
//                     const PopupMenuItem(
//                       value: 'edit',
//                       child: Row(
//                         children: [
//                           Icon(Icons.edit, size: 16),
//                           SizedBox(width: 8),
//                           Text('Edit'),
//                         ],
//                       ),
//                     ),
//                     const PopupMenuItem(
//                       value: 'delete',
//                       child: Row(
//                         children: [
//                           Icon(Icons.delete, size: 16, color: Colors.red),
//                           SizedBox(width: 8),
//                           Text('Delete', style: TextStyle(color: Colors.red)),
//                         ],
//                       ),
//                     ),
//                   ],
//                   onSelected: (value) async {
//                     switch (value) {
//                       case 'view_biometric':
//                         _showBiometricInfo(student);
//                         break;
//                       case 'edit':
//                         _showEditStudentDialog(student);
//                         break;
//                       case 'delete':
//                         _showDeleteStudentConfirmation(student['id'], student['name']);
//                         break;
//                     }
//                   },
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _showBiometricInfo(Map<String, dynamic> student) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: Row(
//           children: [
//             Icon(Icons.fingerprint, color: Colors.green),
//             const SizedBox(width: 8),
//             const Text('Biometric Information'),
//           ],
//         ),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Student: ${student['name']}',
//               style: const TextStyle(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 12),
//             _buildInfoRow('Registration Status', 
//               student['biometricRegistered'] == true ? 'Registered' : 'Not Registered',
//               student['biometricRegistered'] == true ? Colors.green : Colors.red),
//             _buildInfoRow('Fingerprint Quality', 
//               '${student['fingerprintQuality'] ?? 0}%',
//               _getQualityColor(student['fingerprintQuality'] ?? 0)),
//             _buildInfoRow('Capture Method', 
//               student['captureMethod'] ?? 'Unknown', Colors.blue),
//             if (student['createdAt'] != null) ...[
//               _buildInfoRow('Registered On', 
//                 _formatTimestamp(student['createdAt']), Colors.grey),
//             ],
//             const SizedBox(height: 12),
//             Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade100,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.security, size: 16, color: Colors.grey.shade600),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       'Template ID: ${student['fingerprintTemplate']?.substring(0, 8) ?? 'N/A'}...',
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: Colors.grey.shade600,
//                         fontFamily: 'monospace',
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildInfoRow(String label, String value, Color color) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 8),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 100,
//             child: Text(
//               '$label:',
//               style: TextStyle(
//                 fontWeight: FontWeight.w500,
//                 color: Colors.grey.shade700,
//               ),
//             ),
//           ),
//           Expanded(
//             child: Text(
//               value,
//               style: TextStyle(
//                 color: color,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Color _getQualityColor(int quality) {
//     if (quality >= 80) return Colors.green;
//     if (quality >= 60) return Colors.orange;
//     return Colors.red;
//   }

//   String _formatTimestamp(dynamic timestamp) {
//     if (timestamp == null) return 'Unknown';
//     try {
//       final DateTime date = (timestamp as Timestamp).toDate();
//       return '${date.day}/${date.month}/${date.year}';
//     } catch (e) {
//       return 'Unknown';
//     }
//   }

//   void _showAddStudentDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AddStudentDialog(
//         groupId: widget.groupData['id'],
//         groupData: widget.groupData,
//       ),
//     );
//   }

//   void _showEditStudentDialog(Map<String, dynamic> student) {
//     showDialog(
//       context: context,
//       builder: (context) => EditStudentDialog(
//         groupId: widget.groupData['id'],
//         groupData: widget.groupData,
//         student: student,
//       ),
//     );
//   }

//   void _showDeleteStudentConfirmation(String studentId, String studentName) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: const Text('Delete Student'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Are you sure you want to remove $studentName from this classroom?'),
//             const SizedBox(height: 12),
//             Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: Colors.red.shade50,
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(color: Colors.red.shade200),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.warning, color: Colors.red.shade600, size: 16),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       'This will also delete their biometric data permanently.',
//                       style: TextStyle(
//                         color: Colors.red.shade700,
//                         fontSize: 12,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               _deleteStudent(studentId);
//               Navigator.pop(context);
//             },
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             child: const Text(
//               'Delete',
//               style: TextStyle(color: Colors.white),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _deleteStudent(String studentId) async {
//     try {
//       await _firestore
//           .collection('groups')
//           .doc(widget.groupData['id'])
//           .collection('students')
//           .doc(studentId)
//           .delete();

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Student and biometric data removed successfully'),
//             backgroundColor: Color(0xFF4CAF50),
//           ),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error removing student: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }lineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
//         ),
//         disabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide(color: Colors.grey.shade300),
//         ),
//       ),
//     );
//   }

//   Widget _buildBiometricSection() {
//     if (!_scannerAvailable) {
//       return Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           border: Border.all(color: Colors.red.shade300),
//           borderRadius: BorderRadius.circular(12),
//           color: Colors.red.shade50,
//         ),
//         child: Column(
//           children: [
//             Icon(Icons.error_outline, color: Colors.red.shade600, size: 32),
//             const SizedBox(height: 8),
//             Text(
//               'Biometric Scanner Not Available',
//               style: TextStyle(
//                 color: Colors.red.shade800,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 4),
//             Text(
//               'This device does not support biometric scanning. Please use a device with fingerprint scanner.',
//               textAlign: TextAlign.center,
//               style: TextStyle(color: Colors.red.shade700, fontSize: 12),
//             ),
//           ],
//         ),
//       );
//     }

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         border: Border.all(color: Colors.grey.shade300),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(
//                 Icons.fingerprint,
//                 color: _biometricCaptured ? Colors.green : const Color(0xFF4CAF50),
//               ),
//               const SizedBox(width: 8),
//               Text(
//                 'Fingerprint Registration',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: _biometricCaptured ? Colors.green : Colors.black87,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
          
//           if (_biometricCaptured) ...[
//             _buildSuccessInfo(),
//           ] else ...[
//             Text(
//               'Place finger on the scanner $_maxCaptureAttempts times for optimal recognition',
//               style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
//             ),
//           ],
          
//           const SizedBox(height: 12),
          
//           if (_isCapturingBiometric) ...[
//             _buildCapturingWidget(),
//           ] else ...[
//             _buildCaptureButton(),
//           ],
          
//           if (_captureAttempts > 0 && !_biometricCaptured) ...[
//             const SizedBox(height: 12),
//             _buildProgressIndicator(),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildSuccessInfo() {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.green.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const Icon(Icons.check_circle, color: Colors.green, size: 20),
//               const SizedBox(width: 8),
//               const Text(
//                 'Fingerprint captured successfully!',
//                 style: TextStyle(
//                   color: Colors.green,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Text(
//                 'Quality Score: $_fingerprintQuality%',
//                 style: TextStyle(
//                   color: Colors.green.shade700,
//                   fontSize: 12,
//                 ),
//               ),
//               const SizedBox(width: 16),
//               Text(
//                 'Method: $_captureMethod',
//                 style: TextStyle(
//                   color: Colors.green.shade700,
//                   fontSize: 12,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildCapturingWidget() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: const Color(0xFF4CAF50).withOpacity(0.1),
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Column(
//         children: [
//           const CircularProgressIndicator(color: Color(0xFF4CAF50)),
//           const SizedBox(height: 12),
//           Text(
//             'Scanning fingerprint...\nAttempt $_captureAttempts of $_maxCaptureAttempts',
//             textAlign: TextAlign.center,
//             style: const TextStyle(
//               color: Color(0xFF4CAF50),
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Please place your finger firmly on the scanner',
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               color: Colors.grey.shade600,
//               fontSize: 12,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildCaptureButton() {
//     return SizedBox(
//       width: double.infinity,
//       child: ElevatedButton.icon(
//         onPressed: _biometricCaptured ? null : _startFingerprintCapture,
//         icon: Icon(
//           _biometricCaptured ? Icons.check_circle : Icons.fingerprint,
//           color: Colors.white,
//         ),
//         label: Text(
//           _biometricCaptured ? 'Fingerprint Registered' : 'Scan Fingerprint',
//           style: const TextStyle(color: Colors.white),
//         ),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: _biometricCaptured ? Colors.green : const Color(0xFF4CAF50),
//           padding: const EdgeInsets.symmetric(vertical: 12),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(8),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildProgressIndicator() {
//     return Column(
//       children: [
//         LinearProgressIndicator(
//           value: _captureAttempts / _maxCaptureAttempts,
//           backgroundColor: Colors.grey.shade300,
//           valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           'Progress: $_captureAttempts/$_maxCaptureAttempts captures completed',
//           style: TextStyle(
//             color: Colors.grey.shade600,
//             fontSize: 12,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildActionButtons() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.end,
//       children: [
//         TextButton(
//           onPressed: _isLoading || _isCapturingBiometric ? null : () => Navigator.pop(context),
//           child: const Text('Cancel'),
//         ),
//         const SizedBox(width: 8),
//         ElevatedButton(
//           onPressed: (_isLoading || !_biometricCaptured || _isCapturingBiometric) ? null : _addStudent,
//           style: ElevatedButton.styleFrom(
//             backgroundColor: const Color(0xFF4CAF50),
//           ),
//           child: _isLoading
//               ? const SizedBox(
//                   width: 16,
//                   height: 16,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2,
//                     color: Colors.white,
//                   ),
//                 )
//               : const Text(
//                   'Add Student',
//                   style: TextStyle(color: Colors.white),
//                 ),
//         ),
//       ],
//     );
//   }

//   Future<void> _startFingerprintCapture() async {
//     setState(() {
//       _isCapturingBiometric = true;
//       _captureAttempts = 0;
//     });

//     try {
//       List<String> capturedTemplates = [];
//       List<int> qualityScores = [];
      
//       for (int i = 0; i < _maxCaptureAttempts; i++) {
//         setState(() => _captureAttempts = i + 1);
        
//         await Future.delayed(const Duration(milliseconds: 500));
        
//         // Try dedicated scanner first
//         Map<String, dynamic>? result = await BiometricService.captureFingerprint(
//           instruction: 'Place finger on scanner (${i + 1}/$_maxCaptureAttempts)',
//           timeoutSeconds: 30,
//         );

//         // If no dedicated scanner, use device fallback
//         result ??= await BiometricService.captureDeviceBiometric(
//           reason: 'Scan fingerprint for registration (${i + 1}/$_maxCaptureAttempts)',
//           studentId: _rollNumberController.text,
//         );

//         if (!result['success']) {
//           _showErrorSnackBar(result['error'] ?? 'Failed to capture fingerprint');
//           setState(() {
//             _isCapturingBiometric = false;
//             _captureAttempts = 0;
//           });
//           return;
//         }

//         final int quality = result['quality'] ?? 0;
//         if (quality < _minQualityThreshold) {
//           _showErrorSnackBar('Fingerprint quality too low ($quality%). Please try again.');
//           continue;
//         }

//         capturedTemplates.add(result['template'] ?? '');
//         qualityScores.add(quality);
        
//         setState(() => _captureMethod = result['method'] ?? 'scanner');
        
//         await Future.delayed(const Duration(milliseconds: 1000));
//       }

//       if (capturedTemplates.isEmpty) {
//         _showErrorSnackBar('No valid fingerprints captured. Please try again.');
//         setState(() {
//           _isCapturingBiometric = false;
//           _captureAttempts = 0;
//         });
//         return;
//       }

//       // Process captured templates
//       final String combinedTemplate = _combineFingerprintTemplates(capturedTemplates);
//       final int averageQuality = qualityScores.reduce((a, b) => a + b) ~/ qualityScores.length;
      
//       setState(() {
//         _fingerprintTemplate = combinedTemplate;
//         _fingerprintQuality = averageQuality;
//         _biometricCaptured = true;
//         _isCapturingBiometric = false;
//       });

//       _showSuccessSnackBar('Fingerprint registration completed successfully!');
      
//     } catch (e) {
//       _showErrorSnackBar('Error during fingerprint capture: $e');
//       setState(() {
//         _isCapturingBiometric = false;
//         _captureAttempts = 0;
//       });
//     }
//   }

//   String _combineFingerprintTemplates(List<String> templates) {
//     // Combine multiple templates for better accuracy
//     final String combinedData = templates.join('-');
//     var bytes = utf8.encode(combinedData);
//     var digest = sha256.convert(bytes);
//     return digest.toString();
//   }

//   void _addStudent() async {
//     if (_formKey.currentState!.validate()) {
//       if (!_biometricCaptured) {
//         _showErrorSnackBar('Please complete fingerprint registration first');
//         return;
//       }

//       setState(() => _isLoading = true);

//       try {
//         // Check for existing roll number
//         final existingStudents = await _firestore
//             .collection('groups')
//             .doc(widget.groupId)
//             .collection('students')
//             .where('rollNumber', isEqualTo: _rollNumberController.text)
//             .get();

//         if (existingStudents.docs.isNotEmpty) {
//           _showErrorSnackBar('Student with this roll number already exists');
//           return;
//         }

//         // Check for existing email
//         final existingEmails = await _firestore
//             .collection('groups')
//             .doc(widget.groupId)
//             .collection('students')
//             .where('email', isEqualTo: _emailController.text)
//             .get();

//         if (existingEmails.docs.isNotEmpty) {
//           _showErrorSnackBar('Student with this email already exists');
//           return;
//         }

//         // Add student to Firestore with fingerprint data
//         await _firestore
//             .collection('groups')
//             .doc(widget.groupId)
//             .collection('students')
//             .add({
//           'rollNumber': _rollNumberController.text,
//           'name': _nameController.text,
//           'email': _emailController.text,
//           'phone': _phoneController.text,
//           'department': _departmentController.text,
//           'fingerprintTemplate': _fingerprintTemplate,
//           'fingerprintQuality': _fingerprintQuality,
//           'captureMethod': _captureMethod,
//           'biometricRegistered': true,
//           'createdAt': FieldValue.serverTimestamp(),
//           'groupId': widget.groupId,
//           'groupName': widget.groupData['name'],
//         });

//         if (mounted) {
//           Navigator.pop(context);
//           _showSuccessSnackBar('Student added successfully with fingerprint registration!');
//         }
//       } catch (e) {
//         _showErrorSnackBar('Error adding student: $e');
//       } finally {
//         if (mounted) setState(() => _isLoading = false);
//       }
//     }
//   }

//   void _showErrorSnackBar(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(message),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   void _showSuccessSnackBar(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(message),
//           backgroundColor: const Color(0xFF4CAF50),
//         ),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _rollNumberController.dispose();
//     _nameController.dispose();
//     _emailController.dispose();
//     _phoneController.dispose();
//     _departmentController.dispose();
//     super.dispose();
//   }
// }

// // Enhanced Edit Student Dialog (keeps biometric data intact)
// class EditStudentDialog extends StatefulWidget {
//   final String groupId;
//   final Map<String, dynamic> groupData;
//   final Map<String, dynamic> student;

//   const EditStudentDialog({
//     super.key,
//     required this.groupId,
//     required this.groupData,
//     required this.student,
//   });

//   @override
//   State<EditStudentDialog> createState() => _EditStudentDialogState();
// }

// class _EditStudentDialogState extends State<EditStudentDialog> {
//   final _formKey = GlobalKey<FormState>();
//   late TextEditingController _rollNumberController;
//   late TextEditingController _nameController;
//   late TextEditingController _emailController;
//   late TextEditingController _phoneController;
//   late TextEditingController _departmentController;
  
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     _rollNumberController = TextEditingController(text: widget.student['rollNumber']);
//     _nameController = TextEditingController(text: widget.student['name']);
//     _emailController = TextEditingController(text: widget.student['email']);
//     _phoneController = TextEditingController(text: widget.student['phone']);
//     _departmentController = TextEditingController(
//       text: widget.student['department'] ?? 'Computer Science and Engineering'
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Container(
//         width: MediaQuery.of(context).size.width * 0.9,
//         constraints: const BoxConstraints(maxHeight: 650),
//         child: Padding(
//           padding: const EdgeInsets.all(24),
//           child: Form(
//             key: _formKey,
//             child: SingleChildScrollView(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _buildHeader(),
//                   const SizedBox(height: 24),
//                   _buildStudentForm(),
//                   const SizedBox(height: 16),
//                   _buildBiometricStatus(),
//                   const SizedBox(height: 24),
//                   _buildActionButtons(),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildHeader() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Icon(Icons.edit, color: const Color(0xFF4CAF50), size: 28),
//             const SizedBox(width: 12),
//             const Expanded(
//               child: Text(
//                 'Edit Student',
//                 style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Text(
//           'Editing: ${widget.student['name']}',
//           style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
//         ),
//       ],
//     );
//   }

//   Widget _buildStudentForm() {
//     return Column(
//       children: [
//         _buildTextField(
//           controller: _rollNumberController,
//           label: 'Roll Number',
//           icon: Icons.numbers,
//           validator: (value) => value?.isEmpty ?? true ? 'Please enter roll number' : null,
//         ),
//         const SizedBox(height: 16),
//         _buildTextField(
//           controller: _nameController,
//           label: 'Full Name',
//           icon: Icons.person,
//           validator: (value) => value?.isEmpty ?? true ? 'Please enter name' : null,
//         ),
//         const SizedBox(height: 16),
//         _buildTextField(
//           controller: _emailController,
//           label: 'Email Address',
//           icon: Icons.email,
//           validator: (value) {
//             if (value?.isEmpty ?? true) return 'Please enter email';
//             if (!value!.contains('@')) return 'Please enter valid email';
//             return null;
//           },
//         ),
//         const SizedBox(height: 16),
//         _buildTextField(
//           controller: _phoneController,
//           label: 'Phone Number',
//           icon: Icons.phone,
//           validator: (value) => value?.isEmpty ?? true ? 'Please enter phone' : null,
//         ),
//         const SizedBox(height: 16),
//         _buildTextField(
//           controller: _departmentController,
//           label: 'Department',
//           icon: Icons.business,
//           enabled: false,
//           validator: (value) => null,
//         ),
//       ],
//     );
//   }
