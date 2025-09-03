import 'package:flutter/material.dart';

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

  // Sample history data - replace with actual data
  final List<Map<String, dynamic>> attendanceHistory = [
    {
      'date': '2024-03-15',
      'subject': 'Mathematics',
      'checkIn': '9:00 AM',
      'checkOut': '10:30 AM',
      'status': 'Present',
      'location': 'Room 101',
    },
    {
      'date': '2024-03-14',
      'subject': 'Physics',
      'checkIn': '11:00 AM',
      'checkOut': '12:30 PM',
      'status': 'Present',
      'location': 'Lab 202',
    },
    {
      'date': '2024-03-13',
      'subject': 'Chemistry',
      'checkIn': '--',
      'checkOut': '--',
      'status': 'Absent',
      'location': 'Lab 301',
    },
    {
      'date': '2024-03-12',
      'subject': 'English',
      'checkIn': '10:05 AM',
      'checkOut': '11:30 AM',
      'status': 'Late',
      'location': 'Room 205',
    },
    {
      'date': '2024-03-11',
      'subject': 'Computer Science',
      'checkIn': '1:00 PM',
      'checkOut': '2:30 PM',
      'status': 'Present',
      'location': 'Lab 401',
    },
  ];

  final List<Map<String, dynamic>> activityHistory = [
    {
      'date': '2024-03-15',
      'activity': 'Logged in',
      'time': '8:45 AM',
      'type': 'login',
    },
    {
      'date': '2024-03-15',
      'activity': 'Marked attendance for Mathematics',
      'time': '9:00 AM',
      'type': 'attendance',
    },
    {
      'date': '2024-03-15',
      'activity': 'Viewed schedule',
      'time': '9:30 AM',
      'type': 'view',
    },
    {
      'date': '2024-03-14',
      'activity': 'Downloaded assignment',
      'time': '2:15 PM',
      'type': 'download',
    },
    {
      'date': '2024-03-14',
      'activity': 'Logged out',
      'time': '4:00 PM',
      'type': 'logout',
    },
  ];

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
                    child: Column(
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
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Attendance',
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
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Activities',
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
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child:
                                selectedTabIndex == 0
                                    ? _buildAttendanceHistory()
                                    : _buildActivityHistory(),
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

  Widget _buildAttendanceHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attendance History',
          style: TextStyle(
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
              
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      record['subject'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E2E2E),
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
                const SizedBox(height: 8),
                Text(
                  record['date'],
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      record['location'],
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
                    ],
                  ),
                ],
              ],
            ),
          );
        }).toList(),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildActivityHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activities',
          style: TextStyle(
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
        }).toList(),

        const SizedBox(height: 20),
      ],
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
        return const Color(0xFF2196F3);
      case 'view':
        return const Color(0xFF9C27B0);
      case 'download':
        return const Color(0xFF607D8B);
      default:
        return Colors.grey;
    }
  }

  IconData? _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      case 'attendance':
        return Icons.check_circle;
      case 'view':
        return Icons.visibility;
      case 'download':
        return Icons.download;
      default:
       return null;
    }
  }
}
