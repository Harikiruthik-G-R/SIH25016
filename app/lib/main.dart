import 'dart:math' as math;

import 'package:GeoAt/admin/admin_home.dart';
import 'package:GeoAt/login_page.dart';
import 'package:GeoAt/services/biometricservices.dart';
import 'package:GeoAt/sessionmanager.dart';
import 'package:GeoAt/users/users_home.dart';
import 'package:GeoAt/users/group_selection.dart';
import 'faculty/teacherDashboard.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    // Exit app if Firebase fails - no offline mode
    runApp(const FirebaseErrorApp());
    return;
  }

  // Initialize background service after a delay to ensure everything is ready
  try {
    await initializeService();
    debugPrint('Background service initialized successfully');
  } catch (e) {
    debugPrint('Background service initialization failed: $e');
    // Continue without background service - don't crash the app
  }

  runApp(const MyApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // Create notification channel first
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'attendance_foreground',
    'Attendance Service',
    description: 'This channel is used for attendance tracking notifications.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // Changed to false to prevent auto-start issues
      isForegroundMode: true,
      notificationChannelId: 'attendance_foreground',
      initialNotificationTitle: 'Attendance Service',
      initialNotificationContent: 'Ready to track attendance...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false, // Changed to false
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  // Don't auto-start the service - start it only when needed
}

// Helper function to start the service when needed
Future<void> startBackgroundService() async {
  try {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (!isRunning) {
      await service.startService();
      debugPrint('Background service started');
    }
  } catch (e) {
    debugPrint('Error starting background service: $e');
  }
}

// Helper function to stop the service
Future<void> stopBackgroundService() async {
  try {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (isRunning) {
      service.invoke('stopService');
      debugPrint('Background service stopped');
    }
  } catch (e) {
    debugPrint('Error stopping background service: $e');
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  try {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final log = preferences.getStringList('log') ?? <String>[];
    log.add(DateTime.now().toIso8601String());
    await preferences.setStringList('log', log);
  } catch (e) {
    debugPrint('iOS background service error: $e');
  }

  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  try {
    DartPluginRegistrant.ensureInitialized();

    // Initialize Firebase in isolate with error handling
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase initialization failed in background service: $e');
      return; // Exit if Firebase can't be initialized
    }

    // Initialize SharedPreferences with error handling
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
      await preferences.setString("service_status", "running");
    } catch (e) {
      debugPrint('SharedPreferences initialization failed: $e');
    }

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Reduce frequency to avoid overwhelming the system
    Timer.periodic(const Duration(minutes: 2), (timer) async {
      try {
        if (service is AndroidServiceInstance) {
          if (await service.isForegroundService()) {
            // Update notification
            flutterLocalNotificationsPlugin.show(
              888,
              'Attendance Active',
              'Last checked: ${DateTime.now().toString().substring(11, 16)}',
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'attendance_foreground',
                  'Attendance Service',
                  icon: 'ic_bg_service_small',
                  ongoing: true,
                  importance: Importance.low,
                  priority: Priority.low,
                ),
              ),
            );

            // Update attendance status
            await _updateAttendanceStatus();
          }
        }

        // Log service activity
        debugPrint('Background service tick: ${DateTime.now()}');

        if (preferences != null) {
          try {
            await preferences.reload();
            final log = preferences.getStringList('log') ?? <String>[];
            log.add(DateTime.now().toIso8601String());

            // Keep only last 50 entries to prevent memory issues
            if (log.length > 50) {
              log.removeRange(0, log.length - 50);
            }

            await preferences.setStringList('log', log);
          } catch (e) {
            debugPrint('Error updating preferences: $e');
          }
        }

        service.invoke('update', {
          "current_date": DateTime.now().toIso8601String(),
          "device": Platform.operatingSystem,
        });
      } catch (e) {
        debugPrint('Error in background service timer: $e');
      }
    });
  } catch (e) {
    debugPrint('Critical error in background service onStart: $e');
  }
}

Future<void> _updateAttendanceStatus() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    // Find active sessions for all users
    for (final key in keys) {
      if (key.startsWith('active_session_')) {
        final rollNumber = key.split('active_session_')[1];
        final sessionId = prefs.getString(key);
        final checkInTimeStr = prefs.getString('checkin_time_$rollNumber');

        if (sessionId != null && checkInTimeStr != null) {
          await _validateAndUpdateSession(
            rollNumber,
            sessionId,
            checkInTimeStr,
          );
        }
      }
    }
  } catch (e) {
    debugPrint('Background attendance update error: $e');
  }
}

Future<void> _validateAndUpdateSession(
  String rollNumber,
  String sessionId,
  String checkInTimeStr,
) async {
  try {
    final db = FirebaseFirestore.instance;

    // Add timeout and error handling for Firestore operations
    final sessionDoc = await db
        .collection('student_checkins')
        .doc(rollNumber)
        .collection('sessions')
        .doc(sessionId)
        .get()
        .timeout(const Duration(seconds: 15));

    if (!sessionDoc.exists || sessionDoc.data()?['status'] != 'ongoing') {
      // Session is invalid, clear it
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_session_$rollNumber');
      await prefs.remove('checkin_time_$rollNumber');
      debugPrint('Cleared invalid session for $rollNumber');
      return;
    }

    // Get current location with better error handling
    bool locationPermissionGranted = false;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      locationPermissionGranted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('Location permission check failed: $e');
    }

    Map<String, dynamic> updateData = {'lastLocationUpdate': Timestamp.now()};

    if (locationPermissionGranted) {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        ).timeout(const Duration(seconds: 15));

        updateData.addAll({
          'lastKnownLat': position.latitude,
          'lastKnownLng': position.longitude,
        });

        updateData['logs'] = FieldValue.arrayUnion([
          'background_location_update at ${DateTime.now().toIso8601String()}',
        ]);

        debugPrint('Updated session $sessionId for $rollNumber with location');
      } catch (e) {
        debugPrint('Location update failed for session $sessionId: $e');

        updateData['logs'] = FieldValue.arrayUnion([
          'background_ping at ${DateTime.now().toIso8601String()} (no location)',
        ]);
      }
    } else {
      updateData['logs'] = FieldValue.arrayUnion([
        'background_ping at ${DateTime.now().toIso8601String()} (no permission)',
      ]);
    }

    // Update session with timeout
    await db
        .collection('student_checkins')
        .doc(rollNumber)
        .collection('sessions')
        .doc(sessionId)
        .update(updateData)
        .timeout(const Duration(seconds: 15));

    // Check if session should be auto-ended
    final sessionData = sessionDoc.data()!;
    final expectedEndAt =
        (sessionData['expectedEndAt'] as Timestamp?)?.toDate();

    if (expectedEndAt != null && DateTime.now().isAfter(expectedEndAt)) {
      await _autoEndSession(db, rollNumber, sessionId, sessionData);
    }
  } catch (e) {
    debugPrint('Session validation error for $rollNumber: $e');
  }
}

Future<void> _autoEndSession(
  FirebaseFirestore db,
  String rollNumber,
  String sessionId,
  Map<String, dynamic> sessionData,
) async {
  try {
    final now = DateTime.now();
    final checkInAt = (sessionData['checkInAt'] as Timestamp).toDate();
    final durationMinutes = now.difference(checkInAt).inSeconds / 60.0;

    await db
        .collection('student_checkins')
        .doc(rollNumber)
        .collection('sessions')
        .doc(sessionId)
        .update({
          'checkOutAt': Timestamp.fromDate(now),
          'status': 'completed',
          'durationMinutes': durationMinutes,
          'closeReason': 'background_auto_end',
          'logs': FieldValue.arrayUnion([
            'background_auto_end at ${now.toIso8601String()}',
          ]),
        })
        .timeout(const Duration(seconds: 15));

    // Clear from local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_session_$rollNumber');
    await prefs.remove('checkin_time_$rollNumber');

    debugPrint('Auto-ended session $sessionId for $rollNumber');

    // Send notification about auto-end
    final FlutterLocalNotificationsPlugin notifications =
        FlutterLocalNotificationsPlugin();
    await notifications.show(
      999,
      'Session Ended',
      'Attendance session completed automatically.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'attendance_foreground',
          'Attendance Service',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  } catch (e) {
    debugPrint('Auto-end session error: $e');
  }
}

// Error app when Firebase fails
class FirebaseErrorApp extends StatelessWidget {
  const FirebaseErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFF0F8F0)],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red),
                SizedBox(height: 20),
                Text(
                  'Firebase Connection Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Please check your internet connection and restart the app',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Main App Widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoAt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.white,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (context) => const SplashScreen(),
            );
          case '/onboarding':
            return MaterialPageRoute(
              builder: (context) => const OnboardingScreen(),
            );
          case '/login':
            return MaterialPageRoute(builder: (context) => const LoginPage());
          case '/tickscreen':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder:
                  (context) => TickAnimation(
                    message: 'Login Successful!',
                    arguments: args,
                  ),
            );
          case '/groupselection':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (context) => GroupSelectionScreen(studentData: args),
            );
          case '/admin':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder:
                  (context) => AdminHomeScreen(
                    arguments: args,
                    userName: args['userName'] ?? 'Admin',
                    userEmail: args['userEmail'] ?? 'admin@gmail.com',
                  ),
            );
          case '/students':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder:
                  (context) => UserHomeScreen(
                    arguments: args,
                    userName: args['userName'] ?? 'Student',
                    userEmail: args['userEmail'] ?? 'student@gmail.com',
                    rollNumber: args['rollNumber'] ?? 'N/A',
                    groupId: args['groupId'] ?? '',
                    groupName: args['groupName'] ?? '',
                    department: args['department'] ?? '',
                  ),
            );
          case '/teacherDashboard':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder:
                  (context) => TeacherDashboard(
                    teacherId: args['teacherId'] ?? '',
                    teacherName: args['name'] ?? 'Teacher',
                    teacherEmail: args['email'] ?? 'teacher@example.com',
                    subjects: List<String>.from(args['subjects'] ?? []),
                    department: args['department'] ?? '',
                    designation: args['designation'] ?? '',
                  ),
            );
          default:
            return MaterialPageRoute(builder: (context) => const LoginPage());
        }
      },
    );
  }
}

// SplashScreen Widget - Online only
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _startApp();
  }

  Future<void> _startApp() async {
    try {
      // Start animation
      _animationController.forward();

      // Wait for minimum splash time
      await Future.delayed(const Duration(milliseconds: 1500));

      // Verify Firebase connection
      await _verifyFirebaseConnection();

      // Check session and navigate
      await _checkSessionAndNavigate();
    } catch (e) {
      debugPrint('Error in _startApp: $e');
      if (mounted) {
        _showConnectionError();
      }
    }
  }

  Future<void> _verifyFirebaseConnection() async {
    try {
      // Test Firebase connection with a simple query
      await FirebaseFirestore.instance
          .collection('test')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception('Firebase connection failed: $e');
    }
  }

  Future<void> _checkSessionAndNavigate() async {
    if (!mounted) return;

    try {
      // First check if session is valid using the SessionManager validation
      final isSessionValid = await SessionManager.validateSession();

      if (!isSessionValid) {
        // No valid session, go to onboarding
        Navigator.of(context).pushReplacementNamed('/onboarding');
        return;
      }

      // Get session data
      final session = await SessionManager.getSession();

      if (!mounted) return;

      // Double-check essential data exists
      if (session['isLoggedIn'] == true &&
          session['userName']?.isNotEmpty == true &&
          session['userEmail']?.isNotEmpty == true) {
        // Optional: Verify session with Firebase (but don't clear session on failure)
        try {
          await _verifyUserSession(session);
        } catch (e) {
          debugPrint(
            'Firebase verification failed, but continuing with cached session: $e',
          );
          // Don't clear session or throw error - continue with cached data
        }

        // User has valid session - navigate to appropriate home screen
        String route;
        if (session['isAdmin'] == true) {
          route = '/admin';
        } else if (session['isTeacher'] == true) {
          route = '/teacherDashboard';
        } else {
          route = '/students';
        }

        Navigator.of(context).pushReplacementNamed(
          route,
          arguments: {
            'userName': session['userName'] ?? '',
            'userEmail': session['userEmail'] ?? '',
            'rollNumber': session['rollNumber'] ?? '',
            'groupId': session['groupId'] ?? '',
            'groupName': session['groupName'] ?? '',
            'department': session['department'] ?? '',
            // Teacher-specific arguments with correct keys
            'teacherId': session['teacherId'] ?? '',
            'name':
                session['userName'] ?? '', // Use correct key for teacher name
            'email':
                session['userEmail'] ?? '', // Use correct key for teacher email
            'subjects':
                session['teacherSubjects'] ??
                [], // Use correct key for subjects
            'designation': session['designation'] ?? '',
          },
        );
      } else {
        // Session data incomplete, go to onboarding
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    } catch (e) {
      debugPrint('Error checking session: $e');
      // On any error, go to onboarding instead of clearing session
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    }
  }

  Future<void> _verifyUserSession(Map<String, dynamic> session) async {
    final isAdmin = session['isAdmin'] ?? false;
    final userEmail = session['userEmail'] ?? '';

    if (userEmail.isEmpty) {
      throw Exception('Invalid session - no email');
    }

    QuerySnapshot querySnapshot;

    if (isAdmin) {
      querySnapshot = await FirebaseFirestore.instance
          .collection('admins')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));
    } else {
      querySnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));
    }

    if (querySnapshot.docs.isEmpty) {
      throw Exception('User not found in database');
    }
  }

  void _showConnectionError() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Connection Error'),
            content: const Text(
              'Unable to connect to the server. Please check your internet connection and try again.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startApp(); // Retry
                },
                child: const Text('Retry'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF0F8F0)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.1),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'GeoAt',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4CAF50),
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Smart Attendance System',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 80),
              const PulsingCircularProgressIndicator(),
              const SizedBox(height: 20),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'Connecting to server...',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Animated Progress Indicator
class PulsingCircularProgressIndicator extends StatefulWidget {
  const PulsingCircularProgressIndicator({super.key});

  @override
  State<PulsingCircularProgressIndicator> createState() =>
      _PulsingCircularProgressIndicatorState();
}

class _PulsingCircularProgressIndicatorState
    extends State<PulsingCircularProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_controller.value * 0.1),
          child: const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
            strokeWidth: 3,
          ),
        );
      },
    );
  }
}

// Enhanced Onboarding Screen
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int currentPage = 0;

  final List<OnboardingData> onboardingData = [
    OnboardingData(
      title: 'Welcome to GeoAt!',
      description:
          'Track and manage attendance with real-time location verification and secure cloud storage.',
      icon: Icons.location_on,
    ),
    OnboardingData(
      title: 'Secure & Reliable',
      description:
          'Your data is safely stored in the cloud with real-time synchronization across all devices.',
      icon: Icons.cloud_done,
    ),
    OnboardingData(
      title: 'Location Verification',
      description:
          'We need to access your location to verify your attendance accurately.',
      icon: Icons.my_location,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
          child: Column(
            children: [
              // Skip button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed:
                        () => Navigator.pushReplacementNamed(context, '/login'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      backgroundColor: const Color(0xFF4CAF50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              // Page View
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: onboardingData.length,
                  onPageChanged: (int page) {
                    setState(() {
                      currentPage = page;
                    });
                  },
                  itemBuilder: (context, index) {
                    return OnboardingPage(data: onboardingData[index]);
                  },
                ),
              ),

              // Page Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  onboardingData.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: currentPage == index ? 24 : 8,
                    decoration: BoxDecoration(
                      color:
                          currentPage == index
                              ? const Color(0xFF4CAF50)
                              : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Next/Get Started Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                    onPressed: () {
                      if (currentPage < onboardingData.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      currentPage < onboardingData.length - 1
                          ? 'Next'
                          : 'Get Started',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final IconData icon;

  OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class OnboardingPage extends StatelessWidget {
  final OnboardingData data;

  const OnboardingPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 80, color: const Color(0xFF4CAF50)),
          ),
          const SizedBox(height: 40),
          Text(
            data.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E2E2E),
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced Login Page - Online only

// Tick Animation Screen
class TickAnimation extends StatefulWidget {
  final String message;
  final Map<String, dynamic> arguments;

  const TickAnimation({
    super.key,
    required this.message,
    required this.arguments,
  });

  @override
  State<TickAnimation> createState() => _TickAnimationState();
}

class _TickAnimationState extends State<TickAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    // Navigate after animation
    Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        final isAdmin = widget.arguments['isAdmin'] ?? false;
        Navigator.pushReplacementNamed(
          context,
          isAdmin ? '/admin' : '/students',
          arguments: {
            'userName': widget.arguments['name'] ?? '',
            'userEmail': widget.arguments['email'] ?? '',
            'rollNumber': widget.arguments['rollNumber'] ?? '',
            'groupId': widget.arguments['groupId'] ?? '',
            'groupName': widget.arguments['groupName'] ?? '',
            'department': widget.arguments['department'] ?? '',
          },
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF0F8F0)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 60),
                ),
              ),
              const SizedBox(height: 30),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'Redirecting...',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
