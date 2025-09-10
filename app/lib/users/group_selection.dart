import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../sessionmanager.dart';

class GroupSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> studentData;

  const GroupSelectionScreen({super.key, required this.studentData});

  @override
  State<GroupSelectionScreen> createState() => _GroupSelectionScreenState();
}

class _GroupSelectionScreenState extends State<GroupSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? _selectedGroupId;
  String? _selectedGroupName;
  bool _isLoading = false;
  List<Map<String, dynamic>> _groups = [];

  @override
  void initState() {
    super.initState();
    debugPrint("🔥 GroupSelectionScreen initialized");
    debugPrint("📊 Student data: ${widget.studentData}");
    _initAnimations();
    _loadGroups();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
  }

  Future<void> _loadGroups() async {
    debugPrint("📚 Loading groups from Firestore...");
    setState(() => _isLoading = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .orderBy('name')
          .get()
          .timeout(const Duration(seconds: 15));

      final groups =
          querySnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] ?? '',
              'department': data['department'] ?? '',
              'maxStudents': data['maxStudents'] ?? 0,
            };
          }).toList();

      debugPrint("✅ Found ${groups.length} groups");
      for (var group in groups) {
        debugPrint("  - ${group['name']} (${group['department']})");
      }

      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Error loading groups: $e");
      setState(() => _isLoading = false);
      _showError('Failed to load groups. Please try again.');
    }
  }

  Future<void> _selectGroup() async {
    if (_selectedGroupId == null || _selectedGroupName == null) {
      _showError('Please select a group first.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Update session with selected group information
      await SessionManager.saveSession(
        isLoggedIn: true,
        isAdmin: false,
        userName: widget.studentData['name'] ?? '',
        userEmail: widget.studentData['email'] ?? '',
        rollNumber: widget.studentData['rollNumber'] ?? '',
        groupId: _selectedGroupId!,
        groupName: _selectedGroupName!,
        department: widget.studentData['department'] ?? '',
      );

      if (!mounted) return;

      // Navigate to success screen
      Navigator.pushNamed(
        context,
        '/tickscreen',
        arguments: {
          'isAdmin': false,
          'name': widget.studentData['name'],
          'email': widget.studentData['email'],
          'rollNumber': widget.studentData['rollNumber'],
          'groupId': _selectedGroupId,
          'groupName': _selectedGroupName,
          'department': widget.studentData['department'],
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to save group selection. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32), Color(0xFF1B5E20)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(),
                    const SizedBox(height: 32),

                    // Group Selection Card
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child:
                              _isLoading
                                  ? _buildLoadingState()
                                  : _buildGroupSelection(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.school, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          'Welcome, ${widget.studentData['name'] ?? 'Student'}!',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please select your classroom group to continue',
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF4CAF50), strokeWidth: 3),
          SizedBox(height: 16),
          Text(
            'Loading groups...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSelection() {
    if (_groups.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Your Classroom',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the classroom group you belong to:',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),

        // Groups List
        Expanded(
          child: ListView.builder(
            itemCount: _groups.length,
            itemBuilder: (context, index) {
              final group = _groups[index];
              final isSelected = _selectedGroupId == group['id'];

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedGroupId = group['id'];
                      _selectedGroupName = group['name'];
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? const Color(0xFF4CAF50).withOpacity(0.1)
                              : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            isSelected
                                ? const Color(0xFF4CAF50)
                                : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? const Color(0xFF4CAF50)
                                    : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.class_,
                            color:
                                isSelected
                                    ? Colors.white
                                    : Colors.grey.shade600,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group['name'] ?? '',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isSelected
                                          ? const Color(0xFF4CAF50)
                                          : Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Department: ${group['department'] ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                'Max Students: ${group['maxStudents'] ?? 0}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF4CAF50),
                            size: 28,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 24),

        // Continue Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                _selectedGroupId != null && !_isLoading ? _selectGroup : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Text(
                      'Continue to Attendance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Groups Available',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'There are no classroom groups available at the moment. Please contact your administrator.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadGroups,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
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
}
