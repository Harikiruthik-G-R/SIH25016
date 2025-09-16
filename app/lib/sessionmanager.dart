import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class SessionManager {
  // Keys for storing session data
  static const String _keyIsLoggedIn = 'isLoggedIn';
  static const String _keyIsAdmin = 'isAdmin';
  static const String _keyIsTeacher = 'isTeacher';
  static const String _keyUserName = 'userName';
  static const String _keyUserEmail = 'userEmail';
  static const String _keyRollNumber = 'rollNumber';
  static const String _keyGroupId = 'groupId';
  static const String _keyGroupName = 'groupName';
  static const String _keyDepartment = 'department';
  static const String _keyTeacherId = 'teacherId';
  static const String _keyTeacherSubjects = 'teacherSubjects';
  static const String _keyDesignation = 'designation';
  static const String _keyLoginTime = 'loginTime';
  static const String _keyLastActivity = 'lastActivity';

  /// Save complete session with all user data
  /// This method stores all user information securely in SharedPreferences
  static Future<void> saveSession({
    required bool isLoggedIn,
    required bool isAdmin,
    required String userName,
    required String userEmail,
    String rollNumber = '',
    String groupId = '',
    String groupName = '',
    String department = '',
    bool isTeacher = false,
    String teacherId = '',
    List<String> teacherSubjects = const [],
    String designation = '',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentTime = DateTime.now().millisecondsSinceEpoch.toString();

      // Save all session data
      await Future.wait([
        prefs.setBool(_keyIsLoggedIn, isLoggedIn),
        prefs.setBool(_keyIsAdmin, isAdmin),
        prefs.setBool(_keyIsTeacher, isTeacher),
        prefs.setString(_keyUserName, userName),
        prefs.setString(_keyUserEmail, userEmail),
        prefs.setString(_keyRollNumber, rollNumber),
        prefs.setString(_keyGroupId, groupId),
        prefs.setString(_keyGroupName, groupName),
        prefs.setString(_keyDepartment, department),
        prefs.setString(_keyTeacherId, teacherId),
        prefs.setStringList(_keyTeacherSubjects, teacherSubjects),
        prefs.setString(_keyDesignation, designation),
        prefs.setString(_keyLoginTime, currentTime),
        prefs.setString(_keyLastActivity, currentTime),
      ]);

      debugPrint('Session saved successfully for user: $userName');
    } catch (e) {
      debugPrint('Error saving session: $e');
      rethrow; // Re-throw to allow caller to handle the error
    }
  }

  /// Get complete session data
  /// Returns a map containing all stored session information
  static Future<Map<String, dynamic>> getSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final sessionData = {
        'isLoggedIn': prefs.getBool(_keyIsLoggedIn) ?? false,
        'isAdmin': prefs.getBool(_keyIsAdmin) ?? false,
        'isTeacher': prefs.getBool(_keyIsTeacher) ?? false,
        'userName': prefs.getString(_keyUserName) ?? '',
        'userEmail': prefs.getString(_keyUserEmail) ?? '',
        'rollNumber': prefs.getString(_keyRollNumber) ?? '',
        'groupId': prefs.getString(_keyGroupId) ?? '',
        'groupName': prefs.getString(_keyGroupName) ?? '',
        'department': prefs.getString(_keyDepartment) ?? '',
        'teacherId': prefs.getString(_keyTeacherId) ?? '',
        'teacherSubjects': prefs.getStringList(_keyTeacherSubjects) ?? [],
        'designation': prefs.getString(_keyDesignation) ?? '',
        'loginTime': prefs.getString(_keyLoginTime) ?? '',
        'lastActivity': prefs.getString(_keyLastActivity) ?? '',
      };

      // Update last activity time
      await updateLastActivity();

      return sessionData;
    } catch (e) {
      debugPrint('Error getting session: $e');
      return _getEmptySession();
    }
  }

  /// Get empty session data structure
  static Map<String, dynamic> _getEmptySession() {
    return {
      'isLoggedIn': false,
      'isAdmin': false,
      'userName': '',
      'userEmail': '',
      'rollNumber': '',
      'groupId': '',
      'groupName': '',
      'department': '',
      'loginTime': '',
      'lastActivity': '',
    };
  }

  /// Clear all session data
  /// This completely removes all stored session information
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Remove all session keys
      await Future.wait([
        prefs.remove(_keyIsLoggedIn),
        prefs.remove(_keyIsAdmin),
        prefs.remove(_keyUserName),
        prefs.remove(_keyUserEmail),
        prefs.remove(_keyRollNumber),
        prefs.remove(_keyGroupId),
        prefs.remove(_keyGroupName),
        prefs.remove(_keyDepartment),
        prefs.remove(_keyLoginTime),
        prefs.remove(_keyLastActivity),
      ]);

      debugPrint('Session cleared successfully');
    } catch (e) {
      debugPrint('Error clearing session: $e');
      rethrow;
    }
  }

  /// Check if user is currently logged in
  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;

      if (isLoggedIn) {
        // Verify session is still valid by checking if user data exists
        final userName = prefs.getString(_keyUserName) ?? '';
        final userEmail = prefs.getString(_keyUserEmail) ?? '';

        if (userName.isEmpty || userEmail.isEmpty) {
          // Invalid session, clear it
          await clearSession();
          return false;
        }

        // Update last activity
        await updateLastActivity();
      }

      return isLoggedIn;
    } catch (e) {
      debugPrint('Error checking login status: $e');
      return false;
    }
  }

  /// Check if current user is an admin
  static Future<bool> isAdmin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyIsAdmin) ?? false;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  /// Get user's display name
  static Future<String> getUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserName) ?? '';
    } catch (e) {
      debugPrint('Error getting user name: $e');
      return '';
    }
  }

  /// Get user's email address
  static Future<String> getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserEmail) ?? '';
    } catch (e) {
      debugPrint('Error getting user email: $e');
      return '';
    }
  }

  /// Get student's roll number
  static Future<String> getRollNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyRollNumber) ?? '';
    } catch (e) {
      debugPrint('Error getting roll number: $e');
      return '';
    }
  }

  /// Get user's group ID
  static Future<String> getGroupId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyGroupId) ?? '';
    } catch (e) {
      debugPrint('Error getting group ID: $e');
      return '';
    }
  }

  /// Get user's group name
  static Future<String> getGroupName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyGroupName) ?? '';
    } catch (e) {
      debugPrint('Error getting group name: $e');
      return '';
    }
  }

  /// Get user's department
  static Future<String> getDepartment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyDepartment) ?? '';
    } catch (e) {
      debugPrint('Error getting department: $e');
      return '';
    }
  }

  /// Get login timestamp
  static Future<DateTime?> getLoginTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeString = prefs.getString(_keyLoginTime);
      if (timeString != null && timeString.isNotEmpty) {
        final timestamp = int.tryParse(timeString);
        if (timestamp != null) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting login time: $e');
      return null;
    }
  }

  /// Get last activity timestamp
  static Future<DateTime?> getLastActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeString = prefs.getString(_keyLastActivity);
      if (timeString != null && timeString.isNotEmpty) {
        final timestamp = int.tryParse(timeString);
        if (timestamp != null) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting last activity: $e');
      return null;
    }
  }

  /// Update last activity timestamp
  static Future<void> updateLastActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentTime = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString(_keyLastActivity, currentTime);
    } catch (e) {
      debugPrint('Error updating last activity: $e');
    }
  }

  /// Update user's display name
  static Future<void> updateUserName(String userName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserName, userName);
      await updateLastActivity();
      debugPrint('User name updated to: $userName');
    } catch (e) {
      debugPrint('Error updating user name: $e');
      rethrow;
    }
  }

  /// Update user's email address
  static Future<void> updateUserEmail(String userEmail) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserEmail, userEmail);
      await updateLastActivity();
      debugPrint('User email updated to: $userEmail');
    } catch (e) {
      debugPrint('Error updating user email: $e');
      rethrow;
    }
  }

  /// Update user's roll number
  static Future<void> updateRollNumber(String rollNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRollNumber, rollNumber);
      await updateLastActivity();
      debugPrint('Roll number updated to: $rollNumber');
    } catch (e) {
      debugPrint('Error updating roll number: $e');
      rethrow;
    }
  }

  /// Update user's group information
  static Future<void> updateGroupInfo(String groupId, String groupName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString(_keyGroupId, groupId),
        prefs.setString(_keyGroupName, groupName),
      ]);
      await updateLastActivity();
      debugPrint('Group info updated - ID: $groupId, Name: $groupName');
    } catch (e) {
      debugPrint('Error updating group info: $e');
      rethrow;
    }
  }

  /// Update user's department
  static Future<void> updateDepartment(String department) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDepartment, department);
      await updateLastActivity();
      debugPrint('Department updated to: $department');
    } catch (e) {
      debugPrint('Error updating department: $e');
      rethrow;
    }
  }

  /// Check if session has expired based on inactivity
  /// Sessions expire after 24 hours of inactivity by default
  static Future<bool> isSessionExpired({Duration? maxInactivity}) async {
    try {
      final lastActivity = await getLastActivity();
      if (lastActivity == null) return true;

      final inactivityDuration =
          maxInactivity ?? const Duration(days: 7); // Changed from 24 hours
      final now = DateTime.now();
      final timeSinceLastActivity = now.difference(lastActivity);

      return timeSinceLastActivity > inactivityDuration;
    } catch (e) {
      debugPrint('Error checking session expiry: $e');
      return true; // Consider expired on error for security
    }
  }

  /// Get session duration (time since login)
  static Future<Duration?> getSessionDuration() async {
    try {
      final loginTime = await getLoginTime();
      if (loginTime == null) return null;

      final now = DateTime.now();
      return now.difference(loginTime);
    } catch (e) {
      debugPrint('Error getting session duration: $e');
      return null;
    }
  }

  /// Validate current session integrity
  /// Checks if all required session data is present and valid
  static Future<bool> validateSession() async {
    try {
      final session = await getSession();

      // Check if user is marked as logged in
      if (session['isLoggedIn'] != true) {
        debugPrint('Session validation failed: User not logged in');
        return false;
      }

      // Check if essential user data is present
      final userName = session['userName'] as String;
      final userEmail = session['userEmail'] as String;

      if (userName.isEmpty || userEmail.isEmpty) {
        debugPrint('Session validation failed: Missing essential user data');
        await clearSession(); // Clear invalid session
        return false;
      }

      // Check if session has expired
      if (await isSessionExpired()) {
        debugPrint('Session validation failed: Session expired');
        await clearSession(); // Clear expired session
        return false;
      }

      // For students, roll number validation is optional
      // Don't clear session for missing roll number, just log it
      final isAdmin = session['isAdmin'] as bool;
      if (!isAdmin) {
        final rollNumber = session['rollNumber'] as String;
        if (rollNumber.isEmpty) {
          debugPrint(
            'Warning: Student session missing roll number, but continuing...',
          );
          // Don't return false here - roll number might be optional
        }
      }

      debugPrint('Session validation successful');
      return true;
    } catch (e) {
      debugPrint('Error validating session: $e');
      return false;
    }
  }

  /// Get formatted session info for debugging
  static Future<String> getSessionInfo() async {
    try {
      final session = await getSession();
      final loginTime = await getLoginTime();
      final sessionDuration = await getSessionDuration();

      final buffer = StringBuffer();
      buffer.writeln('=== Session Information ===');
      buffer.writeln('Logged In: ${session['isLoggedIn']}');
      buffer.writeln('Is Admin: ${session['isAdmin']}');
      buffer.writeln('User Name: ${session['userName']}');
      buffer.writeln('User Email: ${session['userEmail']}');

      if (!session['isAdmin']) {
        buffer.writeln('Roll Number: ${session['rollNumber']}');
        buffer.writeln('Department: ${session['department']}');
        buffer.writeln(
          'Group: ${session['groupName']} (${session['groupId']})',
        );
      }

      if (loginTime != null) {
        buffer.writeln('Login Time: $loginTime');
      }

      if (sessionDuration != null) {
        buffer.writeln(
          'Session Duration: ${sessionDuration.inHours}h ${sessionDuration.inMinutes % 60}m',
        );
      }

      buffer.writeln('Session Valid: ${await validateSession()}');
      buffer.writeln('============================');

      return buffer.toString();
    } catch (e) {
      return 'Error getting session info: $e';
    }
  }

  /// Refresh session by updating last activity and validating data
  static Future<bool> refreshSession() async {
    try {
      if (await validateSession()) {
        await updateLastActivity();
        debugPrint('Session refreshed successfully');
        return true;
      } else {
        debugPrint('Session refresh failed: Invalid session');
        return false;
      }
    } catch (e) {
      debugPrint('Error refreshing session: $e');
      return false;
    }
  }

  /// Backup session data to a map (for export/debugging)
  static Future<Map<String, dynamic>> exportSession() async {
    try {
      final session = await getSession();
      final loginTime = await getLoginTime();
      final lastActivity = await getLastActivity();

      return {
        ...session,
        'loginTimeFormatted': loginTime?.toIso8601String() ?? '',
        'lastActivityFormatted': lastActivity?.toIso8601String() ?? '',
        'exportedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error exporting session: $e');
      return {};
    }
  }
}
