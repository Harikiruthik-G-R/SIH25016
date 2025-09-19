import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'student_applications_list.dart';

class OnDutyScreen extends StatefulWidget {
  const OnDutyScreen({super.key});

  @override
  State<OnDutyScreen> createState() => _OnDutyScreenState();
}

class _OnDutyScreenState extends State<OnDutyScreen> with TickerProviderStateMixin {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// 🔥 Fetch groups with student count and application stats
  Stream<List<GroupData>> _fetchGroups() async* {
    final groupSnapshots = FirebaseFirestore.instance.collection('groups').snapshots();

    await for (final snapshot in groupSnapshots) {
      final groups = <GroupData>[];

      for (final doc in snapshot.docs) {
        final groupId = doc.id;
        final groupName = doc['name'] ?? '';
        final department = doc['department'] ?? '';
        final imageUrl = doc.data().containsKey('imageUrl') ? doc['imageUrl'] : null;

        // Count total students in subcollection
        final studentsSnapshot = await doc.reference.collection('students').get();
        final totalStudents = studentsSnapshot.size;

        // Fetch application stats (you can adjust to your Firestore structure)
        final applicationsSnapshot = await FirebaseFirestore.instance
            .collection('applications')
            .where('groupId', isEqualTo: groupId)
            .get();

        int pending = 0, approvedToday = 0, rejectedToday = 0;
        final today = DateTime.now();
        for (var app in applicationsSnapshot.docs) {
          final status = app['status'] ?? '';
          final ts = app['applicationDate'];
          DateTime? date;
          if (ts != null) {
            date = (ts as Timestamp).toDate();
          }

          if (status == 'Pending') {
            pending++;
          } else if (status == 'Approved' &&
              date != null &&
              date.year == today.year &&
              date.month == today.month &&
              date.day == today.day) {
            approvedToday++;
          } else if (status == 'Rejected' &&
              date != null &&
              date.year == today.year &&
              date.month == today.month &&
              date.day == today.day) {
            rejectedToday++;
          }
        }

        groups.add(GroupData(
          id: groupId,
          name: groupName,
          department: department,
          totalStudents: totalStudents,
          pendingApplications: pending,
          approvedToday: approvedToday,
          rejectedToday: rejectedToday,
          imageUrl: imageUrl,
        ));
      }

      yield groups;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildHeader(),
            _buildFiltersAndSearch(),
            Expanded(
              child: StreamBuilder<List<GroupData>>(
                stream: _fetchGroups(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState();
                  }
                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState();
                  }

                  var groups = snapshot.data!;

                  // Apply search
                  if (_searchQuery.isNotEmpty) {
                    groups = groups
                        .where((group) =>
                            group.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            group.department.toLowerCase().contains(_searchQuery.toLowerCase()))
                        .toList();
                  }

                  // Apply filters
                  switch (_selectedFilter) {
                    case 'Pending':
                      groups = groups.where((g) => g.pendingApplications > 0).toList();
                      break;
                    case 'High Priority':
                      groups = groups.where((g) => g.pendingApplications > 5).toList();
                      break;
                    case 'No Applications':
                      groups = groups.where((g) => g.pendingApplications == 0).toList();
                      break;
                  }

                  if (groups.isEmpty) {
                    return _buildNoResultsState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return _buildGroupCard(group, index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading groups...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Unable to load groups',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.groups_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No groups found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first group to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.search_off,
              size: 60,
              color: Colors.orange.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No results found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filter',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  /// HEADER
  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.green, Colors.green],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.assignment_turned_in_rounded,
              color: Colors.white,
              size: 28,
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage student applications by groups',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// SEARCH + FILTER
  Widget _buildFiltersAndSearch() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            // child: TextField(
            //   controller: _searchController,
            //   decoration: InputDecoration(
            //     hintText: 'Search groups or departments...',
            //     hintStyle: TextStyle(color: Colors.grey.shade500),
            //     prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
            //     suffixIcon: _searchQuery.isNotEmpty
            //         ? IconButton(
            //             onPressed: () {
            //               _searchController.clear();
            //               setState(() {
            //                 _searchQuery = '';
            //               });
            //             },
            //             icon: Icon(Icons.clear, color: Colors.grey.shade500),
            //           )
            //         : null,
            //     border: InputBorder.none,
            //     contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            //   ),
            //   onChanged: (value) {
            //     setState(() {
            //       _searchQuery = value;
            //     });
            //   },
            // ),
          ),
          const SizedBox(height: 16),
          // Filter Dropdown
          Row(
            children: [
              Icon(Icons.filter_list, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Filter:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFilter,
                      isExpanded: true,
                      icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                      items: ['All', 'Pending', 'High Priority', 'No Applications']
                          .map((f) => DropdownMenuItem(
                                value: f,
                                child: Text(
                                  f,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedFilter = val!),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// GROUP CARD
  Widget _buildGroupCard(GroupData group, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _showGroupDetails(group),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // Group Avatar
                        Hero(
                          tag: 'group-${group.id}',
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: group.imageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: CachedNetworkImage(
                                      imageUrl: group.imageUrl!,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => _buildDefaultAvatar(group),
                                      errorWidget: (context, url, error) => _buildDefaultAvatar(group),
                                    ),
                                  )
                                : _buildDefaultAvatar(group),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Group Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                group.department,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.blue.shade200),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.people,
                                          size: 14,
                                          color: Colors.blue.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${group.totalStudents}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue.shade600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Status Indicators
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (group.pendingApplications > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.pending_actions,
                                      size: 14,
                                      color: Colors.orange.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${group.pendingApplications}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade600,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (group.pendingApplications > 0 && group.approvedToday > 0)
                              const SizedBox(height: 8),
                            if (group.approvedToday > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: Colors.green.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${group.approvedToday}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade600,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (group.pendingApplications == 0 && group.approvedToday == 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'No pending',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultAvatar(GroupData group) {
    final initial = group.name.isNotEmpty ? group.name[0].toUpperCase() : '?';
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showGroupDetails(GroupData group) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => StudentApplicationsListScreen(
          groupName: group.name,
          groupDepartment: group.department,
          groupId: group.id,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.ease;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
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