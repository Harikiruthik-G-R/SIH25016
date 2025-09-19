import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:GeoAt/sessionmanager.dart';

class TeacherDashboard extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String teacherEmail;
  final List<String> subjects;
  final String department;
  final String designation;
  final List<Map<String, dynamic>>? groups;

  const TeacherDashboard({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.teacherEmail,
    required this.subjects,
    required this.department,
    required this.designation,
    this.groups,
  });

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _subjectGroups = {};
  Map<String, int> _todaysAttendance = {};

  @override
  void initState() {
    super.initState();
    // Debug: Print received teacher data
    print('🔍 TeacherDashboard Debug Info:');
    print('Teacher ID: ${widget.teacherId}');
    print('Teacher Name: ${widget.teacherName}');
    print('Teacher Email: ${widget.teacherEmail}');
    print('Subjects: ${widget.subjects}');
    print('Department: ${widget.department}');
    print('Designation: ${widget.designation}');

    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    try {
      setState(() => _isLoading = true);
      await _loadSubjectGroups();
      await _loadTodaysAttendance();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSubjectGroups() async {
    // Query timetables collection and search for teacher's subjects in the schedule
    final timetablesQuery =
        await FirebaseFirestore.instance.collection('timetables').get();

    Map<String, List<Map<String, dynamic>>> subjectGroups = {};

    for (var doc in timetablesQuery.docs) {
      final data = doc.data();
      final scheduleData = data['schedule'];
      final groupName = data['groupName'] ?? 'Unknown Group';
      final groupId = doc.id;

      print('🔍 Processing timetable for group: $groupName (ID: $groupId)');
      print('📋 Schedule data type: ${scheduleData.runtimeType}');
      print('📋 Schedule data: $scheduleData');

      // Handle different schedule data structures
      Map<String, dynamic>? schedule;
      
      if (scheduleData is Map<String, dynamic>) {
        schedule = scheduleData;
      } else if (scheduleData is List) {
        // If schedule is a list, try to convert it to a map or skip
        print('⚠️ Schedule is a List, skipping group $groupName');
        continue;
      } else {
        print('⚠️ Schedule is null or invalid type for group $groupName');
        continue;
      }

      // Search through the schedule for teacher's subjects
      for (var dayEntry in schedule.entries) {
        final daySchedule = dayEntry.value;
        print('📅 Processing day: ${dayEntry.key}, data type: ${daySchedule.runtimeType}');
        
        if (daySchedule is Map<String, dynamic>) {
          for (var periodEntry in daySchedule.entries) {
            final periodData = periodEntry.value;
            print('⏰ Processing period: ${periodEntry.key}, data type: ${periodData.runtimeType}');
            
            if (periodData is Map<String, dynamic>) {
              final subject = periodData['subject'] as String?;
              print('📚 Found subject: $subject');

              if (subject != null && widget.subjects.contains(subject)) {
                print('✅ Subject $subject matches teacher subjects');
                if (!subjectGroups.containsKey(subject)) {
                  subjectGroups[subject] = [];
                }
                // Add group info if not already present
                bool groupExists = subjectGroups[subject]!.any(
                  (group) => group['groupId'] == groupId,
                );
                if (!groupExists) {
                  subjectGroups[subject]!.add({
                    'groupId': groupId,
                    'groupName': groupName,
                  });
                  print('✅ Added group $groupName to subject $subject');
                }
              }
            } else {
              print('⚠️ Period data is not a Map: ${periodData.runtimeType}');
            }
          }
        } else {
          print('⚠️ Day schedule is not a Map: ${daySchedule.runtimeType}');
        }
      }
        }

    print('📊 Final subject groups mapping:');
    for (var entry in subjectGroups.entries) {
      print('   ${entry.key}: ${entry.value.length} groups');
      for (var group in entry.value) {
        print('     - ${group['groupName']} (${group['groupId']})');
      }
    }

    setState(() => _subjectGroups = subjectGroups);
  }

  Future<void> _loadTodaysAttendance() async {
    final today = DateTime.now();
    final todayStr =
        '${today.day.toString().padLeft(2, '0')}-${today.month.toString().padLeft(2, '0')}-${today.year}';

    Map<String, int> attendanceCount = {};

    for (String subject in widget.subjects) {
      attendanceCount[subject] = 0;

      if (_subjectGroups[subject] != null) {
        for (var group in _subjectGroups[subject]!) {
          final groupId = group['groupId'];

          // Query student check-ins for this group and subject today
          final checkinsQuery =
              await FirebaseFirestore.instance
                  .collection('student_checkins')
                  .get();

          for (var studentDoc in checkinsQuery.docs) {
            final sessionsQuery =
                await studentDoc.reference
                    .collection('sessions')
                    .where('date', isEqualTo: todayStr)
                    .where('subject', isEqualTo: subject)
                    .where('groupId', isEqualTo: groupId)
                    .where('status', isEqualTo: 'completed')
                    .get();

            attendanceCount[subject] =
                (attendanceCount[subject] ?? 0) + sessionsQuery.docs.length;
          }
        }
      }
    }

    setState(() => _todaysAttendance = attendanceCount);
  }

  List<Map<String, dynamic>> _getUniqueGroups() {
    Map<String, Map<String, dynamic>> uniqueGroups = {};

    for (var subjectGroups in _subjectGroups.values) {
      for (var group in subjectGroups) {
        uniqueGroups[group['groupId']] = group;
      }
    }

    return uniqueGroups.values.toList();
  }

  List<String> _getSubjectsForGroup(String groupId) {
    List<String> subjects = [];

    for (var entry in _subjectGroups.entries) {
      String subject = entry.key;
      List<Map<String, dynamic>> groups = entry.value;

      if (groups.any((group) => group['groupId'] == groupId)) {
        subjects.add(subject);
      }
    }

    return subjects;
  }

  void _navigateToSubjectAttendance(String subject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SubjectAttendanceScreen(
              subject: subject,
              teacherName: widget.teacherName,
              groups: _subjectGroups[subject] ?? [],
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.dashboard_outlined, size: 20),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teacher Dashboard',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Welcome back',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Debug button to create test attendance data
          Container(
            margin: EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              padding: EdgeInsets.all(8),
              constraints: BoxConstraints(minWidth: 40, minHeight: 40),
              icon: Icon(Icons.bug_report, color: Colors.white, size: 20),
              tooltip: 'Create Test Attendance Data',
              onPressed: () async {
                try {
                  await TestDataCreator.createTestAttendanceData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ Test attendance data created!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Reload data to show the new test data
                    _loadTeacherData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error creating test data: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ),
          Container(
            margin: EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              padding: EdgeInsets.all(8),
              constraints: BoxConstraints(minWidth: 40, minHeight: 40),
              icon: Icon(Icons.refresh, color: Colors.white, size: 20),
              onPressed: _loadTeacherData,
            ),
          ),
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: PopupMenuButton<String>(
              padding: EdgeInsets.all(8),
              constraints: BoxConstraints(minWidth: 40, minHeight: 40),
              icon: Icon(Icons.account_circle, color: Colors.white, size: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) async {
                if (value == 'logout') {
                  await SessionManager.clearSession();
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/',
                      (route) => false,
                    );
                  }
                }
              },
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(
                            Icons.logout,
                            color: Color(0xFFD32F2F),
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Text('Logout'),
                        ],
                      ),
                    ),
                  ],
            ),
          ),
        ],
      ),
      body:
          _isLoading
              ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.grey[50]!, Colors.white],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: CircularProgressIndicator(
                          color: Color(0xFF1B5E20),
                          strokeWidth: 3,
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Loading dashboard...',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enhanced Welcome Card
                    Container(
                      margin: EdgeInsets.only(bottom: 32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF1B5E20).withOpacity(0.3),
                            blurRadius: 20,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome back,',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white.withOpacity(0.9),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        widget.teacherName,
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildWelcomeInfoItem(
                                      Icons.work_outline,
                                      'Position',
                                      widget.designation,
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  Expanded(
                                    child: _buildWelcomeInfoItem(
                                      Icons.business,
                                      'Department',
                                      widget.department,
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  Expanded(
                                    child: _buildWelcomeInfoItem(
                                      Icons.email_outlined,
                                      'Email',
                                      widget.teacherEmail.split('@')[0],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Enhanced Groups Section
                    if (_subjectGroups.isNotEmpty) ...[
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.groups,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16),
                          Text(
                            'Your Classes',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                          Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFF1976D2).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_getUniqueGroups().length} groups',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1976D2),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _getUniqueGroups().length,
                          itemBuilder: (context, index) {
                            final group = _getUniqueGroups()[index];
                            final subjectsInGroup = _getSubjectsForGroup(
                              group['groupId'],
                            );

                            return Container(
                              width: 260,
                              margin: EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Colors.white, Colors.grey[50]!],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 15,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Color(0xFF1976D2),
                                                Color(0xFF1565C0),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Color(
                                                  0xFF1976D2,
                                                ).withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.class_,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            group['groupName'],
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[800],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Color(
                                          0xFF1976D2,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${subjectsInGroup.length} subjects',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF1976D2),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Expanded(
                                      child: Text(
                                        subjectsInGroup.take(2).join(', ') +
                                            (subjectsInGroup.length > 2
                                                ? '...'
                                                : ''),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                          height: 1.4,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 32),
                    ],

                    // Enhanced Subjects Section
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.book,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Text(
                          'Your Subjects',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                        Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF1B5E20).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${widget.subjects.length} subjects',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1B5E20),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    // Debug info for troubleshooting
                    if (_isLoading) 
                      Container(
                        padding: EdgeInsets.all(16),
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🔄 Loading Data...',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Teacher subjects: ${widget.subjects.join(", ")}',
                              style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                            ),
                            Text(
                              'Subject groups loaded: ${_subjectGroups.keys.join(", ")}',
                              style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                            ),
                          ],
                        ),
                      ),

                    // Enhanced Subjects Grid
                    widget.subjects.isEmpty
                        ? _buildEnhancedEmptyState()
                        : GridView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1.2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: widget.subjects.length,
                          itemBuilder: (context, index) {
                            final subject = widget.subjects[index];
                            final attendanceCount =
                                _todaysAttendance[subject] ?? 0;
                            final groupCount =
                                _subjectGroups[subject]?.length ?? 0;

                            return _buildEnhancedSubjectCard(
                              subject,
                              attendanceCount,
                              groupCount,
                            );
                          },
                        ),
                  ],
                ),
              ),
    );
  }

  Widget _buildWelcomeInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildEnhancedSubjectCard(
    String subject,
    int attendanceCount,
    int groupCount,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToSubjectAttendance(subject),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF1B5E20).withOpacity(0.3),
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(Icons.subject, color: Colors.white, size: 18),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        subject,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.today, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            'Today\'s Attendance',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '$attendanceCount students',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFF1976D2).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$groupCount groups',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF1976D2),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedEmptyState() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.white, Colors.grey[50]!]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey[100]!, Colors.grey[200]!],
                ),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(
                Icons.school_outlined,
                size: 64,
                color: Colors.grey[500],
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No subjects assigned',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Contact your administrator to get\nsubjects assigned to your account',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Refresh Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SubjectAttendanceScreen extends StatefulWidget {
  final String subject;
  final String teacherName;
  final List<Map<String, dynamic>> groups;

  const SubjectAttendanceScreen({
    super.key,
    required this.subject,
    required this.teacherName,
    required this.groups,
  });

  @override
  State<SubjectAttendanceScreen> createState() =>
      _SubjectAttendanceScreenState();
}

class _SubjectAttendanceScreenState extends State<SubjectAttendanceScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _selectedDateRange;
  List<Map<String, dynamic>> _attendanceRecords = [];
  final Map<String, List<String>> _groupStudents = {};
  Map<String, int> _attendanceStats = {};
  String _selectedGroupFilter = 'All Groups';
  String _selectedStatusFilter = 'All Status';

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Cached students data to avoid reloading on search
  Map<String, List<Map<String, dynamic>>> _cachedStudentsData = {
    'Excellent (90-100%)': [],
    'Good (75-89%)': [],
    'Average (60-74%)': [],
    'Below Average (40-59%)': [],
    'Poor (0-39%)': [],
  };
  bool _studentsDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadGroupStudents(),
        _loadAttendanceForDate(),
        _loadAllStudentsInGroups(), // Add this to populate cached student data
      ]);
      await _calculateStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGroupStudents() async {
    try {
      _groupStudents.clear();

      print('📚 Loading students for ${widget.groups.length} groups...');

      for (var group in widget.groups) {
        final groupId = group['groupId'];
        final groupName = group['groupName'] ?? 'Unknown Group';

        print('🔍 Processing group: $groupName (ID: $groupId)');
        print('🔍 Full group data: $group');

        // Let's also check what groups actually exist in Firestore
        try {
          print('🔍 Checking available groups in Firestore...');
          final allGroupsQuery =
              await FirebaseFirestore.instance.collection('groups').get();
          print('📋 Found ${allGroupsQuery.docs.length} groups in Firestore:');

          String? correctGroupId;
          for (var doc in allGroupsQuery.docs) {
            final data = doc.data();
            final name = data['name'] ?? 'Unknown';
            print('   - ID: ${doc.id}, Name: $name');

            // Check if this matches our group name exactly
            if (name == groupName) {
              correctGroupId = doc.id;
              print('   ✅ POTENTIAL MATCH: ID: ${doc.id}, Name: $name');
            }
          }

          // Use the correct group ID if found
          if (correctGroupId != null && correctGroupId != groupId) {
            print(
              '🔄 Switching from $groupId to $correctGroupId for group $groupName',
            );
            group['groupId'] = correctGroupId; // Update the group data
          }
        } catch (e) {
          print('❌ Error checking available groups: $e');
        }

        // Get the (potentially corrected) group ID
        final finalGroupId = group['groupId'];

        // Get students by looking through student_checkins collection
        // and finding students that belong to this group for the teacher's subject
        Set<String> students = {};

        try {
          // Try multiple approaches to access the student_checkins collection
          print('  🔍 Attempt 1: Standard collection query...');
          final checkinsQuery =
              await FirebaseFirestore.instance
                  .collection('student_checkins')
                  .get();

          print(
            '  👥 Standard query returned ${checkinsQuery.docs.length} student documents',
          );

          if (checkinsQuery.docs.isEmpty) {
            // Try direct access to specific documents we know should exist
            print('  🔍 Attempt 2: Direct document access...');
            final knownRollNumbers = ['23CSR071', '23CSR112', '23EEE029'];

            for (String rollNumber in knownRollNumbers) {
              try {
                final docRef = FirebaseFirestore.instance
                    .collection('student_checkins')
                    .doc(rollNumber);
                final docSnap = await docRef.get();

                if (docSnap.exists) {
                  print('  ✅ Found document for $rollNumber');
                  final sessionsSnap =
                      await docRef.collection('sessions').get();
                  print('    � Sessions: ${sessionsSnap.docs.length}');

                  // Check if any sessions match our criteria
                  for (var sessionDoc in sessionsSnap.docs) {
                    final sessionData = sessionDoc.data();
                    final studentData =
                        sessionData['student'] as Map<String, dynamic>?;
                    final sessionSubject =
                        sessionData['subject']?.toString() ?? '';
                    final studentGroupId =
                        studentData?['groupId']?.toString() ?? '';
                    final studentGroupName =
                        studentData?['groupName']?.toString() ?? '';

                    print(
                      '    🔖 Session: subject=$sessionSubject, groupId=$studentGroupId, groupName=$studentGroupName',
                    );

                    // Check if this session belongs to our group and subject
                    if ((studentGroupId == finalGroupId ||
                            studentGroupName == groupName) &&
                        sessionSubject == widget.subject) {
                      students.add(rollNumber);
                      print(
                        '  ✅ Added student $rollNumber for group $groupName with subject ${widget.subject}',
                      );
                      break;
                    }
                  }
                } else {
                  print('  ❌ Document $rollNumber does not exist');
                }
              } catch (docError) {
                print('  ❌ Error accessing document $rollNumber: $docError');
              }
            }
          } else {
            // Process the documents normally
            for (var studentDoc in checkinsQuery.docs) {
              final rollNumber = studentDoc.id;

              // Get all sessions for this student
              final sessionsQuery =
                  await studentDoc.reference.collection('sessions').get();

              for (var sessionDoc in sessionsQuery.docs) {
                final sessionData = sessionDoc.data();
                final studentData =
                    sessionData['student'] as Map<String, dynamic>?;
                final sessionSubject = sessionData['subject']?.toString() ?? '';
                final studentGroupId =
                    studentData?['groupId']?.toString() ?? '';
                final studentGroupName =
                    studentData?['groupName']?.toString() ?? '';

                // Check if this student belongs to the current group and has sessions for the current subject
                if ((studentGroupId == finalGroupId ||
                        studentGroupName == groupName) &&
                    sessionSubject == widget.subject) {
                  students.add(rollNumber);
                  print(
                    '  ✅ Found student $rollNumber for group $groupName with subject ${widget.subject}',
                  );
                  break; // Found a matching session, no need to check more sessions for this student
                }
              }
            }
          }
        } catch (e) {
          print('  ❌ Error accessing student_checkins: $e');
        }

        // Also try to get students from students collection as additional fallback
        if (students.isEmpty) {
          print(
            '  🔍 Attempt 3: Loading from groups/$finalGroupId/students subcollection...',
          );
          try {
            final studentsQuery =
                await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(finalGroupId)
                    .collection('students')
                    .get();

            print(
              '  👥 Found ${studentsQuery.docs.length} students in groups/$groupId/students subcollection',
            );

            for (var doc in studentsQuery.docs) {
              final studentData = doc.data();
              final rollNumber = studentData['rollNumber']?.toString();
              if (rollNumber != null) {
                students.add(rollNumber);
                print(
                  '  ✅ Added student $rollNumber from groups subcollection',
                );
              }
            }
          } catch (e) {
            print(
              '  ❌ Error accessing groups/$finalGroupId/students subcollection: $e',
            );
          }
        }

        // Also try to get students from groups collection as fallback
        if (students.isEmpty) {
          final studentsQuery =
              await FirebaseFirestore.instance
                  .collection('groups')
                  .doc(finalGroupId)
                  .collection('students')
                  .get();

          for (var doc in studentsQuery.docs) {
            // The document ID is the roll number
            students.add(doc.id);

            // Also check if there's student data in the document
            final studentData = doc.data();
            if (studentData.containsKey('rollNumber')) {
              students.add(studentData['rollNumber'].toString());
            }
          }

          // If still no students found in subcollection, try to get from group document itself
          if (students.isEmpty) {
            final groupDoc =
                await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(finalGroupId)
                    .get();

            if (groupDoc.exists) {
              final groupData = groupDoc.data();
              if (groupData != null && groupData.containsKey('students')) {
                final groupStudents = groupData['students'];
                if (groupStudents is List) {
                  for (var student in groupStudents) {
                    if (student is String) {
                      students.add(student);
                    } else if (student is Map &&
                        student.containsKey('rollNumber')) {
                      students.add(student['rollNumber'].toString());
                    }
                  }
                }
              }
            }
          }
        }

        // Convert to list and store
        final studentsList = students.toList();
        _groupStudents[groupName] = studentsList;

        if (mounted) {
          print(
            'Loaded ${studentsList.length} students for group $groupName: $studentsList',
          );
        }
      }
    } catch (e) {
      print('Error loading group students: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading group students: $e')),
        );
      }
    }
  }

  Future<void> _loadAttendanceForDate() async {
    try {
      List<Map<String, dynamic>> records = [];

      print('🔍 Loading attendance for subject: ${widget.subject}');
      print('📅 Selected date: $_selectedDate');
      print('📅 Selected date range: $_selectedDateRange');

      // Try to get all student check-ins from student_checkins collection
      QuerySnapshot? checkinsQuery;

      try {
        // First, let's get all documents in student_checkins collection
        print('🔍 Attempting to access student_checkins collection...');
        checkinsQuery =
            await FirebaseFirestore.instance
                .collection('student_checkins')
                .get();
        print(
          '👥 Collection query returned ${checkinsQuery.docs.length} documents',
        );

        // List all document IDs if any exist
        if (checkinsQuery.docs.isNotEmpty) {
          final docIds = checkinsQuery.docs.map((doc) => doc.id).toList();
          print('📋 Document IDs in student_checkins: $docIds');

          // Test access to first document
          final firstDoc = checkinsQuery.docs.first;
          print('🔍 Testing access to first document: ${firstDoc.id}');
          final sessionsSnap =
              await firstDoc.reference.collection('sessions').get();
          print('   Sessions in ${firstDoc.id}: ${sessionsSnap.docs.length}');

          if (sessionsSnap.docs.isNotEmpty) {
            final sampleSession = sessionsSnap.docs.first.data();
            print('   Sample session subject: ${sampleSession['subject']}');
            print('   Sample session student: ${sampleSession['student']}');
          }
        } else {
          print('⚠️ No documents found in student_checkins collection');

          // Let's try to check if any new documents were created recently
          // by looking for specific roll numbers we know exist
          final knownRollNumbers = ['23CSR071', '23CSR112', '23EEE029'];
          for (String rollNumber in knownRollNumbers) {
            try {
              final testDoc =
                  await FirebaseFirestore.instance
                      .collection('student_checkins')
                      .doc(rollNumber)
                      .get();
              if (testDoc.exists) {
                print('✅ Found document for $rollNumber');
                final sessions =
                    await testDoc.reference.collection('sessions').get();
                print('   Sessions: ${sessions.docs.length}');
                checkinsQuery =
                    await FirebaseFirestore.instance
                        .collection('student_checkins')
                        .get(); // Refresh the query
                break;
              } else {
                print('❌ Document $rollNumber does not exist');
              }
            } catch (e) {
              print('❌ Error accessing $rollNumber: $e');
            }
          }
        }
      } catch (e) {
        print('❌ Error accessing student_checkins collection: $e');
        print('❌ Error type: ${e.runtimeType}');
        print('❌ Error details: $e');

        // Try alternative collection names
        final alternativeNames = [
          'student_check_ins',
          'students_checkins',
          'checkins',
          'student_sessions',
        ];
        for (String altName in alternativeNames) {
          try {
            print('🔍 Trying alternative collection name: $altName');
            checkinsQuery =
                await FirebaseFirestore.instance.collection(altName).get();
            print(
              '✅ Found collection $altName with ${checkinsQuery.docs.length} documents',
            );
            break;
          } catch (altError) {
            print('❌ Collection $altName not found: $altError');
          }
        }
      }

      if (checkinsQuery == null || checkinsQuery.docs.isEmpty) {
        print(
          '⚠️ No student check-in documents found, trying refresh approach...',
        );

        // Wait a moment and try again (in case of Firebase caching issues)
        await Future.delayed(Duration(milliseconds: 500));

        try {
          checkinsQuery = await FirebaseFirestore.instance
              .collection('student_checkins')
              .get(GetOptions(source: Source.server)); // Force server fetch
          print(
            '🔄 Retry query returned ${checkinsQuery.docs.length} documents',
          );
        } catch (e) {
          print('❌ Retry failed: $e');
        }

        if (checkinsQuery == null || checkinsQuery.docs.isEmpty) {
          // Let's explore what collections are available
          print('🔍 Exploring available Firestore collections...');
          try {
            // Try to list some known collections to see what's available
            final knownCollections = [
              'users',
              'students',
              'groups',
              'timetables',
              'attendance',
            ];
            for (String collection in knownCollections) {
              try {
                final testQuery =
                    await FirebaseFirestore.instance
                        .collection(collection)
                        .limit(1)
                        .get();
                print(
                  '✅ Collection "$collection" exists with ${testQuery.docs.length} documents (showing 1)',
                );
                if (testQuery.docs.isNotEmpty) {
                  print(
                    '   Sample document keys: ${testQuery.docs.first.data().keys.toList()}',
                  );
                }
              } catch (e) {
                print('❌ Collection "$collection" error: $e');
              }
            }

            // Try to load students from the students collection as fallback
            print(
              '🔍 Attempting to use groups/{groupId}/students subcollection as fallback...',
            );

            // Get all groups to find students
            for (var group in widget.groups) {
              final groupId = group['groupId'];
              final groupName = group['groupName'] ?? 'Unknown Group';

              try {
                final studentsSnap =
                    await FirebaseFirestore.instance
                        .collection('groups')
                        .doc(groupId)
                        .collection('students')
                        .get();
                print(
                  '👥 Group $groupName has ${studentsSnap.docs.length} students in subcollection',
                );

                // Create dummy attendance records from students if needed
                for (var studentDoc in studentsSnap.docs) {
                  final studentData = studentDoc.data();
                  final rollNumber = studentData['rollNumber']?.toString();

                  if (rollNumber != null) {
                    print('📝 Student: $rollNumber in group $groupName');
                  }
                }
              } catch (e) {
                print('❌ Error accessing groups/$groupId/students: $e');
              }
            }
          } catch (e) {
            print('❌ Error exploring collections: $e');
          }

          setState(() => _attendanceRecords = []);
          return;
        }
      }

      // Process all student documents
      for (var studentDoc in checkinsQuery.docs) {
        final rollNumber = studentDoc.id;
        print('📚 Processing student: $rollNumber');

        // Get all sessions for this student
        QuerySnapshot sessionsQuery;
        try {
          sessionsQuery =
              await studentDoc.reference.collection('sessions').get();
          print(
            '  � Student $rollNumber has ${sessionsQuery.docs.length} sessions',
          );
        } catch (e) {
          print('  ❌ Error loading sessions for $rollNumber: $e');
          continue;
        }

        for (var sessionDoc in sessionsQuery.docs) {
          final sessionData = sessionDoc.data() as Map<String, dynamic>;
          final studentData = sessionData['student'] as Map<String, dynamic>?;
          final sessionSubject = sessionData['subject']?.toString() ?? '';
          final sessionDate = sessionData['date'] as Timestamp?;

          print(
            '    � Session ${sessionDoc.id}: subject="$sessionSubject", date=${sessionDate?.toDate()}',
          );

          // First, load ALL records regardless of subject or date for debugging
          if (sessionDate != null && studentData != null) {
            final sessionDateTime = sessionDate.toDate();

            // Get group information from the student data (stored in session)
            final groupId = studentData['groupId']?.toString() ?? '';
            final groupName =
                studentData['groupName']?.toString() ?? 'Unknown Group';

            // Calculate session duration if completed
            double? durationMinutes;
            if (sessionData['durationMinutes'] != null) {
              durationMinutes =
                  (sessionData['durationMinutes'] as num).toDouble();
            } else if (sessionData['checkInAt'] != null &&
                sessionData['checkOutAt'] != null) {
              final checkIn = (sessionData['checkInAt'] as Timestamp).toDate();
              final checkOut =
                  (sessionData['checkOutAt'] as Timestamp).toDate();
              durationMinutes =
                  checkOut.difference(checkIn).inMinutes.toDouble();
            }

            // Extract the day from the session data or calculate from date
            String dayName = sessionData['day']?.toString() ?? '';
            if (dayName.isEmpty) {
              final weekday = sessionDateTime.weekday;
              const dayNames = [
                'Monday',
                'Tuesday',
                'Wednesday',
                'Thursday',
                'Friday',
                'Saturday',
                'Sunday',
              ];
              dayName = dayNames[(weekday - 1) % 7];
            }

            // Create the record
            final record = {
              'sessionId': sessionDoc.id,
              'rollNumber': rollNumber,
              'studentName': studentData['name'] ?? 'Unknown',
              'studentEmail': studentData['email'] ?? '',
              'department': studentData['department'] ?? '',
              'groupId': groupId,
              'groupName': groupName,
              'subject': sessionSubject,
              'period': sessionData['period'],
              'roomOrLocation': sessionData['roomOrLocation'] ?? '',
              'campus': sessionData['campus'] ?? '',
              'checkInAt': sessionData['checkInAt'],
              'checkOutAt': sessionData['checkOutAt'],
              'expectedEndAt': sessionData['expectedEndAt'],
              'status': sessionData['status'] ?? '',
              'checkInLat': sessionData['checkInLat'],
              'checkInLng': sessionData['checkInLng'],
              'checkOutLat': sessionData['checkOutLat'],
              'checkOutLng': sessionData['checkOutLng'],
              'durationMinutes': durationMinutes,
              'closeReason': sessionData['closeReason'],
              'logs': sessionData['logs'] ?? [],
              'date': sessionDate,
              'isEnrolled': true, // We'll determine this later
              'day': dayName,
            };

            records.add(record);
            print(
              '    ✅ Added record for $rollNumber (${studentData['name']}) - Subject: $sessionSubject',
            );
          }
        }
      }

      print('� Total records loaded before filtering: ${records.length}');

      // Now apply filtering
      List<Map<String, dynamic>> filteredRecords = [];

      for (var record in records) {
        bool matchesSubject = false;
        bool matchesDate = false;

        // Subject filter
        final recordSubject = record['subject']?.toString() ?? '';
        matchesSubject = recordSubject == widget.subject;

        // Date filter
        final recordDate = record['date'] as Timestamp?;
        if (recordDate != null) {
          final sessionDateTime = recordDate.toDate();

          if (_selectedDateRange != null) {
            matchesDate =
                sessionDateTime.isAfter(
                  _selectedDateRange!.start.subtract(Duration(days: 1)),
                ) &&
                sessionDateTime.isBefore(
                  _selectedDateRange!.end.add(Duration(days: 1)),
                );
          } else {
            // Show all records by default unless user specifically selected a date
            matchesDate = true;
          }
        }

        if (matchesSubject && matchesDate) {
          // Check enrollment status
          final rollNumber = record['rollNumber']?.toString() ?? '';
          final groupName = record['groupName']?.toString() ?? '';

          bool isEnrolled = false;
          if (_groupStudents.containsKey(groupName)) {
            isEnrolled = _groupStudents[groupName]!.contains(rollNumber);
          }

          if (!isEnrolled) {
            for (var groupStudentsList in _groupStudents.values) {
              if (groupStudentsList.contains(rollNumber)) {
                isEnrolled = true;
                break;
              }
            }
          }

          record['isEnrolled'] = isEnrolled;
          filteredRecords.add(record);
          print(
            '    🎯 Record matches filters: $rollNumber - ${record['studentName']}',
          );
        }
      }

      print(
        '🎯 Records matching subject filter ($widget.subject): ${records.where((r) => r['subject'] == widget.subject).length}',
      );
      print('🎯 Records matching date filter: ${filteredRecords.length}');

      // Apply additional UI filters
      filteredRecords = _applyFilters(filteredRecords);

      print(
        '🎯 Final attendance records count after all filters: ${filteredRecords.length}',
      );
      setState(() => _attendanceRecords = filteredRecords);
    } catch (e) {
      print('❌ Error loading attendance: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading attendance: $e')));
      }
    }
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> records) {
    return records.where((record) {
      // Group filter
      if (_selectedGroupFilter != 'All Groups' &&
          record['groupName'] != _selectedGroupFilter) {
        return false;
      }

      // Status filter
      if (_selectedStatusFilter != 'All Status') {
        switch (_selectedStatusFilter) {
          case 'Present':
            return record['status'] == 'completed';
          case 'Ongoing':
            return record['status'] == 'ongoing';
          case 'Absentees':
            return record['isEnrolled'] == false;
          default:
            break;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _calculateStats() async {
    try {
      Map<String, int> stats = {
        'totalSessions': 0,
        'completedSessions': 0,
        'ongoingSessions': 0,
        'authorizedStudents': 0,
        'absenteeStudents': 0,
      };

      for (var record in _attendanceRecords) {
        stats['totalSessions'] = (stats['totalSessions'] ?? 0) + 1;

        if (record['status'] == 'completed') {
          stats['completedSessions'] = (stats['completedSessions'] ?? 0) + 1;
        } else if (record['status'] == 'ongoing') {
          stats['ongoingSessions'] = (stats['ongoingSessions'] ?? 0) + 1;
        }

        if (record['isEnrolled'] == true) {
          stats['authorizedStudents'] = (stats['authorizedStudents'] ?? 0) + 1;
        } else {
          stats['absenteeStudents'] = (stats['absenteeStudents'] ?? 0) + 1;
        }
      }

      setState(() => _attendanceStats = stats);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error calculating stats: $e')));
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedDateRange = null; // Clear range when single date selected
      });
      _loadAttendanceForDate();
      _calculateStats();
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _loadAttendanceForDate();
      _calculateStats();
    }
  }

  void _showStudentDetails(Map<String, dynamic> record) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Student Details'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Name: ${record['studentName'] ?? 'N/A'}'),
                  SizedBox(height: 8),
                  Text('Roll Number: ${record['rollNumber'] ?? 'N/A'}'),
                  SizedBox(height: 8),
                  Text('Group: ${record['groupName'] ?? 'N/A'}'),
                  SizedBox(height: 8),
                  Text('Department: ${record['department'] ?? 'N/A'}'),
                  SizedBox(height: 8),
                  Text('Status: ${record['status'] ?? 'N/A'}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.analytics_outlined, size: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.subject,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Statistics Dashboard',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Container(
            color: const Color(0xFF1B5E20),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              indicatorPadding: EdgeInsets.symmetric(horizontal: 24),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w400),
              tabs: [
                Tab(
                  icon: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.list_alt, size: 20),
                  ),
                  text: 'Attendance',
                ),
                Tab(
                  icon: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.insights, size: 20),
                  ),
                  text: 'Analytics',
                ),
                Tab(
                  icon: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.people_outline, size: 20),
                  ),
                  text: 'Students',
                ),
              ],
            ),
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: PopupMenuButton<String>(
              icon: Icon(Icons.date_range_outlined, color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) {
                if (value == 'single') {
                  _selectDate();
                } else if (value == 'range') {
                  _selectDateRange();
                }
              },
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value: 'single',
                      child: Row(
                        children: [
                          Icon(Icons.today, size: 20, color: Color(0xFF1B5E20)),
                          SizedBox(width: 12),
                          Text('Select Date'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'range',
                      child: Row(
                        children: [
                          Icon(
                            Icons.date_range,
                            size: 20,
                            color: Color(0xFF1B5E20),
                          ),
                          SizedBox(width: 12),
                          Text('Date Range'),
                        ],
                      ),
                    ),
                  ],
            ),
          ),
          Container(
            margin: EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadAllData,
            ),
          ),
        ],
      ),
      body:
          _isLoading
              ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.grey[50]!, Colors.white],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: CircularProgressIndicator(
                          color: Color(0xFF1B5E20),
                          strokeWidth: 3,
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Loading statistics...',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildAttendanceTab(),
                  _buildAnalyticsTab(),
                  _buildStudentsTab(),
                ],
              ),
    );
  }

  Widget _buildAttendanceTab() {
    return Column(
      children: [
        // Enhanced Filters and Date Info
        Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey[50]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Enhanced Date Display
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF1B5E20).withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_month,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedDateRange != null
                                ? 'Date Range'
                                : 'Selected Date',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _selectedDateRange != null
                                ? '${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}'
                                : _formatDate(_selectedDate),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_getTotalStudentCount()} students',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1B5E20),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Enhanced Filters
              Row(
                children: [
                  Expanded(
                    child: _buildEnhancedDropdownFilter(
                      'Group',
                      Icons.group,
                      _selectedGroupFilter,
                      ['All Groups'] +
                          widget.groups
                              .map<String>((g) => g['groupName'] ?? 'Unknown')
                              .toList(),
                      (value) => setState(() {
                        _selectedGroupFilter = value ?? 'All Groups';
                        _attendanceRecords = _applyFilters(_attendanceRecords);
                        _calculateStats();
                      }),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildEnhancedDropdownFilter(
                      'Status',
                      Icons.verified,
                      _selectedStatusFilter,
                      ['All Status', 'Present', 'Absentees'],
                      (value) => setState(() {
                        _selectedStatusFilter = value ?? 'All Status';
                      }),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Enhanced Attendance List
        Expanded(child: _buildFilteredStudentsList()),
      ],
    );
  }

  // Helper method to get students who are present
  List<Map<String, dynamic>> _getPresentStudents() {
    if (_selectedDateRange == null) {
      // If we have no attendance records but have cached student data, use that instead
      if (_attendanceRecords.isEmpty && _cachedStudentsData.isNotEmpty) {
        List<Map<String, dynamic>> presentStudents = [];

        // Get students from Excellent and Good categories (they have attendance)
        for (var category in [
          'Excellent (90-100%)',
          'Good (75-89%)',
          'Average (60-74%)',
          'Below Average (40-59%)',
        ]) {
          for (var student in _cachedStudentsData[category] ?? []) {
            print(
              '[DEBUG] Adding present student: ${student['rollNumber']} - ${student['studentName']} - ${student['attendanceRate']}%',
            );
            presentStudents.add({
              'rollNumber': student['rollNumber'],
              'studentName': student['studentName'] ?? 'Unknown',
              'name': student['studentName'] ?? 'Unknown',
              'status': 'completed', // Simulated status
              'groupId': student['groupId'],
              'attendancePercentage':
                  student['attendanceRate']?.toDouble() ?? 0.0,
            });
          }
        }

        print(
          '[DEBUG] Present students from cached data: ${presentStudents.length}',
        );
        print(
          '[DEBUG] Present students: ${presentStudents.map((s) => s['rollNumber']).toList()}',
        );
        return presentStudents;
      }

      // When no specific date range is selected, return unique students who have any check-in record
      Map<String, Map<String, dynamic>> uniqueStudents = {};
      for (var record in _attendanceRecords) {
        String rollNumber = record['rollNumber'] ?? '';
        if (rollNumber.isNotEmpty &&
            (record['status'] == 'completed' ||
                record['status'] == 'checked_in')) {
          uniqueStudents[rollNumber] = record;
        }
      }
      print('[DEBUG] Present students found: ${uniqueStudents.length}');
      print(
        '[DEBUG] Present students: ${uniqueStudents.values.map((s) => s['rollNumber']).toList()}',
      );
      return uniqueStudents.values.toList();
    } else {
      // When a specific date range is selected, return students present in that range
      return _attendanceRecords
          .where(
            (r) => r['status'] == 'completed' || r['status'] == 'checked_in',
          )
          .toList();
    }
  }

  // Helper method to get students who are absent
  List<Map<String, dynamic>> _getAbsentStudents() {
    if (_selectedDateRange == null) {
      // If we have no attendance records but have cached student data, use that instead
      if (_attendanceRecords.isEmpty && _cachedStudentsData.isNotEmpty) {
        List<Map<String, dynamic>> absentStudents = [];

        // Get students from Poor category (they have no attendance)
        for (var student in _cachedStudentsData['Poor (0-39%)'] ?? []) {
          print(
            '[DEBUG] Adding absent student: ${student['rollNumber']} - ${student['studentName']} - ${student['attendanceRate']}%',
          );
          absentStudents.add({
            'rollNumber': student['rollNumber'],
            'studentName': student['studentName'] ?? 'Unknown',
            'name': student['studentName'] ?? 'Unknown',
            'status': 'absent',
            'groupId': student['groupId'],
            'attendancePercentage':
                student['attendanceRate']?.toDouble() ?? 0.0,
          });
        }

        print(
          '[DEBUG] Absent students from cached data: ${absentStudents.length}',
        );
        print(
          '[DEBUG] Absent students: ${absentStudents.map((s) => s['rollNumber']).toList()}',
        );
        return absentStudents;
      }

      // When no specific date range is selected, find enrolled students without any attendance records
      Set<String> presentStudentRolls =
          _getPresentStudents()
              .map((s) => s['rollNumber'] as String)
              .where((roll) => roll.isNotEmpty)
              .toSet();

      print('[DEBUG] Present student rolls: $presentStudentRolls');

      // Get all enrolled students for this group from cached data
      List<Map<String, dynamic>> absentStudents = [];
      for (var group in _cachedStudentsData.values) {
        for (var student in group) {
          String rollNumber = student['rollNumber'] ?? '';
          if (rollNumber.isNotEmpty &&
              !presentStudentRolls.contains(rollNumber)) {
            absentStudents.add({
              'rollNumber': rollNumber,
              'name': student['name'] ?? 'Unknown',
              'status': 'absent',
              'timestamp': null,
              'groupId': student['groupId'],
            });
          }
        }
      }
      print('[DEBUG] Absent students found: ${absentStudents.length}');
      print(
        '[DEBUG] Absent students: ${absentStudents.map((s) => s['rollNumber']).toList()}',
      );
      return absentStudents;
    } else {
      // When a specific date range is selected, return students marked as absent in that range
      return _attendanceRecords.where((r) => r['status'] == 'absent').toList();
    }
  }

  int _getTotalStudentCount() {
    // If we have attendance records, use those
    if (_attendanceRecords.isNotEmpty) {
      return _attendanceRecords.length;
    }

    // Otherwise, count all students from cached data
    int totalCount = 0;
    for (var studentList in _cachedStudentsData.values) {
      totalCount += studentList.length;
    }
    return totalCount;
  }

  Widget _buildFilteredStudentsList() {
    // Get students based on status filter
    List<Map<String, dynamic>> studentsToShow = [];

    switch (_selectedStatusFilter) {
      case 'Present':
        studentsToShow = _getPresentStudents();
        break;
      case 'Absentees':
        studentsToShow = _getAbsentStudents();
        break;
      case 'All Status':
      default:
        // Show all students (present + absent)
        studentsToShow = [];
        studentsToShow.addAll(_getPresentStudents());
        studentsToShow.addAll(_getAbsentStudents());
        break;
    }

    // If no students found with current filter but we have cached data, show message
    if (studentsToShow.isEmpty &&
        _cachedStudentsData.values.any((list) => list.isNotEmpty)) {
      return Center(
        child: Container(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1B5E20).withOpacity(0.1),
                    Color(0xFF2E7D32).withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(
                  Icons.filter_list_off,
                  size: 48,
                  color: Color(0xFF1B5E20),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'No Students Found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 12),
              Text(
                'No students match the current filter: $_selectedStatusFilter',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // If no students at all, show empty state
    if (studentsToShow.isEmpty) {
      return _buildEnhancedEmptyState();
    }

    // Show students in list format (small horizontal rows)
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: studentsToShow.length,
      itemBuilder: (context, index) {
        final student = studentsToShow[index];
        final isPresent = student['status'] != 'absent';
        return _buildStudentRowCard(student, isPresent);
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildEnhancedStatsCards(),
          SizedBox(height: 24),
          _buildEnhancedAttendanceTrendChart(),
          SizedBox(height: 24),
          _buildEnhancedGroupWiseStats(),
        ],
      ),
    );
  }

  Widget _buildStudentRowCard(Map<String, dynamic> record, bool isPresent) {
    final rollNumber = record['rollNumber'] ?? 'Unknown';
    final studentName = record['studentName'] ?? record['name'] ?? 'Unknown';
    final checkInTime =
        record['checkInAt'] != null
            ? (record['checkInAt'] as Timestamp).toDate()
            : null;
    final attendancePercentage = record['attendancePercentage'];

    // Debug print to see what data we're getting
    print(
      '[DEBUG] Building card for $rollNumber: name=$studentName, percentage=$attendancePercentage',
    );

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPresent ? Colors.green[200]! : Colors.red[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // Status indicator circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isPresent ? Colors.green[50] : Colors.red[50],
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPresent ? Colors.green[300]! : Colors.red[300]!,
                  width: 2,
                ),
              ),
              child: Icon(
                isPresent ? Icons.check : Icons.close,
                color: isPresent ? Colors.green[600] : Colors.red[600],
                size: 20,
              ),
            ),
            SizedBox(width: 16),

            // Student info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rollNumber,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    studentName,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Status badge and additional info
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isPresent ? Colors.green[600] : Colors.red[600],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPresent ? 'Present' : 'Absent',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: 4),

                // Show attendance percentage (always show if available, even if 0)
                if (attendancePercentage != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.percent, size: 14, color: Colors.grey[500]),
                      SizedBox(width: 2),
                      Text(
                        '${attendancePercentage.toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                else if (checkInTime != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      SizedBox(width: 2),
                      Text(
                        '${checkInTime.hour.toString().padLeft(2, '0')}:${checkInTime.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedStatsCards() {
    // Calculate real stats from cached student data
    int totalStudents = 0;
    int excellentStudents = 0;
    int goodStudents = 0;
    int poorStudents = 0;
    double totalAttendanceRate = 0;
    int studentsWithAttendance = 0;

    for (var entry in _cachedStudentsData.entries) {
      final categoryStudents = entry.value;
      totalStudents += categoryStudents.length;

      switch (entry.key) {
        case 'Excellent (90-100%)':
          excellentStudents = categoryStudents.length;
          break;
        case 'Good (75-89%)':
          goodStudents = categoryStudents.length;
          break;
        case 'Poor (0-39%)':
          poorStudents = categoryStudents.length;
          break;
      }

      // Calculate average attendance rate
      for (var student in categoryStudents) {
        final rate = student['attendanceRate']?.toDouble() ?? 0.0;
        totalAttendanceRate += rate;
        studentsWithAttendance++;
      }
    }

    final averageAttendanceRate =
        studentsWithAttendance > 0
            ? (totalAttendanceRate / studentsWithAttendance).round()
            : 0;

    final stats = [
      {
        'title': 'Total Students',
        'value': '$totalStudents',
        'icon': Icons.people_outline,
        'color': Color(0xFF1976D2),
        'gradient': [Color(0xFF1976D2), Color(0xFF1565C0)],
      },
      {
        'title': 'Excellent Rate',
        'value': '$excellentStudents',
        'icon': Icons.star_outline,
        'color': Color(0xFF2E7D32),
        'gradient': [Color(0xFF2E7D32), Color(0xFF1B5E20)],
      },
      {
        'title': 'Avg Attendance',
        'value': '$averageAttendanceRate%',
        'icon': Icons.trending_up,
        'color': Color(0xFFE65100),
        'gradient': [Color(0xFFE65100), Color(0xFFBF360C)],
      },
      {
        'title': 'Poor Attendance',
        'value': '$poorStudents',
        'icon': Icons.trending_down,
        'color': Color(0xFFD32F2F),
        'gradient': [Color(0xFFD32F2F), Color(0xFFC62828)],
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return _buildEnhancedStatCard(
          stat['title'] as String,
          stat['value'] as String,
          stat['icon'] as IconData,
          stat['gradient'] as List<Color>,
        );
      },
    );
  }

  Widget _buildEnhancedStatCard(
    String title,
    String value,
    IconData icon,
    List<Color> gradientColors,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {}, // Add functionality if needed
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 24, color: Colors.white),
                ),
                SizedBox(height: 12),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedAttendanceCard(Map<String, dynamic> record, int index) {
    final isPresent = record['status'] == 'completed';
    final isEnrolled = record['isEnrolled'] == true;
    final checkInTime =
        record['checkInAt'] != null
            ? (record['checkInAt'] as Timestamp).toDate()
            : null;
    final duration = record['durationMinutes']?.toInt() ?? 0;

    Color statusColor =
        isPresent
            ? Color(0xFF2E7D32)
            : record['status'] == 'ongoing'
            ? Color(0xFFE65100)
            : Colors.grey[600]!;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showStudentDetails(record),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors:
                              isPresent
                                  ? [Color(0xFF2E7D32), Color(0xFF1B5E20)]
                                  : record['status'] == 'ongoing'
                                  ? [Color(0xFFE65100), Color(0xFFBF360C)]
                                  : [Colors.grey[500]!, Colors.grey[600]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        isPresent ? Icons.check : Icons.schedule,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  record['studentName'] ?? 'Unknown',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                              if (!isEnrolled) ...[
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFFD32F2F),
                                        Color(0xFFC62828),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'ABSENTEE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.badge,
                                size: 16,
                                color: Colors.grey[500],
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Roll: ${record['rollNumber']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(width: 12),
                              Icon(
                                Icons.group,
                                size: 16,
                                color: Colors.grey[500],
                              ),
                              SizedBox(width: 4),
                              Text(
                                '${record['groupName']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isPresent
                            ? 'Present'
                            : record['status']?.toUpperCase() ?? 'UNKNOWN',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (checkInTime != null ||
                    record['roomOrLocation']?.isNotEmpty == true ||
                    duration > 0) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        if (checkInTime != null) ...[
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.blue[700],
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '${checkInTime.hour.toString().padLeft(2, '0')}:${checkInTime.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (record['roomOrLocation']?.isNotEmpty == true) ...[
                          if (checkInTime != null) SizedBox(width: 16),
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.green[700],
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              record['roomOrLocation'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (duration > 0) ...[
                          Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer,
                                  size: 14,
                                  color: Colors.orange[700],
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '${duration}min',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedDropdownFilter(
    String label,
    IconData icon,
    String value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Color(0xFF1B5E20)),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF1B5E20)),
              onChanged: onChanged,
              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
              items:
                  options.map((String option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(
                        option,
                        style: TextStyle(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedEmptyState() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey[100]!, Colors.grey[200]!],
                ),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 64,
                color: Colors.grey[500],
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No attendance records found',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Try adjusting your filters or date selection\nto find the records you\'re looking for',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Refresh Data',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedAttendanceTrendChart() {
    // Calculate attendance distribution from cached data
    Map<String, int> attendanceDistribution = {};
    Map<String, Color> categoryColors = {
      'Excellent (90-100%)': Color(0xFF2E7D32),
      'Good (75-89%)': Color(0xFF66BB6A),
      'Average (60-74%)': Color(0xFFFFA726),
      'Below Average (40-59%)': Color(0xFFFF7043),
      'Poor (0-39%)': Color(0xFFE57373),
    };

    for (var entry in _cachedStudentsData.entries) {
      attendanceDistribution[entry.key] = entry.value.length;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.analytics, color: Colors.white, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance Distribution',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      Text(
                        'Student performance breakdown',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            // Attendance category bars
            ...attendanceDistribution.entries.map((entry) {
              final category = entry.key;
              final count = entry.value;
              final maxCount =
                  attendanceDistribution.values.isNotEmpty
                      ? attendanceDistribution.values.reduce(
                        (a, b) => a > b ? a : b,
                      )
                      : 1;
              final percentage = maxCount > 0 ? (count / maxCount) : 0.0;

              return Container(
                margin: EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            category.replaceAll('(', '\n('),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                              height: 1.2,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColors[category]?.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  categoryColors[category]?.withOpacity(0.3) ??
                                  Colors.grey,
                            ),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: categoryColors[category],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: percentage,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                categoryColors[category] ?? Colors.grey,
                                (categoryColors[category] ?? Colors.grey)
                                    .withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedGroupWiseStats() {
    // Calculate group-wise stats from cached student data
    Map<String, Map<String, dynamic>> groupStats = {};

    // Get group information from widget.groups
    for (var group in widget.groups) {
      final groupName = group['groupName'] ?? 'Unknown Group';
      groupStats[groupName] = {
        'totalStudents': 0,
        'excellentStudents': 0,
        'goodStudents': 0,
        'averageStudents': 0,
        'belowAverageStudents': 0,
        'poorStudents': 0,
        'averageAttendanceRate': 0.0,
      };
    }

    // Calculate stats from cached student data
    for (var entry in _cachedStudentsData.entries) {
      final category = entry.key;
      final students = entry.value;

      for (var student in students) {
        final studentGroupName = student['groupName'] ?? 'Unknown Group';

        if (groupStats.containsKey(studentGroupName)) {
          groupStats[studentGroupName]!['totalStudents'] =
              (groupStats[studentGroupName]!['totalStudents'] as int) + 1;

          final attendanceRate = student['attendanceRate']?.toDouble() ?? 0.0;
          final currentAvg =
              groupStats[studentGroupName]!['averageAttendanceRate'] as double;
          final totalStudents =
              groupStats[studentGroupName]!['totalStudents'] as int;

          // Update average attendance rate
          groupStats[studentGroupName]!['averageAttendanceRate'] =
              ((currentAvg * (totalStudents - 1)) + attendanceRate) /
              totalStudents;

          // Categorize student
          switch (category) {
            case 'Excellent (90-100%)':
              groupStats[studentGroupName]!['excellentStudents'] =
                  (groupStats[studentGroupName]!['excellentStudents'] as int) +
                  1;
              break;
            case 'Good (75-89%)':
              groupStats[studentGroupName]!['goodStudents'] =
                  (groupStats[studentGroupName]!['goodStudents'] as int) + 1;
              break;
            case 'Average (60-74%)':
              groupStats[studentGroupName]!['averageStudents'] =
                  (groupStats[studentGroupName]!['averageStudents'] as int) + 1;
              break;
            case 'Below Average (40-59%)':
              groupStats[studentGroupName]!['belowAverageStudents'] =
                  (groupStats[studentGroupName]!['belowAverageStudents']
                      as int) +
                  1;
              break;
            case 'Poor (0-39%)':
              groupStats[studentGroupName]!['poorStudents'] =
                  (groupStats[studentGroupName]!['poorStudents'] as int) + 1;
              break;
          }
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.group, color: Colors.white, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Group Performance',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      Text(
                        'Attendance statistics by group',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            if (groupStats.isEmpty)
              Container(
                padding: EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'No group data available',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ),
              )
            else
              ...groupStats.entries.map((entry) {
                final groupName = entry.key;
                final stats = entry.value;
                final totalStudents = stats['totalStudents'] as int;
                final excellentStudents = stats['excellentStudents'] as int;
                final goodStudents = stats['goodStudents'] as int;
                final poorStudents = stats['poorStudents'] as int;
                final averageAttendanceRate =
                    (stats['averageAttendanceRate'] as double).round();

                Color performanceColor =
                    averageAttendanceRate >= 80
                        ? Color(0xFF2E7D32)
                        : averageAttendanceRate >= 60
                        ? Color(0xFFE65100)
                        : Color(0xFFD32F2F);

                return Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: performanceColor.withOpacity(0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: performanceColor.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  groupName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '$totalStudents total students',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  performanceColor,
                                  performanceColor.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$averageAttendanceRate%',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Student category breakdown
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatItem(
                              'Excellent',
                              excellentStudents.toString(),
                              Color(0xFF2E7D32),
                              Icons.check_circle,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _buildStatItem(
                              'Good',
                              goodStudents.toString(),
                              Color(0xFF66BB6A),
                              Icons.trending_up,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _buildStatItem(
                              'Poor',
                              poorStudents.toString(),
                              Color(0xFFE57373),
                              Icons.warning,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>>
  _loadAllStudentsInGroups() async {
    try {
      Map<String, List<Map<String, dynamic>>> groupedStudents = {
        'Excellent (90-100%)': [],
        'Good (75-89%)': [],
        'Average (60-74%)': [],
        'Below Average (40-59%)': [],
        'Poor (0-39%)': [],
      };

      // Get groups passed from the parent widget
      List<Map<String, dynamic>> teacherGroups = widget.groups;

      print('🔍 Loading students for ${teacherGroups.length} groups...');

      for (var group in teacherGroups) {
        final groupName = group['groupName'] ?? 'Unknown Group';
        final groupId = group['groupId'];

        print('📚 Processing group: $groupName');
        print('🔑 Group ID: "$groupId"');

        // Verify the group ID is correct by checking available groups
        try {
          print('🔍 Checking available groups in Firestore...');
          final allGroupsQuery =
              await FirebaseFirestore.instance.collection('groups').get();
          print('📋 Found ${allGroupsQuery.docs.length} groups in Firestore:');

          String? correctGroupId;
          for (var doc in allGroupsQuery.docs) {
            final data = doc.data();
            final name = data['name'] ?? 'Unknown';

            // Check if this matches our group name exactly
            if (name == groupName) {
              correctGroupId = doc.id;
              print('   ✅ POTENTIAL MATCH: ID: ${doc.id}, Name: $name');
            }
          }

          // Use the correct group ID if found
          if (correctGroupId != null) {
            print(
              '🔄 Found correct group ID: $correctGroupId for group $groupName',
            );
            group['groupId'] = correctGroupId; // Update the group data
          }
        } catch (e) {
          print('❌ Error verifying group ID: $e');
        }

        final finalGroupId = group['groupId'];

        // STEP 1: Load ALL students from groups/{groupId}/students subcollection
        try {
          print(
            '📚 Loading ALL students from groups/$finalGroupId/students subcollection...',
          );
          final studentsQuery =
              await FirebaseFirestore.instance
                  .collection('groups')
                  .doc(finalGroupId)
                  .collection('students')
                  .get();

          print(
            '👥 Found ${studentsQuery.docs.length} total students in group $groupName',
          );

          // STEP 2: For each student, check their attendance in student_checkins
          for (var studentDoc in studentsQuery.docs) {
            final studentData = studentDoc.data();
            final rollNumber = studentData['rollNumber'] ?? 'Unknown';
            final studentName =
                studentData['name'] ?? studentData['studentName'] ?? 'Unknown';
            final studentEmail =
                studentData['email'] ?? studentData['studentEmail'] ?? '';

            print('🔍 Checking attendance for student: $rollNumber');

            // STEP 3: Check attendance records for this student
            bool hasAttendanceToday = false;
            Map<String, dynamic>? latestSession;
            int totalSessions = 0;
            int attendedSessions = 0;

            try {
              // Get ALL sessions for this student in this subject
              final allSessionsQuery =
                  await FirebaseFirestore.instance
                      .collection('student_checkins')
                      .doc(rollNumber)
                      .collection('sessions')
                      .where('subject', isEqualTo: widget.subject)
                      .get();

              totalSessions = allSessionsQuery.docs.length;
              attendedSessions =
                  allSessionsQuery.docs
                      .where(
                        (doc) =>
                            doc.data()['status'] == 'completed' ||
                            doc.data()['status'] == 'checked_in',
                      )
                      .length;

              // Check for today's attendance specifically
              final todaySessionsQuery =
                  await FirebaseFirestore.instance
                      .collection('student_checkins')
                      .doc(rollNumber)
                      .collection('sessions')
                      .where('subject', isEqualTo: widget.subject)
                      .where(
                        'date',
                        isEqualTo:
                            _selectedDate.toIso8601String().split('T')[0],
                      )
                      .get();

              if (todaySessionsQuery.docs.isNotEmpty) {
                hasAttendanceToday = true;
                latestSession = todaySessionsQuery.docs.first.data();
                print(
                  '✅ Found attendance record for $rollNumber in subject ${widget.subject} (Total: $totalSessions sessions, Attended: $attendedSessions)',
                );
              } else {
                print(
                  '❌ No attendance record found for $rollNumber in subject ${widget.subject} on ${_selectedDate.toIso8601String().split('T')[0]} (Total: $totalSessions sessions, Attended: $attendedSessions)',
                );
              }
            } catch (e) {
              print('⚠️ Error checking attendance for $rollNumber: $e');
            }

            // STEP 4: Create student record with attendance status
            final studentRecord = {
              'id': studentDoc.id,
              'rollNumber': rollNumber,
              'studentName': studentName,
              'studentEmail': studentEmail,
              'department': studentData['department'] ?? '',
              'groupId': finalGroupId,
              'groupName': groupName,
              'isEnrolled': true,
              'phone': studentData['phone'] ?? '',
              'year': studentData['year'] ?? '',
              'section': studentData['section'] ?? '',
              'admissionYear': studentData['admissionYear'] ?? '',
              'biometricRegistered':
                  studentData['biometricRegistered'] ?? false,
              'totalSessions': totalSessions,
              'attendedSessions': attendedSessions,
              'attendanceRate':
                  totalSessions > 0
                      ? ((attendedSessions / totalSessions) * 100).round()
                      : 0,
              'hasAttendanceToday': hasAttendanceToday,
              'latestSession': latestSession,
            };

            // STEP 5: Add to appropriate list based on attendance rate
            final attendanceRate =
                totalSessions > 0
                    ? ((attendedSessions / totalSessions) * 100).round()
                    : 0;
            String groupKey;

            if (attendanceRate >= 90) {
              groupKey = 'Excellent (90-100%)';
            } else if (attendanceRate >= 75) {
              groupKey = 'Good (75-89%)';
            } else if (attendanceRate >= 60) {
              groupKey = 'Average (60-74%)';
            } else if (attendanceRate >= 40) {
              groupKey = 'Below Average (40-59%)';
            } else {
              groupKey = 'Poor (0-39%)';
            }

            groupedStudents[groupKey]!.add(studentRecord);
            print(
              '✅ Added $rollNumber to $groupKey ($attendanceRate% attendance)',
            );
          }

          print('📊 Final count by attendance rate:');
          for (var entry in groupedStudents.entries) {
            if (entry.value.isNotEmpty) {
              print('   ${entry.key}: ${entry.value.length} students');
            }
          }
        } catch (e) {
          print(
            '❌ Error loading students from groups/$finalGroupId/students: $e',
          );
        }
      }

      _cachedStudentsData = groupedStudents;
      _studentsDataLoaded = true;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      return groupedStudents;
    } catch (e) {
      print('❌ Error in _loadAllStudentsInGroups: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // Return empty groups on error
      return {
        'Excellent (90-100%)': [],
        'Good (75-89%)': [],
        'Average (60-74%)': [],
        'Below Average (40-59%)': [],
        'Poor (0-39%)': [],
      };
    }
  }

  Widget _buildStudentsTab() {
    if (!_studentsDataLoaded) {
      return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _loadAllStudentsInGroups(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF1B5E20),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading students...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF1B5E20),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  SizedBox(height: 16),
                  Text(
                    'Error loading students',
                    style: TextStyle(fontSize: 18, color: Colors.red[600]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Cache the data and rebuild with the content
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _cachedStudentsData =
                  snapshot.data ??
                  {
                    'Excellent (90-100%)': [],
                    'Good (75-89%)': [],
                    'Average (60-74%)': [],
                    'Below Average (40-59%)': [],
                    'Poor (0-39%)': [],
                  };
              _studentsDataLoaded = true;
            });
          });

          return _buildStudentsContent(
            snapshot.data ??
                {
                  'Excellent (90-100%)': [],
                  'Good (75-89%)': [],
                  'Average (60-74%)': [],
                  'Below Average (40-59%)': [],
                  'Poor (0-39%)': [],
                },
          );
        },
      );
    }

    return _buildStudentsContent(_cachedStudentsData);
  }

  Widget _buildStudentsContent(
    Map<String, List<Map<String, dynamic>>> groupedStudents,
  ) {
    // Get non-empty groups for tabs
    final nonEmptyGroups =
        groupedStudents.entries
            .where((entry) => entry.value.isNotEmpty)
            .toList();

    if (nonEmptyGroups.isEmpty) {
      return Center(
        child: Container(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                'No Students Found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'No students have attendance records yet.',
                style: TextStyle(color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: nonEmptyGroups.length,
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey[50]!],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: TabBar(
              isScrollable: true,
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Color(0xFF1B5E20),
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              tabs:
                  nonEmptyGroups.map((entry) {
                    IconData icon;

                    if (entry.key.contains('90-100')) {
                      icon = Icons.star;
                    } else if (entry.key.contains('75-89')) {
                      icon = Icons.thumb_up;
                    } else if (entry.key.contains('60-74')) {
                      icon = Icons.trending_up;
                    } else if (entry.key.contains('40-59')) {
                      icon = Icons.trending_down;
                    } else {
                      icon = Icons.warning;
                    }

                    return Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 16),
                          SizedBox(height: 4),
                          Text(
                            '${entry.key.split(' ')[0]}\n(${_filterStudents(entry.value).length})',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          ),
          // Search Bar
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search students by name, roll number, or email...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                prefixIcon: Icon(
                  Icons.search,
                  color: Color(0xFF1B5E20),
                  size: 20,
                ),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                          onPressed: _clearSearch,
                        )
                        : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: TextStyle(fontSize: 14),
            ),
          ),
          Expanded(
            child: TabBarView(
              children:
                  nonEmptyGroups.map((entry) {
                    return _buildEnhancedStudentsList(
                      _filterStudents(entry.value),
                      true, // All students are enrolled
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedStudentsList(
    List<Map<String, dynamic>> students,
    bool isEnrolled,
  ) {
    if (students.isEmpty) {
      return Center(
        child: Container(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors:
                        isEnrolled
                            ? [
                              Color(0xFF1B5E20).withOpacity(0.1),
                              Color(0xFF2E7D32).withOpacity(0.1),
                            ]
                            : [
                              Color(0xFFD32F2F).withOpacity(0.1),
                              Color(0xFFC62828).withOpacity(0.1),
                            ],
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(
                  isEnrolled ? Icons.people_outline : Icons.warning_outlined,
                  size: 64,
                  color: isEnrolled ? Color(0xFF1B5E20) : Color(0xFFD32F2F),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'No ${isEnrolled ? 'enrolled' : 'absentee'} students',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12),
              Text(
                isEnrolled
                    ? 'No students enrolled in any groups for this subject'
                    : 'No absentee records found',
                style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        final rollNumber = student['rollNumber'] ?? 'Unknown';
        final studentName = student['studentName'] ?? 'Unknown';
        final department = student['department'] ?? '';
        final groupName = student['groupName'] ?? 'Unknown Group';
        final totalSessions = student['totalSessions'] ?? 0;
        final attendedSessions = student['attendedSessions'] ?? 0;
        final attendanceRate = student['attendanceRate'] ?? 0;

        return Container(
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey[50]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.all(20),
              childrenPadding: EdgeInsets.only(left: 20, right: 20, bottom: 20),
              leading: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors:
                        isEnrolled
                            ? [Color(0xFF1B5E20), Color(0xFF2E7D32)]
                            : [Color(0xFFD32F2F), Color(0xFFC62828)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (isEnrolled
                              ? Color(0xFF1B5E20)
                              : Color(0xFFD32F2F))
                          .withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(Icons.person, color: Colors.white, size: 30),
              ),
              title: Text(
                studentName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.badge_outlined,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Roll: $rollNumber',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.group_outlined,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          groupName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (department.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            department,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: attendanceRate >= 75
                              ? Color(0xFF2E7D32).withOpacity(0.1)
                              : attendanceRate >= 50
                              ? Color(0xFFE65100).withOpacity(0.1)
                              : Color(0xFFD32F2F).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$attendanceRate%',
                          style: TextStyle(
                            color: attendanceRate >= 75
                                ? Color(0xFF2E7D32)
                                : attendanceRate >= 50
                                ? Color(0xFFE65100)
                                : Color(0xFFD32F2F),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        '$attendedSessions/$totalSessions sessions',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildStudentDetailRow('Roll Number', rollNumber),
                      _buildStudentDetailRow('Name', studentName),
                      if (student['studentEmail']?.toString().isNotEmpty ==
                          true)
                        _buildStudentDetailRow(
                          'Email',
                          student['studentEmail'],
                        ),
                      if (department.isNotEmpty)
                        _buildStudentDetailRow('Department', department),
                      _buildStudentDetailRow('Group', groupName),
                      if (student['year']?.toString().isNotEmpty == true)
                        _buildStudentDetailRow('Year', student['year']),
                      if (student['section']?.toString().isNotEmpty == true)
                        _buildStudentDetailRow('Section', student['section']),
                      if (student['phone']?.toString().isNotEmpty == true)
                        _buildStudentDetailRow('Phone', student['phone']),
                      SizedBox(height: 16),
                      Text(
                        'Attendance Summary for ${widget.subject}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAttendanceStatCard(
                              'Total Sessions',
                              totalSessions.toString(),
                              Icons.assignment_outlined,
                              Color(0xFF1976D2),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildAttendanceStatCard(
                              'Attended',
                              attendedSessions.toString(),
                              Icons.check_circle_outline,
                              Color(0xFF2E7D32),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildAttendanceStatCard(
                              'Rate',
                              '$attendanceRate%',
                              Icons.trending_up,
                              attendanceRate >= 75
                                  ? Color(0xFF2E7D32)
                                  : attendanceRate >= 50
                                  ? Color(0xFFE65100)
                                  : Color(0xFFD32F2F),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentDetailRow(String label, dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  // Search functionality methods
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }

  List<Map<String, dynamic>> _filterStudents(
    List<Map<String, dynamic>> students,
  ) {
    if (_searchQuery.isEmpty) {
      return students;
    }

    return students.where((student) {
      final name = (student['name'] ?? '').toString().toLowerCase();
      final rollNumber = (student['rollNumber'] ?? '').toString().toLowerCase();
      final email = (student['email'] ?? '').toString().toLowerCase();
      final department = (student['department'] ?? '').toString().toLowerCase();

      return name.contains(_searchQuery) ||
          rollNumber.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          department.contains(_searchQuery);
    }).toList();
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
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
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

// Test data creator for debugging
class TestDataCreator {
  static Future<void> createTestAttendanceData() async {
    print('🧪 Creating test attendance data...');

    final db = FirebaseFirestore.instance;
    final now = DateTime.now();

    // Test students from the group
    final testStudents = [
      {
        'rollNumber': '23CSR071',
        'name': 'Test Student 1',
        'email': 'student1@test.com',
      },
      {
        'rollNumber': '23CSR112',
        'name': 'Test Student 2',
        'email': 'student2@test.com',
      },
      {
        'rollNumber': '23EEE029',
        'name': 'Test Student 3',
        'email': 'student3@test.com',
      },
    ];

    try {
      for (final student in testStudents) {
        // Create multiple sessions for each student (simulating attendance over different days)
        for (int dayOffset = 0; dayOffset < 3; dayOffset++) {
          final sessionDate = now.subtract(Duration(days: dayOffset));
          final sessionId =
              'test_session_${sessionDate.millisecondsSinceEpoch}_${student['rollNumber']}';

          // Simulate some students missing some sessions
          bool shouldCreateSession = true;
          if (dayOffset == 1 && student['rollNumber'] == '23CSR071') {
            shouldCreateSession = false; // 23CSR071 missed day 1
          }
          if (dayOffset == 2 && student['rollNumber'] == '23EEE029') {
            shouldCreateSession = false; // 23EEE029 missed day 2
          }

          if (shouldCreateSession) {
            // Create attendance data following the markattendance.dart structure
            await db
                .collection('student_checkins')
                .doc(student['rollNumber'])
                .collection('sessions')
                .doc(sessionId)
                .set({
                  'student': {
                    'rollNumber': student['rollNumber'],
                    'name': student['name'],
                    'email': student['email'],
                    'department': 'CSE',
                    'groupId': 'kcVkbB1SIcZf6UrYny8N',
                    'groupName': 'III-CSE-B',
                  },
                  'campus': 'Main Campus',
                  'day': _getDayOfWeek(sessionDate.weekday),
                  'date': sessionDate.toIso8601String().split('T')[0],
                  'period': 3,
                  'subject': 'IOT LAB B1/ CN LAB B2',
                  'roomOrLocation': 'Lab 201',
                  'checkInAt': Timestamp.fromDate(
                    sessionDate.subtract(Duration(minutes: 30)),
                  ),
                  'expectedEndAt': Timestamp.fromDate(
                    sessionDate.add(Duration(hours: 1)),
                  ),
                  'checkInLat': 12.9716,
                  'checkInLng': 77.5946,
                  'status':
                      'completed', // Mark as completed for historical sessions
                  'logs': [
                    'Test attendance data created for debugging - Day $dayOffset',
                  ],
                  'createdAt': Timestamp.fromDate(sessionDate),
                });

            print(
              '✅ Created test attendance for ${student['rollNumber']} on ${sessionDate.toIso8601String().split('T')[0]}',
            );
          } else {
            print(
              '❌ Skipped session for ${student['rollNumber']} on ${sessionDate.toIso8601String().split('T')[0]} (simulating absence)',
            );
          }
        }
      }

      print(
        '🎉 Test attendance data created successfully with multiple sessions!',
      );
      print('📱 Refresh the attendance view to see the test data');
    } catch (e) {
      print('❌ Error creating test data: $e');
    }
  }

  static String _getDayOfWeek(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }
}