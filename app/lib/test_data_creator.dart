import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility class to create test attendance data for debugging
class TestDataCreator {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Create sample attendance data for testing teacher dashboard
  static Future<void> createTestAttendanceData() async {
    try {
      print('🧪 Creating test attendance data...');

      // Test students from the group III-CSE-B
      final testStudents = [
        {
          'rollNumber': '23CSR071',
          'name': 'Student One',
          'email': 'student1@example.com',
          'groupId': 'kcVkbB1SIcZf6UrYny8N',
          'groupName': 'III-CSE-B',
          'department': 'CSE',
        },
        {
          'rollNumber': '23CSR112',
          'name': 'Student Two',
          'email': 'student2@example.com',
          'groupId': 'kcVkbB1SIcZf6UrYny8N',
          'groupName': 'III-CSE-B',
          'department': 'CSE',
        },
        {
          'rollNumber': '23EEE029',
          'name': 'Student Three',
          'email': 'student3@example.com',
          'groupId': 'kcVkbB1SIcZf6UrYny8N',
          'groupName': 'III-CSE-B',
          'department': 'EEE',
        },
      ];

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (final student in testStudents) {
        // Create session for each student
        final sessionRef = await _db
            .collection('student_checkins')
            .doc(student['rollNumber'] as String)
            .collection('sessions')
            .add({
              'student': {
                'name': student['name'],
                'email': student['email'],
                'rollNumber': student['rollNumber'],
                'department': student['department'],
                'groupId': student['groupId'],
                'groupName': student['groupName'],
              },
              'campus': 'Test Campus',
              'day': _weekdayName(now.weekday),
              'date': Timestamp.fromDate(today),
              'period': 1,
              'subject':
                  'IOT LAB B1/ CN LAB B2', // Match what teacher is looking for
              'roomOrLocation': 'Lab 101',
              'checkInAt': Timestamp.fromDate(now.subtract(Duration(hours: 1))),
              'expectedEndAt': Timestamp.fromDate(now.add(Duration(hours: 1))),
              'checkInLat': 12.9716,
              'checkInLng': 77.5946,
              'status': 'completed',
              'checkOutAt': Timestamp.fromDate(
                now.subtract(Duration(minutes: 10)),
              ),
              'checkOutLat': 12.9716,
              'checkOutLng': 77.5946,
              'durationMinutes': 50.0,
              'closeReason': 'period_ended',
              'logs': [
                'check-in created at ${now.subtract(Duration(hours: 1)).toIso8601String()}',
                'check-out completed at ${now.subtract(Duration(minutes: 10)).toIso8601String()}',
              ],
            });

        print(
          '✅ Created test session for ${student['rollNumber']}: ${sessionRef.id}',
        );
      }

      print('🎉 Test attendance data created successfully!');
    } catch (e) {
      print('❌ Error creating test data: $e');
      rethrow;
    }
  }

  /// Clear all test attendance data
  static Future<void> clearTestAttendanceData() async {
    try {
      print('🗑️ Clearing test attendance data...');

      final testRollNumbers = ['23CSR071', '23CSR112', '23EEE029'];

      for (final rollNumber in testRollNumbers) {
        final sessionsQuery =
            await _db
                .collection('student_checkins')
                .doc(rollNumber)
                .collection('sessions')
                .get();

        for (final doc in sessionsQuery.docs) {
          await doc.reference.delete();
          print('🗑️ Deleted session ${doc.id} for $rollNumber');
        }
      }

      print('✅ Test attendance data cleared!');
    } catch (e) {
      print('❌ Error clearing test data: $e');
      rethrow;
    }
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
}
