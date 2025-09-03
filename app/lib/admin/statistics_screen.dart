import 'package:flutter/material.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _selectedPeriod = 'This Week';
  final List<String> _periods = ['Today', 'This Week', 'This Month', 'This Year'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            initialValue: _selectedPeriod,
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
              });
            },
            itemBuilder: (context) => _periods.map((period) {
              return PopupMenuItem<String>(
                value: period,
                child: Text(period),
              );
            }).toList(),
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedPeriod,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF0F8F0)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overview Cards
              Row(
                children: [
                  Expanded(
                    child: _buildOverviewCard(
                      'Total Check-ins',
                      '1,234',
                      Icons.check_circle,
                      const Color(0xFF4CAF50),
                      '+12.5%',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildOverviewCard(
                      'Active Users',
                      '89',
                      Icons.people,
                      const Color(0xFF2196F3),
                      '+5.2%',
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildOverviewCard(
                      'Avg. Daily',
                      '176',
                      Icons.trending_up,
                      const Color(0xFFFF9800),
                      '+8.1%',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildOverviewCard(
                      'Peak Hour',
                      '9:00 AM',
                      Icons.schedule,
                      const Color(0xFF9C27B0),
                      'Same',
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              
              // Charts Section
              const Text(
                'Attendance Trends',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E2E2E),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Chart Container
              Container(
                height: 250,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Chart will be implemented here',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Recent Activity
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E2E2E),
                ),
              ),
              
              const SizedBox(height: 16),
              
              _buildActivityList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String change,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                child: Icon(icon, color: color, size: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: change.contains('-')
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  change,
                  style: TextStyle(
                    color: change.contains('-') ? Colors.red : Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E2E2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList() {
    final activities = [
      {
        'user': 'John Doe',
        'action': 'Checked in',
        'location': 'Main Campus',
        'time': '2 minutes ago',
      },
      {
        'user': 'Jane Smith',
        'action': 'Checked out',
        'location': 'Library',
        'time': '15 minutes ago',
      },
      {
        'user': 'Mike Johnson',
        'action': 'Checked in',
        'location': 'Lab Building',
        'time': '1 hour ago',
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: activities.length,
        separatorBuilder: (context, index) => Divider(
          color: Colors.grey.shade200,
          height: 1,
        ),
        itemBuilder: (context, index) {
          final activity = activities[index];
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person,
                color: Color(0xFF4CAF50),
                size: 24,
              ),
            ),
            title: Text(
              activity['user']!,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${activity['action']} at ${activity['location']}',
            ),
            trailing: Text(
              activity['time']!,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          );
        },
      ),
    );
  }
}