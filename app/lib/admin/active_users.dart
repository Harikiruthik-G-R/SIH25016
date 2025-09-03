
// active_users_screen.dart
import 'package:flutter/material.dart';

class ActiveUsersScreen extends StatefulWidget {
  const ActiveUsersScreen({super.key});

  @override
  State<ActiveUsersScreen> createState() => _ActiveUsersScreenState();
}

class _ActiveUsersScreenState extends State<ActiveUsersScreen> {
  final List<Map<String, dynamic>> _activeUsers = [
    {
      'name': 'John Doe',
      'email': 'john@example.com',
      'role': 'Student',
      'group': 'Computer Science',
      'lastSeen': DateTime.now().subtract(const Duration(minutes: 5)),
      'status': 'online',
      'location': 'Main Campus',
    },
    {
      'name': 'Jane Smith',
      'email': 'jane@example.com',
      'role': 'Faculty',
      'group': 'Mathematics',
      'lastSeen': DateTime.now().subtract(const Duration(hours: 1)),
      'status': 'away',
      'location': 'Library',
    },
    {
      'name': 'Mike Johnson',
      'email': 'mike@example.com',
      'role': 'Student',
      'group': 'Physics',
      'lastSeen': DateTime.now().subtract(const Duration(minutes: 15)),
      'status': 'online',
      'location': 'Lab Building',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Users'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshUsers,
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
        child: Column(
          children: [
            // Stats Header
            Container(
              margin: const EdgeInsets.all(16),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Online', _activeUsers.where((u) => u['status'] == 'online').length, Colors.green),
                  _buildStatItem('Away', _activeUsers.where((u) => u['status'] == 'away').length, Colors.orange),
                  _buildStatItem('Total', _activeUsers.length, const Color(0xFF4CAF50)),
                ],
              ),
            ),
            
            // Users List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _activeUsers.length,
                itemBuilder: (context, index) {
                  final user = _activeUsers[index];
                  return _buildUserCard(user);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    Color statusColor = user['status'] == 'online' ? Colors.green : Colors.orange;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.person,
                color: Color(0xFF4CAF50),
                size: 24,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          user['name'],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email']),
            Text('${user['role']} - ${user['group']}'),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  user['location'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                user['status'].toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatLastSeen(user['lastSeen']),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _refreshUsers() {
    // TODO: Implement refresh logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Users refreshed'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }
}
