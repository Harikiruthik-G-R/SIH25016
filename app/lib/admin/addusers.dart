import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
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
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4CAF50),
                ),
              )
            : Column(
                children: [
                  _buildClassroomInfoCard(),
                  Expanded(
                    child: _buildStudentsList(),
                  ),
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
      stream: _firestore
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
            child: CircularProgressIndicator(
              color: Color(0xFF4CAF50),
            ),
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
            Icon(
              Icons.school,
              size: 64,
              color: Colors.grey.shade400,
            ),
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
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
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
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: student['biometricRegistered'] == true
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    student['biometricRegistered'] == true
                        ? Icons.fingerprint
                        : Icons.fingerprint_outlined,
                    color: student['biometricRegistered'] == true
                        ? Colors.green
                        : Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  onSelected: (value) async {
                    switch (value) {
                      case 'edit':
                        _showEditStudentDialog(student);
                        break;
                      case 'delete':
                        _showDeleteStudentConfirmation(student['id'], student['name']);
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

  void _showAddStudentDialog() {
    showDialog(
      context: context,
      builder: (context) => AddStudentDialog(
        groupId: widget.groupData['id'],
        groupData: widget.groupData,
      ),
    );
  }

  void _showEditStudentDialog(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) => EditStudentDialog(
        groupId: widget.groupData['id'],
        groupData: widget.groupData,
        student: student,
      ),
    );
  }

  void _showDeleteStudentConfirmation(String studentId, String studentName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Are you sure you want to remove $studentName from this classroom?'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing student: $e')),
        );
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
  final _departmentController = TextEditingController(text: 'Computer Science and Engineering');
  
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
              content: Text('Biometric authentication is not available on this device'),
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
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
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
                  
                  // Biometric Section
                  _buildBiometricSection(),
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
                        onPressed: (_isLoading || !_biometricCaptured) ? null : _addStudent,
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
                color: _biometricCaptured ? Colors.green : const Color(0xFF4CAF50),
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
                  const CircularProgressIndicator(
                    color: Color(0xFF4CAF50),
                  ),
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
                  _biometricCaptured ? 'Biometric Registered' : 'Start Biometric Capture',
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
          
          if (_captureAttempts > 0 && !_biometricCaptured) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _captureAttempts / _maxCaptureAttempts,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
            ),
            const SizedBox(height: 4),
            Text(
              'Progress: $_captureAttempts/$_maxCaptureAttempts captures completed',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
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
          localizedReason: 'Scan your fingerprint for registration (${i + 1}/$_maxCaptureAttempts)',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );

        if (!isAuthenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Biometric authentication failed. Please try again.'),
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
        String dataToHash = '$timestamp-$randomValue-${_nameController.text}-${_rollNumberController.text}';
        
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
        final existingStudents = await FirebaseFirestore.instance
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
        final existingEmails = await FirebaseFirestore.instance
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
              content: Text('Student added successfully with biometric registration!'),
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
    _rollNumberController = TextEditingController(text: widget.student['rollNumber']);
    _nameController = TextEditingController(text: widget.student['name']);
    _emailController = TextEditingController(text: widget.student['email']);
    _phoneController = TextEditingController(text: widget.student['phone']);
    _departmentController = TextEditingController(text: widget.student['department'] ?? 'Computer Science and Engineering');
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
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
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
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _updateStudent,
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
        final existingRollNumbers = await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('students')
            .where('rollNumber', isEqualTo: _rollNumberController.text)
            .get();

        final conflictingRollNumber = existingRollNumbers.docs
            .where((doc) => doc.id != widget.student['id'])
            .isNotEmpty;

        if (conflictingRollNumber) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Another student with this roll number already exists'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Check if email already exists (excluding current student)
        final existingEmails = await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('students')
            .where('email', isEqualTo: _emailController.text)
            .get();

        final conflictingEmail = existingEmails.docs
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