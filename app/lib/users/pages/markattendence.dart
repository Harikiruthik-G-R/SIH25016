import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:location/location.dart' as loc;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Background service (hooks – optional but supported)
import 'package:flutter_background_service/flutter_background_service.dart';

import 'location_validation_service.dart';

class MarkAttendanceScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String rollNumber; // used as studentId for analytics path
  final String groupId;
  final String groupName;
  final String department;

  const MarkAttendanceScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.rollNumber,
    required this.groupId,
    required this.groupName,
    required this.department,
  });

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _waveController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  // UI / state
  bool _loading = false;
  bool _checkedIn = false;
  String? _activeSessionDocId;
  DateTime? _checkInTime;
  String _checkInStatus = 'Ready to check in';

  // Current period info
  int? _currentPeriod;
  String? _currentSubject;
  String? _currentRoomOrLocationName;
  DateTime? _periodStart;
  DateTime? _periodEnd;
  String?
  _campusName; // which location doc matched (e.g., "Lab 2", "Fort", etc.)
  String? _nextSubject;

  // Location bounds from all campus/location docs for this group
  final List<_BoundsBox> _allowedBounds = [];

  // Logs to show in UI
  final List<String> _logs = [];

  // Ticker to auto-checkout at end of period
  Timer? _periodTicker;
  Timer? _uiUpdateTimer;

  // ====== Firestore handles ======
  final _db = FirebaseFirestore.instance;

  // ====== Helpers ======
  void _log(String msg) {
    // visible log + console
    final line = "[${DateTime.now().toIso8601String().substring(11, 19)}] $msg";
    print(line);
    if (mounted) {
      setState(() => _logs.insert(0, line));
    }
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _primeData();
    _startUITimer();
    _restoreSession();
  }

  void _initAnimations() {
    _waveController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeController.forward();
  }

  void _startUITimer() {
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _periodTicker?.cancel();
    _uiUpdateTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  // Restore session on app restart
  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString('active_session_${widget.rollNumber}');
      final checkInTimeStr = prefs.getString(
        'checkin_time_${widget.rollNumber}',
      );

      if (sessionId != null && checkInTimeStr != null) {
        final sessionDoc =
            await _db
                .collection('student_checkins')
                .doc(widget.rollNumber)
                .collection('sessions')
                .doc(sessionId)
                .get();

        if (sessionDoc.exists && sessionDoc.data()?['status'] == 'ongoing') {
          setState(() {
            _activeSessionDocId = sessionId;
            _checkedIn = true;
            _checkInTime = DateTime.parse(checkInTimeStr);
            _checkInStatus = 'Attendance active';
          });
          await WakelockPlus.enable();
          await _startBackgroundTicker();
          _log("Session restored: $sessionId");
        } else {
          // Clear invalid session
          await _clearStoredSession();
        }
      }
    } catch (e) {
      _log("Session restore error: $e");
    }
  }

  Future<void> _saveSession() async {
    if (_activeSessionDocId != null && _checkInTime != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'active_session_${widget.rollNumber}',
        _activeSessionDocId!,
      );
      await prefs.setString(
        'checkin_time_${widget.rollNumber}',
        _checkInTime!.toIso8601String(),
      );
    }
  }

  Future<void> _clearStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_session_${widget.rollNumber}');
    await prefs.remove('checkin_time_${widget.rollNumber}');
  }

  // --------------------------
  // High-level flow
  // --------------------------
  Future<void> _primeData() async {
    setState(() => _loading = true);
    try {
      _log("Loading locations for group: ${widget.groupId}");
      await _loadGroupLocationsAndTimetable();
      _log("Loaded ${_allowedBounds.length} campus bounds.");

      // Check and request permissions early
      await _checkAndRequestPermissions();

      await _resolvePeriodForNow();
      _log("Resolved current period/time.");
    } catch (e, st) {
      _log("Error while priming data: $e");
      print(st);
      _showErrorDialog("Failed to load data. Please try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Enhanced error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Error'),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _primeData(); // Retry
                },
                child: const Text('Retry'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  // Enhanced success dialog
  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Color(0xFF2E7D32)),
                ),
                const SizedBox(width: 12),
                Text(title),
              ],
            ),
            content: Text(message),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  // NEW: Check and request all necessary permissions
  Future<bool> _checkAndRequestPermissions() async {
    try {
      _log("Checking location permissions...");

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _log("Location services are disabled.");
        _showErrorDialog("Please enable location services in device settings.");
        return false;
      }

      // Check current location permission
      LocationPermission permission = await Geolocator.checkPermission();
      _log("Current location permission: $permission");

      if (permission == LocationPermission.denied) {
        _log("Requesting location permission...");
        permission = await Geolocator.requestPermission();
        _log("Permission result: $permission");
      }

      if (permission == LocationPermission.deniedForever) {
        _log("Location permission permanently denied.");
        _showErrorDialog(
          "Location permission permanently denied. Please enable in app settings.",
        );
        return false;
      }

      if (permission == LocationPermission.denied) {
        _log("Location permission denied by user.");
        _showErrorDialog(
          "Location permission is required for attendance marking.",
        );
        return false;
      }

      // Try to request background location if needed (for continuous tracking)
      if (permission == LocationPermission.whileInUse) {
        _log("Attempting to get background location permission...");
        try {
          final bgPermission = await Permission.locationAlways.request();
          _log("Background location permission: $bgPermission");
          if (bgPermission.isGranted) {
            _log("Background location permission granted.");
          } else {
            _log(
              "Background location permission not granted, continuing with foreground only.",
            );
          }
        } catch (e) {
          _log("Background permission request failed (non-fatal): $e");
        }
      }

      _log("Location permissions configured successfully.");
      return true;
    } catch (e) {
      _log("Error checking permissions: $e");
      return false;
    }
  }

  // Loads locations from timetables collection for the group
  // Reads location bounds directly from timetable documents
  Future<void> _loadGroupLocationsAndTimetable() async {
    _allowedBounds.clear();

    try {
      // Query timetables for this group
      final q =
          await _db
              .collection('timetables')
              .where('groupId', isEqualTo: widget.groupId)
              .get();

      if (q.docs.isEmpty) {
        _log("No timetables found for group ${widget.groupId}");
        return;
      }

      _log("Found ${q.docs.length} timetable(s) for group ${widget.groupId}");

      for (final d in q.docs) {
        final data = d.data();
        final timetableId = d.id;

        // Read locations from the timetable document
        final locations = data['locations'] as Map<String, dynamic>?;
        if (locations == null) {
          _log("No locations found in timetable $timetableId");
          continue;
        }

        _log(
          "Processing ${locations.length} locations from timetable $timetableId",
        );

        // Process each location in the timetable
        for (final entry in locations.entries) {
          final locationName = entry.key;
          final locationData = entry.value as Map<String, dynamic>?;

          if (locationData == null) continue;

          final bounds = locationData['bounds'] as Map<String, dynamic>?;
          if (bounds == null) {
            _log("No bounds found for location $locationName");
            continue;
          }

          _log("Loading bounds for location: $locationName");

          final box = _BoundsBox.fromMap(bounds);
          if (box != null) {
            _allowedBounds.add(
              box.copyWith(timetableId: timetableId, campusName: locationName),
            );
            _log(
              "Added bounds for $locationName: ${bounds['topLeftLat']}, ${bounds['topLeftLng']} to ${bounds['bottomRightLat']}, ${bounds['bottomRightLng']}",
            );
          } else {
            _log("Failed to parse bounds for location $locationName");
          }
        }
      }

      _log("Total locations loaded: ${_allowedBounds.length}");
    } catch (e, st) {
      _log("Error loading locations from timetables: $e");
      print(st);
    }
  }

  // FIXED: New method to check if current time is within a time range string
  bool _isWithinTimeRange(String timeRange) {
    try {
      final parts = timeRange.split('-');
      if (parts.length != 2) return false;

      final now = DateTime.now();

      final startParts = parts[0].split(':');
      final startHour = int.parse(startParts[0]);
      final startMinute = int.parse(startParts[1]);

      final endParts = parts[1].split(':');
      final endHour = int.parse(endParts[0]);
      final endMinute = int.parse(endParts[1]);

      final startTime = DateTime(
        now.year,
        now.month,
        now.day,
        startHour,
        startMinute,
      );
      DateTime endTime = DateTime(
        now.year,
        now.month,
        now.day,
        endHour,
        endMinute,
      );

      // Handle cases where end time is next day (like 23:00-01:00)
      if (endTime.isBefore(startTime)) {
        endTime = endTime.add(const Duration(days: 1));
      }

      return now.isAfter(startTime) && now.isBefore(endTime);
    } catch (e) {
      _log("Error parsing time range '$timeRange': $e");
      return false;
    }
  }

  // FIXED: Check against actual Firestore structure (schedule > Friday > 1)
  Future<void> _resolvePeriodFromFirestore() async {
    if (_allowedBounds.isEmpty) {
      _currentPeriod = null;
      _currentSubject = null;
      _currentRoomOrLocationName = null;
      _nextSubject = null;
      _periodStart = null;
      _periodEnd = null;
      return;
    }

    // Get timetableId from first available bounds
    final timetableId =
        _allowedBounds
            .firstWhere(
              (b) => b.timetableId != null,
              orElse: () => _allowedBounds.first,
            )
            .timetableId;

    if (timetableId == null) {
      _log("No timetableId linked to locations; cannot resolve period.");
      return;
    }

    try {
      final now = DateTime.now();
      final dayName = _weekdayName(now.weekday);

      _log("Checking timetable for $dayName in document: $timetableId");

      // Query the correct structure: timetables/{id}/schedule/{DayName}/{period}
      final timetableDoc =
          await _db.collection('timetables').doc(timetableId).get();

      if (!timetableDoc.exists) {
        _log("Timetable document $timetableId not found");
        return;
      }

      final timetableData = timetableDoc.data();
      if (timetableData == null) {
        _log("Timetable data is null");
        return;
      }

      // Navigate: schedule > Friday > 1, 2, 3...
      final schedule = timetableData['schedule'] as Map<String, dynamic>?;
      if (schedule == null) {
        _log("No 'schedule' field in timetable");
        return;
      }

      final daySchedule = schedule[dayName] as Map<String, dynamic>?;
      if (daySchedule == null) {
        _log("No schedule found for $dayName");
        _resetPeriodState();
        return;
      }

      _log("Found schedule for $dayName with ${daySchedule.length} periods");

      // Find current active period
      String? currentPeriodKey;
      Map<String, dynamic>? currentPeriodData;
      String? nextPeriodKey;
      Map<String, dynamic>? nextPeriodData;

      // Check each period (1, 2, 3, etc.)
      for (final entry in daySchedule.entries) {
        final periodKey = entry.key;
        final periodData = entry.value as Map<String, dynamic>?;

        if (periodData == null) continue;

        final timeRange = periodData['time'] as String?;
        if (timeRange == null) continue;

        _log(
          "Checking period $periodKey: ${periodData['subject']} at $timeRange",
        );

        if (_isWithinTimeRange(timeRange)) {
          currentPeriodKey = periodKey;
          currentPeriodData = periodData;
          _log(
            "✅ Found active period $periodKey: ${periodData['subject']} at $timeRange",
          );
          break;
        } else {
          _log(
            "❌ Not in active period $periodKey: ${periodData['subject']} at $timeRange",
          );
        }
      }

      if (currentPeriodData != null && currentPeriodKey != null) {
        final timeRange = currentPeriodData['time'] as String;
        final timeParts = timeRange.split('-');

        // Parse start and end times
        final startParts = timeParts[0].split(':');
        final endParts = timeParts[1].split(':');

        final startTime = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(startParts[0]),
          int.parse(startParts[1]),
        );

        DateTime endTime = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(endParts[0]),
          int.parse(endParts[1]),
        );

        // Handle next day end time
        if (endTime.isBefore(startTime)) {
          endTime = endTime.add(const Duration(days: 1));
        }

        // Find next period (period number + 1)
        final currentPeriodNum = int.tryParse(currentPeriodKey) ?? 0;
        final nextPeriodKeyToCheck = (currentPeriodNum + 1).toString();
        nextPeriodData =
            daySchedule[nextPeriodKeyToCheck] as Map<String, dynamic>?;

        if (mounted) {
          setState(() {
            _currentPeriod = currentPeriodNum;
            _currentSubject = currentPeriodData!['subject']?.toString();
            _currentRoomOrLocationName =
                currentPeriodData['location']?.toString();
            _periodStart = startTime;
            _periodEnd = endTime;
            _nextSubject = nextPeriodData?['subject']?.toString();
          });
        }

        _log(
          "Current period: P$_currentPeriod ($_currentSubject) until ${_fmtHM(endTime)}",
        );
        if (_nextSubject != null) {
          _log("Next subject: $_nextSubject");
        }
      } else {
        _log("No active period found for current time");
        _resetPeriodState();
      }
    } catch (e, st) {
      _log("Error querying Firestore timetable: $e");
      print(st);
      _resetPeriodState();
    }
  }

  void _resetPeriodState() {
    if (mounted) {
      setState(() {
        _currentPeriod = null;
        _currentSubject = null;
        _currentRoomOrLocationName = null;
        _nextSubject = null;
        _periodStart = null;
        _periodEnd = null;
      });
    }
  }

  DateTime? _parseStartTime(String timeRange, DateTime baseDate) {
    try {
      final parts = timeRange.split('-');
      if (parts.isEmpty) return null;

      final startParts = parts[0].split(':');
      return DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        int.parse(startParts[0]),
        int.parse(startParts[1]),
      );
    } catch (e) {
      return null;
    }
  }

  // Resolve what period we are currently in, load subject/location info and next subject.
  Future<void> _resolvePeriodForNow() async {
    // Use the new Firestore-based approach instead of the old one
    await _resolvePeriodFromFirestore();
    return;
  }

  // --------------------------
  // Check-in/out
  // --------------------------

  Future<void> _onCheckInPressed() async {
    if (_loading) return;
    if (_checkedIn) {
      _showErrorDialog("Already checked in.");
      return;
    }
    if (_currentPeriod == null || _periodStart == null || _periodEnd == null) {
      _showErrorDialog("Not within any period window right now.");
      _log("Check-in blocked: no active period.");
      return;
    }

    // Start wave animation
    _waveController.repeat();
    setState(() {
      _loading = true;
      _checkInStatus = 'Getting location...';
    });

    try {
      // Location permission + current position
      setState(() => _checkInStatus = 'Checking location...');
      final position = await _getPositionOrAsk();
      if (position == null) {
        _showErrorDialog("Location permission denied or unavailable.");
        _log("Permission denied.");
        return;
      }

      setState(() => _checkInStatus = 'Validating campus bounds...');
      // Validate inside ANY allowed bounds (Railway/Fort/etc.)
      final inside = _firstBoundsContaining(
        position.latitude,
        position.longitude,
      );
      if (inside == null) {
        _showErrorDialog("You are not within an allowed campus boundary.");
        _log("Check-in blocked: outside all bounds.");
        return;
      }

      _campusName = inside.campusName;

      setState(() => _checkInStatus = 'Creating session...');
      // Create session document
      final sessionsColl = _db
          .collection('student_checkins')
          .doc(widget.rollNumber) // use rollNumber as stable id
          .collection('sessions');

      final now = DateTime.now();
      final docRef = await sessionsColl.add({
        'student': {
          'name': widget.userName,
          'email': widget.userEmail,
          'rollNumber': widget.rollNumber,
          'department': widget.department,
          'groupId': widget.groupId,
          'groupName': widget.groupName,
        },
        'campus': _campusName,
        'day': _weekdayName(now.weekday),
        'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
        'period': _currentPeriod,
        'subject': _currentSubject,
        'roomOrLocation': _currentRoomOrLocationName,
        'checkInAt': Timestamp.fromDate(now),
        'expectedEndAt': Timestamp.fromDate(_periodEnd!),
        'checkInLat': position.latitude,
        'checkInLng': position.longitude,
        'status': 'ongoing',
        'logs': ['check-in created at ${now.toIso8601String()}'],
      });

      _activeSessionDocId = docRef.id;
      _checkInTime = now;
      _checkedIn = true;
      _checkInStatus = 'Attendance active';

      // Save session to local storage
      await _saveSession();

      _log(
        "Checked in for period $_currentPeriod ($_currentSubject) at $_campusName.",
      );

      // Show success dialog
      _showSuccessDialog(
        'Check-in Successful!',
        'You are now checked in for $_currentSubject at $_campusName. Keep your device active to maintain attendance.',
      );

      // Keep device awake and start background ticker
      await WakelockPlus.enable();
      await _startBackgroundTicker();

      // Start pulse animation
      _pulseController.repeat(reverse: true);
    } catch (e, st) {
      _log("Check-in error: $e");
      print(st);
      _showErrorDialog("Check-in failed. Please try again.");
    } finally {
      _waveController.stop();
      _waveController.reset();
      if (mounted) {
        setState(() {
          _loading = false;
          if (!_checkedIn) _checkInStatus = 'Ready to check in';
        });
      }
    }
  }

  Future<void> _onCheckoutPressed() async {
    if (_loading) return;
    if (!_checkedIn || _activeSessionDocId == null) {
      _showErrorDialog("You haven't checked in yet.");
      return;
    }

    final ok = await _confirm(
      title: "Checkout Confirmation",
      message:
          "Are you sure you want to check out now? If you check out early, the session will be closed and you may be marked absent.",
      confirmText: "Yes, Checkout",
      cancelText: "Cancel",
    );

    if (ok != true) {
      _log("Checkout canceled by user.");
      return;
    }

    setState(() {
      _loading = true;
      _checkInStatus = 'Checking out...';
    });

    try {
      final position = await _safePosition();
      await _completeSession(
        reason: "manual",
        checkoutLat: position?.latitude,
        checkoutLng: position?.longitude,
      );

      _showSuccessDialog(
        'Checkout Successful!',
        'You have been checked out successfully. Your attendance has been recorded.',
      );
    } catch (e, st) {
      _log("Checkout error: $e");
      print(st);
      _showErrorDialog("Checkout failed. Please try again.");
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _checkInStatus = 'Ready to check in';
        });
      }
    }
  }

  // Auto-checkout at end of period
  Future<void> _autoCheckout() async {
    if (!_checkedIn || _activeSessionDocId == null) return;
    _log("Auto-checkout triggered (period end).");
    try {
      final position = await _safePosition();
      await _completeSession(
        reason: "period_ended",
        checkoutLat: position?.latitude,
        checkoutLng: position?.longitude,
      );

      _showSuccessDialog(
        'Period Ended',
        'Your attendance session has been automatically completed.',
      );

      // Prepare next period (if any)
      await _resolvePeriodForNow();
      if (_currentPeriod != null) {
        _log("Next period is $_currentPeriod ($_currentSubject).");
      } else {
        _log("No further periods today.");
      }
    } catch (e) {
      _log("Auto-checkout failed: $e");
    }
  }

  // Update session doc to completed
  Future<void> _completeSession({
    required String reason,
    double? checkoutLat,
    double? checkoutLng,
  }) async {
    _periodTicker?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    await _stopBackgroundService();
    await WakelockPlus.disable();
    await _clearStoredSession();

    if (_activeSessionDocId == null) return;

    final now = DateTime.now();
    final docRef = _db
        .collection('student_checkins')
        .doc(widget.rollNumber)
        .collection('sessions')
        .doc(_activeSessionDocId);

    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data()!;
    final DateTime checkInAt = (data['checkInAt'] as Timestamp).toDate();
    final durationMinutes =
        now.difference(checkInAt).inSeconds / 60.0; // fractional minutes

    await docRef.update({
      'checkOutAt': Timestamp.fromDate(now),
      'checkOutLat': checkoutLat,
      'checkOutLng': checkoutLng,
      'status': 'completed',
      'durationMinutes': durationMinutes,
      'closeReason': reason,
      'logs': FieldValue.arrayUnion([
        'checkout $reason at ${now.toIso8601String()}',
      ]),
    });

    _log(
      "Session ${_activeSessionDocId!} closed. Duration: ${durationMinutes.toStringAsFixed(1)} min.",
    );

    // Reset UI flags
    if (mounted) {
      setState(() {
        _activeSessionDocId = null;
        _checkedIn = false;
        _checkInTime = null;
        _checkInStatus = 'Ready to check in';
      });
    }
  }

  // --------------------------
  // Background ticker & timing
  // --------------------------

  Future<void> _startBackgroundTicker() async {
    // Local ticker to check period end every 10s (also updates progress)
    _periodTicker?.cancel();
    _periodTicker = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_periodEnd != null && DateTime.now().isAfter(_periodEnd!)) {
        _periodTicker?.cancel();
        await _autoCheckout();
      } else {
        if (mounted) setState(() {}); // refresh progress UI
      }
    });

    // Optional Android foreground service so the OS keeps us running.
    if (Platform.isAndroid) {
      try {
        final service = FlutterBackgroundService();
        final started = await service.isRunning();
        if (!started) {
          await service.startService();
          _log("Background service started.");
        } else {
          _log("Background service already running.");
        }
      } catch (e) {
        _log("Background service start failed (non-fatal): $e");
      }
    }
  }

  Future<void> _stopBackgroundService() async {
    if (Platform.isAndroid) {
      try {
        final service = FlutterBackgroundService();
        if (await service.isRunning()) {
          service.invoke('stopService');
          _log("Background service stop invoked.");
        }
      } catch (_) {}
    }
  }

  // --------------------------
  // Utils
  // --------------------------

  // IMPROVED: Better error handling and multiple fallback strategies
Future<geo.Position?> _getPositionOrAsk() async {
  try {
    _log("Checking location service availability...");
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _log("Location services are disabled.");
      return null;
    }

    _log("Checking location permissions...");
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    _log("Current permission status: $permission");

    if (permission == geo.LocationPermission.deniedForever) {
      _log("Location permissions are permanently denied.");
      return null;
    }

    if (permission == geo.LocationPermission.denied) {
      _log("Requesting location permission...");
      permission = await geo.Geolocator.requestPermission();
      _log("Permission request result: $permission");

      if (permission != geo.LocationPermission.always &&
          permission != geo.LocationPermission.whileInUse) {
        _log("Location permission not granted.");
        return null;
      }
    }

    // NEW: Use location package for mock detection
    loc.Location location = loc.Location();
    loc.LocationData? locationData;

    // Try multiple strategies to get location with mock detection
    geo.Position? position;

    // Strategy 1: High accuracy with mock detection
    try {
      _log("Attempting high accuracy location with mock detection...");
      locationData = await location.getLocation();
      
      // NEW: Validate location for mocking
      final validationResult = await LocationValidationService.validateLocation(locationData);
      if (validationResult['isMocked'] == true) {
        _log("Mock location detected: ${validationResult['reason']}");
        // Throw custom exception that calling code can handle
        throw MockLocationException(validationResult['reason']);
      }
      
      // Convert LocationData to Position for compatibility
      position = geo.Position(
        longitude: locationData.longitude!,
        latitude: locationData.latitude!,
        timestamp: DateTime.fromMillisecondsSinceEpoch(locationData.time!.toInt()),
        accuracy: locationData.accuracy!,
        altitude: locationData.altitude ?? 0.0,
        altitudeAccuracy: 0.0, // LocationData doesn't have altitudeAccuracy, set default
        heading: locationData.heading ?? 0.0,
        headingAccuracy: 0.0, // LocationData doesn't have headingAccuracy, set default
        speed: locationData.speed ?? 0.0,
        speedAccuracy: 0.0, // LocationData doesn't have speedAccuracy, set default
      );
      
      _log("High accuracy position obtained: ${position.latitude}, ${position.longitude}");
      return position;
    } on MockLocationException {
      rethrow; // Re-throw mock location exceptions
    } catch (e) {
      _log("High accuracy with mock detection failed: $e");
    }

    // Strategy 2: Fallback to Geolocator (less mock detection but still functional)
    try {
      _log("Attempting fallback location...");
      position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      _log("Fallback position obtained: ${position.latitude}, ${position.longitude}");
      return position;
    } catch (e) {
      _log("Fallback location failed: $e");
    }

    // Strategy 3: Last known position
    try {
      _log("Attempting to get last known position...");
      position = await geo.Geolocator.getLastKnownPosition();
      if (position != null) {
        _log("Last known position obtained: ${position.latitude}, ${position.longitude}");
        return position;
      }
    } catch (e) {
      _log("Last known position failed: $e");
    }

    _log("All location strategies failed.");
    return null;
  } catch (e) {
    if (e is MockLocationException) {
      rethrow; // Let mock location exceptions bubble up
    }
    _log("Error in location process: $e");
    return null;
  }
}

// Update your existing _safePosition method to use proper prefixing
Future<geo.Position?> _safePosition() async {
  try {
    return await geo.Geolocator.getCurrentPosition(
      desiredAccuracy: geo.LocationAccuracy.medium,
    ).timeout(const Duration(seconds: 6));
  } catch (e) {
    _log("Safe position failed: $e");
    return null;
  }
}

// Update the method signature in _firstBoundsContaining if needed
_BoundsBox? _firstBoundsContaining(double lat, double lng) {
  for (final b in _allowedBounds) {
    if (b.contains(lat, lng)) return b;
  }
  return null;
}
  Future<bool?> _confirm({
    required String title,
    required String message,
    String confirmText = "OK",
    String cancelText = "Cancel",
  }) {
    return showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(cancelText),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
                child: Text(confirmText),
              ),
            ],
          ),
    );
  }

  static String _weekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[(weekday - 1) % 7];
  }

  static DateTime _hmToToday(DateTime base, String hhmm) {
    final parts = hhmm.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return DateTime(base.year, base.month, base.day, h, m);
  }

  static Map<String, dynamic> _defaultPeriodTimings() {
    // Fallback if timetable doesn't define explicit times
    // Adjust as per your institute
    return {
      "1": {"start": "09:00", "end": "09:50"},
      "2": {"start": "09:50", "end": "10:40"},
      "3": {"start": "10:55", "end": "11:45"},
      "4": {"start": "11:45", "end": "12:35"},
      "5": {"start": "13:30", "end": "14:20"},
      "6": {"start": "14:20", "end": "15:10"},
      "7": {"start": "15:20", "end": "16:10"},
    };
  }

  // --------------------------
  // UI
  // --------------------------
  @override
  Widget build(BuildContext context) {
    final canCheckIn =
        !_checkedIn &&
        !_loading &&
        _currentPeriod != null &&
        _periodStart != null &&
        _periodEnd != null;

    final canCheckOut = _checkedIn && !_loading;

    final remainingStr =
        _periodEnd == null
            ? "-"
            : _fmtDuration(_periodEnd!.difference(DateTime.now()));

    final progress =
        _periodStart != null && _periodEnd != null
            ? _progressPct(_periodStart!, _periodEnd!, DateTime.now())
            : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text(
          'Mark Attendance',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _primeData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeController,
        child: Column(
          children: [
            // Enhanced Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            Text(
                              "${widget.rollNumber} • ${widget.department}",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_checkedIn && _checkInTime != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.greenAccent,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.greenAccent.withOpacity(
                                        0.3 + (_pulseController.value * 0.7),
                                      ),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _checkInStatus,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  "Since ${_fmtTime(_checkInTime!)} • ${_getSessionDuration()}",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Main content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildEnhancedStatusCard(
                    canCheckIn: canCheckIn,
                    canCheckOut: canCheckOut,
                    progress: progress,
                    remainingStr: remainingStr,
                  ),
                  const SizedBox(height: 20),
                  if (_checkedIn) _buildSessionDetailsCard(),
                  if (_checkedIn) const SizedBox(height: 20),
                  _buildQuickInfoCard(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildEnhancedButton(
                  onPressed: canCheckIn ? _onCheckInPressed : null,
                  icon: Icons.login_rounded,
                  label: "Check In",
                  backgroundColor: const Color(0xFF2E7D32),
                  isLoading: _loading && !_checkedIn,
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEnhancedButton(
                  onPressed: canCheckOut ? _onCheckoutPressed : null,
                  icon: Icons.logout_rounded,
                  label: "Check Out",
                  backgroundColor: const Color(0xFFFF6B35),
                  isLoading: _loading && _checkedIn,
                  isPrimary: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color backgroundColor,
    bool isLoading = false,
    bool isPrimary = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              onPressed != null ? backgroundColor : Colors.grey.shade300,
          foregroundColor:
              onPressed != null ? Colors.white : Colors.grey.shade600,
          elevation: onPressed != null ? 4 : 0,
          shadowColor: backgroundColor.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child:
            isLoading
                ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      onPressed != null ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildEnhancedStatusCard({
    required bool canCheckIn,
    required bool canCheckOut,
    required double progress,
    required String remainingStr,
  }) {
    final now = DateTime.now();
    final day = _weekdayName(now.weekday);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.schedule,
                  color: Color(0xFF2E7D32),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Current Period",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E2E2E),
                      ),
                    ),
                    Text(
                      day,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(canCheckIn, canCheckOut),
            ],
          ),

          const SizedBox(height: 20),

          // Current and Next Period Info
          Row(
            children: [
              Expanded(
                child: _buildPeriodInfo(
                  title: "Current",
                  period: _currentPeriod?.toString() ?? "—",
                  subject: _currentSubject ?? "No class",
                  location: _currentRoomOrLocationName ?? _campusName ?? "—",
                  isActive: true,
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.grey.shade200,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              Expanded(
                child: _buildPeriodInfo(
                  title: "Next",
                  period: _nextSubject != null ? "Up next" : "—",
                  subject: _nextSubject ?? "No class",
                  location: remainingStr != "-" ? "In $remainingStr" : "—",
                  isActive: false,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Progress Bar with Time
          if (_periodStart != null && _periodEnd != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _fmtTime(_periodStart!),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _fmtTime(_periodEnd!),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress < 0.8 ? const Color(0xFF2E7D32) : Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                remainingStr != "-"
                    ? "$remainingStr remaining"
                    : "No active period",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "No active period right now",
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Loading animation for check-in
          if (_loading && !_checkedIn) ...[
            const SizedBox(height: 20),
            _buildLoadingIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final delay = index * 0.2;
                  final animationValue = (_waveController.value - delay).clamp(
                    0.0,
                    1.0,
                  );
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 6,
                    height: 20 + (10 * math.sin(animationValue * math.pi)),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF2E7D32,
                      ).withOpacity(0.3 + (0.7 * animationValue)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            _checkInStatus,
            style: const TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool canCheckIn, bool canCheckOut) {
    Color backgroundColor;
    Color textColor;
    String text;
    IconData icon;

    if (canCheckOut) {
      backgroundColor = const Color(0xFFE8F5E9);
      textColor = const Color(0xFF2E7D32);
      text = "Active";
      icon = Icons.check_circle;
    } else if (canCheckIn) {
      backgroundColor = const Color(0xFFFFF3E0);
      textColor = const Color(0xFFFF9800);
      text = "Ready";
      icon = Icons.radio_button_unchecked;
    } else {
      backgroundColor = Colors.grey.shade100;
      textColor = Colors.grey.shade600;
      text = "Waiting";
      icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodInfo({
    required String title,
    required String period,
    required String subject,
    required String location,
    required bool isActive,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          period,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isActive ? const Color(0xFF2E7D32) : Colors.grey.shade700,
          ),
        ),
        Text(
          subject,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2E2E2E),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          location,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildSessionDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  color: Color(0xFF2E7D32),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Session Details",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E2E2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            "Check-in Time",
            _checkInTime != null ? _fmtTime(_checkInTime!) : "—",
          ),
          _buildDetailRow("Duration", _getSessionDuration()),
          _buildDetailRow("Campus", _campusName ?? "—"),
          _buildDetailRow(
            "Session ID",
            _activeSessionDocId?.substring(0, 8) ?? "—",
          ),
          if (_periodEnd != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFCC80)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    color: Color(0xFFFF9800),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Auto checkout at ${_fmtTime(_periodEnd!)}",
                      style: const TextStyle(
                        color: Color(0xFFFF9800),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF2E2E2E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Info",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E2E2E),
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickInfoRow(Icons.group, "Group", widget.groupName),
          _buildQuickInfoRow(Icons.email, "Email", widget.userEmail),
          _buildQuickInfoRow(Icons.school, "Department", widget.department),
        ],
      ),
    );
  }

  Widget _buildQuickInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF2E2E2E),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getSessionDuration() {
    if (_checkInTime == null) return "—";
    final duration = DateTime.now().difference(_checkInTime!);
    return _fmtDuration(duration);
  }

  // --------------------------
  // Formatting helpers
  // --------------------------

  static String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  static String _fmtHM(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  static String _fmtDuration(Duration d) {
    if (d.isNegative) return "0m";
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return "${h}h ${m}m";
    return "${m}m";
  }

  static double _progressPct(DateTime start, DateTime end, DateTime now) {
    final total = end.difference(start).inSeconds;
    final done = now.difference(start).inSeconds;
    if (total <= 0) return 0;
    return (done / total).clamp(0.0, 1.0);
  }
}

class MockLocationException implements Exception {
  final String reason;
  MockLocationException(this.reason);
  
  @override
  String toString() => 'MockLocationException: $reason';
}
// =====================
// Bounds helper
// =====================
class _BoundsBox {
  final double topLeftLat;
  final double topLeftLng;
  final double bottomRightLat;
  final double bottomRightLng;
  final String? timetableId;
  final String campusName;

  const _BoundsBox({
    required this.topLeftLat,
    required this.topLeftLng,
    required this.bottomRightLat,
    required this.bottomRightLng,
    required this.campusName,
    this.timetableId,
  });

  factory _BoundsBox.from({
    required double topLeftLat,
    required double topLeftLng,
    required double bottomRightLat,
    required double bottomRightLng,
    required String campusName,
    String? timetableId,
  }) {
    return _BoundsBox(
      topLeftLat: topLeftLat,
      topLeftLng: topLeftLng,
      bottomRightLat: bottomRightLat,
      bottomRightLng: bottomRightLng,
      campusName: campusName,
      timetableId: timetableId,
    );
  }

  _BoundsBox copyWith({String? timetableId, String? campusName}) {
    return _BoundsBox(
      topLeftLat: topLeftLat,
      topLeftLng: topLeftLng,
      bottomRightLat: bottomRightLat,
      bottomRightLng: bottomRightLng,
      campusName: campusName ?? this.campusName,
      timetableId: timetableId ?? this.timetableId,
    );
  }

  static _BoundsBox? fromMap(Map<String, dynamic> map) {
    try {
      return _BoundsBox(
        topLeftLat: (map['topLeftLat'] as num).toDouble(),
        topLeftLng: (map['topLeftLng'] as num).toDouble(),
        bottomRightLat: (map['bottomRightLat'] as num).toDouble(),
        bottomRightLng: (map['bottomRightLng'] as num).toDouble(),
        campusName: "Campus",
      );
    } catch (_) {
      return null;
    }
  }

  bool contains(double lat, double lng) {
    // top-left (max lat, min lng) and bottom-right (min lat, max lng)
    final minLat = bottomRightLat;
    final maxLat = topLeftLat;
    final minLng = topLeftLng;
    final maxLng = bottomRightLng;
    return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
  }
}
