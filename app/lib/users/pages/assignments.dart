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

class _AssignmentsScreenState extends State<AssignmentsScreen>
    with SingleTickerProviderStateMixin {
  int selectedTabIndex = 0;
  late TabController _tabController;
  String searchQuery = '';
  String filterPriority = 'All';
  bool isSearchVisible = false;

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
      'instructions': 'Show all working steps clearly. Use proper mathematical notation.',
      'resources': ['Chapter 3 Textbook', 'Practice Problems PDF'],
    },
    {
      'title': 'Physics Lab Report',
      'subject': 'Physics',
      'dueDate': '2024-03-18',
      'priority': 'Medium',
      'description': 'Write a detailed lab report on electromagnetic induction experiment',
      'submissionType': 'Document',
      'maxMarks': 50,
      'instructions': 'Include hypothesis, methodology, results, and conclusion.',
      'resources': ['Lab Manual', 'Sample Report Template'],
    },
    {
      'title': 'Chemistry Project',
      'subject': 'Chemistry',
      'dueDate': '2024-03-25',
      'priority': 'Low',
      'description': 'Research project on organic compounds',
      'submissionType': 'Presentation',
      'maxMarks': 75,
      'instructions': 'Prepare a 15-minute presentation with visual aids.',
      'resources': ['Chemistry Database', 'Reference Articles'],
    },
  ];

  final List<Map<String, dynamic>> completedAssignments = [
    {
      'title': 'English Essay',
      'subject': 'English',
      'submittedDate': '2024-03-10',
      'grade': 'A',
      'marks': '85/100',
      'feedback': 'Excellent work with good structure and flow. Consider adding more supporting evidence.',
      'attachments': ['essay_final.pdf'],
    },
    {
      'title': 'Computer Science Project',
      'subject': 'Computer Science',
      'submittedDate': '2024-03-08',
      'grade': 'B+',
      'marks': '78/100',
      'feedback': 'Good implementation but could improve documentation. Code structure is solid.',
      'attachments': ['project_code.zip', 'documentation.pdf'],
    },
    {
      'title': 'History Assignment',
      'subject': 'History',
      'submittedDate': '2024-03-05',
      'grade': 'A-',
      'marks': '88/100',
      'feedback': 'Well researched with comprehensive analysis. Minor formatting issues.',
      'attachments': ['history_report.docx'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get filteredPendingAssignments {
    return pendingAssignments.where((assignment) {
      final matchesSearch = assignment['title']
              .toString()
              .toLowerCase()
              .contains(searchQuery.toLowerCase()) ||
          assignment['subject']
              .toString()
              .toLowerCase()
              .contains(searchQuery.toLowerCase());
      final matchesPriority =
          filterPriority == 'All' || assignment['priority'] == filterPriority;
      return matchesSearch && matchesPriority;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Assignments',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor:Color(0xFF43A047),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(isSearchVisible ? Icons.close : Icons.search, size: 20),
            onPressed: () {
              setState(() {
                isSearchVisible = !isSearchVisible;
                if (!isSearchVisible) {
                  searchQuery = '';
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white, size: 20),
            onSelected: (String value) {
              setState(() {
                filterPriority = value;
              });
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'All', child: Text('All Priority')),
              const PopupMenuItem(value: 'High', child: Text('High Priority')),
              const PopupMenuItem(value: 'Medium', child: Text('Medium Priority')),
              const PopupMenuItem(value: 'Low', child: Text('Low Priority')),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF43A047),
              Color(0xFF43A047),
              Color(0xFF43A047),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section - More compact
              // Container(
              //   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              //   child: Column(
              //     children: [
              //       Container(
              //         padding: const EdgeInsets.all(12),
              //         decoration: BoxDecoration(
              //           color: Colors.white.withOpacity(0.2),
              //           borderRadius: BorderRadius.circular(12),
              //         ),
              //         child: const Icon(
              //           Icons.assignment,
              //           size: 28,
              //           color: Colors.white,
              //         ),
              //       ),
              //       const SizedBox(height: 12),
              //       const Text(
              //         'My Assignments',
              //         style: TextStyle(
              //           fontSize: 20,
              //           fontWeight: FontWeight.w600,
              //           color: Colors.white,
              //         ),
              //         textAlign: TextAlign.center,
              //       ),
              //       const SizedBox(height: 4),
              //       Text(
              //         widget.userName,
              //         style: TextStyle(
              //           fontSize: 14,
              //           color: Colors.white.withOpacity(0.9),
              //           fontWeight: FontWeight.w400,
              //         ),
              //       ),
              //       // Search Bar - More compact
              //       if (isSearchVisible) ...[
              //         const SizedBox(height: 12),
              //         Container(
              //           height: 40,
              //           decoration: BoxDecoration(
              //             color: Colors.white.withOpacity(0.2),
              //             borderRadius: BorderRadius.circular(20),
              //           ),
              //           child: TextField(
              //             onChanged: (value) {
              //               setState(() {
              //                 searchQuery = value;
              //               });
              //             },
              //             decoration: const InputDecoration(
              //               hintText: 'Search assignments...',
              //               hintStyle: TextStyle(color: Colors.white70, fontSize: 14),
              //               prefixIcon: Icon(Icons.search, color: Colors.white70, size: 18),
              //               border: InputBorder.none,
              //               contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              //             ),
              //             style: const TextStyle(color: Colors.white, fontSize: 14),
              //           ),
              //         ),
              //       ],
              //     ],
              //   ),
              // ),

              // Content Section
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    child: Column(
                      children: [
                        // Tab Selector - More compact
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              onTap: (index) {
                                setState(() {
                                  selectedTabIndex = index;
                                });
                              },
                              indicator: BoxDecoration(
                                color: Color(0xFF43A047),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              labelColor: Colors.white,
                              unselectedLabelColor: Colors.grey.shade600,
                              labelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                              tabs: [
                                Tab(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.pending_actions, size: 14),
                                      const SizedBox(width: 6),
                                      Text('Pending (${filteredPendingAssignments.length})'),
                                    ],
                                  ),
                                ),
                                Tab(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.check_circle, size: 14),
                                      const SizedBox(width: 6),
                                      Text('Completed (${completedAssignments.length})'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Content List
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildPendingAssignments(),
                              _buildCompletedAssignments(),
                            ],
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
      floatingActionButton: selectedTabIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                _showUploadDialog();
              },
              backgroundColor: Color(0xFF43A047),
              child: const Icon(Icons.add, size: 20),
            )
          : null,
    );
  }

  Widget _buildPendingAssignments() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards - More compact
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total',
                  filteredPendingAssignments.length.toString(),
                  Icons.assignment,
                  const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryCard(
                  'High Priority',
                  filteredPendingAssignments
                      .where((a) => a['priority'] == 'High')
                      .length
                      .toString(),
                  Icons.priority_high,
                  const Color(0xFFF44336),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (filteredPendingAssignments.isEmpty) ...[
            const Center(
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No assignments found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ...filteredPendingAssignments.map((assignment) {
              return _buildPendingAssignmentCard(assignment);
            }),
          ],

          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildCompletedAssignments() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grade Statistics
          _buildGradeStatistics(),
          const SizedBox(height: 16),

          ...completedAssignments.map((assignment) {
            return _buildCompletedAssignmentCard(assignment);
          }),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
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
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAssignmentCard(Map<String, dynamic> assignment) {
    final daysLeft = _getDaysLeft(assignment['dueDate']);
    final isUrgent = daysLeft <= 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
        border: isUrgent
            ? Border.all(color: const Color(0xFFF44336), width: 1.5)
            : Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - More compact
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getPriorityColor(assignment['priority']).withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    assignment['title'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                Row(
                  children: [
                    if (isUrgent) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF44336),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'URGENT',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(assignment['priority']),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        assignment['priority'],
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content - More compact
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment['subject'],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  assignment['description'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                
                // Due date and marks info - More compact
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: isUrgent ? const Color(0xFFF44336) : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$daysLeft days left',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isUrgent ? FontWeight.w600 : FontWeight.normal,
                        color: isUrgent ? const Color(0xFFF44336) : Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${assignment['maxMarks']} pts',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                
                // Action buttons - More compact
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showEnhancedAssignmentDetails(assignment),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF43A047),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('View', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showSubmissionDialog(assignment),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2E7D32),
                          side: const BorderSide(color: Color(0xFF2E7D32), width: 1),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text('Submit', style: TextStyle(fontSize: 12)),
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
  }

  Widget _buildCompletedAssignmentCard(Map<String, dynamic> assignment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _getGradeColor(assignment['grade']).withOpacity(0.2),
          width: 0.5,
        ),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getGradeColor(assignment['grade']),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  assignment['grade'],
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            assignment['subject'],
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              assignment['feedback'],
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
                height: 1.3,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 3),
                  Text(
                    'Submitted: ${assignment['submittedDate']}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              Text(
                assignment['marks'],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getGradeColor(assignment['grade']),
                ),
              ),
            ],
          ),
          if (assignment['attachments'] != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: (assignment['attachments'] as List<String>).take(2).map((file) {
                return Chip(
                  label: Text(
                    file,
                    style: const TextStyle(fontSize: 9),
                  ),
                  backgroundColor: Colors.grey.shade100,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGradeStatistics() {
    final gradeCount = <String, int>{};
    for (final assignment in completedAssignments) {
      final grade = assignment['grade'] as String;
      gradeCount[grade] = (gradeCount[grade] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2E7D32).withOpacity(0.1),
            const Color(0xFF43A047).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grade Distribution',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: gradeCount.entries.map((entry) {
              return Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _getGradeColor(entry.key),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        entry.value.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  int _getDaysLeft(String dueDateString) {
    final dueDate = DateTime.parse(dueDateString);
    final now = DateTime.now();
    return dueDate.difference(now).inDays;
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

  void _showEnhancedAssignmentDetails(Map<String, dynamic> assignment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  assignment['title'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getPriorityColor(assignment['priority']),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  assignment['priority'],
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Subject', assignment['subject']),
                _buildDetailRow('Description', assignment['description']),
                _buildDetailRow('Due Date', assignment['dueDate']),
                _buildDetailRow('Max Marks', assignment['maxMarks'].toString()),
                _buildDetailRow('Submission Type', assignment['submissionType']),
                
                if (assignment['instructions'] != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Instructions:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      assignment['instructions'],
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],

                if (assignment['resources'] != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Resources:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  ...assignment['resources'].map<Widget>((resource) => 
                    Container(
                      margin: const EdgeInsets.only(bottom: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.attach_file, size: 10),
                          const SizedBox(width: 3),
                          Text(
                            resource,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ).toList(),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(fontSize: 12)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showSubmissionDialog(assignment);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit Assignment', style: TextStyle(fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSubmissionDialog(Map<String, dynamic> assignment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Submit: ${assignment['title']}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.upload_file, color: Color(0xFF2E7D32), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upload ${assignment['submissionType']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Max: ${assignment['maxMarks']} marks',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const TextField(
                maxLines: 2,
                style: TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'Comments (Optional)',
                  labelStyle: TextStyle(fontSize: 12),
                  hintText: 'Add any comments about your submission...',
                  hintStyle: TextStyle(fontSize: 11),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(8),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(fontSize: 12)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _handleFileUpload(assignment);
              },
              icon: const Icon(Icons.upload, size: 16),
              label: const Text('Choose File', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showUploadDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Quick Submission',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select an assignment to submit:',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              ...filteredPendingAssignments.take(3).map((assignment) =>
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: _getPriorityColor(assignment['priority']),
                    child: Text(
                      assignment['priority'][0],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  title: Text(
                    assignment['title'],
                    style: const TextStyle(fontSize: 12),
                  ),
                  subtitle: Text(
                    assignment['subject'],
                    style: const TextStyle(fontSize: 10),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showSubmissionDialog(assignment);
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  void _handleFileUpload(Map<String, dynamic> assignment) {
    // Show a snackbar for demo purposes
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'File upload initiated for ${assignment['title']}',
          style: const TextStyle(fontSize: 12),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
    
    // Here you would implement actual file upload logic
    // Example: using file_picker package
    /*
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        File file = File(result.files.single.path!);
        // Upload file logic here
      }
    } catch (e) {
      // Handle error
    }
    */
  }
}