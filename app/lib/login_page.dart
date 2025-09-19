import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:GeoAt/services/biometricservices.dart';
import 'package:GeoAt/sessionmanager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final TextEditingController loginController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool obscurePassword = true;
  bool isBiometricLoading = false;
  bool isBiometricAvailable = false;
  late AnimationController _animationController;
  late AnimationController _biometricAnimationController;
  final _formKey = GlobalKey<FormState>();
  String selectedRole = 'Admin';
  final List<String> roles = ['Admin', 'Student', 'Teacher'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    
    _biometricAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _biometricAnimationController.dispose();
    loginController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await BiometricService.isScannerAvailable();
      setState(() {
        isBiometricAvailable = isAvailable;
      });
    } catch (e) {
      debugPrint("Error checking biometric availability: $e");
    }
  }

  Future<void> _loginWithBiometric() async {
    if (!isBiometricAvailable) {
      _showError("Biometric authentication is not available on this device");
      return;
    }

    if (selectedRole != 'Student') {
      _showError("Biometric login is only available for students");
      return;
    }

    final loginValue = loginController.text.trim();
    if (loginValue.isEmpty) {
      _showError("Please enter your email or phone number first");
      return;
    }

    setState(() => isBiometricLoading = true);
    _biometricAnimationController.repeat();

    try {
      // Initialize scanner for authentication
      final initialized = await BiometricService.initializeScannerForCapture();
      if (!initialized) {
        _showError("Failed to initialize biometric scanner");
        return;
      }

      // Capture fingerprint for authentication
      final result = await BiometricService.captureForEnrollment("Authentication");
      
      if (!(result['success'] ?? false)) {
        _showError(result['error'] ?? 'Biometric capture failed');
        return;
      }

      final capturedTemplate = result['template'] as String? ?? '';
      if (capturedTemplate.isEmpty) {
        _showError("Failed to capture biometric data");
        return;
      }

      // Authenticate using captured template
      await _authenticateWithBiometric(loginValue, capturedTemplate);

    } catch (e) {
      debugPrint("Biometric authentication error: $e");
      _showError("Biometric authentication failed. Please try again.");
    } finally {
      setState(() => isBiometricLoading = false);
      _biometricAnimationController.stop();
      _biometricAnimationController.reset();
    }
  }

  Future<void> _authenticateWithBiometric(String loginValue, String capturedTemplate) async {
    try {
      debugPrint("Starting biometric authentication for: $loginValue");

      // Find student document
      final studentDoc = await _findStudentDocument(loginValue);
      if (studentDoc == null) {
        throw Exception("Student not found with the provided credentials");
      }

      final data = studentDoc.data() as Map<String, dynamic>;
      debugPrint("Found student: ${data['name']}");

      // Get stored biometric template - check common field names
      String? storedTemplate = _getStoredBiometricTemplate(data);
      
      if (storedTemplate == null || storedTemplate.isEmpty) {
        throw Exception("No biometric data found for this student. Please register biometrics first.");
      }

      debugPrint("Comparing biometric templates...");
      debugPrint("Stored template length: ${storedTemplate.length}");
      debugPrint("Captured template length: ${capturedTemplate.length}");

      // Perform biometric verification
      bool isAuthenticated = await _verifyBiometricTemplate(storedTemplate, capturedTemplate);

      if (!isAuthenticated) {
        throw Exception("Biometric verification failed. Please try again or use password login.");
      }

      debugPrint("Biometric authentication successful!");

      // Navigate to group selection
      if (!mounted) return;

      Navigator.pushNamed(
        context,
        '/groupselection',
        arguments: {
          'name': data['name'],
          'email': data['email'],
          'rollNumber': data['rollNumber'],
          'department': data['department'],
          'groupId': data['groupId'],
          'groupName': data['groupName'],
          'studentId': studentDoc.id,
          'biometricAuth': true,
        },
      );

      _showSuccess("Biometric login successful! Welcome ${data['name']}");

    } catch (e) {
      debugPrint("Biometric authentication error: $e");
      _showError(e.toString().replaceAll("Exception: ", ""));
    }
  }

  Future<QueryDocumentSnapshot?> _findStudentDocument(String loginValue) async {
    bool isEmail = loginValue.contains('@');
    bool isPhone = RegExp(r'^\d{10}$').hasMatch(loginValue);
    
    QuerySnapshot querySnapshot;
    
    try {
      if (isEmail) {
        querySnapshot = await FirebaseFirestore.instance
            .collectionGroup('students')
            .where('email', isEqualTo: loginValue)
            .limit(1)
            .get();
      } else if (isPhone) {
        querySnapshot = await FirebaseFirestore.instance
            .collectionGroup('students')
            .where('phone', isEqualTo: loginValue)
            .limit(1)
            .get();
      } else {
        querySnapshot = await FirebaseFirestore.instance
            .collectionGroup('students')
            .where('rollNumber', isEqualTo: loginValue)
            .limit(1)
            .get();
      }

      return querySnapshot.docs.isNotEmpty ? querySnapshot.docs.first : null;
    } catch (e) {
      debugPrint("Error finding student document: $e");
      return null;
    }
  }

  String? _getStoredBiometricTemplate(Map<String, dynamic> data) {
    // Check multiple possible field names for stored biometric data
    final possibleFields = [
      'fingerprintTemplate',
      'fingerprint_template', 
      'biometricTemplate',
      'biometric_template',
      'template',
      'fingerprintData',
      'fingerprint_data'
    ];

    for (final field in possibleFields) {
      final value = data[field] as String?;
      if (value != null && value.isNotEmpty) {
        debugPrint("Found biometric data in field: $field");
        return value;
      }
    }

    return null;
  }

  Future<bool> _verifyBiometricTemplate(String storedTemplate, String capturedTemplate) async {
    try {
      // Method 1: Direct comparison (most reliable for exact matches)
      if (storedTemplate == capturedTemplate) {
        debugPrint("Direct template match found!");
        return true;
      }

      // Method 2: Hash-based comparison
      final storedHash = sha256.convert(utf8.encode(storedTemplate)).toString();
      final capturedHash = sha256.convert(utf8.encode(capturedTemplate)).toString();
      
      if (storedHash == capturedHash) {
        debugPrint("Hash-based template match found!");
        return true;
      }

      // Method 3: Use BiometricService verification
      final verifyResult = await BiometricService.verifyFingerprint(
        storedTemplate,
        capturedTemplate,
      );

      final confidence = verifyResult['confidence'] as double? ?? 0.0;
      final isMatch = verifyResult['isMatch'] as bool? ?? false;
      
      debugPrint("BiometricService verification - Confidence: ${(confidence * 100).toStringAsFixed(1)}%, Match: $isMatch");

      // Use a reasonable threshold for biometric matching
      const double CONFIDENCE_THRESHOLD = 0.80;
      
      if (confidence >= CONFIDENCE_THRESHOLD || isMatch) {
        debugPrint("BiometricService verification successful!");
        return true;
      }

      // Method 4: Normalized template comparison (fallback)
      final normalizedSimilarity = _calculateNormalizedSimilarity(storedTemplate, capturedTemplate);
      debugPrint("Normalized similarity: ${(normalizedSimilarity * 100).toStringAsFixed(1)}%");

      if (normalizedSimilarity >= 0.75) {
        debugPrint("Normalized similarity match found!");
        return true;
      }

      debugPrint("All verification methods failed");
      return false;

    } catch (e) {
      debugPrint("Error in biometric verification: $e");
      return false;
    }
  }

  double _calculateNormalizedSimilarity(String template1, String template2) {
    if (template1.isEmpty || template2.isEmpty) return 0.0;
    if (template1 == template2) return 1.0;

    // Normalize templates to same length for comparison
    final len1 = template1.length;
    final len2 = template2.length;
    final minLen = math.min(len1, len2);
    final maxLen = math.max(len1, len2);

    if (minLen == 0) return 0.0;

    // Calculate character-by-character similarity
    int matches = 0;
    for (int i = 0; i < minLen; i++) {
      if (template1[i] == template2[i]) {
        matches++;
      }
    }

    // Account for length difference
    double lengthPenalty = minLen.toDouble() / maxLen.toDouble();
    double matchRatio = matches.toDouble() / minLen.toDouble();
    
    return matchRatio * lengthPenalty;
  }

  // Keep all your existing login methods unchanged
  Future<void> loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    final loginValue = loginController.text.trim();
    final password = passwordController.text.trim();

    debugPrint("Login attempt:");
    debugPrint("loginValue: $loginValue");
    debugPrint("selectedRole: $selectedRole");

    setState(() => isLoading = true);

    try {
      if (selectedRole == 'Admin') {
        await _loginAdmin(loginValue, password);
      } else if (selectedRole == 'Teacher') {
        await _loginTeacher(loginValue, password);
      } else {
        await _loginStudent(loginValue, password);
      }
    } on TimeoutException {
      _showError("Connection timeout. Please check your internet connection.");
    } catch (e) {
      debugPrint("Login error: $e");

      if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        _showError("Network error. Please check your internet connection.");
      } else if (e.toString().contains('Invalid credentials')) {
        _showError(e.toString().replaceAll('Exception: ', ''));
      } else {
        _showError("Login failed. Please try again.");
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loginAdmin(String email, String password) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('admins')
        .where('email', isEqualTo: email)
        .limit(1)
        .get()
        .timeout(const Duration(seconds: 15));

    if (querySnapshot.docs.isEmpty) {
      throw Exception("Invalid admin credentials. Please check your email.");
    }

    final data = querySnapshot.docs.first.data();
    final storedPassword = (data['password'] ?? '').toString();

    if (storedPassword != password) {
      throw Exception("Invalid credentials. Please check your password.");
    }

    await SessionManager.saveSession(
      isLoggedIn: true,
      isAdmin: true,
      userName: (data['name'] ?? '').toString(),
      userEmail: (data['email'] ?? '').toString(),
    );

    if (!mounted) return;
    Navigator.pushNamed(
      context,
      '/tickscreen',
      arguments: {
        'isAdmin': true,
        'name': data['name'],
        'email': data['email'],
      },
    );
  }

  Future<void> _loginTeacher(String email, String password) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('teachers')
        .where('email', isEqualTo: email)
        .limit(1)
        .get()
        .timeout(const Duration(seconds: 15));

    if (querySnapshot.docs.isEmpty) {
      throw Exception("Invalid teacher credentials. Please check your email.");
    }

    final data = querySnapshot.docs.first.data();
    final storedPassword = (data['password'] ?? '').toString();

    if (storedPassword.isEmpty) {
      throw Exception(
        "Password not set for this teacher. Please contact admin.",
      );
    }

    if (storedPassword != password) {
      throw Exception("Invalid credentials. Please check your password.");
    }

    final subjects = data['subjects'] as List<dynamic>? ?? [];
    final subjectNames = subjects.map((subject) {
      if (subject is String) {
        return subject;
      } else if (subject is Map && subject['name'] != null) {
        return subject['name'].toString();
      }
      return subject.toString();
    }).toList();

    await SessionManager.saveSession(
      isLoggedIn: true,
      isAdmin: false,
      isTeacher: true,
      userName: (data['name'] ?? '').toString(),
      userEmail: (data['email'] ?? '').toString(),
      teacherId: querySnapshot.docs.first.id,
      teacherSubjects: subjectNames.cast<String>(),
      department: (data['department'] ?? '').toString(),
      designation: (data['designation'] ?? '').toString(),
    );

    if (!mounted) return;
    Navigator.pushNamed(
      context,
      '/teacherDashboard',
      arguments: {
        'teacherId': querySnapshot.docs.first.id,
        'name': data['name'],
        'email': data['email'],
        'subjects': subjectNames,
        'department': data['department'] ?? '',
        'designation': data['designation'] ?? '',
      },
    );
  }

  Future<void> _loginStudent(String loginValue, String password) async {
    QuerySnapshot querySnapshot;

    bool isEmail = loginValue.contains('@');
    bool isPhone = RegExp(r'^\d{10}$').hasMatch(loginValue);

    try {
      if (isEmail) {
        querySnapshot = await FirebaseFirestore.instance
            .collectionGroup('students')
            .where('email', isEqualTo: loginValue.trim())
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 15));
      } else if (isPhone) {
        querySnapshot = await FirebaseFirestore.instance
            .collectionGroup('students')
            .where('phone', isEqualTo: loginValue.trim())
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 15));
      } else {
        querySnapshot = await FirebaseFirestore.instance
            .collectionGroup('students')
            .where('rollNumber', isEqualTo: loginValue.trim())
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 15));
      }

      if (querySnapshot.docs.isEmpty) {
        throw Exception(
          "Invalid student credentials. Please check your ${isEmail ? 'email' : isPhone ? 'phone number' : 'roll number'}.",
        );
      }

      final data = querySnapshot.docs.first.data() as Map<String, dynamic>;
      final storedPassword = (data['password'] ?? '').toString();

      if (RegExp(r'^\d{10}$').hasMatch(password.trim())) {
        if (data['phone'].toString().trim() != password.trim()) {
          throw Exception("Invalid credentials. Please check your phone number.");
        }
      } else {
        if (storedPassword.trim() != password.trim()) {
          throw Exception("Invalid credentials. Please check your password.");
        }
      }

      if (!mounted) return;

      debugPrint("Student login successful for: ${data['name']}");
      debugPrint("Navigating to group selection screen...");

      Navigator.pushNamed(
        context,
        '/groupselection',
        arguments: {
          'name': data['name'],
          'email': data['email'],
          'rollNumber': data['rollNumber'],
          'department': data['department'],
        },
      );
    } catch (e) {
      debugPrint("Login error: $e");
      throw Exception("Login failed. Please try again.");
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String? _validateLogin(String? value) {
    if (value == null || value.isEmpty) {
      return selectedRole == 'Admin'
          ? 'Please enter your email'
          : 'Please enter your roll number or email';
    }

    if (selectedRole == 'Admin') {
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
        return 'Please enter a valid email';
      }
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 3) {
      return 'Password must be at least 3 characters';
    }
    return null;
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2E2E2E),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hintText ?? 'Enter your ${label.toLowerCase()}',
            prefixIcon: Icon(icon, color: const Color(0xFF4CAF50)),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Role',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2E2E2E),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
            color: Colors.white,
          ),
          child: DropdownButtonFormField<String>(
            value: selectedRole,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.person, color: Color(0xFF4CAF50)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            items: roles.map((String role) {
              return DropdownMenuItem<String>(
                value: role,
                child: Text(role),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                selectedRole = newValue!;
                loginController.clear();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBiometricButton() {
    if (!isBiometricAvailable || selectedRole != 'Student') return const SizedBox.shrink();

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
        ),
      ),
      child: FadeTransition(
        opacity: _animationController,
        child: Column(
          children: [
            const Text(
              'Or sign in with',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(36),
                  onTap: isBiometricLoading || isLoading ? null : _loginWithBiometric,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: isBiometricLoading
                        ? RotationTransition(
                            turns: _biometricAnimationController,
                            child: const Icon(
                              Icons.fingerprint,
                              color: Colors.white,
                              size: 32,
                            ),
                          )
                        : const Icon(
                            Icons.fingerprint,
                            color: Colors.white,
                            size: 32,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isBiometricLoading ? 'Authenticating...' : 'Fingerprint',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (selectedRole == 'Student')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Enter email/phone first',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF0F8F0)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Welcome section
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: Curves.easeOut,
                      ),
                    ),
                    child: FadeTransition(
                      opacity: _animationController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome Back!',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E2E2E),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to your account to continue',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Role selection
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: const Interval(0.1, 1.0, curve: Curves.easeOut),
                      ),
                    ),
                    child: FadeTransition(
                      opacity: _animationController,
                      child: _buildRoleDropdown(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Login field
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
                      ),
                    ),
                    child: FadeTransition(
                      opacity: _animationController,
                      child: _buildInputField(
                        controller: loginController,
                        label: selectedRole == 'Admin' ? 'Email' : 'Roll Number / Email',
                        icon: selectedRole == 'Admin' ? Icons.email : Icons.badge,
                        keyboardType: selectedRole == 'Admin'
                            ? TextInputType.emailAddress
                            : TextInputType.text,
                        validator: _validateLogin,
                        hintText: selectedRole == 'Admin'
                            ? 'Enter your email address'
                            : 'Enter roll number or email',
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Password field
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
                      ),
                    ),
                    child: FadeTransition(
                      opacity: _animationController,
                      child: _buildInputField(
                        controller: passwordController,
                        label: 'Password',
                        icon: Icons.lock,
                        obscureText: obscurePassword,
                        validator: _validatePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility : Icons.visibility_off,
                            color: const Color(0xFF4CAF50),
                          ),
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Login button
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
                      ),
                    ),
                    child: FadeTransition(
                      opacity: _animationController,
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4CAF50).withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading || isBiometricLoading ? null : loginUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Biometric login option
                  Center(child: _buildBiometricButton()),

                  const SizedBox(height: 20),

                  // Connection status indicator
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Connected to server',
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
            ),
          ),
        ),
      ),
    );
  }
}