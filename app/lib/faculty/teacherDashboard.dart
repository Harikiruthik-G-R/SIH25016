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
      final schedule = data['schedule'] as Map<String, dynamic>?;
      final groupName = data['groupName'] ?? 'Unknown Group';
      final groupId = doc.id;

      if (schedule != null) {
        // Search through the schedule for teacher's subjects
        for (var daySchedule in schedule.values) {
          if (daySchedule is Map<String, dynamic>) {
            for (var periodData in daySchedule.values) {
              if (periodData is Map<String, dynamic>) {
                final subject = periodData['subject'] as String?;

                if (subject != null && widget.subjects.contains(subject)) {
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
                  }
                }
              }
            }
          }
        }
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
  Map<String, List<String>> _groupStudents = {};
  Map<String, int> _attendanceStats = {};
  String _selectedGroupFilter = 'All Groups';
  String _selectedStatusFilter = 'All Status';

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Cached students data to avoid reloading on search
  Map<String, List<Map<String, dynamic>>> _cachedStudentsData = {
    'Enrolled': [],
    'Absentees': [],
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
      await Future.wait([_loadGroupStudents(), _loadAttendanceForDate()]);
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

      for (var group in widget.groups) {
        final groupId = group['groupId'];
        final groupName = group['groupName'] ?? 'Unknown Group';

        // Try to get students from groups collection
        final studentsQuery =
            await FirebaseFirestore.instance
                .collection('groups')
                .doc(groupId)
                .collection('students')
                .get();

        List<String> students = [];
        for (var doc in studentsQuery.docs) {
          // The document ID is the roll number
          students.add(doc.id);

          // Also check if there's student data in the document
          final studentData = doc.data();
          if (studentData.containsKey('rollNumber')) {
            students.add(studentData['rollNumber'].toString());
          }
        }

        // If no students found in subcollection, try to get from group document itself
        if (students.isEmpty) {
          final groupDoc =
              await FirebaseFirestore.instance
                  .collection('groups')
                  .doc(groupId)
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

        // Remove duplicates and store
        students = students.toSet().toList();
        _groupStudents[groupName] = students;

        if (mounted) {
          print(
            'Loaded ${students.length} students for group $groupName: $students',
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

      // Get all student check-ins from student_checkins collection
      final checkinsQuery =
          await FirebaseFirestore.instance.collection('student_checkins').get();

      for (var studentDoc in checkinsQuery.docs) {
        final rollNumber = studentDoc.id;

        // Get all sessions for this student
        final sessionsQuery =
            await studentDoc.reference.collection('sessions').get();

        for (var sessionDoc in sessionsQuery.docs) {
          final sessionData = sessionDoc.data();
          final studentData = sessionData['student'] as Map<String, dynamic>?;
          final sessionSubject = sessionData['subject']?.toString() ?? '';
          final sessionDate = sessionData['date'] as Timestamp?;

          // Filter by subject and date
          if (sessionSubject == widget.subject && sessionDate != null) {
            final sessionDateTime = sessionDate.toDate();
            final isInDateRange =
                _selectedDateRange == null ||
                (sessionDateTime.isAfter(
                      _selectedDateRange!.start.subtract(Duration(days: 1)),
                    ) &&
                    sessionDateTime.isBefore(
                      _selectedDateRange!.end.add(Duration(days: 1)),
                    ));

            final isInSelectedDate =
                sessionDateTime.year == _selectedDate.year &&
                sessionDateTime.month == _selectedDate.month &&
                sessionDateTime.day == _selectedDate.day;

            if (_selectedDateRange != null ? isInDateRange : isInSelectedDate) {
              // Get group information from the student data (stored in session)
              final groupId = studentData?['groupId']?.toString() ?? '';
              final groupName =
                  studentData?['groupName']?.toString() ?? 'Unknown Group';

              // Verify if student is enrolled in any group for this subject
              bool isEnrolled = false;

              // Check against the specific group from the session data
              if (_groupStudents.containsKey(groupName)) {
                isEnrolled = _groupStudents[groupName]!.contains(rollNumber);
              }

              // If not found in session group, check all groups as fallback
              if (!isEnrolled) {
                for (var groupStudentsList in _groupStudents.values) {
                  if (groupStudentsList.contains(rollNumber)) {
                    isEnrolled = true;
                    break;
                  }
                }
              }

              // Calculate session duration if completed
              double? durationMinutes;
              if (sessionData['durationMinutes'] != null) {
                durationMinutes =
                    (sessionData['durationMinutes'] as num).toDouble();
              } else if (sessionData['checkInAt'] != null &&
                  sessionData['checkOutAt'] != null) {
                final checkIn =
                    (sessionData['checkInAt'] as Timestamp).toDate();
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

              records.add({
                'sessionId': sessionDoc.id,
                'rollNumber': rollNumber,
                'studentName': studentData?['name'] ?? 'Unknown',
                'studentEmail': studentData?['email'] ?? '',
                'department': studentData?['department'] ?? '',
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
                'isEnrolled': isEnrolled,
                'day': dayName,
              });
            }
          }
        }
      }

      // Apply filters
      records = _applyFilters(records);

      setState(() => _attendanceRecords = records);
    } catch (e) {
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.subject,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Statistics Dashboard',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
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
                        '${_attendanceRecords.length} records',
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
                      ['All Status', 'Present', 'Ongoing', 'Absentees'],
                      (value) => setState(() {
                        _selectedStatusFilter = value ?? 'All Status';
                        _attendanceRecords = _applyFilters(_attendanceRecords);
                        _calculateStats();
                      }),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Enhanced Attendance List
        Expanded(
          child:
              _attendanceRecords.isEmpty
                  ? _buildEnhancedEmptyState()
                  : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _attendanceRecords.length,
                    itemBuilder: (context, index) {
                      final record = _attendanceRecords[index];
                      return AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        child: _buildEnhancedAttendanceCard(record, index),
                      );
                    },
                  ),
        ),
      ],
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

  Widget _buildEnhancedStatsCards() {
    final stats = [
      {
        'title': 'Total Sessions',
        'value': '${_attendanceStats['totalSessions'] ?? 0}',
        'icon': Icons.assignment_outlined,
        'color': Color(0xFF1976D2),
        'gradient': [Color(0xFF1976D2), Color(0xFF1565C0)],
      },
      {
        'title': 'Completed',
        'value': '${_attendanceStats['completedSessions'] ?? 0}',
        'icon': Icons.check_circle_outline,
        'color': Color(0xFF2E7D32),
        'gradient': [Color(0xFF2E7D32), Color(0xFF1B5E20)],
      },
      {
        'title': 'Ongoing',
        'value': '${_attendanceStats['ongoingSessions'] ?? 0}',
        'icon': Icons.schedule_outlined,
        'color': Color(0xFFE65100),
        'gradient': [Color(0xFFE65100), Color(0xFFBF360C)],
      },
      {
        'title': 'Absentees',
        'value': '${_attendanceStats['absenteeStudents'] ?? 0}',
        'icon': Icons.person_off_outlined,
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
                  child: Icon(Icons.trending_up, color: Colors.white, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance Trends',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      Text(
                        'Visual analytics coming soon',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1B5E20).withOpacity(0.1),
                    Color(0xFF2E7D32).withOpacity(0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Color(0xFF1B5E20).withOpacity(0.2)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFF1B5E20).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        Icons.analytics,
                        size: 48,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Interactive Charts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Coming Soon',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedGroupWiseStats() {
    Map<String, Map<String, int>> groupStats = {};

    for (var record in _attendanceRecords) {
      final groupName = record['groupName'] ?? 'Unknown';
      if (!groupStats.containsKey(groupName)) {
        groupStats[groupName] = {'present': 0, 'total': 0};
      }
      groupStats[groupName]!['total'] =
          (groupStats[groupName]!['total'] ?? 0) + 1;
      if (record['status'] == 'completed') {
        groupStats[groupName]!['present'] =
            (groupStats[groupName]!['present'] ?? 0) + 1;
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
                final total = stats['total'] ?? 0;
                final present = stats['present'] ?? 0;
                final percentage =
                    total > 0 ? (present / total * 100).round() : 0;

                Color performanceColor =
                    percentage >= 80
                        ? Color(0xFF2E7D32)
                        : percentage >= 60
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
                                  '$total total sessions',
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  percentage >= 80
                                      ? Icons.trending_up
                                      : percentage >= 60
                                      ? Icons.trending_flat
                                      : Icons.trending_down,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '$present/$total',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Attendance Rate',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '$percentage%',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: performanceColor,
                                        fontWeight: FontWeight.bold,
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
                                    widthFactor:
                                        total > 0 ? present / total : 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            performanceColor,
                                            performanceColor.withOpacity(0.8),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
        'Enrolled': [],
        'Absentees': [],
      };

      // Get groups passed from the parent widget
      List<Map<String, dynamic>> teacherGroups = widget.groups;

      print('🔍 Loading students for ${teacherGroups.length} groups...');

      // Debug: List all available groups in Firestore
      try {
        final allGroupsQuery =
            await FirebaseFirestore.instance.collection('groups').get();
        print('🏫 Available groups in Firestore:');
        for (var doc in allGroupsQuery.docs) {
          print('   - ${doc.id}: ${doc.data()['name'] ?? 'Unknown Name'}');
        }
      } catch (e) {
        print('❌ Error fetching all groups: $e');
      }

      for (var group in teacherGroups) {
        final groupName = group['groupName'] ?? 'Unknown Group';
        final originalGroupId = group['groupId'];

        print('📚 Processing group: $groupName');
        print('🔑 Original Group ID: "$originalGroupId"');
        print('📋 Full group data: $group');

        // Find the correct group ID by querying with group name
        String? correctGroupId;
        try {
          final allGroupsQuery =
              await FirebaseFirestore.instance.collection('groups').get();
          for (var doc in allGroupsQuery.docs) {
            final groupData = doc.data();
            if (groupData['name'] == groupName) {
              correctGroupId = doc.id;
              print(
                '✅ Found correct group ID: $correctGroupId for group name: $groupName',
              );
              break;
            }
          }
        } catch (e) {
          print('❌ Error finding correct group ID: $e');
        }

        if (correctGroupId == null) {
          print('⚠️ Could not find correct group ID for group: $groupName');
          continue;
        }

        // Try to get students from groups collection (students subcollection)
        try {
          print(
            '🔎 Querying students subcollection for group $correctGroupId...',
          );

          final studentsQuery =
              await FirebaseFirestore.instance
                  .collection('groups')
                  .doc(correctGroupId)
                  .collection('students')
                  .get();

          print(
            '📊 Students query result: ${studentsQuery.docs.length} documents found',
          );

          if (studentsQuery.docs.isEmpty) {
            print('⚠️ No students found in subcollection for group $groupName');
          } else {
            print('📋 Processing ${studentsQuery.docs.length} students...');
          }

          for (var studentDoc in studentsQuery.docs) {
            final studentData = studentDoc.data();
            final studentId = studentDoc.id; // Auto-generated document ID
            final rollNumber = studentData['rollNumber'] ?? 'Unknown';

            print(
              '👤 Processing student: ID=$studentId, Roll=$rollNumber, Name=${studentData['name'] ?? 'Unknown'}',
            );

            // Create student record with group information
            final studentRecord = {
              'id': studentId,
              'rollNumber': rollNumber,
              'studentName':
                  studentData['name'] ??
                  studentData['studentName'] ??
                  'Unknown',
              'studentEmail':
                  studentData['email'] ?? studentData['studentEmail'] ?? '',
              'department': studentData['department'] ?? '',
              'groupId': correctGroupId,
              'groupName': groupName,
              'isEnrolled': true,
              'phone': studentData['phone'] ?? '',
              'year': studentData['year'] ?? '',
              'section': studentData['section'] ?? '',
              'admissionYear': studentData['admissionYear'] ?? '',
              'biometricRegistered':
                  studentData['biometricRegistered'] ?? false,
              'createdAt': studentData['createdAt'],
              // Add attendance statistics (will be calculated later if needed)
              'totalSessions': 0,
              'attendedSessions': 0,
              'attendanceRate': 0,
            };

            groupedStudents['Enrolled']!.add(studentRecord);
          }

          print(
            '✅ Found ${studentsQuery.docs.length} students in subcollection for group $groupName',
          );
        } catch (e) {
          print(
            '⚠️ Error accessing students subcollection for group $correctGroupId: $e',
          );
        }

        // If no students found in subcollection, try to get from group document itself
        if (groupedStudents['Enrolled']!
            .where((s) => s['groupId'] == correctGroupId)
            .isEmpty) {
          try {
            final groupDoc =
                await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(correctGroupId)
                    .get();

            if (groupDoc.exists) {
              final groupData = groupDoc.data();
              if (groupData != null && groupData.containsKey('students')) {
                final groupStudents = groupData['students'];
                if (groupStudents is List) {
                  for (var student in groupStudents) {
                    String rollNumber = '';
                    String studentName = 'Unknown';
                    String studentEmail = '';
                    String department = '';

                    if (student is String) {
                      // Student is just a roll number string
                      rollNumber = student;
                    } else if (student is Map<String, dynamic>) {
                      // Student is an object with details
                      rollNumber =
                          student['rollNumber']?.toString() ??
                          student['roll']?.toString() ??
                          student['id']?.toString() ??
                          '';
                      studentName =
                          student['name']?.toString() ??
                          student['studentName']?.toString() ??
                          'Unknown';
                      studentEmail =
                          student['email']?.toString() ??
                          student['studentEmail']?.toString() ??
                          '';
                      department = student['department']?.toString() ?? '';
                    }

                    if (rollNumber.isNotEmpty) {
                      final studentRecord = {
                        'rollNumber': rollNumber,
                        'studentName': studentName,
                        'studentEmail': studentEmail,
                        'department': department,
                        'groupId': correctGroupId,
                        'groupName': groupName,
                        'isEnrolled': true,
                        'phone': '',
                        'year': '',
                        'section': '',
                        'admissionYear': '',
                        'totalSessions': 0,
                        'attendedSessions': 0,
                        'attendanceRate': 0,
                      };

                      groupedStudents['Enrolled']!.add(studentRecord);
                    }
                  }
                }
              }
            }
            print(
              '✅ Found ${groupedStudents['Enrolled']!.where((s) => s['groupId'] == correctGroupId).length} students in group document for $groupName',
            );
          } catch (e) {
            print('⚠️ Error accessing group document for $correctGroupId: $e');
          }
        }
      }

      // Calculate attendance statistics for enrolled students
      await _calculateStudentAttendanceStats(groupedStudents['Enrolled']!);

      // Add absentees from attendance records (students who attended but are not in any group)
      for (var record in _attendanceRecords) {
        if (record['isEnrolled'] == false) {
          // Check if this student is already in the absentees list
          bool alreadyExists = groupedStudents['Absentees']!.any(
            (student) => student['rollNumber'] == record['rollNumber'],
          );

          if (!alreadyExists) {
            groupedStudents['Absentees']!.add({
              'rollNumber': record['rollNumber'],
              'studentName': record['studentName'] ?? 'Unknown',
              'studentEmail': record['studentEmail'] ?? '',
              'department': record['department'] ?? '',
              'groupId': record['groupId'] ?? '',
              'groupName': record['groupName'] ?? 'Unknown Group',
              'isEnrolled': false,
              'phone': '',
              'year': '',
              'section': '',
              'admissionYear': '',
              'totalSessions': 1,
              'attendedSessions': record['status'] == 'completed' ? 1 : 0,
              'attendanceRate': record['status'] == 'completed' ? 100 : 0,
            });
          }
        }
      }

      print(
        '📊 Final count - Enrolled: ${groupedStudents['Enrolled']!.length}, Absentees: ${groupedStudents['Absentees']!.length}',
      );

      return groupedStudents;
    } catch (e) {
      print('❌ Error loading all students: $e');
      throw Exception('Failed to load students: $e');
    }
  }

  Future<void> _calculateStudentAttendanceStats(
    List<Map<String, dynamic>> students,
  ) async {
    try {
      for (var student in students) {
        final rollNumber = student['rollNumber'];
        int totalSessions = 0;
        int attendedSessions = 0;

        // Count attendance sessions for this student in the current subject
        for (var record in _attendanceRecords) {
          if (record['rollNumber'] == rollNumber &&
              record['subject'] == widget.subject) {
            totalSessions++;
            if (record['status'] == 'completed') {
              attendedSessions++;
            }
          }
        }

        // Update student record with attendance stats
        student['totalSessions'] = totalSessions;
        student['attendedSessions'] = attendedSessions;
        student['attendanceRate'] =
            totalSessions > 0
                ? ((attendedSessions / totalSessions) * 100).round()
                : 0;
      }
    } catch (e) {
      print('⚠️ Error calculating attendance stats: $e');
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
                  snapshot.data ?? {'Enrolled': [], 'Absentees': []};
              _studentsDataLoaded = true;
            });
          });

          return _buildStudentsContent(
            snapshot.data ?? {'Enrolled': [], 'Absentees': []},
          );
        },
      );
    }

    return _buildStudentsContent(_cachedStudentsData);
  }

  Widget _buildStudentsContent(
    Map<String, List<Map<String, dynamic>>> groupedStudents,
  ) {
    return DefaultTabController(
      length: 2,
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
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Color(0xFF1B5E20),
              labelStyle: TextStyle(fontWeight: FontWeight.bold),
              unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
              tabs: [
                Container(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Enrolled (${_filterStudents(groupedStudents['Enrolled']!).length})',
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Absentees (${_filterStudents(groupedStudents['Absentees']!).length})',
                      ),
                    ],
                  ),
                ),
              ],
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
              children: [
                _buildEnhancedStudentsList(
                  _filterStudents(groupedStudents['Enrolled']!),
                  true,
                ),
                _buildEnhancedStudentsList(
                  _filterStudents(groupedStudents['Absentees']!),
                  false,
                ),
              ],
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
                          gradient: LinearGradient(
                            colors:
                                attendanceRate >= 75
                                    ? [Color(0xFF2E7D32), Color(0xFF1B5E20)]
                                    : attendanceRate >= 50
                                    ? [Color(0xFFE65100), Color(0xFFBF360C)]
                                    : [Color(0xFFD32F2F), Color(0xFFC62828)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$attendanceRate%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
}
