import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'student_applications_list.dart';

class OnDutyScreen extends StatefulWidget {
  const OnDutyScreen({super.key});

  @override
  State<OnDutyScreen> createState() => _OnDutyScreenState();
}

class _OnDutyScreenState extends State<OnDutyScreen> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Sample data - replace with actual database data
  List<GroupData> _groups = [
    GroupData(
      id: '1',
      name: 'CSE 3rd Year A',
      department: 'Computer Science',
      totalStudents: 45,
      pendingApplications: 8,
      approvedToday: 12,
      rejectedToday: 2,
      imageUrl: null,
    ),
    GroupData(
      id: '2',
      name: 'ECE 2nd Year B',
      department: 'Electronics',
      totalStudents: 42,
      pendingApplications: 5,
      approvedToday: 8,
      rejectedToday: 1,
      imageUrl: null,
    ),
    GroupData(
      id: '3',
      name: 'MECH 4th Year',
      department: 'Mechanical',
      totalStudents: 38,
      pendingApplications: 12,
      approvedToday: 6,
      rejectedToday: 3,
      imageUrl: null,
    ),
    GroupData(
      id: '4',
      name: 'IT 1st Year A',
      department: 'Information Technology',
      totalStudents: 50,
      pendingApplications: 3,
      approvedToday: 15,
      rejectedToday: 0,
      imageUrl: null,
    ),
    GroupData(
      id: '5',
      name: 'Civil 3rd Year',
      department: 'Civil Engineering',
      totalStudents: 35,
      pendingApplications: 7,
      approvedToday: 4,
      rejectedToday: 2,
      imageUrl: null,
    ),
  ];

  List<GroupData> get _filteredGroups {
    List<GroupData> filtered = _groups;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((group) =>
              group.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              group.department.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Apply status filter
    switch (_selectedFilter) {
      case 'Pending':
        filtered = filtered.where((group) => group.pendingApplications > 0).toList();
        break;
      case 'High Priority':
        filtered = filtered.where((group) => group.pendingApplications > 5).toList();
        break;
      case 'No Applications':
        filtered = filtered.where((group) => group.pendingApplications == 0).toList();
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
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Column(
        children: [
          _buildHeader(),
          _buildFiltersAndSearch(),
          Expanded(
            child: _buildGroupsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'On-Duty Applications',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E2E2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage student leave applications by group',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: _buildSummaryCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalPending = _groups.fold<int>(0, (sum, group) => sum + group.pendingApplications);
    final totalApproved = _groups.fold<int>(0, (sum, group) => sum + group.approvedToday);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                totalPending.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Pending',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                totalApproved.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Approved Today',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ],
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
                decoration: InputDecoration(
                  hintText: 'Search groups or departments...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF4CAF50)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                items: ['All', 'Pending', 'High Priority', 'No Applications']
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

  Widget _buildGroupsList() {
    final filteredGroups = _filteredGroups;

    if (filteredGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No groups found',
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
      itemCount: filteredGroups.length,
      itemBuilder: (context, index) {
        final group = filteredGroups[index];
        return _buildGroupCard(group);
      },
    );
  }

  Widget _buildGroupCard(GroupData group) {
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
          onTap: () => _showGroupDetails(group),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildGroupAvatar(group),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildGroupInfo(group),
                ),
                const SizedBox(width: 16),
                _buildNotificationBadges(group),
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

  Widget _buildGroupAvatar(GroupData group) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            _getGroupColor(group.department),
            _getGroupColor(group.department).withOpacity(0.8),
          ],
        ),
      ),
      child: group.imageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: group.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildDefaultGroupIcon(group),
                errorWidget: (context, url, error) => _buildDefaultGroupIcon(group),
              ),
            )
          : _buildDefaultGroupIcon(group),
    );
  }

  Widget _buildDefaultGroupIcon(GroupData group) {
    return Center(
      child: Text(
        group.name.split(' ').take(2).map((word) => word[0]).join(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getGroupColor(String department) {
    switch (department.toLowerCase()) {
      case 'computer science':
        return const Color(0xFF2196F3);
      case 'electronics':
        return const Color(0xFF4CAF50);
      case 'mechanical':
        return const Color(0xFFFF9800);
      case 'information technology':
        return const Color(0xFF9C27B0);
      case 'civil engineering':
        return const Color(0xFF795548);
      default:
        return const Color(0xFF607D8B);
    }
  }

  Widget _buildGroupInfo(GroupData group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E2E2E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          group.department,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.people,
              size: 16,
              color: Colors.grey.shade500,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '${group.totalStudents} students',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: group.pendingApplications > 5
                      ? Colors.red.withOpacity(0.1)
                      : group.pendingApplications > 0
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  group.pendingApplications > 5
                      ? 'High Priority'
                      : group.pendingApplications > 0
                          ? 'Pending Review'
                          : 'Up to Date',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: group.pendingApplications > 5
                        ? Colors.red
                        : group.pendingApplications > 0
                            ? Colors.orange
                            : Colors.green,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationBadges(GroupData group) {
    return Column(
      children: [
        if (group.pendingApplications > 0)
          _buildBadge(
            count: group.pendingApplications,
            color: Colors.red,
            icon: Icons.pending_actions,
            label: 'Pending',
          ),
        if (group.approvedToday > 0) ...[
          const SizedBox(height: 8),
          _buildBadge(
            count: group.approvedToday,
            color: Colors.green,
            icon: Icons.check_circle,
            label: 'Approved',
          ),
        ],
        if (group.rejectedToday > 0) ...[
          const SizedBox(height: 8),
          _buildBadge(
            count: group.rejectedToday,
            color: Colors.grey,
            icon: Icons.cancel,
            label: 'Rejected',
          ),
        ],
      ],
    );
  }

  Widget _buildBadge({
    required int count,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            count.toString(),
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

  void _showGroupDetails(GroupData group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentApplicationsListScreen(
          groupName: group.name,
          groupDepartment: group.department,
          groupId: group.id,
        ),
      ),
    );
  }
}

class GroupData {
  final String id;
  final String name;
  final String department;
  final int totalStudents;
  final int pendingApplications;
  final int approvedToday;
  final int rejectedToday;
  final String? imageUrl;

  GroupData({
    required this.id,
    required this.name,
    required this.department,
    required this.totalStudents,
    required this.pendingApplications,
    required this.approvedToday,
    required this.rejectedToday,
    this.imageUrl,
  });
}