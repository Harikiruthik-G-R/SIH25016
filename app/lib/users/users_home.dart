

import 'package:GeoAt/sessionmanager.dart';
import 'package:GeoAt/users/pages/academic.dart';
import 'package:GeoAt/users/pages/assignments.dart';
import 'package:GeoAt/users/pages/history.dart';
import 'package:GeoAt/users/pages/markattendence.dart';
import 'package:GeoAt/users/pages/schedule.dart';
import 'package:flutter/material.dart';
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
  PageController _pageController = PageController();
  int _currentPage = 0;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startClock();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
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
      begin: const Offset(0, 0.3),
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
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.logout, color: Colors.red.shade600, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Logout Confirmation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E2E2E),
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to logout from your account?',
            style: TextStyle(fontSize: 16, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
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
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
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
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4CAF50),
              Color(0xFF45A049),
              Color(0xFF388E3C),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Fixed Header Profile Section
              _buildHeaderSection(),
              
              // Scrollable Content
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
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          
                          // Time and Date Card
                          SlideTransition(
                            position: _slideAnimation,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: _buildTimeCard(),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Quick Actions Header
                          SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.3),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: _animationController,
                              curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
                            )),
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: const Text(
                                'Student Dashboard',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E2E2E),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Feature Grid
                          SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.3),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: _animationController,
                              curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
                            )),
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: _buildStudentFeatureGrid(),
                            ),
                          ),
                          
                          const SizedBox(height: 30),
                        ],
                      ),
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

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Avatar
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _getInitials(widget.userName),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // User Info
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
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Student',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.rollNumber.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Roll: ${widget.rollNumber}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          
          // Settings Button
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: IconButton(
                icon: isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.settings, color: Colors.white, size: 24),
                onPressed: isLoading ? null : _showLogoutConfirmation,
                tooltip: 'Settings',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentDate,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              AnimatedBuilder(
                animation: _floatingAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, sin(_floatingAnimation.value * 2 * pi) * 3),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.access_time,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

Widget _buildStudentFeatureGrid() {
  final features = [
    {
      'icon': Icons.location_on,
      'title': 'Mark Attendance',
      'description': 'Check in/out location',
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
      'icon': Icons.schedule,
      'title': 'My Schedule',
      'description': 'View class timetable',
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
      'icon': Icons.history,
      'title': 'History',
      'description': 'View your history',
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
      'icon': Icons.assignment,
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
      'icon': Icons.grade,
      'title': 'Grades',
      'description': 'Academic performance',
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
    // {
    //   'icon': Icons.notifications,
    //   'title': 'Notifications',
    //   'description': 'Important updates',
    //   'color': const Color(0xFF607D8B),
    //   'onTap': () => Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //       builder: (context) => NotificationsScreen(
    //         // userName: widget.userName,
    //         // userEmail: widget.userEmail,
    //         // rollNumber: widget.rollNumber,
    //         // groupId: widget.groupId,
    //         // groupName: widget.groupName,
    //         // department: widget.department,
    //       ),
    //     ),
    //   ),
    // },
  ];

  return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
    ),
    itemCount: features.length,
    itemBuilder: (context, index) {
      final feature = features[index];
      return GestureDetector(
        onTap: feature['onTap'] as VoidCallback,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (feature['color'] as Color).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  feature['icon'] as IconData,
                  size: 32,
                  color: feature['color'] as Color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                feature['title'] as String,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  feature['description'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
  }
  
  class NotificationsScreen {
  }


  void _showFeatureDialog(String title, String message) {
    var context;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E2E2E),
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Got it!',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
