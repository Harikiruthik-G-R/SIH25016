import 'package:flutter/material.dart';

class GradesScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String rollNumber;
  final String groupId;
  final String groupName;
  final String department;

  const GradesScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.rollNumber,
    required this.groupId,
    required this.groupName,
    required this.department,
  });

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  List<Map<String, dynamic>> grades = [];
  bool isLoading = true;
  String selectedSemester = 'All Semesters';
  
  final List<String> semesters = [
    'All Semesters',
    'Semester 1',
    'Semester 2',
    'Semester 3',
    'Semester 4',
    'Semester 5',
    'Semester 6',
    'Semester 7',
    'Semester 8'
  ];

  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  Future<void> _loadGrades() async {
    // Simulate API call delay
    await Future.delayed(const Duration(seconds: 2));
    
    // Mock data - replace with actual API call
    setState(() {
      grades = [
        {
          'subject': 'Data Structures',
          'code': 'CS101',
          'semester': 'Semester 3',
          'credits': 4,
          'grade': 'A',
          'points': 9.0,
          'type': 'Core'
        },
        {
          'subject': 'Database Management',
          'code': 'CS102',
          'semester': 'Semester 4',
          'credits': 3,
          'grade': 'A+',
          'points': 10.0,
          'type': 'Core'
        },
        {
          'subject': 'Operating Systems',
          'code': 'CS201',
          'semester': 'Semester 4',
          'credits': 4,
          'grade': 'B+',
          'points': 8.0,
          'type': 'Core'
        },
        {
          'subject': 'Software Engineering',
          'code': 'CS301',
          'semester': 'Semester 5',
          'credits': 3,
          'grade': 'A',
          'points': 9.0,
          'type': 'Core'
        },
        {
          'subject': 'Web Development',
          'code': 'CS302',
          'semester': 'Semester 5',
          'credits': 3,
          'grade': 'A+',
          'points': 10.0,
          'type': 'Elective'
        },
      ];
      isLoading = false;
    });
  }

  List<Map<String, dynamic>> get filteredGrades {
    if (selectedSemester == 'All Semesters') {
      return grades;
    }
    return grades.where((grade) => grade['semester'] == selectedSemester).toList();
  }

  double get currentGPA {
    if (filteredGrades.isEmpty) return 0.0;
    
    double totalPoints = 0;
    int totalCredits = 0;
    
    for (var grade in filteredGrades) {
      totalPoints += (grade['points'] as double) * (grade['credits'] as int);
      totalCredits += grade['credits'] as int;
    }
    
    return totalCredits > 0 ? totalPoints / totalCredits : 0.0;
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A+':
        return Colors.green.shade600;
      case 'A':
        return Colors.green.shade500;
      case 'B+':
        return Colors.blue.shade500;
      case 'B':
        return Colors.blue.shade400;
      case 'C+':
        return Colors.orange.shade500;
      case 'C':
        return Colors.orange.shade400;
      default:
        return Colors.red.shade500;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Grades'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Student Info Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Roll No: ${widget.rollNumber} | ${widget.department}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Group: ${widget.groupName}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // GPA Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current GPA',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  currentGPA.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: currentGPA >= 8.0 
                        ? Colors.green 
                        : currentGPA >= 6.0 
                            ? Colors.orange 
                            : Colors.red,
                  ),
                ),
              ],
            ),
          ),

          // Semester Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'Filter by Semester:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    value: selectedSemester,
                    isExpanded: true,
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedSemester = newValue!;
                      });
                    },
                    items: semesters.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Grades List
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : filteredGrades.isEmpty
                    ? const Center(
                        child: Text(
                          'No grades found for selected semester',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredGrades.length,
                        itemBuilder: (context, index) {
                          final grade = filteredGrades[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                grade['subject'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Code: ${grade['code']}'),
                                  Text('${grade['semester']} | ${grade['credits']} Credits'),
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: grade['type'] == 'Core' 
                                          ? Colors.blue.shade50 
                                          : Colors.purple.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      grade['type'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: grade['type'] == 'Core' 
                                            ? Colors.blue.shade700 
                                            : Colors.purple.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getGradeColor(grade['grade']),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  grade['grade'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}