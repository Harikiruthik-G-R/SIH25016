import 'package:GeoAt/sessionmanager.dart';
import 'package:GeoAt/users/pages/academic.dart';
import 'package:GeoAt/users/pages/assignments.dart';
import 'package:GeoAt/users/pages/history.dart';
import 'package:GeoAt/users/pages/markattendence.dart';
import 'package:GeoAt/users/pages/onduty.dart';
import 'package:GeoAt/users/pages/schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';

class UserHomeScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String rollNumber;
  final String groupId;
  final String groupName;
  final String department;
  final Map<String, dynamic> arguments;

  const UserHomeScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.rollNumber,
    required this.groupId,
    required this.groupName,
    required this.department,
    required this.arguments,
  });

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _floatingController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _floatingAnimation;
  
  bool isLoading = false;
  String currentTime = '';
  String currentDate = '';
  Timer? _timer;
  final PageController _pageController = PageController();
  int _selectedIndex = 0;
  
  // Mock data for demonstration
  List<Map<String, dynamic>> notifications = [
    {'title': 'Assignment Due', 'message': 'Math assignment due tomorrow', 'time': '2h ago', 'unread': true},
    {'title': 'Class Cancelled', 'message': 'Physics class cancelled today', 'time': '4h ago', 'unread': true},
    {'title': 'Grade Updated', 'message': 'Your Chemistry grade has been updated', 'time': '1d ago', 'unread': false},
  ];

  List<Map<String, dynamic>> recentActivities = [
    {'activity': 'Marked attendance for Math class', 'time': '10:30 AM', 'icon': Icons.check_circle, 'color': Colors.green},
    {'activity': 'Submitted Physics assignment', 'time': '9:15 AM', 'icon': Icons.assignment_turned_in, 'color': Colors.blue},
    {'activity': 'Viewed schedule for next week', 'time': 'Yesterday', 'icon': Icons.schedule, 'color': Colors.orange},
  ];

  List<Map<String, dynamic>> quickStats = [
    {'label': 'Attendance', 'value': '92%', 'icon': Icons.person_outline, 'color': Color(0xFF4CAF50)},
    {'label': 'Assignments', 'value': '8/10', 'icon': Icons.assignment_outlined, 'color': Color(0xFF2196F3)},
    {'label': 'Grade', 'value': 'A-', 'icon': Icons.grade_outlined, 'color': Color(0xFFFF9800)},
    {'label': 'Events', 'value': '3', 'icon': Icons.event_outlined, 'color': Color(0xFF9C27B0)},
  ];
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startClock();
    // Set status bar color
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF4CAF50),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _floatingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _floatingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
    _floatingController.repeat(reverse: true);
  }

  void _startClock() {
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    final formattedTime = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    final formattedDate = '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
    
    if (mounted) {
      setState(() {
        currentTime = formattedTime;
        currentDate = formattedDate;
      });
    }
  }

  String _getInitials(String name) {
    List<String> nameParts = name.trim().split(' ');
    if (nameParts.length == 1) {
      return nameParts[0].isNotEmpty ? nameParts[0][0].toUpperCase() : 'U';
    }
    return (nameParts[0][0] + nameParts[nameParts.length - 1][0]).toUpperCase();
  }

  Future<void> _logout() async {
    setState(() => isLoading = true);
    
    try {
      await SessionManager.clearSession();
      
      if (!mounted) return;
      
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );
    } catch (e) {
      debugPrint('Logout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error logging out. Please try again.'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.logout_rounded, color: Colors.red.shade600, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Logout',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) return 'Good Afternoon';
    else return 'Good Evening';
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatingController.dispose();
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildTimeCard(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Quick Stats Section
                    _buildSectionHeader('Quick Stats'),
                    const SizedBox(height: 12),
                    _buildQuickStats(),
                    const SizedBox(height: 24),
                    
                    // Quick Actions
                    _buildSectionHeader('Quick Actions'),
                    const SizedBox(height: 12),
                    _buildStudentFeatureGrid(),
                    const SizedBox(height: 24),
                    
                    // Notifications Section
                    _buildSectionHeader('Notifications'),
                    const SizedBox(height: 12),
                    _buildNotifications(),
                    const SizedBox(height: 24),
                    
                    // Recent Activity Section
                    _buildSectionHeader('Recent Activity'),
                    const SizedBox(height: 12),
                    _buildRecentActivity(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildSectionHeader(String title) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      )),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 25),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
        ),
      ),
      child: Row(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _getInitials(widget.userName),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.userName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Student${widget.rollNumber.isNotEmpty ? " • ${widget.rollNumber}" : ""}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                        onPressed: () {
                          // Handle notifications tap
                        },
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ),
                    if (notifications.any((n) => n['unread']))
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.settings_rounded, color: Colors.white, size: 20),
                    onPressed: isLoading ? null : _showLogoutConfirmation,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  _getGreeting(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentTime,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  currentDate,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _floatingAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, sin(_floatingAnimation.value * 2 * pi) * 2),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.access_time_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: quickStats.length,
        itemBuilder: (context, index) {
          final stat = quickStats[index];
          return Container(
            width: 90,
            margin: EdgeInsets.only(right: index == quickStats.length - 1 ? 0 : 12),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  stat['icon'] as IconData,
                  color: stat['color'] as Color,
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  stat['value'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stat['label'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotifications() {
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
        children: notifications.take(3).map((notification) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: notification['unread'] ? Colors.blue : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
            title: Text(
              notification['title'],
              style: TextStyle(
                fontSize: 14,
                fontWeight: notification['unread'] ? FontWeight.w600 : FontWeight.w500,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            subtitle: Text(
              notification['message'],
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              notification['time'],
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentActivity() {
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
        children: recentActivities.map((activity) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (activity['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                activity['icon'] as IconData,
                size: 16,
                color: activity['color'] as Color,
              ),
            ),
            title: Text(
              activity['activity'],
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              activity['time'],
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStudentFeatureGrid() {
    final features = [
      {
        'icon': Icons.location_on_rounded,
        'title': 'Mark Attendance',
        'description': 'Check in/out',
        'color': const Color(0xFF4CAF50),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MarkAttendanceScreen(
              userName: widget.userName,
              userEmail: widget.userEmail,
              rollNumber: widget.rollNumber,
              groupId: widget.groupId,
              groupName: widget.groupName,
              department: widget.department,
            ),
          ),
        ),
      },
      {
        'icon': Icons.schedule_rounded,
        'title': 'My Schedule',
        'description': 'Class timetable',
        'color': const Color(0xFF2196F3),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MyScheduleScreen(
              userName: widget.userName,
              userEmail: widget.userEmail,
              rollNumber: widget.rollNumber,
              groupId: widget.groupId,
              groupName: widget.groupName,
              department: widget.department,
            ),
          ),
        ),
      },
      {
        'icon': Icons.history_rounded,
        'title': 'History',
        'description': 'View records',
        'color': const Color(0xFF9C27B0),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HistoryScreen(
              userName: widget.userName,
              userEmail: widget.userEmail,
              rollNumber: widget.rollNumber,
              groupId: widget.groupId,
              groupName: widget.groupName,
              department: widget.department,
            ),
          ),
        ),
      },
      {
        'icon': Icons.assignment_rounded,
        'title': 'Assignments',
        'description': 'Pending tasks',
        'color': const Color(0xFFFF9800),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AssignmentsScreen(
              userName: widget.userName,
              userEmail: widget.userEmail,
              rollNumber: widget.rollNumber,
              groupId: widget.groupId,
              groupName: widget.groupName,
              department: widget.department,
            ),
          ),
        ),
      },
      {
        'icon': Icons.grade_rounded,
        'title': 'Grades',
        'description': 'Performance',
        'color': const Color(0xFFE91E63),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GradesScreen(
              userName: widget.userName,
              userEmail: widget.userEmail,
              rollNumber: widget.rollNumber,
              groupId: widget.groupId,
              groupName: widget.groupName,
              department: widget.department,
            ),
          ),
        ),
      },
      {
        'icon': Icons.library_books_rounded,
        'title': 'On-Duty',
        'description': 'Apply for On-Duty',
        'color': const Color(0xFF795548),
        'onTap': ()=> Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => OnDutyApplyPage(
     userName: widget.userName,
              userEmail: widget.userEmail,
              rollNumber: widget.rollNumber,
              groupId: widget.groupId,
              groupName: widget.groupName,
              department: widget.department,
    ),
  ),
),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: feature['onTap'] as VoidCallback,
            borderRadius: BorderRadius.circular(12),
            child: Container(
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
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (feature['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        feature['icon'] as IconData,
                        size: 20,
                        color: feature['color'] as Color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      feature['title'] as String,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      feature['description'] as String,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
              _buildNavItem(1, Icons.schedule_rounded, 'Schedule'),
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
}

class NotificationsScreen {
}