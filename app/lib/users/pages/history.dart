import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:convert';

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

class _HistoryScreenState extends State<HistoryScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  int selectedTabIndex = 0;
  bool _isLoading = true;
  bool _isRefreshing = false;
  
  // Calendar related
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Weekly view related
  DateTime _selectedWeek = DateTime.now();
  bool _isWeeklyView = true;
  
  // Data storage
  List<Map<String, dynamic>> attendanceHistory = [];
  List<Map<String, dynamic>> activityHistory = [];
  Map<String, List<Map<String, dynamic>>> dailyAttendance = {};
  Map<String, AttendanceSummary> monthlyStats = {};
  
  // Cache keys
  static const String _attendanceCacheKey = 'attendance_history_cache';
  static const String _activityCacheKey = 'activity_history_cache';
  static const String _lastUpdateKey = 'last_update_timestamp';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedDay = DateTime.now();
    _loadCachedData().then((_) => _loadHistoryData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Cache Management
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_lastUpdateKey) ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      // Use cache if less than 5 minutes old
      if (currentTime - lastUpdate < 300000) {
        final attendanceCache = prefs.getString(_attendanceCacheKey);
        final activityCache = prefs.getString(_activityCacheKey);
        
        if (attendanceCache != null && activityCache != null) {
          setState(() {
            attendanceHistory = List<Map<String, dynamic>>.from(
              jsonDecode(attendanceCache)
            );
            activityHistory = List<Map<String, dynamic>>.from(
              jsonDecode(activityCache)
            );
            _processAttendanceData();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading cached data: $e");
    }
  }

  Future<void> _cacheData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_attendanceCacheKey, jsonEncode(attendanceHistory));
      await prefs.setString(_activityCacheKey, jsonEncode(activityHistory));
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint("Error caching data: $e");
    }
  }

  Future<void> _loadHistoryData() async {
    if (_isRefreshing) return;
    
    setState(() => _isRefreshing = true);

    try {
      await Future.wait([_loadAttendanceHistory(), _loadActivityHistory()]);
      await _cacheData();
    } catch (e) {
      debugPrint("Error loading history data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load history: ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadAttendanceHistory() async {
    try {
      debugPrint("📚 Loading attendance history for: ${widget.rollNumber}");

      final sessionsSnapshot = await FirebaseFirestore.instance
          .collection('student_checkins')
          .doc(widget.rollNumber)
          .collection('sessions')
          .orderBy('checkInAt', descending: true)
          .limit(100)
          .get();

      final List<Map<String, dynamic>> sessions = [];

      for (final doc in sessionsSnapshot.docs) {
        final data = doc.data();
        final checkInAt = (data['checkInAt'] as Timestamp?)?.toDate();
        final checkOutAt = (data['checkOutAt'] as Timestamp?)?.toDate();

        if (checkInAt != null) {
          final dateStr = DateFormat('yyyy-MM-dd').format(checkInAt);
          final checkInTime = DateFormat('h:mm a').format(checkInAt);
          final checkOutTime = checkOutAt != null 
              ? DateFormat('h:mm a').format(checkOutAt) 
              : '--';

          String status = 'Present';
          if (data['status'] == 'ongoing') {
            status = 'Active';
          } else if (data['closeReason'] == 'manual') {
            status = 'Early Exit';
          } else if (data['closeReason'] == 'background_auto_end') {
            status = 'Auto-ended';
          }

          sessions.add({
            'id': doc.id,
            'date': dateStr,
            'dateTime': checkInAt,
            'subject': data['subject'] ?? 'Unknown Subject',
            'checkIn': checkInTime,
            'checkOut': checkOutTime,
            'status': status,
            'location': data['campusName'] ?? data['locationName'] ?? 'Unknown Location',
            'period': data['period']?.toString() ?? '--',
            'duration': data['durationMinutes']?.toDouble() ?? 0.0,
            'groupId': data['groupId'] ?? widget.groupId,
            'groupName': data['groupName'] ?? widget.groupName,
            'logs': data['logs'] ?? [],
          });
        }
      }

      if (mounted) {
        setState(() {
          attendanceHistory = sessions;
          _processAttendanceData();
        });
      }

      debugPrint("✅ Loaded ${sessions.length} attendance sessions");
    } catch (e) {
      debugPrint("❌ Error loading attendance history: $e");
      throw Exception("Failed to load attendance history: $e");
    }
  }

  void _processAttendanceData() {
    dailyAttendance.clear();
    monthlyStats.clear();

    // Group by date
    for (final record in attendanceHistory) {
      final date = record['date'] as String;
      if (!dailyAttendance.containsKey(date)) {
        dailyAttendance[date] = [];
      }
      dailyAttendance[date]!.add(record);
    }

    // Calculate monthly stats
    final Map<String, Map<String, int>> monthlyData = {};
    
    for (final record in attendanceHistory) {
      final dateTime = record['dateTime'] as DateTime;
      final monthKey = DateFormat('yyyy-MM').format(dateTime);
      
      if (!monthlyData.containsKey(monthKey)) {
        monthlyData[monthKey] = {
          'present': 0,
          'absent': 0,
          'late': 0,
          'total_hours': 0,
        };
      }
      
      final status = record['status'] as String;
      if (status.toLowerCase() == 'present' || status.toLowerCase() == 'active') {
        monthlyData[monthKey]!['present'] = monthlyData[monthKey]!['present']! + 1;
      } else if (status.toLowerCase() == 'absent') {
        monthlyData[monthKey]!['absent'] = monthlyData[monthKey]!['absent']! + 1;
      } else if (status.toLowerCase() == 'late') {
        monthlyData[monthKey]!['late'] = monthlyData[monthKey]!['late']! + 1;
      }
      
      monthlyData[monthKey]!['total_hours'] = monthlyData[monthKey]!['total_hours']! + 
          (record['duration'] as double).round();
    }

    // Convert to AttendanceSummary objects
    monthlyData.forEach((month, data) {
      final total = data['present']! + data['absent']! + data['late']!;
      monthlyStats[month] = AttendanceSummary(
        present: data['present']!,
        absent: data['absent']!,
        late: data['late']!,
        totalHours: data['total_hours']!,
        attendancePercentage: total > 0 ? (data['present']! / total * 100) : 0.0,
      );
    });
  }

  Future<void> _loadActivityHistory() async {
    try {
      debugPrint("📊 Loading activity history for: ${widget.rollNumber}");

      final sessionsSnapshot = await FirebaseFirestore.instance
          .collection('student_checkins')
          .doc(widget.rollNumber)
          .collection('sessions')
          .orderBy('checkInAt', descending: true)
          .limit(30)
          .get();

      final List<Map<String, dynamic>> activities = [];

      for (final doc in sessionsSnapshot.docs) {
        final data = doc.data();
        final checkInAt = (data['checkInAt'] as Timestamp?)?.toDate();
        final checkOutAt = (data['checkOutAt'] as Timestamp?)?.toDate();

        if (checkInAt != null) {
          final dateStr = DateFormat('yyyy-MM-dd').format(checkInAt);
          final timeStr = DateFormat('h:mm a').format(checkInAt);

          activities.add({
            'date': dateStr,
            'activity': 'Checked in for ${data['subject'] ?? 'class'}',
            'time': timeStr,
            'type': 'checkin',
            'details': 'Period ${data['period'] ?? '--'} at ${data['campusName'] ?? 'campus'}',
          });

          if (checkOutAt != null) {
            final checkOutTimeStr = DateFormat('h:mm a').format(checkOutAt);
            final duration = data['durationMinutes']?.toDouble() ?? 0.0;

            activities.add({
              'date': DateFormat('yyyy-MM-dd').format(checkOutAt),
              'activity': 'Checked out from ${data['subject'] ?? 'class'}',
              'time': checkOutTimeStr,
              'type': 'checkout',
              'details': 'Duration: ${_formatDuration(duration)} - ${data['closeReason'] ?? 'completed'}',
            });
          }
        }
      }

      activities.sort((a, b) {
        final dateA = DateTime.parse('${a['date']} ${_convertTo24Hour(a['time'])}');
        final dateB = DateTime.parse('${b['date']} ${_convertTo24Hour(b['time'])}');
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          activityHistory = activities.take(50).toList();
        });
      }

      debugPrint("✅ Loaded ${activities.length} activities");
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

  List<Map<String, dynamic>> _getAttendanceForDay(DateTime day) {
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    return dailyAttendance[dateStr] ?? [];
  }

  bool _hasAttendanceOnDay(DateTime day) {
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    return dailyAttendance.containsKey(dateStr) && dailyAttendance[dateStr]!.isNotEmpty;
  }

  // Weekly view helper methods
  void _onWeekChanged(DateTime newWeek) {
    setState(() {
      _selectedWeek = newWeek;
    });
  }

  Map<String, List<Map<String, dynamic>>> _getWeekAttendance(DateTime weekStart) {
    final Map<String, List<Map<String, dynamic>>> weekData = {};
    final weekStartDate = _getWeekStart(weekStart);
    
    // Initialize all 7 days of the week
    for (int i = 0; i < 7; i++) {
      final date = weekStartDate.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      weekData[dateStr] = [];
    }
    
    // Fill with actual attendance data
    for (final record in attendanceHistory) {
      final recordDate = record['date'] as String;
      if (weekData.containsKey(recordDate)) {
        weekData[recordDate]!.add(record);
      }
    }
    
    return weekData;
  }

  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  @override
 Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF5F5F5),
    appBar: AppBar(
      title: const Text(
        'Attendance History',
        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
      ),
      backgroundColor: const Color(0xFF4CAF50),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: _isRefreshing 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.refresh),
          onPressed: _isRefreshing ? null : _loadHistoryData,
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        tabs: const [
          Tab(icon: Icon(Icons.calendar_month), text: 'Calendar'),
          Tab(icon: Icon(Icons.list_alt), text: 'List'),
          Tab(icon: Icon(Icons.timeline), text: 'Activities'),
        ],
      ),
    ),
    body: _isLoading 
        ? _buildLoadingState()
        : TabBarView(
            controller: _tabController,
            children: [
              _buildCalendarView(),
              _buildListView(),
              _buildActivitiesView(),
            ],
          ),
    bottomNavigationBar: _buildBottomNavBar(), // Add this line
  );
}

Widget _buildBottomNavBar() {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_rounded, 'Home'),
            _buildNavItem(1, Icons.history, 'History'),
            _buildNavItem(2, Icons.notifications_rounded, 'Alerts'),
            _buildNavItem(3, Icons.person_rounded, 'Profile'),
          ],
        ),
      ),
    ),
  );
}

Widget _buildNavItem(int index, IconData icon, String label) {
  final isSelected = _selectedIndex == index;
  return GestureDetector(
    onTap: () => _onBottomNavTapped(index),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF4CAF50).withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade600,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildLoadingState() {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF4CAF50)),
            SizedBox(height: 16),
            Text(
              'Loading attendance data...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarView() {
    return Column(
      children: [
        // Stats Card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildMonthlyStats(),
        ),
        
        // Calendar
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                TableCalendar<Map<String, dynamic>>(
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 30)),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  eventLoader: _getAttendanceForDay,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    markerDecoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: const Color(0xFF81C784),
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                    formatButtonShowsNext: false,
                    formatButtonDecoration: BoxDecoration(
                      color: Color(0xFF4CAF50),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    formatButtonTextStyle: TextStyle(color: Colors.white),
                  ),
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    if (_calendarFormat != format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    }
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                ),
                const SizedBox(height: 16),
                if (_selectedDay != null)
                  Expanded(child: _buildSelectedDayAttendance()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMonthlyStats() {
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    final stats = monthlyStats[currentMonth] ?? 
        AttendanceSummary(present: 0, absent: 0, late: 0, totalHours: 0, attendancePercentage: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'This Month',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E2E2E),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: stats.attendancePercentage >= 75
                    ? const Color(0xFF4CAF50).withOpacity(0.1)
                    : const Color(0xFFFF9800).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${stats.attendancePercentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: stats.attendancePercentage >= 75
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF9800),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatItem('Present', stats.present.toString(), 
                  const Color(0xFF4CAF50), Icons.check_circle),
            ),
            Expanded(
              child: _buildStatItem('Absent', stats.absent.toString(), 
                  const Color(0xFFF44336), Icons.cancel),
            ),
            Expanded(
              child: _buildStatItem('Late', stats.late.toString(), 
                  const Color(0xFFFF9800), Icons.schedule),
            ),
            Expanded(
              child: _buildStatItem('Hours', '${stats.totalHours}h', 
                  const Color(0xFF2196F3), Icons.timer),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDayAttendance() {
    final dayAttendance = _getAttendanceForDay(_selectedDay!);
    final dateStr = DateFormat('EEEE, MMM dd, yyyy').format(_selectedDay!);

    if (dayAttendance.isEmpty) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.event_busy, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'No classes on $dateStr',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateStr,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E2E2E),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: dayAttendance.length,
            itemBuilder: (context, index) {
              final record = dayAttendance[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStatusColor(record['status']).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getStatusColor(record['status']).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(record['status']),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        record['period'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record['subject'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${record['checkIn']} - ${record['checkOut']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(record['status']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        record['status'],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(record['status']),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildListView() {
    if (attendanceHistory.isEmpty) {
      return _buildEmptyState(
        'No Attendance Records',
        'Start marking your attendance to see history here.',
        Icons.school_outlined,
      );
    }

    return Column(
      children: [
        // View Toggle
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isWeeklyView = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _isWeeklyView ? const Color(0xFF4CAF50) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Weekly View',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _isWeeklyView ? Colors.white : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isWeeklyView = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_isWeeklyView ? const Color(0xFF4CAF50) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Daily List',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: !_isWeeklyView ? Colors.white : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Content based on view type
        Expanded(
          child: _isWeeklyView ? _buildWeeklyView() : _buildDailyListView(),
        ),
      ],
    );
  }

  Widget _buildWeeklyView() {
    return Column(
      children: [
        _WeekSelector(
          currentWeek: _selectedWeek,
          onWeekChanged: _onWeekChanged,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadHistoryData,
            color: const Color(0xFF4CAF50),
            child: _WeeklyTimelineView(
              weekStart: _selectedWeek,
              attendanceData: _getWeekAttendance(_selectedWeek),
            ),
          ),
        ),
      ],
    );
  }

 Widget _buildDailyListView() {
    // Group attendance by date
    final Map<String, List<Map<String, dynamic>>> groupedByDate = {};
    
    for (final record in attendanceHistory) {
      final date = record['date'] as String;
      if (!groupedByDate.containsKey(date)) {
        groupedByDate[date] = [];
      }
      groupedByDate[date]!.add(record);
    }

    final sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Sort in descending order

    return RefreshIndicator(
      onRefresh: _loadHistoryData,
      color: const Color(0xFF4CAF50),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final dateStr = sortedDates[index];
          final dayRecords = groupedByDate[dateStr]!;
          final date = DateTime.parse(dateStr);
          final formattedDate = DateFormat('EEEE, MMM dd, yyyy').format(date);
          final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateStr;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isToday 
                        ? const Color(0xFF4CAF50).withOpacity(0.1)
                        : Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isToday 
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF2E2E2E),
                        ),
                      ),
                      if (isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Today',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: dayRecords.map((record) => 
                      _buildAttendanceRecordCard(record, 
                          isLast: record == dayRecords.last)).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttendanceRecordCard(Map<String, dynamic> record, {bool isLast = false}) {
    final status = record['status'] as String;
    final statusColor = _getStatusColor(status);

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Period ${record['period']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            record['subject'],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E2E2E),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                '${record['checkIn']} - ${record['checkOut']}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  record['location'],
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (record['duration'] > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.timer, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Duration: ${_formatDuration(record['duration'])}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivitiesView() {
    if (activityHistory.isEmpty) {
      return _buildEmptyState(
        'No Activities',
        'Your recent activities will appear here.',
        Icons.timeline,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistoryData,
      color: const Color(0xFF4CAF50),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: activityHistory.length,
        itemBuilder: (context, index) {
          final activity = activityHistory[index];
          final isCheckin = activity['type'] == 'checkin';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline indicator
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isCheckin 
                            ? const Color(0xFF4CAF50) 
                            : const Color(0xFFFF9800),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (index < activityHistory.length - 1)
                      Container(
                        width: 2,
                        height: 60,
                        color: Colors.grey.shade300,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Activity content
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                activity['activity'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E2E2E),
                                ),
                              ),
                            ),
                            Text(
                              activity['time'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        if (activity['details'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            activity['details'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM dd, yyyy').format(
                            DateTime.parse(activity['date'])
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String title, String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
      case 'active':
        return const Color(0xFF4CAF50);
      case 'absent':
        return const Color(0xFFF44336);
      case 'late':
        return const Color(0xFFFF9800);
      case 'early exit':
        return const Color(0xFFFF5722);
      case 'auto-ended':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF607D8B);
    }
  }
  int _selectedIndex = 1; // Since this is the Schedule/History page

// Add this method to handle navigation
void _onBottomNavTapped(int index) {
  if (index == _selectedIndex) return; // Don't navigate to same page
  
  setState(() {
    _selectedIndex = index;
  });

  // Navigate based on index
  switch (index) {
    case 0: // Home
      Navigator.pushReplacementNamed(context, '/');
      break;
    case 1: // Schedule/History - current page, do nothing
      break;
    case 2: // Alerts
      Navigator.pushReplacementNamed(context, '/alerts');
      break;
    case 3: // Profile
   Navigator.pushReplacementNamed(
  context, 
  '/profile',
  arguments: {
    'userName': widget.userName,
    'userEmail': widget.userEmail,
    'rollNumber': widget.rollNumber,
    'groupId': widget.groupId,
    'groupName': widget.groupName,
    'department': widget.department,
  }
);
      break;
  }
}
}


// Helper class for attendance summary
class AttendanceSummary {
  final int present;
  final int absent;
  final int late;
  final int totalHours;
  final double attendancePercentage;

  AttendanceSummary({
    required this.present,
    required this.absent,
    required this.late,
    required this.totalHours,
    required this.attendancePercentage,
  });
}

// Week Selector Widget
class _WeekSelector extends StatelessWidget {
  final DateTime currentWeek;
  final Function(DateTime) onWeekChanged;

  const _WeekSelector({
    required this.currentWeek,
    required this.onWeekChanged,
  });

  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = _getWeekStart(currentWeek);
    final weekEnd = weekStart.add(const Duration(days: 6));
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              final previousWeek = currentWeek.subtract(const Duration(days: 7));
              onWeekChanged(previousWeek);
            },
            icon: const Icon(Icons.chevron_left, color: Color(0xFF4CAF50)),
          ),
          Column(
            children: [
              Text(
                '${DateFormat('MMM dd').format(weekStart)} - ${DateFormat('MMM dd, yyyy').format(weekEnd)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E2E2E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Week View',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () {
              final nextWeek = currentWeek.add(const Duration(days: 7));
              if (nextWeek.isBefore(DateTime.now().add(const Duration(days: 7)))) {
                onWeekChanged(nextWeek);
              }
            },
            icon: Icon(
              Icons.chevron_right,
              color: currentWeek.add(const Duration(days: 7))
                      .isBefore(DateTime.now().add(const Duration(days: 7)))
                  ? const Color(0xFF4CAF50)
                  : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

// Weekly Timeline View Widget
class _WeeklyTimelineView extends StatelessWidget {
  final DateTime weekStart;
  final Map<String, List<Map<String, dynamic>>> attendanceData;

  const _WeeklyTimelineView({
    required this.weekStart,
    required this.attendanceData,
  });

  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final actualWeekStart = _getWeekStart(weekStart);
    final days = List.generate(7, (index) => 
        actualWeekStart.add(Duration(days: index)));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final date = days[index];
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final dayAttendance = attendanceData[dateStr] ?? [];
        final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateStr;
        final dayName = DateFormat('EEEE').format(date);
        final dayNumber = DateFormat('dd').format(date);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isToday 
                      ? const Color(0xFF4CAF50).withOpacity(0.1)
                      : Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isToday 
                            ? const Color(0xFF4CAF50)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: isToday 
                            ? null 
                            : Border.all(color: Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Text(
                          dayNumber,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isToday ? Colors.white : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isToday 
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF2E2E2E),
                          ),
                        ),
                        Text(
                          DateFormat('MMM dd, yyyy').format(date),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (dayAttendance.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${dayAttendance.length} class${dayAttendance.length != 1 ? 'es' : ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (dayAttendance.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No classes scheduled',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: dayAttendance.map((record) => 
                      _buildWeeklyAttendanceCard(record, 
                          isLast: record == dayAttendance.last)).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeeklyAttendanceCard(Map<String, dynamic> record, {bool isLast = false}) {
    final status = record['status'] as String;
    final statusColor = _getStatusColor(status);

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              record['period'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['subject'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${record['checkIn']} - ${record['checkOut']}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
      case 'active':
        return const Color(0xFF4CAF50);
      case 'absent':
        return const Color(0xFFF44336);
      case 'late':
        return const Color(0xFFFF9800);
      case 'early exit':
        return const Color(0xFFFF5722);
      case 'auto-ended':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF607D8B);
    }
  }
}