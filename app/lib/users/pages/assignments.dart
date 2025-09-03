import 'package:flutter/material.dart';

class AssignmentsScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String rollNumber;
  final String groupId;
  final String groupName;
  final String department;

  const AssignmentsScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.rollNumber,
    required this.groupId,
    required this.groupName,
    required this.department,
  });

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  int selectedTabIndex = 0;
  
  // Sample assignments data - replace with actual data
  final List<Map<String, dynamic>> pendingAssignments = [
    {
      'title': 'Mathematics Assignment 1',
      'subject': 'Mathematics',
      'dueDate': '2024-03-20',
      'priority': 'High',
      'description': 'Solve problems 1-15 from Chapter 3',
      'submissionType': 'PDF Upload',
      'maxMarks': 100,
    },
    {
      'title': 'Physics Lab Report',
      'subject': 'Physics',
      'dueDate': '2024-03-18',
      'priority': 'Medium',
      'description': 'Write a detailed lab report on electromagnetic induction experiment',
      'submissionType': 'Document',
      'maxMarks': 50,
    },
    {
      'title': 'Chemistry Project',
      'subject': 'Chemistry',
      'dueDate': '2024-03-25',
      'priority': 'Low',
      'description': 'Research project on organic compounds',
      'submissionType': 'Presentation',
      'maxMarks': 75,
    },
  ];

  final List<Map<String, dynamic>> completedAssignments = [
    {
      'title': 'English Essay',
      'subject': 'English',
      'submittedDate': '2024-03-10',
      'grade': 'A',
      'marks': '85/100',
      'feedback': 'Excellent work with good structure and flow',
    },
    {
      'title': 'Computer Science Project',
      'subject': 'Computer Science',
      'submittedDate': '2024-03-08',
      'grade': 'B+',
      'marks': '78/100',
      'feedback': 'Good implementation but could improve documentation',
    },
    {
      'title': 'History Assignment',
      'subject': 'History',
      'submittedDate': '2024-03-05',
      'grade': 'A-',
      'marks': '88/100',
      'feedback': 'Well researched with comprehensive analysis',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Assignments',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFFF9800),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF9800),
              Color(0xFFF57C00),
              Color(0xFFE65100),
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
                        Icons.assignment,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'My Assignments',
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
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selectedTabIndex == 0
                                          ? const Color(0xFFFF9800)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Pending',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: selectedTabIndex == 0
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
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selectedTabIndex == 1
                                          ? const Color(0xFFFF9800)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Completed',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: selectedTabIndex == 1
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
                            child: selectedTabIndex == 0
                                ? _buildPendingAssignments()
                                : _buildCompletedAssignments(),
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

  Widget _buildPendingAssignments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pending Tasks',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E2E2E),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${pendingAssignments.length} tasks',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF9800),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        ...pendingAssignments.map((assignment) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
                    Expanded(
                      child: Text(
                        assignment['title'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E2E2E),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(assignment['priority']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        assignment['priority'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getPriorityColor(assignment['priority']),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  assignment['subject'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFF9800),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  assignment['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'Due: ${assignment['dueDate']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${assignment['maxMarks']} marks',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Add view details functionality
                          _showAssignmentDetails(assignment);
                        },
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('View Details'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9800),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Add submit functionality
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Submit functionality coming soon!'),
                              backgroundColor: Color(0xFFFF9800),
                            ),
                          );
                        },
                        icon: const Icon(Icons.upload, size: 16),
                        label: const Text('Submit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF9800),
                          side: const BorderSide(color: Color(0xFFFF9800)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
        
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCompletedAssignments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Completed Tasks',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E2E2E),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${completedAssignments.length} completed',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4CAF50),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        ...completedAssignments.map((assignment) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
                    Expanded(
                      child: Text(
                        assignment['title'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E2E2E),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getGradeColor(assignment['grade']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        assignment['grade'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getGradeColor(assignment['grade']),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  assignment['subject'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFF9800),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  assignment['feedback'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          'Submitted: ${assignment['submittedDate']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      assignment['marks'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _getGradeColor(assignment['grade']),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
        
        const SizedBox(height: 20),
      ],
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFF44336);
      case 'medium':
        return const Color(0xFFFF9800);
      case 'low':
        return const Color(0xFF4CAF50);
      default:
        return Colors.grey;
    }
  }

  Color _getGradeColor(String grade) {
    if (grade.startsWith('A')) {
      return const Color(0xFF4CAF50);
    } else if (grade.startsWith('B')) {
      return const Color(0xFF2196F3);
    } else if (grade.startsWith('C')) {
      return const Color(0xFFFF9800);
    } else {
      return const Color(0xFFF44336);
    }
  }

  void _showAssignmentDetails(Map<String, dynamic> assignment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            assignment['title'],
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E2E2E),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subject: ${assignment['subject']}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text('Description: ${assignment['description']}'),
              const SizedBox(height: 8),
              Text('Due Date: ${assignment['dueDate']}'),
              const SizedBox(height: 8),
              Text('Max Marks: ${assignment['maxMarks']}'),
              const SizedBox(height: 8),
              Text('Submission Type: ${assignment['submissionType']}'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}