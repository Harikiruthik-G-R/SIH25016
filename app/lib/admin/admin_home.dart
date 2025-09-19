import 'package:GeoAt/sessionmanager.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import 'statistics_screen.dart';
import 'groups.dart';
import 'addusers.dart';
import 'coordinates.dart';
import 'active_users.dart';
import 'timetable_screen.dart';
import 'teachers_screen.dart';
import 'onduty.dart';

class AdminHomeScreen extends StatefulWidget {
  final String userName;
  final String userEmail;

  const AdminHomeScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required Map<String, dynamic> arguments,
  });

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  String? _profileImageUrl;
  bool _isLoading = true;
  String _collegeName = '';
  String _staffName = '';
  String _designation = '';

  String _currentSection = 'Dashboard';

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => ProfileDialog(
        currentImageUrl: _profileImageUrl,
        currentCollegeName: _collegeName,
        currentStaffName: _staffName,
        currentDesignation: _designation,
        onProfileUpdated: (imageUrl, collegeName, staffName, designation) {
          setState(() {
            _profileImageUrl = imageUrl;
            _collegeName = collegeName;
            _staffName = staffName;
            _designation = designation;
          });
        },
      ),
    );
  }

Widget _buildDashboardContent() {
  return Container(
    color: const Color(0xFFF8F9FA),
    child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StreamBuilder<DateTime>(
                  stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
                  initialData: DateTime.now(),
                  builder: (context, snapshot) {
                    final now = snapshot.data ?? DateTime.now();
                    final dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
                    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF45A049)]),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [BoxShadow(color: const Color(0xFF4CAF50).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '${dayNames[now.weekday % 7]}, ${monthNames[now.month - 1]} ${now.day}, ${now.year}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.access_time, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(child: _buildResponsiveGrid()),
        ],
      ),
    ),
  );
}
 Widget _buildResponsiveGrid() {
  // Use MediaQuery instead of LayoutBuilder to avoid layout recursion
  final screenWidth = MediaQuery.of(context).size.width;
  
  if (screenWidth > 1400) {
    // Extra Large Desktop - 4 columns
    return _buildFourColumnLayout();
  } else if (screenWidth > 1000) {
    // Large Desktop - 4 columns with smaller spacing
    return _buildFourColumnLayout(spacing: 12);
  } else if (screenWidth > 800) {
    // Tablet - 2x2 grid
    return _buildTwoByTwoLayout();
  } else if (screenWidth > 600) {
    // Small tablet - 2 columns
    return _buildTwoColumnLayout();
  } else {
    // Mobile - Single column
    return _buildSingleColumnLayout();
  }
}
  Widget _buildFourColumnLayout({double spacing = 16}) {
    return Column(
      children: [
        // Top row with count cards and rankings
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: _buildRecentGroupsCard(),
              ),
              SizedBox(width: spacing),
              Expanded(
                flex: 1,
                child: _buildRecentStaffsCard(),
              ),
              SizedBox(width: spacing),
              Expanded(
                flex: 1,
                child: _buildTodayLeaveRankingCard(),
              ),
              SizedBox(width: spacing),
              Expanded(
                flex: 1,
                child: _buildSemesterLeaveRankingCard(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Bottom row with horizontal least leave card
        _buildLeastLeaveCard(),
      ],
    );
  }

  Widget _buildTwoByTwoLayout() {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildRecentGroupsCard()),
              const SizedBox(width: 16),
              Expanded(child: _buildRecentStaffsCard()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Add the horizontal card here
        _buildLeastLeaveCard(),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildTodayLeaveRankingCard()),
              const SizedBox(width: 16),
              Expanded(child: _buildSemesterLeaveRankingCard()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTwoColumnLayout() {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildRecentGroupsCard()),
              const SizedBox(width: 16),
              Expanded(child: _buildRecentStaffsCard()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Add the horizontal card here
        _buildLeastLeaveCard(),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildTodayLeaveRankingCard()),
              const SizedBox(width: 16),
              Expanded(child: _buildSemesterLeaveRankingCard()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSingleColumnLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Keep the count cards side by side even on mobile
          Row(
            children: [
              Expanded(child: _buildRecentGroupsCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildRecentStaffsCard()),
            ],
          ),
          const SizedBox(height: 16),
          // Add the new horizontal card here
          _buildLeastLeaveCard(),
          const SizedBox(height: 16),
          SizedBox(
            height: 350,
            child: _buildTodayLeaveRankingCard(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 350,
            child: _buildSemesterLeaveRankingCard(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRecentGroupsCard() {
    // Sample count data - replace with actual data from your database
    int totalGroups = 12;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.groups_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              totalGroups.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Groups',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentStaffsCard() {
    // Sample count data - replace with actual data from your database  
    int totalStaffs = 25;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              totalStaffs.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Staff',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayLeaveRankingCard() {
    // Sample data - replace with actual data from your database
    List<Map<String, dynamic>> todayLeaves = [
      {'group': 'CSE 3rd Year A', 'leaves': 12, 'total': 45},
      {'group': 'ECE 2nd Year B', 'leaves': 8, 'total': 42},
      {'group': 'MECH 4th Year', 'leaves': 7, 'total': 38},
      {'group': 'IT 1st Year A', 'leaves': 5, 'total': 50},
    ];

    return _buildDashboardCard(
      title: 'Today\'s Leave Ranking',
      subtitle: 'Real-time absence tracking',
      icon: Icons.today_rounded,
      iconColor: const Color(0xFFFF9800),
      gradientColors: const [Color.fromARGB(255, 238, 105, 4), Color.fromARGB(255, 238, 105, 4)],
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: todayLeaves.length,
              itemBuilder: (context, index) {
                final data = todayLeaves[index];
                double percentage = (data['leaves'] / data['total']) * 100;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color.fromARGB(255, 238, 105, 4).withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(255, 238, 105, 4).withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color.fromARGB(255, 238, 105, 4), Color.fromARGB(255, 238, 105, 4)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
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
                                  data['group'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Color(0xFF2E2E2E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${data['leaves']} out of ${data['total']} students',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 238, 105, 4).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Color.fromARGB(255, 238, 105, 4),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: Colors.grey.shade200,
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: percentage / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: const LinearGradient(
                                colors: [Color.fromARGB(255, 238, 105, 4), Color.fromARGB(255, 238, 105, 4)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: () => _setCurrentSection('Statistics'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('View Detailed Stats'),
              style: TextButton.styleFrom(
                foregroundColor: const Color.fromARGB(255, 238, 105, 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterLeaveRankingCard() {
    // Sample data - replace with actual data from your database
    List<Map<String, dynamic>> semesterLeaves = [
      {'group': 'ECE 2nd Year B', 'leaves': 245, 'total': 2100, 'trend': 'up'},
      {'group': 'CSE 3rd Year A', 'leaves': 198, 'total': 2250, 'trend': 'down'},
      {'group': 'MECH 4th Year', 'leaves': 156, 'total': 1900, 'trend': 'stable'},
      {'group': 'IT 1st Year A', 'leaves': 142, 'total': 2500, 'trend': 'up'},
    ];

    return _buildDashboardCard(
      title: 'Semester Leave Ranking',
      subtitle: 'Complete semester overview',
      icon: Icons.calendar_month_rounded,
      iconColor: const Color.fromARGB(255, 237, 6, 6),
      gradientColors: const [Color.fromARGB(255, 237, 6, 6), Color.fromARGB(255, 237, 6, 6)],
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: semesterLeaves.length,
              itemBuilder: (context, index) {
                final data = semesterLeaves[index];
                double percentage = (data['leaves'] / data['total']) * 100;
                IconData trendIcon = data['trend'] == 'up' 
                    ? Icons.trending_up_rounded 
                    : data['trend'] == 'down' 
                    ? Icons.trending_down_rounded 
                    : Icons.trending_flat_rounded;
                Color trendColor = data['trend'] == 'up' 
                    ? Colors.red 
                    : data['trend'] == 'down' 
                    ? Colors.green 
                    : Colors.grey;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color.fromARGB(255, 237, 6, 6).withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(255, 237, 6, 6).withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color.fromARGB(255, 237, 6, 6), Color.fromARGB(255, 237, 6, 6)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
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
                                  data['group'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Color(0xFF2E2E2E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '${data['leaves']} total leaves',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(trendIcon, color: trendColor, size: 16),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 237, 6, 6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Color.fromARGB(255, 237, 6, 6),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: Colors.grey.shade200,
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: percentage / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: const LinearGradient(
                                colors: [Color.fromARGB(255, 237, 6, 6), Color.fromARGB(255, 237, 6, 6)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: () => _setCurrentSection('Statistics'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('View Full Report'),
              style: TextButton.styleFrom(
                foregroundColor: const Color.fromARGB(255, 237, 6, 6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeastLeaveCard() {
    // Sample data for the group with least leave today
    Map<String, dynamic> leastLeaveGroup = {
      'group': 'IT 3rd Year B',
      'department': 'Information Technology',
      'totalStudents': 48,
      'leavesToday': 2,
      'attendanceRate': 95.8,
      'rank': '1st',
    };

    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF4CAF50)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon section
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // Content section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Best Attendance Today',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            leastLeaveGroup['rank'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    leastLeaveGroup['group'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Flexible(
                    child: Text(
                      '${leastLeaveGroup['leavesToday']} on leave • ${leastLeaveGroup['attendanceRate']}%',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Stats section
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${leastLeaveGroup['totalStudents'] - leastLeaveGroup['leavesToday']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Present',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required List<Color> gradientColors,
    required Widget child,
  }) {
    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey.shade50.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.9),
          width: 1,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Card Header
            Container(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: iconColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E2E2E),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Card Content
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  bool _isExpanded = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
    _loadProfileData();
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _profileImageUrl = prefs.getString('profileImageUrl');
      _collegeName = prefs.getString('collegeName') ?? '';
      _staffName = prefs.getString('staffName') ?? '';
      _designation = prefs.getString('designation') ?? '';
      _isLoading = false;
    });
  }

 // ...existing code...
Widget _getSection() {
  switch (_currentSection) {
    case 'Dashboard':
      return _buildDashboardContent();
    case 'Groups':
      return const GroupsScreen();
    case 'Schedules':
      return AddUsersScreen(groupData: const {});
    case 'Set Coordinates':
      return const CoordinatesScreen();
    case 'Teachers':
      return const TeachersScreen();
    case 'Active Users':
      return const ActiveUsersScreen();
    case 'Statistics':
      return const StatisticsScreen();
    case 'Timetable':
      return const TimetableScreen();
    case 'Onduty':
      return const OnDutyScreen();
    default:
      return _buildDashboardContent();
  }
}
// ...existing code...

  void _toggleMenu() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get the screen size and safe area
    final screenSize = MediaQuery.of(context);
    final isPhone = screenSize.size.width < 600; // Check if device is phone

    return Scaffold(
      // Add safe area handling
      body: SafeArea(
        child: isPhone ? _buildPhoneLayout() : _buildTabletLayout(),
      ),
    );
  }

  // Add new method for phone layout
  Widget _buildPhoneLayout() {
    return Column(
      children: [
        // Top App Bar with menu button
        Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _toggleMenu,
                icon: AnimatedIcon(
                  icon: AnimatedIcons.menu_close,
                  progress: _animationController,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                _currentSection,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showProfileDialog,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF4CAF50).withOpacity(0.1),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _profileImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: _profileImageUrl!,
                              imageBuilder: (context, imageProvider) => Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  image: DecorationImage(
                                    image: imageProvider,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            )
                          : _buildDefaultAvatar(),
                ),
              ),
            ],
          ),
        ),

        // Main Content
        Expanded(
          child: Stack(
            children: [
              // Content Area
              _getSection(),

              // Drawer Menu
              if (_isExpanded)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 280,
                  child: Material(
                    elevation: 8,
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          _buildProfileSection(),
                          const Divider(),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              children: [
                                _buildMenuItem(
                                  icon: Icons.dashboard_outlined,
                                  title: 'Dashboard',
                                  isSelected: _currentSection == 'Dashboard',
                                  onTap: () => _setCurrentSection('Dashboard'),
                                ),
                                _buildMenuItem(
                                  icon: Icons.group_outlined,
                                  title: 'Groups',
                                  isSelected: _currentSection == 'Groups',
                                  onTap: () => _setCurrentSection('Groups'),
                                ),
                                _buildMenuItem(
                                  icon: Icons.location_on_outlined,
                                  title: 'Set Coordinates',
                                  isSelected: _currentSection == 'Set Coordinates',
                                  onTap: () => _setCurrentSection('Set Coordinates'),
                                ),
                                _buildMenuItem(
                                  icon: Icons.schedule_outlined,
                                  title: 'Timetable',
                                  isSelected: _currentSection == 'Timetable',
                                  onTap: () => _setCurrentSection('Timetable'),
                                ),
                                _buildMenuItem(
                                  icon: Icons.school_outlined,
                                  title: 'Teachers',
                                  isSelected: _currentSection == 'Teachers',
                                  onTap: () => _setCurrentSection('Teachers'),
                                ),
                                _buildMenuItem(
                                  icon: Icons.search_outlined,
                                  title: 'Onduty',
                                  isSelected: _currentSection == 'Onduty',
                                  onTap: () => _setCurrentSection('Onduty'),
                                ),
                                _buildMenuItem(
                                  icon: Icons.bar_chart_outlined,
                                  title: 'Statistics',
                                  isSelected: _currentSection == 'Statistics',
                                  onTap: () => _setCurrentSection('Statistics'),
                                ),
                              ],
                            ),
                          ),
                          _buildMenuItem(
                            icon: Icons.logout_outlined,
                            title: 'Logout',
                            isLogout: true,
                            onTap: _logout,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Add new method for tablet/desktop layout
  Widget _buildTabletLayout() {
    // Keep your existing Row layout here
    return Row(
      children: [
        // Your existing sidebar code
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _isExpanded ? 280 : 70,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Menu Toggle Button
                Container(
                  height: 70,
                  padding: EdgeInsets.symmetric(
                    horizontal: _isExpanded ? 20 : 10,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _toggleMenu,
                        icon: AnimatedIcon(
                          icon: AnimatedIcons.menu_close,
                          progress: _animationController,
                        ),
                      ),
                      if (_isExpanded) ...[
                        const SizedBox(width: 10),
                        const Text(
                          'Admin Panel',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (_isExpanded) ...[
                  // Profile Section (only show when expanded)
                  _buildProfileSection(),
                  const Divider(),
                ],

                // Menu Items
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: _isExpanded ? 10 : 5,
                    ),
                    children: [
                      _buildMenuItem(
                        icon: Icons.dashboard_outlined,
                        title: 'Dashboard',
                        isSelected: _currentSection == 'Dashboard',
                        onTap: () => _setCurrentSection('Dashboard'),
                      ),
                      _buildMenuItem(
                        icon: Icons.group_outlined,
                        title: 'Groups',
                        isSelected: _currentSection == 'Groups',
                        onTap: () => _setCurrentSection('Groups'),
                      ),
                      _buildMenuItem(
                        icon: Icons.location_on_outlined,
                        title: 'Set Coordinates',
                        isSelected: _currentSection == 'Set Coordinates',
                        onTap: () => _setCurrentSection('Set Coordinates'),
                      ),
                      _buildMenuItem(
                        icon: Icons.schedule_outlined,
                        title: 'Timetable',
                        isSelected: _currentSection == 'Timetable',
                        onTap: () => _setCurrentSection('Timetable'),
                      ),
                      _buildMenuItem(
                        icon: Icons.school_outlined,
                        title: 'Teachers',
                        isSelected: _currentSection == 'Teachers',
                        onTap: () => _setCurrentSection('Teachers'),
                      ),
                      _buildMenuItem(
                        icon: Icons.search_outlined,
                        title: 'Onduty',
                        isSelected: _currentSection == 'Onduty',
                        onTap: () => _setCurrentSection('Onduty'),
                      ),
                      _buildMenuItem(
                        icon: Icons.bar_chart_outlined,
                        title: 'Statistics',
                        isSelected: _currentSection == 'Statistics',
                        onTap: () => _setCurrentSection('Statistics'),
                      ),
                    ],
                  ),
                ),

                // Logout Button
                Padding(
                  padding: EdgeInsets.all(_isExpanded ? 20 : 10),
                  child: _buildMenuItem(
                    icon: Icons.logout_outlined,
                    title: 'Logout',
                    isLogout: true,
                    onTap: _logout,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Your existing main content area
        Expanded(
          child: Container(
            color: const Color(0xFFF5F5F5),
            child: Column(
              children: [
                // Top Bar
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        _currentSection,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text('Welcome, ${widget.userName}'),
                    ],
                  ),
                ),

                // Dynamic Content Area
                Expanded(child: _getSection()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    bool isSelected = false,
    bool isLogout = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: _isExpanded ? 15 : 5,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected ? const Color(0xFF4CAF50).withOpacity(0.1) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isLogout
                      ? Colors.red
                      : isSelected
                          ? const Color(0xFF4CAF50)
                          : Colors.grey.shade700,
                ),
                if (_isExpanded) ...[
                  const SizedBox(width: 15),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isLogout
                          ? Colors.red
                          : isSelected
                              ? const Color(0xFF4CAF50)
                              : Colors.grey.shade700,
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

  void _setCurrentSection(String section) {
    setState(() {
      _currentSection = section;
      // On phone, close the menu after selection
      if (MediaQuery.of(context).size.width < 600 && _isExpanded) {
        _toggleMenu();
      }
    });
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF4CAF50).withOpacity(0.1),
      ),
      child: const Icon(Icons.person, size: 40, color: Color(0xFF4CAF50)),
    );
  }

  void _logout() async {
    await SessionManager.clearSession();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _showProfileDialog,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF4CAF50), width: 3),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : _profileImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: _profileImageUrl!,
                          imageBuilder: (context, imageProvider) => Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: imageProvider,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          placeholder: (context, url) => const CircularProgressIndicator(),
                          errorWidget: (context, url, error) => _buildDefaultAvatar(),
                        )
                      : _buildDefaultAvatar(),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            _staffName.isNotEmpty ? _staffName : widget.userName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E2E2E),
            ),
          ),
          if (_designation.isNotEmpty)
            Text(
              _designation,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }
}
class ProfileDialog extends StatefulWidget {
  final String? currentImageUrl;
  final String currentCollegeName;
  final String currentStaffName;
  final String currentDesignation;
  final Function(String?, String, String, String) onProfileUpdated;

  const ProfileDialog({
    super.key,
    this.currentImageUrl,
    required this.currentCollegeName,
    required this.currentStaffName,
    required this.currentDesignation,
    required this.onProfileUpdated,
  });

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  final _collegeNameController = TextEditingController();
  final _staffNameController = TextEditingController();
  final _designationController = TextEditingController();

  File? _selectedImage;
  bool _isUploading = false;
  bool _isSaving = false;
  double _uploadProgress = 0.0;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _collegeNameController.text = widget.currentCollegeName;
    _staffNameController.text = widget.currentStaffName;
    _designationController.text = widget.currentDesignation;
    _profileImageUrl = widget.currentImageUrl;
  }

  @override
  void dispose() {
    _collegeNameController.dispose();
    _staffNameController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: SingleChildScrollView(
        child: Container(
          width:
              MediaQuery.of(context).size.width > 600
                  ? 500
                  : MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Text(
                      'Profile Settings',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E2E2E),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed:
                          _isUploading || _isSaving
                              ? null
                              : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Profile Image Section
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _isUploading || _isSaving ? null : _pickImage,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF4CAF50),
                              width: 3,
                            ),
                          ),
                          child: _buildProfileImage(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed:
                            _isUploading || _isSaving ? null : _pickImage,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Change Photo'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF4CAF50),
                        ),
                      ),
                      if (_isUploading) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: 200,
                          child: Column(
                            children: [
                              LinearProgressIndicator(
                                value: _uploadProgress,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF4CAF50),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Uploading... ${(_uploadProgress * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Form Fields
                _buildTextField(
                  controller: _staffNameController,
                  label: 'Staff Name',
                  icon: Icons.person,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter staff name';
                    }
                    if (value.trim().length < 2) {
                      return 'Staff name must be at least 2 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                _buildTextField(
                  controller: _collegeNameController,
                  label: 'College Name',
                  icon: Icons.school,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter college name';
                    }
                    if (value.trim().length < 3) {
                      return 'College name must be at least 3 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                _buildTextField(
                  controller: _designationController,
                  label: 'Designation',
                  icon: Icons.work,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter designation';
                    }
                    if (value.trim().length < 2) {
                      return 'Designation must be at least 2 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 30),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isUploading || _isSaving
                                ? null
                                : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          side: BorderSide(
                            color:
                                _isUploading || _isSaving
                                    ? Colors.grey
                                    : const Color(0xFF4CAF50),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                _isUploading || _isSaving
                                    ? Colors.grey
                                    : const Color(0xFF4CAF50),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            (_isUploading || _isSaving) ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child:
                            _isSaving
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text(
                                  'Save Profile',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    if (_selectedImage != null) {
      return ClipOval(
        child: Image.file(
          _selectedImage!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error loading selected image: $error');
            return _buildDefaultAvatar();
          },
        ),
      );
    }

    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: _profileImageUrl!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          placeholder:
              (context, url) => Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade200,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF4CAF50),
                    strokeWidth: 2,
                  ),
                ),
              ),
          errorWidget: (context, url, error) {
            debugPrint('Error loading network image: $error');
            return _buildDefaultAvatar();
          },
        ),
      );
    }

    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF4CAF50).withOpacity(0.1),
      ),
      child: const Icon(Icons.camera_alt, size: 40, color: Color(0xFF4CAF50)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      enabled: !_isUploading && !_isSaving,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color:
              _isUploading || _isSaving ? Colors.grey : const Color(0xFF4CAF50),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        // Validate file size (limit to 5MB)
        final File imageFile = File(image.path);
        final int fileSizeInBytes = await imageFile.length();
        final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

        if (fileSizeInMB > 5.0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image size should be less than 5MB'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedImage = imageFile;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pick image. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return _profileImageUrl;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final String fileName =
          'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(fileName);

      final UploadTask uploadTask = storageRef.putFile(_selectedImage!);

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (mounted) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        }
      });

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _profileImageUrl = downloadUrl;
        _isUploading = false;
        _uploadProgress = 1.0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploaded successfully!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }

      return downloadUrl;
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });

      debugPrint('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      String? finalImageUrl = _profileImageUrl;

      // Upload image if a new one was selected
      if (_selectedImage != null) {
        finalImageUrl = await _uploadImage();
        if (finalImageUrl == null) {
          // Image upload failed
          setState(() {
            _isSaving = false;
          });
          return;
        }
      }

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profileImageUrl', finalImageUrl ?? '');
      await prefs.setString('collegeName', _collegeNameController.text.trim());
      await prefs.setString('staffName', _staffNameController.text.trim());
      await prefs.setString('designation', _designationController.text.trim());

      // Call the callback function
      widget.onProfileUpdated(
        finalImageUrl,
        _collegeNameController.text.trim(),
        _staffNameController.text.trim(),
        _designationController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
