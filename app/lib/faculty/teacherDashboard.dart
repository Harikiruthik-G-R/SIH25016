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

  const TeacherDashboard({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.teacherEmail,
    required this.subjects,
    required this.department,
    required this.designation,
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
      builder: (context) => StudentDetailsDialog(record: record),
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

  Widget _buildStudentsTab() {
    // Group students by enrollment status
    Map<String, List<Map<String, dynamic>>> groupedStudents = {
      'Enrolled': [],
      'Absentees': [],
    };

    for (var record in _attendanceRecords) {
      if (record['isEnrolled'] == true) {
        groupedStudents['Enrolled']!.add(record);
      } else {
        groupedStudents['Absentees']!.add(record);
      }
    }

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
                      Text('Enrolled (${groupedStudents['Enrolled']!.length})'),
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
                        'Absentees (${groupedStudents['Absentees']!.length})',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildEnhancedStudentsList(groupedStudents['Enrolled']!, true),
                _buildEnhancedStudentsList(
                  groupedStudents['Absentees']!,
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
                    ? 'All students are properly enrolled'
                    : 'No absentee records found',
                style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Group by student (roll number)
    Map<String, List<Map<String, dynamic>>> studentSessions = {};
    for (var record in students) {
      final rollNumber = record['rollNumber'];
      if (!studentSessions.containsKey(rollNumber)) {
        studentSessions[rollNumber] = [];
      }
      studentSessions[rollNumber]!.add(record);
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: studentSessions.length,
      itemBuilder: (context, index) {
        final rollNumber = studentSessions.keys.elementAt(index);
        final sessions = studentSessions[rollNumber]!;
        final studentData = sessions.first;
        final sessionCount = sessions.length;
        final completedSessions =
            sessions.where((s) => s['status'] == 'completed').length;
        final attendanceRate =
            sessionCount > 0
                ? (completedSessions / sessionCount * 100).round()
                : 0;

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
                width: 56,
                height: 56,
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
                child: Center(
                  child: Text(
                    rollNumber.length >= 2
                        ? rollNumber.substring(rollNumber.length - 2)
                        : rollNumber,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              title: Text(
                studentData['studentName'] ?? 'Unknown',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.grey[800],
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFF1976D2).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$completedSessions/$sessionCount sessions',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1976D2),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              attendanceRate >= 80
                                  ? Color(0xFF2E7D32).withOpacity(0.1)
                                  : attendanceRate >= 60
                                  ? Color(0xFFE65100).withOpacity(0.1)
                                  : Color(0xFFD32F2F).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$attendanceRate% rate',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                attendanceRate >= 80
                                    ? Color(0xFF2E7D32)
                                    : attendanceRate >= 60
                                    ? Color(0xFFE65100)
                                    : Color(0xFFD32F2F),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              children:
                  sessions.map((session) {
                    final sessionDate =
                        session['date'] != null
                            ? (session['date'] as Timestamp).toDate()
                            : null;
                    final isCompleted = session['status'] == 'completed';

                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isCompleted
                                  ? Color(0xFF2E7D32).withOpacity(0.3)
                                  : Color(0xFFE65100).withOpacity(0.3),
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showStudentDetails(session),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    isCompleted
                                        ? Color(0xFF2E7D32).withOpacity(0.1)
                                        : Color(0xFFE65100).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isCompleted
                                    ? Icons.check_circle
                                    : Icons.schedule,
                                color:
                                    isCompleted
                                        ? Color(0xFF2E7D32)
                                        : Color(0xFFE65100),
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sessionDate != null
                                        ? _formatDate(sessionDate)
                                        : 'Unknown Date',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '${session['roomOrLocation'] ?? 'Unknown Location'} • Period ${session['period'] ?? 'N/A'}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (session['durationMinutes'] != null)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${session['durationMinutes'].toInt()}min',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        );
      },
    );
  }
} // End of _SubjectAttendanceScreenState class

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
}

// Student Details Dialog
class StudentDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> record;

  const StudentDetailsDialog({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final checkInTime =
        record['checkInAt'] != null
            ? (record['checkInAt'] as Timestamp).toDate()
            : null;
    final checkOutTime =
        record['checkOutAt'] != null
            ? (record['checkOutAt'] as Timestamp).toDate()
            : null;
    final expectedEndTime =
        record['expectedEndAt'] != null
            ? (record['expectedEndAt'] as Timestamp).toDate()
            : null;

    final isEnrolled = record['isEnrolled'] == true;
    final isCompleted = record['status'] == 'completed';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 500,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Enhanced Header
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors:
                      isEnrolled
                          ? [Color(0xFF1B5E20), Color(0xFF2E7D32)]
                          : [Color(0xFFD32F2F), Color(0xFFC62828)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isEnrolled ? Color(0xFF1B5E20) : Color(0xFFD32F2F))
                        .withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
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
                          isEnrolled ? Icons.verified_user : Icons.warning,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record['studentName'] ?? 'Unknown Student',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Roll: ${record['rollNumber']}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isEnrolled ? 'ENROLLED' : 'ABSENTEE',
                                    style: TextStyle(
                                      color:
                                          isEnrolled
                                              ? Color(0xFF1B5E20)
                                              : Color(0xFFD32F2F),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Quick Status Bar
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildQuickStat(
                            Icons.assignment,
                            'Session',
                            record['subject'] ?? 'N/A',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        Expanded(
                          child: _buildQuickStat(
                            Icons.location_on,
                            'Location',
                            record['roomOrLocation'] ?? 'N/A',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        Expanded(
                          child: _buildQuickStat(
                            Icons.schedule,
                            'Status',
                            record['status']?.toUpperCase() ?? 'N/A',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Enhanced Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEnhancedDetailSection(
                      'Student Information',
                      Icons.person,
                      Color(0xFF1976D2),
                      [
                        _buildEnhancedDetailRow(
                          'Email',
                          record['studentEmail'],
                        ),
                        _buildEnhancedDetailRow(
                          'Department',
                          record['department'],
                        ),
                        _buildEnhancedDetailRow('Group', record['groupName']),
                        _buildEnhancedDetailRow('Campus', record['campus']),
                      ],
                    ),

                    _buildEnhancedDetailSection(
                      'Session Information',
                      Icons.class_,
                      Color(0xFF2E7D32),
                      [
                        _buildEnhancedDetailRow(
                          'Session ID',
                          record['sessionId'],
                        ),
                        _buildEnhancedDetailRow('Subject', record['subject']),
                        _buildEnhancedDetailRow(
                          'Period',
                          '${record['period'] ?? 'N/A'}',
                        ),
                        _buildEnhancedDetailRow('Day', record['day']),
                      ],
                    ),

                    _buildEnhancedDetailSection(
                      'Timing Information',
                      Icons.access_time,
                      Color(0xFFE65100),
                      [
                        _buildEnhancedDetailRow(
                          'Check-in Time',
                          checkInTime != null
                              ? _formatDateTime(checkInTime)
                              : 'N/A',
                        ),
                        _buildEnhancedDetailRow(
                          'Check-out Time',
                          checkOutTime != null
                              ? _formatDateTime(checkOutTime)
                              : 'N/A',
                        ),
                        _buildEnhancedDetailRow(
                          'Expected End',
                          expectedEndTime != null
                              ? _formatDateTime(expectedEndTime)
                              : 'N/A',
                        ),
                        _buildEnhancedDetailRow(
                          'Duration',
                          record['durationMinutes'] != null
                              ? '${record['durationMinutes'].toInt()} minutes'
                              : 'N/A',
                        ),
                        if (record['closeReason'] != null)
                          _buildEnhancedDetailRow(
                            'Close Reason',
                            record['closeReason'],
                          ),
                      ],
                    ),

                    if (record['checkInLat'] != null &&
                        record['checkInLng'] != null)
                      _buildEnhancedDetailSection(
                        'Location Information',
                        Icons.location_on,
                        Color(0xFF7B1FA2),
                        [
                          _buildEnhancedDetailRow(
                            'Check-in Coordinates',
                            '${record['checkInLat']?.toStringAsFixed(6)}, ${record['checkInLng']?.toStringAsFixed(6)}',
                          ),
                          if (record['checkOutLat'] != null &&
                              record['checkOutLng'] != null)
                            _buildEnhancedDetailRow(
                              'Check-out Coordinates',
                              '${record['checkOutLat']?.toStringAsFixed(6)}, ${record['checkOutLng']?.toStringAsFixed(6)}',
                            ),
                        ],
                      ),

                    if (record['logs'] != null &&
                        (record['logs'] as List).isNotEmpty)
                      _buildEnhancedDetailSection(
                        'Activity Logs',
                        Icons.list_alt,
                        Color(0xFF455A64),
                        [
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF455A64).withOpacity(0.05),
                                  Color(0xFF455A64).withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Color(0xFF455A64).withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.terminal,
                                      size: 20,
                                      color: Color(0xFF455A64),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'System Logs',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF455A64),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children:
                                        (record['logs'] as List)
                                            .map<Widget>(
                                              (log) => Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 2,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      margin: EdgeInsets.only(
                                                        top: 6,
                                                      ),
                                                      width: 6,
                                                      height: 6,
                                                      decoration: BoxDecoration(
                                                        color: Color(
                                                          0xFF455A64,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              3,
                                                            ),
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        log.toString(),
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontFamily:
                                                              'monospace',
                                                          color:
                                                              Colors.grey[700],
                                                          height: 1.4,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                            .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // Enhanced Footer
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          isCompleted
                              ? Color(0xFF2E7D32).withOpacity(0.1)
                              : Color(0xFFE65100).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isCompleted ? Icons.check_circle : Icons.schedule,
                      color:
                          isCompleted ? Color(0xFF2E7D32) : Color(0xFFE65100),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCompleted ? 'Session Completed' : 'Session Ongoing',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (record['durationMinutes'] != null)
                          Text(
                            'Duration: ${record['durationMinutes'].toInt()} minutes',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Details View',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
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

  Widget _buildQuickStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2),
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

  Widget _buildEnhancedDetailSection(
    String title,
    IconData icon,
    Color accentColor,
    List<Widget> children,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor, accentColor.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withOpacity(0.1)),
              ),
              child: Column(children: children),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedDetailRow(String label, String? value) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    value?.isNotEmpty == true
                        ? Colors.grey[50]
                        : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value ?? 'N/A',
                style: TextStyle(
                  color:
                      value?.isNotEmpty == true
                          ? Colors.black87
                          : Colors.grey[500],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
