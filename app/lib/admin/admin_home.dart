import 'package:GeoAt/sessionmanager.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';
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
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header with Date/Time
          _buildWelcomeHeader(),
          const SizedBox(height: 24),
          
          // Statistics Cards Grid
          _buildStatisticsGrid(),
          const SizedBox(height: 24),
          
          // Charts Section
          _buildChartsSection(),
          const SizedBox(height: 24),
          
          // Recent Activity Section
          _buildRecentActivitySection(),
        ],
      ),
    ),
  );
}

  // Welcome Header with Date/Time
  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
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
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, ${_staffName.isNotEmpty ? _staffName : widget.userName}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _designation.isNotEmpty ? _designation : 'Administrator',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                StreamBuilder<DateTime>(
                  stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
                  initialData: DateTime.now(),
                  builder: (context, snapshot) {
                    final now = snapshot.data ?? DateTime.now();
                    final dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
                    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${dayNames[now.weekday % 7]}, ${monthNames[now.month - 1]} ${now.day}, ${now.year}',
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.dashboard,
              color: Colors.white,
              size: 48,
            ),
          ),
        ],
      ),
    );
  }

  // Statistics Cards Grid
  Widget _buildStatisticsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 4;
        double childAspectRatio = 1.3;
        
        if (constraints.maxWidth < 1200) {
          crossAxisCount = 2;
          childAspectRatio = 1.4;
        }
        if (constraints.maxWidth < 600) {
          crossAxisCount = 2;
          childAspectRatio = 1.2;
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          children: [
            _buildStatCard(
              title: 'Total Students',
              value: '1,247',
              change: '+12%',
              isPositive: true,
              icon: Icons.school,
              color: const Color(0xFF4CAF50),
            ),
            _buildStatCard(
              title: 'Active Teachers',
              value: '89',
              change: '+3%',
              isPositive: true,
              icon: Icons.person,
              color: const Color(0xFF2196F3),
            ),
            _buildStatCard(
              title: 'Present Today',
              value: '1,156',
              change: '-2%',
              isPositive: false,
              icon: Icons.check_circle,
              color: const Color(0xFF4CAF50),
            ),
            _buildStatCard(
              title: 'Absent Today',
              value: '91',
              change: '+5%',
              isPositive: false,
              icon: Icons.cancel,
              color: const Color(0xFFFF5722),
            ),
          ],
        );
      },
    );
  }

  // Individual Stat Card
  Widget _buildStatCard({
    required String title,
    required String value,
    required String change,
    required bool isPositive,
    required IconData icon,
    required Color color,
  }) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      color: isPositive ? Colors.green : Colors.red,
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      change,
                      style: TextStyle(
                        color: isPositive ? Colors.green : Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E2E2E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Charts Section
  Widget _buildChartsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            children: [
              Expanded(flex: 2, child: _buildAttendanceChart()),
              const SizedBox(width: 16),
              Expanded(child: _buildDepartmentChart()),
            ],
          );
        } else {
          return Column(
            children: [
              _buildAttendanceChart(),
              const SizedBox(height: 16),
              _buildDepartmentChart(),
            ],
          );
        }
      },
    );
  }

  // Attendance Line Chart
  Widget _buildAttendanceChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Attendance Trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E2E2E),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Text(
                            days[value.toInt()],
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 60,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 85),
                      FlSpot(1, 88),
                      FlSpot(2, 82),
                      FlSpot(3, 90),
                      FlSpot(4, 87),
                      FlSpot(5, 75),
                      FlSpot(6, 78),
                    ],
                    isCurved: true,
                    color: const Color(0xFF4CAF50),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFF4CAF50),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Department Pie Chart
  Widget _buildDepartmentChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Students by Department',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E2E2E),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          color: const Color(0xFF4CAF50),
                          value: 35,
                          title: '35%',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          color: const Color(0xFF2196F3),
                          value: 25,
                          title: '25%',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          color: const Color(0xFFFF9800),
                          value: 20,
                          title: '20%',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          color: const Color(0xFF9C27B0),
                          value: 20,
                          title: '20%',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem('CSE', const Color(0xFF4CAF50), '437'),
                    _buildLegendItem('ECE', const Color(0xFF2196F3), '312'),
                    _buildLegendItem('MECH', const Color(0xFFFF9800), '249'),
                    _buildLegendItem('IT', const Color(0xFF9C27B0), '249'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, String count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label ($count)',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF2E2E2E),
            ),
          ),
        ],
      ),
    );
  }

  // Recent Activity Section
  Widget _buildRecentActivitySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E2E2E),
                ),
              ),
              TextButton(
                onPressed: () => _setCurrentSection('Statistics'),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final activities = [
                {
                  'title': 'New group "CSE 3rd Year C" created',
                  'subtitle': '45 students added',
                  'time': '2 hours ago',
                  'icon': Icons.group_add,
                  'color': const Color(0xFF4CAF50),
                },
                {
                  'title': 'Dr. Rajesh Kumar joined as faculty',
                  'subtitle': 'Computer Science Department',
                  'time': '4 hours ago',
                  'icon': Icons.person_add,
                  'color': const Color(0xFF2196F3),
                },
                {
                  'title': 'Attendance marked for ECE 2nd Year',
                  'subtitle': '38 out of 42 students present',
                  'time': '6 hours ago',
                  'icon': Icons.check_circle,
                  'color': const Color(0xFF4CAF50),
                },
                {
                  'title': 'Timetable updated for IT Department',
                  'subtitle': 'New schedule effective from Monday',
                  'time': '1 day ago',
                  'icon': Icons.schedule,
                  'color': const Color(0xFFFF9800),
                },
                {
                  'title': 'Coordinates updated for Main Building',
                  'subtitle': 'Location tracking improved',
                  'time': '2 days ago',
                  'icon': Icons.location_on,
                  'color': const Color(0xFF9C27B0),
                },
              ];

              final activity = activities[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (activity['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    activity['icon'] as IconData,
                    color: activity['color'] as Color,
                    size: 20,
                  ),
                ),
                title: Text(
                  activity['title'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  activity['subtitle'] as String,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                trailing: Text(
                  activity['time'] as String,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
              );
            },
          ),
        ],
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
