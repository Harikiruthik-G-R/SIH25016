import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MyScheduleScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String rollNumber;
  final String groupId;
  final String groupName;
  final String department;

  const MyScheduleScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.rollNumber,
    required this.groupId,
    required this.groupName,
    required this.department,
  });

  @override
  State<MyScheduleScreen> createState() => _MyScheduleScreenState();
}

class _MyScheduleScreenState extends State<MyScheduleScreen> with TickerProviderStateMixin {
  int selectedDayIndex = DateTime.now().weekday - 1;
  bool _isLoading = true;
  bool _isRefreshing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  final List<String> weekDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  
  final List<String> weekDaysShort = [
    'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN',
  ];

  Map<String, Map<String, Map<String, dynamic>>> timetableData = {};
  List<String> periods = [];
  String timetableName = '';

  // Cache keys
  static const String _timetableCacheKey = 'timetable_cache';
  static const String _lastUpdateKey = 'timetable_last_update';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    
    // Set status bar color to match header
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF4CAF50),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
    
    _loadCachedData().then((_) => _loadTimetableData());
  }

  @override
  void dispose() {
    _animationController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Cache Management
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_lastUpdateKey) ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      if (currentTime - lastUpdate < 600000) {
        final timetableCache = prefs.getString(_timetableCacheKey);

        if (timetableCache != null) {
          final cachedData = jsonDecode(timetableCache);
          setState(() {
            timetableData = Map<String, Map<String, Map<String, dynamic>>>.from(
              cachedData['schedule']?.map(
                    (day, periods) => MapEntry(
                      day,
                      Map<String, Map<String, dynamic>>.from(
                        periods.map(
                          (period, data) =>
                              MapEntry(period, Map<String, dynamic>.from(data)),
                        ),
                      ),
                    ),
                  ) ??
                  {},
            );
            periods = List<String>.from(cachedData['periods'] ?? []);
            timetableName = cachedData['name'] ?? '';
            _isLoading = false;
          });
          _animationController.forward();
          _slideController.forward();
        }
      }
    } catch (e) {
      debugPrint("Error loading cached timetable: $e");
    }
  }

  Future<void> _cacheData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'schedule': timetableData,
        'periods': periods,
        'name': timetableName,
      };
      await prefs.setString(_timetableCacheKey, jsonEncode(cacheData));
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint("Error caching timetable data: $e");
    }
  }

  Future<void> _loadTimetableData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      debugPrint("📚 Loading timetable for group: ${widget.groupId}");

      final timetableQuery = await FirebaseFirestore.instance
          .collection('timetables')
          .where('groupId', isEqualTo: widget.groupId)
          .limit(1)
          .get();

      if (timetableQuery.docs.isNotEmpty) {
        final timetableDoc = timetableQuery.docs.first;
        final data = timetableDoc.data();

        setState(() {
          timetableName = data['name'] ?? data['groupName'] ?? widget.groupName;
          periods = List<String>.from(data['periods'] ?? []);

          final schedule = data['schedule'] as Map<String, dynamic>? ?? {};
          timetableData = {};

          for (final dayEntry in schedule.entries) {
            final dayName = dayEntry.key;
            final daySchedule = dayEntry.value as Map<String, dynamic>;

            timetableData[dayName] = {};
            for (final periodEntry in daySchedule.entries) {
              final periodNum = periodEntry.key;
              final periodData = periodEntry.value as Map<String, dynamic>;

              timetableData[dayName]![periodNum] = periodData;
            }
          }
        });

        await _cacheData();
        _animationController.forward();
        _slideController.forward();
        debugPrint("✅ Loaded timetable successfully for: ${data['groupName']} (Doc ID: ${timetableDoc.id})");
      } else {
        debugPrint("❌ No timetable found for groupId: ${widget.groupId}");
        if (mounted) {
          _showSnackBar('No timetable found for your group', Colors.orange);
        }
      }
    } catch (e) {
      debugPrint("❌ Error loading timetable: $e");
      if (mounted) {
        _showSnackBar('Failed to load timetable', Colors.red);
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

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _getCurrentDayName() {
    final now = DateTime.now();
    return weekDays[now.weekday - 1];
  }

  bool _isCurrentDay(int index) {
    return index == DateTime.now().weekday - 1;
  }

  List<Map<String, dynamic>> _getTodaysSchedule() {
    final today = _getCurrentDayName();
    final todaySchedule = timetableData[today] ?? {};

    List<Map<String, dynamic>> schedule = [];

    for (final period in periods) {
      if (todaySchedule.containsKey(period) &&
          todaySchedule[period]!['subject']?.isNotEmpty == true) {
        schedule.add({
          'period': period,
          'subject': todaySchedule[period]!['subject'],
          'location': todaySchedule[period]!['location'],
          'time': todaySchedule[period]!['time'],
        });
      }
    }

    return schedule;
  }

  List<Map<String, dynamic>> _getSelectedDaySchedule() {
    final selectedDay = weekDays[selectedDayIndex];
    final daySchedule = timetableData[selectedDay] ?? {};

    List<Map<String, dynamic>> schedule = [];

    for (final period in periods) {
      if (daySchedule.containsKey(period) &&
          daySchedule[period]!['subject']?.isNotEmpty == true) {
        schedule.add({
          'period': period,
          'subject': daySchedule[period]!['subject'],
          'location': daySchedule[period]!['location'],
          'time': daySchedule[period]!['time'],
        });
      }
    }

    return schedule;
  }

  Color _getSubjectColor(String subject) {
    final colors = [
      const Color(0xFF4CAF50), // Green
      const Color(0xFF2196F3), // Blue
      const Color(0xFF9C27B0), // Purple
      const Color(0xFFFF9800), // Orange
      const Color(0xFFE91E63), // Pink
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFF795548), // Brown
      const Color(0xFF607D8B), // Blue Grey
    ];
    
    return colors[subject.hashCode % colors.length];
  }

  int _getTotalClassesThisWeek() {
    int total = 0;
    for (final day in timetableData.keys) {
      final daySchedule = timetableData[day] ?? {};
      for (final period in periods) {
        if (daySchedule.containsKey(period) &&
            daySchedule[period]!['subject']?.isNotEmpty == true) {
          total++;
        }
      }
    }
    return total;
  }

  Map<String, int> _getSubjectCount() {
    Map<String, int> subjects = {};
    for (final day in timetableData.keys) {
      final daySchedule = timetableData[day] ?? {};
      for (final period in periods) {
        if (daySchedule.containsKey(period) &&
            daySchedule[period]!['subject']?.isNotEmpty == true) {
          final subject = daySchedule[period]!['subject'];
          subjects[subject] = (subjects[subject] ?? 0) + 1;
        }
      }
    }
    return subjects;
  }

  String _getInitials(String name) {
    List<String> nameParts = name.trim().split(' ');
    if (nameParts.length == 1) {
      return nameParts[0].isNotEmpty ? nameParts[0][0].toUpperCase() : 'U';
    }
    return (nameParts[0][0] + nameParts[nameParts.length - 1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeaderSection(),
            Expanded(
              child: _isLoading ? _buildLoadingState() : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
        ),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _getInitials(widget.userName),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4CAF50),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Schedule',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${widget.department} • ${widget.rollNumber}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              onPressed: _isRefreshing ? null : _loadTimetableData,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              _buildQuickStats(),
              const SizedBox(height: 16),
              _buildDaySelector(),
              const SizedBox(height: 16),
              _buildScheduleSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    final todaySchedule = _getTodaysSchedule();
    final totalWeekClasses = _getTotalClassesThisWeek();
    final subjectCount = _getSubjectCount();
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Today\'s Classes',
            '${todaySchedule.length}',
            Icons.today_rounded,
            const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Week Total',
            '$totalWeekClasses',
            Icons.calendar_view_week_rounded,
            const Color(0xFF2196F3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Subjects',
            '${subjectCount.length}',
            Icons.subject_rounded,
            const Color(0xFFFF9800),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Day',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: weekDays.length,
              itemBuilder: (context, index) {
                final isSelected = index == selectedDayIndex;
                final isToday = _isCurrentDay(index);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedDayIndex = index;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: index == weekDays.length - 1 ? 0 : 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                            )
                          : null,
                      color: isSelected
                          ? null
                          : (isToday
                              ? const Color(0xFF4CAF50).withOpacity(0.1)
                              : const Color(0xFFF8FAFB)),
                      borderRadius: BorderRadius.circular(8),
                      border: isToday && !isSelected
                          ? Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3))
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        weekDaysShort[index],
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isToday
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFF6B7280)),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${weekDays[selectedDayIndex]} Classes',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                if (_isCurrentDay(selectedDayIndex))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          RefreshIndicator(
            onRefresh: _loadTimetableData,
            color: const Color(0xFF4CAF50),
            child: _buildScheduleList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: const Color(0xFFF8FAFB),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF4CAF50),
              strokeWidth: 2.5,
            ),
            SizedBox(height: 16),
            Text(
              'Loading your schedule...',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleList() {
    final selectedDaySchedule = _getSelectedDaySchedule();

    if (selectedDaySchedule.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.free_breakfast_rounded,
                size: 36,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No Classes Today!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Enjoy your free time',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: selectedDaySchedule.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final classData = selectedDaySchedule[index];
        final subjectColor = _getSubjectColor(classData['subject']);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: subjectColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: subjectColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: subjectColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'P${classData['period']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classData['subject'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            classData['location'] ?? 'TBA',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.access_time_outlined,
                          size: 12,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          classData['time'] ?? 'TBA',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
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
      },
    );
  }
}