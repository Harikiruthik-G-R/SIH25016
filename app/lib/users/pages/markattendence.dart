import 'package:flutter/material.dart';

class MarkAttendanceScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String rollNumber;
  final String groupId;
  final String groupName;
  final String department;

  const MarkAttendanceScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.rollNumber,
    required this.groupId,
    required this.groupName,
    required this.department,
  });

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mark Attendance',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
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
                        Icons.location_on,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Location-Based Attendance',
                      style: const TextStyle(
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
                    Text(
                      'Roll: ${widget.rollNumber}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
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
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          
                          // Feature Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 20,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                              border: Border.all(
                                color: const Color(0xFF4CAF50).withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 80,
                                  color: const Color(0xFF4CAF50).withOpacity(0.7),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Mark Your Attendance',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E2E2E),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Use location-based check-in to mark your attendance for classes and events.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 30),
                                
                                // Check In/Out Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: isLoading ? null : () {
                                          // Add check-in functionality
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Check-in functionality coming soon!'),
                                              backgroundColor: Color(0xFF4CAF50),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.login),
                                        label: const Text('Check In'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF4CAF50),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: isLoading ? null : () {
                                          // Add check-out functionality
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Check-out functionality coming soon!'),
                                              backgroundColor: Color(0xFFFF9800),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.logout),
                                        label: const Text('Check Out'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFFF9800),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Student Info Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Student Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E2E2E),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildInfoRow('Name', widget.userName),
                                _buildInfoRow('Roll Number', widget.rollNumber),
                                _buildInfoRow('Email', widget.userEmail),
                                _buildInfoRow('Department', widget.department),
                                _buildInfoRow('Group', widget.groupName),
                              ],
                            ),
                          ),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2E2E2E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}