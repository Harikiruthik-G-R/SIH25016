import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String rollNumber;
  final String groupId;
  final String groupName;
  final String department;

  const HistoryScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.rollNumber,
    required this.groupId,
    required this.groupName,
    required this.department,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int selectedTabIndex = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> attendanceHistory = [];
  List<Map<String, dynamic>> activityHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
  }

  Future<void> _loadHistoryData() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([_loadAttendanceHistory(), _loadActivityHistory()]);
    } catch (e) {
      debugPrint("Error loading history data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load history: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadAttendanceHistory() async {
    try {
      debugPrint("📚 Loading attendance history for: ${widget.rollNumber}");

      final sessionsSnapshot =
          await FirebaseFirestore.instance
              .collection('student_checkins')
              .doc(widget.rollNumber)
              .collection('sessions')
              .orderBy('checkInAt', descending: true)
              .limit(50)
              .get();

      final List<Map<String, dynamic>> sessions = [];

      for (final doc in sessionsSnapshot.docs) {
        final data = doc.data();
        final checkInAt = (data['checkInAt'] as Timestamp?)?.toDate();
        final checkOutAt = (data['checkOutAt'] as Timestamp?)?.toDate();

        if (checkInAt != null) {
          final dateStr = DateFormat('yyyy-MM-dd').format(checkInAt);
          final checkInTime = DateFormat('h:mm a').format(checkInAt);
          final checkOutTime =
              checkOutAt != null
                  ? DateFormat('h:mm a').format(checkOutAt)
                  : '--';

          // Determine status based on session data
          String status = 'Present';
          if (data['status'] == 'ongoing') {
            status = 'Active';
          } else if (data['closeReason'] == 'manual') {
            status = 'Early Exit';
          } else if (data['closeReason'] == 'background_auto_end') {
            status = 'Auto-ended';
          } else if (checkInAt.isAfter(
            checkInAt.add(const Duration(minutes: 10)),
          )) {
            status = 'Late';
          }

          sessions.add({
            'id': doc.id,
            'date': dateStr,
            'subject': data['subject'] ?? 'Unknown Subject',
            'checkIn': checkInTime,
            'checkOut': checkOutTime,
            'status': status,
            'location':
                data['campusName'] ??
                data['locationName'] ??
                'Unknown Location',
            'period': data['period']?.toString() ?? '--',
            'duration': data['durationMinutes']?.toDouble() ?? 0.0,
            'groupId': data['groupId'] ?? widget.groupId,
            'groupName': data['groupName'] ?? widget.groupName,
            'checkInLat': data['checkInLat'],
            'checkInLng': data['checkInLng'],
            'checkOutLat': data['checkOutLat'],
            'checkOutLng': data['checkOutLng'],
            'logs': data['logs'] ?? [],
          });
        }
      }

      debugPrint("✅ Loaded ${sessions.length} attendance sessions");

      if (mounted) {
        setState(() {
          attendanceHistory = sessions;
        });
      }
    } catch (e) {
      debugPrint("❌ Error loading attendance history: $e");
      throw Exception("Failed to load attendance history: $e");
    }
  }

  Future<void> _loadActivityHistory() async {
    try {
      debugPrint("📊 Loading activity history for: ${widget.rollNumber}");

      // Get recent sessions for activity timeline
      final sessionsSnapshot =
          await FirebaseFirestore.instance
              .collection('student_checkins')
              .doc(widget.rollNumber)
              .collection('sessions')
              .orderBy('checkInAt', descending: true)
              .limit(20)
              .get();

      final List<Map<String, dynamic>> activities = [];

      for (final doc in sessionsSnapshot.docs) {
        final data = doc.data();
        final checkInAt = (data['checkInAt'] as Timestamp?)?.toDate();
        final checkOutAt = (data['checkOutAt'] as Timestamp?)?.toDate();

        if (checkInAt != null) {
          final dateStr = DateFormat('yyyy-MM-dd').format(checkInAt);
          final timeStr = DateFormat('h:mm a').format(checkInAt);

          // Add check-in activity
          activities.add({
            'date': dateStr,
            'activity': 'Checked in for ${data['subject'] ?? 'class'}',
            'time': timeStr,
            'type': 'checkin',
            'details':
                'Period ${data['period'] ?? '--'} at ${data['campusName'] ?? 'campus'}',
          });

          // Add check-out activity if exists
          if (checkOutAt != null) {
            final checkOutTimeStr = DateFormat('h:mm a').format(checkOutAt);
            final duration = data['durationMinutes']?.toDouble() ?? 0.0;

            activities.add({
              'date': DateFormat('yyyy-MM-dd').format(checkOutAt),
              'activity': 'Checked out from ${data['subject'] ?? 'class'}',
              'time': checkOutTimeStr,
              'type': 'checkout',
              'details':
                  'Duration: ${_formatDuration(duration)} - ${data['closeReason'] ?? 'completed'}',
            });
          }

          // Skip system logs to keep activity view clean
          // Only show check-in and check-out activities
        }
      }

      // Sort activities by date and time (most recent first)
      activities.sort((a, b) {
        final dateA = DateTime.parse(
          '${a['date']} ${_convertTo24Hour(a['time'])}',
        );
        final dateB = DateTime.parse(
          '${b['date']} ${_convertTo24Hour(b['time'])}',
        );
        return dateB.compareTo(dateA);
      });

      debugPrint("✅ Loaded ${activities.length} activities");

      if (mounted) {
        setState(() {
          activityHistory =
              activities.take(30).toList(); // Limit to last 30 activities
        });
      }
    } catch (e) {
      debugPrint("❌ Error loading activity history: $e");
      throw Exception("Failed to load activity history: $e");
    }
  }

  String _convertTo24Hour(String time12) {
    try {
      final DateTime parsedTime = DateFormat('h:mm a').parse(time12);
      return DateFormat('HH:mm:ss').format(parsedTime);
    } catch (e) {
      return '00:00:00';
    }
  }

  String _formatDuration(double minutes) {
    if (minutes < 60) {
      return '${minutes.toStringAsFixed(0)}m';
    } else {
      final hours = (minutes / 60).floor();
      final remainingMinutes = (minutes % 60).floor();
      return '${hours}h ${remainingMinutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'History',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF9C27B0),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistoryData,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF9C27B0), Color(0xFF8E24AA), Color(0xFF7B1FA2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.history,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Activity History',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Student: ${widget.userName}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    Text(
                      'Roll No: ${widget.rollNumber}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),

              // Content Section
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    child:
                        _isLoading
                            ? _buildLoadingState()
                            : Column(
                              children: [
                                // Tab Selector
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              selectedTabIndex = 0;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  selectedTabIndex == 0
                                                      ? const Color(0xFF9C27B0)
                                                      : Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'Attendance (${attendanceHistory.length})',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color:
                                                    selectedTabIndex == 0
                                                        ? Colors.white
                                                        : Colors.grey.shade600,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              selectedTabIndex = 1;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  selectedTabIndex == 1
                                                      ? const Color(0xFF9C27B0)
                                                      : Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'Activities (${activityHistory.length})',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color:
                                                    selectedTabIndex == 1
                                                        ? Colors.white
                                                        : Colors.grey.shade600,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Content List
                                Expanded(
                                  child: RefreshIndicator(
                                    onRefresh: _loadHistoryData,
                                    child: SingleChildScrollView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      child:
                                          selectedTabIndex == 0
                                              ? _buildAttendanceHistory()
                                              : _buildActivityHistory(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF9C27B0)),
          SizedBox(height: 16),
          Text(
            'Loading history...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceHistory() {
    if (attendanceHistory.isEmpty) {
      return _buildEmptyState(
        'No Attendance Records',
        'No check-in sessions found. Start marking your attendance to see history here.',
        Icons.school_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attendance History (${attendanceHistory.length} sessions)',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E2E2E),
          ),
        ),
        const SizedBox(height: 16),

        ...attendanceHistory.map((record) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: _getStatusColor(record['status']).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record['subject'] ?? 'Unknown Subject',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E2E2E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Period ${record['period']} • ${record['date']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          record['status'],
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        record['status'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(record['status']),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Location and group info
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        record['location'] ?? 'Unknown Location',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.group, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      record['groupName'] ?? widget.groupName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),

                if (record['status'] != 'Absent') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'In: ${record['checkIn']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Text(
                        'Out: ${record['checkOut']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (record['duration'] > 0) ...[
                        const SizedBox(width: 20),
                        Text(
                          'Duration: ${_formatDuration(record['duration'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                // Session details (expandable)
                if (record['logs'] != null &&
                    (record['logs'] as List).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ExpansionTile(
                    title: Text(
                      'Session Details',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    children: [
                      ...((record['logs'] as List)
                          .take(3)
                          .map(
                            (log) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 2,
                              ),
                              child: Text(
                                log.toString(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          )),
                      if ((record['logs'] as List).length > 3)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '... and ${(record['logs'] as List).length - 3} more entries',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildActivityHistory() {
    if (activityHistory.isEmpty) {
      return _buildEmptyState(
        'No Activities',
        'No recent activities found. Your check-ins and app usage will appear here.',
        Icons.timeline,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activities (${activityHistory.length} items)',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E2E2E),
          ),
        ),
        const SizedBox(height: 16),

        ...activityHistory.map((activity) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getActivityColor(activity['type']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getActivityIcon(activity['type']),
                    color: _getActivityColor(activity['type']),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity['activity'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E2E2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (activity['details'] != null) ...[
                        Text(
                          activity['details'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Row(
                        children: [
                          Text(
                            activity['date'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            activity['time'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildEmptyState(String title, String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadHistoryData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return const Color(0xFF4CAF50);
      case 'absent':
        return const Color(0xFFF44336);
      case 'late':
        return const Color(0xFFFF9800);
      case 'active':
        return const Color(0xFF2196F3);
      case 'early exit':
        return const Color(0xFFFF5722);
      case 'auto-ended':
        return const Color(0xFF795548);
      default:
        return Colors.grey;
    }
  }

  Color _getActivityColor(String type) {
    switch (type.toLowerCase()) {
      case 'login':
        return const Color(0xFF4CAF50);
      case 'logout':
        return const Color(0xFFFF9800);
      case 'attendance':
      case 'checkin':
        return const Color(0xFF2196F3);
      case 'checkout':
        return const Color(0xFF9C27B0);
      case 'view':
        return const Color(0xFF9C27B0);
      case 'download':
        return const Color(0xFF607D8B);
      default:
        return Colors.grey;
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      case 'attendance':
      case 'checkin':
        return Icons.check_circle;
      case 'checkout':
        return Icons.exit_to_app;
      case 'view':
        return Icons.visibility;
      case 'download':
        return Icons.download;
      default:
        return Icons.info;
    }
  }
}
