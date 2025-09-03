import 'package:flutter/material.dart';

class MyScheduleScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String rollNumber;
  final String groupId;
  final String groupName;
  final String department;

  const MyScheduleScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.rollNumber,
    required this.groupId,
    required this.groupName,
    required this.department,
  });

  @override
  State<MyScheduleScreen> createState() => _MyScheduleScreenState();
}

class _MyScheduleScreenState extends State<MyScheduleScreen> {
  int selectedDayIndex = DateTime.now().weekday - 1;
  
  final List<String> weekDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  // Sample schedule data - replace with actual data
  final Map<String, List<Map<String, String>>> scheduleData = {
    'Monday': [
      {'time': '9:00 AM - 10:30 AM', 'subject': 'Mathematics', 'room': 'Room 101'},
      {'time': '11:00 AM - 12:30 PM', 'subject': 'Physics', 'room': 'Lab 202'},
      {'time': '2:00 PM - 3:30 PM', 'subject': 'Chemistry', 'room': 'Lab 301'},
    ],
    'Tuesday': [
      {'time': '10:00 AM - 11:30 AM', 'subject': 'English', 'room': 'Room 205'},
      {'time': '1:00 PM - 2:30 PM', 'subject': 'Computer Science', 'room': 'Lab 401'},
    ],
    'Wednesday': [
      {'time': '9:00 AM - 10:30 AM', 'subject': 'Biology', 'room': 'Lab 501'},
      {'time': '11:00 AM - 12:30 PM', 'subject': 'History', 'room': 'Room 302'},
      {'time': '3:00 PM - 4:30 PM', 'subject': 'Physical Education', 'room': 'Gymnasium'},
    ],
    'Thursday': [
      {'time': '8:00 AM - 9:30 AM', 'subject': 'Mathematics', 'room': 'Room 101'},
      {'time': '10:00 AM - 11:30 AM', 'subject': 'Physics', 'room': 'Lab 202'},
    ],
    'Friday': [
      {'time': '9:00 AM - 10:30 AM', 'subject': 'Chemistry', 'room': 'Lab 301'},
      {'time': '11:00 AM - 12:30 PM', 'subject': 'English', 'room': 'Room 205'},
      {'time': '2:00 PM - 3:30 PM', 'subject': 'Computer Science', 'room': 'Lab 401'},
    ],
    'Saturday': [
      {'time': '10:00 AM - 11:30 AM', 'subject': 'Extra Activities', 'room': 'Multi-purpose Hall'},
    ],
    'Sunday': [],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Schedule',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2196F3),
              Color(0xFF1976D2),
              Color(0xFF1565C0),
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
                        Icons.schedule,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Class Timetable',
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
                        // Day Selector
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select Day',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E2E2E),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 50,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: weekDays.length,
                                  itemBuilder: (context, index) {
                                    final isSelected = index == selectedDayIndex;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedDayIndex = index;
                                        });
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 12),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFF2196F3)
                                              : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        child: Center(
                                          child: Text(
                                            weekDays[index].substring(0, 3),
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.grey.shade600,
                                              fontWeight: FontWeight.w600,
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
                        ),
                        
                        // Schedule List
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${weekDays[selectedDayIndex]} Schedule',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E2E2E),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Schedule Items
                                _buildScheduleList(),
                                
                                const SizedBox(height: 20),
                              ],
                            ),
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

  Widget _buildScheduleList() {
    final daySchedule = scheduleData[weekDays[selectedDayIndex]] ?? [];
    
    if (daySchedule.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.free_breakfast,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No classes scheduled',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enjoy your free day!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: daySchedule.asMap().entries.map((entry) {
        final index = entry.key;
        final schedule = entry.value;
        
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
                  color: const Color(0xFF2196F3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.access_time,
                  color: Color(0xFF2196F3),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule['subject'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E2E2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      schedule['time'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      schedule['room'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}