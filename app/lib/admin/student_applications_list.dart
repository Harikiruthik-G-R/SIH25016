import 'package:flutter/material.dart';
import 'onduty_aproval.dart';

class StudentApplicationsListScreen extends StatefulWidget {
  final String groupName;
  final String groupDepartment;
  final String groupId;

  const StudentApplicationsListScreen({
    super.key,
    required this.groupName,
    required this.groupDepartment,
    required this.groupId,
  });

  @override
  State<StudentApplicationsListScreen> createState() => _StudentApplicationsListScreenState();
}

class _StudentApplicationsListScreenState extends State<StudentApplicationsListScreen> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Sample student application data - replace with actual database data
  List<StudentApplication> _applications = [
    StudentApplication(
      id: '1',
      studentName: 'John Doe',
      rollNumber: '20CSE001',
      reason: 'Medical appointment',
      fromDate: DateTime.now().subtract(const Duration(days: 1)),
      toDate: DateTime.now().add(const Duration(days: 1)),
      status: 'Pending',
      appliedDate: DateTime.now().subtract(const Duration(hours: 2)),
      imageUrl: null,
    ),
    StudentApplication(
      id: '2',
      studentName: 'Jane Smith',
      rollNumber: '20CSE002',
      reason: 'Family emergency',
      fromDate: DateTime.now(),
      toDate: DateTime.now().add(const Duration(days: 2)),
      status: 'Pending',
      appliedDate: DateTime.now().subtract(const Duration(hours: 5)),
      imageUrl: null,
    ),
    StudentApplication(
      id: '3',
      studentName: 'Mike Johnson',
      rollNumber: '20CSE003',
      reason: 'Personal work',
      fromDate: DateTime.now().add(const Duration(days: 1)),
      toDate: DateTime.now().add(const Duration(days: 1)),
      status: 'Approved',
      appliedDate: DateTime.now().subtract(const Duration(hours: 8)),
      imageUrl: null,
    ),
    StudentApplication(
      id: '4',
      studentName: 'Sarah Wilson',
      rollNumber: '20CSE004',
      reason: 'Interview',
      fromDate: DateTime.now().add(const Duration(days: 2)),
      toDate: DateTime.now().add(const Duration(days: 2)),
      status: 'Pending',
      appliedDate: DateTime.now().subtract(const Duration(minutes: 30)),
      imageUrl: null,
    ),
  ];

  List<StudentApplication> get _filteredApplications {
    List<StudentApplication> filtered = _applications;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((app) =>
              app.studentName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              app.rollNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              app.reason.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Apply status filter
    switch (_selectedFilter) {
      case 'Pending':
        filtered = filtered.where((app) => app.status == 'Pending').toList();
        break;
      case 'Approved':
        filtered = filtered.where((app) => app.status == 'Approved').toList();
        break;
      case 'Rejected':
        filtered = filtered.where((app) => app.status == 'Rejected').toList();
        break;
      default:
        break;
    }

    return filtered;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.groupDepartment,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildFiltersAndSearch(),
          Expanded(
            child: _buildApplicationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final pendingCount = _applications.where((app) => app.status == 'Pending').length;
    final approvedCount = _applications.where((app) => app.status == 'Approved').length;
    final rejectedCount = _applications.where((app) => app.status == 'Rejected').length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'On-Duty Applications',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E2E2E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Review and approve student applications',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatusChip('Pending', pendingCount, Colors.orange),
              const SizedBox(width: 8),
              _buildStatusChip('Approved', approvedCount, Colors.green),
              const SizedBox(width: 8),
              _buildStatusChip('Rejected', rejectedCount, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersAndSearch() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search students, roll numbers, or reasons...',
                  prefixIcon: Icon(Icons.search, color: Color(0xFF4CAF50)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilter,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                items: ['All', 'Pending', 'Approved', 'Rejected']
                    .map((filter) => DropdownMenuItem(
                          value: filter,
                          child: Text(filter),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsList() {
    final filteredApplications = _filteredApplications;

    if (filteredApplications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No applications found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filter criteria',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: filteredApplications.length,
      itemBuilder: (context, index) {
        final application = filteredApplications[index];
        return _buildApplicationCard(application);
      },
    );
  }

  Widget _buildApplicationCard(StudentApplication application) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToApproval(application),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildStudentAvatar(application),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildApplicationInfo(application),
                ),
                const SizedBox(width: 16),
                _buildStatusBadge(application),
                const SizedBox(width: 12),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentAvatar(StudentApplication application) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
        ),
      ),
      child: application.imageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                application.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(application),
              ),
            )
          : _buildDefaultAvatar(application),
    );
  }

  Widget _buildDefaultAvatar(StudentApplication application) {
    return Center(
      child: Text(
        application.studentName.split(' ').map((word) => word[0]).join(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildApplicationInfo(StudentApplication application) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          application.studentName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E2E2E),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          application.rollNumber,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          application.reason,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              Icons.access_time,
              size: 14,
              color: Colors.grey.shade500,
            ),
            const SizedBox(width: 4),
            Text(
              _formatTimeAgo(application.appliedDate),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(StudentApplication application) {
    Color color;
    IconData icon;
    
    switch (application.status) {
      case 'Approved':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'Rejected':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.orange;
        icon = Icons.pending_actions;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            application.status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _navigateToApproval(StudentApplication application) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OnDutyApprovalScreen(
          studentApplication: application,
          groupName: widget.groupName,
        ),
      ),
    );
  }
}

class StudentApplication {
  final String id;
  final String studentName;
  final String rollNumber;
  final String reason;
  final DateTime fromDate;
  final DateTime toDate;
  final String status;
  final DateTime appliedDate;
  final String? imageUrl;

  StudentApplication({
    required this.id,
    required this.studentName,
    required this.rollNumber,
    required this.reason,
    required this.fromDate,
    required this.toDate,
    required this.status,
    required this.appliedDate,
    this.imageUrl,
  });
}