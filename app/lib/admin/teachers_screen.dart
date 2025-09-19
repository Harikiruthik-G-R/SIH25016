import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'dart:io';
import 'dart:math' as math;

class TeachersScreen extends StatefulWidget {
  const TeachersScreen({super.key});

  @override
  State<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends State<TeachersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore.collection('teachers').get();
      setState(() {
        _teachers =
            snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList();
      });
    } catch (e) {
      _showErrorSnackBar('Error loading teachers: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredTeachers {
    if (_searchQuery.isEmpty) return _teachers;
    return _teachers.where((teacher) {
      final name = teacher['name']?.toString().toLowerCase() ?? '';
      final email = teacher['email']?.toString().toLowerCase() ?? '';
      final department = teacher['department']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          email.contains(query) ||
          department.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FDF8), Colors.white],
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading ? _buildLoadingState() : _buildTeachersList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
    );
  }

  Widget _buildTeachersList() {
    if (_filteredTeachers.isEmpty) {
      return _buildEmptyState();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        itemCount: _filteredTeachers.length,
        itemBuilder: (context, index) {
          return _buildTeacherCard(_filteredTeachers[index], index);
        },
      ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher, int index) {
    final subjects = teacher['subjects'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showTeacherDetails(teacher),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4CAF50),
                            const Color(0xFF66BB6A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4CAF50).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            teacher['name'] ?? 'Unknown Name',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(
                                0xFF1A1A1A,
                              ), // Darker for better contrast
                              letterSpacing: 0.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            teacher['designation'] ?? 'No designation',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF4A4A4A), // Better contrast
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            teacher['department'] ?? 'No department',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF666666), // Improved readability
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: PopupMenuButton(
                        padding: EdgeInsets.zero,
                        icon: Container(
                          padding: const EdgeInsets.all(10),
                          child: const Icon(
                            Icons.more_vert_rounded,
                            size: 22,
                            color: Color(0xFF666666),
                          ),
                        ),
                        itemBuilder:
                            (context) => [
                              const PopupMenuItem(
                                value: 'view',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.visibility_rounded,
                                      size: 18,
                                      color: Color(0xFF4CAF50),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'View Details',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'subjects',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.book_rounded,
                                      size: 18,
                                      color: Color(0xFF2196F3),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Manage Subjects',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'groups',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.groups_rounded,
                                      size: 18,
                                      color: Color(0xFF9C27B0),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Manage Groups',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.edit_rounded,
                                      size: 18,
                                      color: Color(0xFFFF9800),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Edit',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.delete_rounded,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                        onSelected:
                            (value) =>
                                _handleTeacherAction(value.toString(), teacher),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FDF8), // Lighter background
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        Icons.email_rounded,
                        teacher['email'] ?? 'No email',
                        color: const Color(0xFF1976D2),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.phone_rounded,
                        teacher['phone'] ?? 'No phone',
                        color: const Color(0xFF388E3C),
                      ),
                      if (subjects.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.book_rounded,
                          'Subjects: ${subjects.length}',
                          color: const Color(0xFF7B1FA2),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              subjects.take(3).map((subject) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF4CAF50,
                                        ).withOpacity(0.3),
                                        offset: const Offset(0, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    _getSubjectDisplayName(subject),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          Colors
                                              .white, // White text on green background
                                      letterSpacing: 0.2,
                                      height: 1.2,
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                        if (subjects.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '+${subjects.length - 3} more subjects',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF666666),
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                      // Display assigned groups
                      Builder(
                        builder: (context) {
                          final assignedGroups =
                              teacher['assignedGroups'] as List<dynamic>? ?? [];
                          if (assignedGroups.isEmpty) return const SizedBox();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                Icons.groups_rounded,
                                'Groups: ${assignedGroups.length}',
                                color: const Color(0xFF9C27B0),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    assignedGroups.take(2).map((group) {
                                      final groupName =
                                          group is Map
                                              ? group['name'] ?? 'Unnamed Group'
                                              : group.toString();
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF9C27B0),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF9C27B0,
                                              ).withOpacity(0.3),
                                              offset: const Offset(0, 2),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          groupName,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            letterSpacing: 0.2,
                                            height: 1.2,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                              if (assignedGroups.length > 2)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '+${assignedGroups.length - 2} more groups',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF666666),
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {required Color color}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF2A2A2A), // Dark text for better readability
              fontSize: 15,
              letterSpacing: 0.1,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Improved header with better text contrast
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16), // reduced
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2E7D32),
            const Color(0xFF4CAF50),
            const Color(0xFF66BB6A),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12), // smaller icon padding
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 26,
                  ), // smaller icon
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Teachers Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22, // smaller
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage faculty and their subjects',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14, // smaller
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16), // reduced space
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showAddTeacherDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2E7D32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.person_add_rounded, size: 20),
                    label: const Text(
                      'Add Teacher',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showBulkUploadDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.25),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.upload_file_rounded, size: 20),
                    label: const Text(
                      'Bulk Upload',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12), // reduced
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search teachers...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.white.withOpacity(0.9),
                    size: 22,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Improved empty state
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school_rounded,
                size: 60,
                color: const Color(0xFF4CAF50).withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _searchQuery.isEmpty ? 'No Teachers Added' : 'No Teachers Found',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2A2A2A),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Start by adding teachers to manage your faculty'
                  : 'Try searching with different keywords',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showAddTeacherDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Add First Teacher',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleTeacherAction(String action, Map<String, dynamic> teacher) {
    switch (action) {
      case 'view':
        _showTeacherDetails(teacher);
        break;
      case 'subjects':
        _showManageSubjectsDialog(teacher);
        break;
      case 'groups':
        _showManageGroupsDialog(teacher);
        break;
      case 'edit':
        _showAddTeacherDialog(teacher: teacher);
        break;
      case 'delete':
        _showDeleteConfirmation(teacher['id']);
        break;
    }
  }

  void _showAddTeacherDialog({Map<String, dynamic>? teacher}) {
    showDialog(
      context: context,
      builder:
          (context) =>
              AddTeacherDialog(teacher: teacher, onTeacherAdded: _loadTeachers),
    );
  }

  void _showBulkUploadDialog() {
    showDialog(
      context: context,
      builder: (context) => BulkUploadDialog(onUploadCompleted: _loadTeachers),
    );
  }

  // Helper function to get subject display name
  String _getSubjectDisplayName(dynamic subject) {
    if (subject is String) {
      return subject;
    } else if (subject is Map) {
      final name = subject['name']?.toString() ?? '';
      final code = subject['code']?.toString() ?? '';
      if (code.isNotEmpty) {
        return '$code\n$name';
      }
      return name;
    }
    return subject.toString();
  }

  void _showTeacherDetails(Map<String, dynamic> teacher) {
    showDialog(
      context: context,
      builder: (context) => TeacherDetailsDialog(teacher: teacher),
    );
  }

  void _showManageSubjectsDialog(Map<String, dynamic> teacher) {
    showDialog(
      context: context,
      builder:
          (context) => ManageSubjectsDialog(
            teacher: teacher,
            onSubjectsUpdated: _loadTeachers,
          ),
    );
  }

  void _showManageGroupsDialog(Map<String, dynamic> teacher) {
    showDialog(
      context: context,
      builder:
          (context) => ManageGroupsDialog(
            teacher: teacher,
            onGroupsUpdated: _loadTeachers,
          ),
    );
  }

  void _showDeleteConfirmation(String teacherId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Teacher'),
            content: const Text(
              'Are you sure you want to delete this teacher? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _deleteTeacher(teacherId);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteTeacher(String teacherId) async {
    try {
      await _firestore.collection('teachers').doc(teacherId).delete();
      _showSuccessSnackBar('Teacher deleted successfully');
      _loadTeachers();
    } catch (e) {
      _showErrorSnackBar('Error deleting teacher: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// Add Teacher Dialog
class AddTeacherDialog extends StatefulWidget {
  final Map<String, dynamic>? teacher;
  final VoidCallback onTeacherAdded;

  const AddTeacherDialog({
    super.key,
    this.teacher,
    required this.onTeacherAdded,
  });

  @override
  State<AddTeacherDialog> createState() => _AddTeacherDialogState();
}

class _AddTeacherDialogState extends State<AddTeacherDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _designationController = TextEditingController();
  final _departmentController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _specializationController = TextEditingController();
  final _joiningDateController = TextEditingController();
  final _experienceController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.teacher != null) {
      _nameController.text = widget.teacher!['name'] ?? '';
      _emailController.text = widget.teacher!['email'] ?? '';
      _phoneController.text = widget.teacher!['phone'] ?? '';
      _designationController.text = widget.teacher!['designation'] ?? '';
      _departmentController.text = widget.teacher!['department'] ?? '';
      _qualificationController.text = widget.teacher!['qualification'] ?? '';
      _specializationController.text = widget.teacher!['specialization'] ?? '';
      _joiningDateController.text = widget.teacher!['joiningDate'] ?? '';
      _experienceController.text = widget.teacher!['experience'] ?? '';
      _passwordController.text = widget.teacher!['password'] ?? '';
    }
  }

  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF4CAF50), const Color(0xFF66BB6A)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(
              Icons.person_add_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.teacher != null ? 'Edit Teacher' : 'Add New Teacher',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E2E2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.teacher != null
                      ? 'Update teacher information'
                      : 'Fill in the details below',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
              color: Colors.grey[600],
              splashRadius: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Personal Information',
            Icons.person_outline_rounded,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_rounded,
                  isRequired: true,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Please enter name';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.email_rounded,
                  isRequired: true,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Please enter email';
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value!)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _phoneController,
            label: 'Phone Number',
            icon: Icons.phone_rounded,
            isRequired: true,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Please enter phone number';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildPasswordField(),

          const SizedBox(height: 32),
          _buildSectionHeader(
            'Professional Details',
            Icons.work_outline_rounded,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _designationController,
                  label: 'Designation',
                  icon: Icons.badge_rounded,
                  isRequired: true,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter designation';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _departmentController,
                  label: 'Department',
                  icon: Icons.business_rounded,
                  isRequired: true,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter department';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _qualificationController,
                  label: 'Qualification',
                  icon: Icons.school_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _specializationController,
                  label: 'Specialization',
                  icon: Icons.stars_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          _buildSectionHeader('Employment Details', Icons.timeline_rounded),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _joiningDateController,
                  label: 'Date of Joining',
                  icon: Icons.calendar_today_rounded,
                  hintText: 'DD.MM.YYYY',
                  keyboardType: TextInputType.datetime,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _experienceController,
                  label: 'Experience',
                  icon: Icons.trending_up_rounded,
                  hintText: 'e.g., 5 years',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF4CAF50), size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2E2E2E),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey[300]!, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    String? hintText,
    bool isRequired = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
            children:
                isRequired
                    ? const [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ]
                    : [],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                offset: const Offset(0, 2),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hintText ?? 'Enter $label',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF4CAF50), size: 20),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF4CAF50),
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: 'Password',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                offset: const Offset(0, 2),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            validator: (value) {
              if (value != null && value.isNotEmpty && value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Enter password for teacher login (optional)',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[600],
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF4CAF50),
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!, width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors:
                      _isLoading
                          ? [Colors.grey[400]!, Colors.grey[500]!]
                          : [const Color(0xFF4CAF50), const Color(0xFF66BB6A)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow:
                    _isLoading
                        ? null
                        : [
                          BoxShadow(
                            color: const Color(0xFF4CAF50).withOpacity(0.3),
                            offset: const Offset(0, 4),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTeacher,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                        : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.teacher != null
                                  ? Icons.update_rounded
                                  : Icons.person_add_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                widget.teacher != null
                                    ? 'Update Teacher'
                                    : 'Add Teacher',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced build method for the dialog
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isWideScreen = screenSize.width > 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.transparent,
      child: Container(
        width:
            isWideScreen
                ? math.min(screenSize.width * 0.85, 1200.0)
                : screenSize.width * 0.95,
        height: math.min(screenSize.height * 0.85, 800.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, 10),
              blurRadius: 30,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 4),
              blurRadius: 10,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildDialogHeader(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildFormFields(),
                      // Add some bottom padding for better scroll experience
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveTeacher() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final teacherData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'designation': _designationController.text.trim(),
        'department': _departmentController.text.trim(),
        'qualification': _qualificationController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'joiningDate': _joiningDateController.text.trim(),
        'experience': _experienceController.text.trim(),
        'subjects': widget.teacher?['subjects'] ?? [],
        'assignedGroups': widget.teacher?['assignedGroups'] ?? [],
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Only include password if it's not empty
      final passwordText = _passwordController.text.trim();
      if (passwordText.isNotEmpty) {
        teacherData['password'] = passwordText;
      }

      if (widget.teacher != null) {
        // Updating existing teacher
        await FirebaseFirestore.instance
            .collection('teachers')
            .doc(widget.teacher!['id'])
            .update(teacherData)
            .timeout(const Duration(seconds: 30));
        if (mounted) {
          _showSuccessSnackBar('Teacher updated successfully');
          Navigator.pop(context);
          widget.onTeacherAdded();
        }
      } else {
        // Adding new teacher
        teacherData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('teachers')
            .add(teacherData)
            .timeout(const Duration(seconds: 30));
        if (mounted) {
          _showSuccessSnackBar('Teacher added successfully');
          Navigator.pop(context);
          widget.onTeacherAdded();
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error saving teacher: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _qualificationController.dispose();
    _specializationController.dispose();
    _joiningDateController.dispose();
    _experienceController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// Bulk Upload Dialog
class BulkUploadDialog extends StatefulWidget {
  final VoidCallback onUploadCompleted;

  const BulkUploadDialog({super.key, required this.onUploadCompleted});

  @override
  State<BulkUploadDialog> createState() => _BulkUploadDialogState();
}

class _BulkUploadDialogState extends State<BulkUploadDialog> {
  String? _selectedFileName;
  List<List<dynamic>>? _parsedData;
  bool _isLoading = false;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogHeader(),
            const SizedBox(height: 24),
            _buildFileUploadSection(),
            if (_parsedData != null) ...[
              const SizedBox(height: 16),
              _buildPreviewSection(),
            ],
            const Spacer(),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.upload_file, color: Color(0xFF4CAF50)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Bulk Upload Teachers',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildFileUploadSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_upload, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            _selectedFileName ?? 'No file selected',
            style: TextStyle(
              color: _selectedFileName != null ? Colors.black87 : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isLoading ? null : _selectFile,
            child:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Select CSV/Excel File'),
          ),
          const SizedBox(height: 8),
          Text(
            'Expected format: Name, Email, Phone, Designation, Department, Qualification, Specialization, Joining Date, Experience, Password (optional)\n\nNote: If password is not provided, default password "teacher123" will be assigned. Subjects should be added individually after importing teachers using the "Manage Subjects" option.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    if (_parsedData == null || _parsedData!.isEmpty) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text(
              'No data to preview',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview (${_parsedData!.isNotEmpty ? _parsedData!.length - 1 : 0} teachers)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns:
                        _parsedData!.isNotEmpty
                            ? _parsedData![0].map((header) {
                              return DataColumn(
                                label: Text(
                                  header.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList()
                            : [],
                    rows:
                        _parsedData!.length > 1
                            ? _parsedData!.skip(1).take(5).map((row) {
                              return DataRow(
                                cells:
                                    row.map((cell) {
                                      return DataCell(
                                        Text(
                                          cell?.toString() ?? '',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                              );
                            }).toList()
                            : [],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed:
              (_parsedData != null && !_isProcessing) ? _uploadTeachers : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
          ),
          child:
              _isProcessing
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Text(
                    'Upload Teachers',
                    style: TextStyle(color: Colors.white),
                  ),
        ),
      ],
    );
  }

  Future<void> _selectFile() async {
    setState(() => _isLoading = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;

        setState(() => _selectedFileName = fileName);

        // Process file in background to avoid blocking UI
        if (fileName.toLowerCase().endsWith('.csv')) {
          await _parseCSVInBackground(file);
        } else {
          await _parseExcelInBackground(file);
        }
      } else {
        print('File selection cancelled or path is null');
      }
    } catch (e) {
      print('File selection error: $e');
      _showErrorSnackBar('Error selecting file: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _parseCSVInBackground(File file) async {
    try {
      // Use compute to run parsing in background isolate
      final parsedData = await compute(_parseCSVIsolate, file.path);
      if (mounted) {
        setState(() => _parsedData = parsedData);
        print('Valid rows: ${parsedData.length}');
      }
    } catch (e) {
      print('CSV parsing error: $e');
      if (mounted) {
        _showErrorSnackBar('Error parsing CSV: $e');
      }
    }
  }

  Future<void> _parseExcelInBackground(File file) async {
    try {
      // Use compute to run parsing in background isolate
      final parsedData = await compute(_parseExcelIsolate, file.path);
      if (mounted) {
        setState(() => _parsedData = parsedData);
        print('Valid rows: ${parsedData.length}');
      }
    } catch (e) {
      print('Excel parsing error: $e');
      if (mounted) {
        _showErrorSnackBar('Error parsing Excel: $e');
      }
    }
  }

  // Static method for isolate - CSV parsing
  static Future<List<List<dynamic>>> _parseCSVIsolate(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();

      // Parse the entire CSV content at once
      final fields = const CsvToListConverter().convert(content);

      // Filter out empty rows
      final nonEmptyFields =
          fields
              .where(
                (row) =>
                    row.isNotEmpty &&
                    row.any((cell) => cell.toString().trim().isNotEmpty),
              )
              .toList();

      return nonEmptyFields;
    } catch (e) {
      print('CSV isolate parsing error: $e');
      return [];
    }
  }

  // Static method for isolate - Excel parsing
  static Future<List<List<dynamic>>> _parseExcelIsolate(String filePath) async {
    try {
      print('Excel parsing started for: $filePath');
      final file = File(filePath);

      if (!await file.exists()) {
        print('Excel file does not exist: $filePath');
        return [];
      }

      final bytes = await file.readAsBytes();
      print('Excel file bytes read: ${bytes.length}');

      final excel = excel_pkg.Excel.decodeBytes(bytes);
      print('Excel decoded, tables count: ${excel.tables.length}');

      if (excel.tables.isEmpty) {
        print('Excel has no tables');
        return [];
      }

      final tableName = excel.tables.keys.first;
      print('Processing table: $tableName');
      final table = excel.tables[tableName];

      if (table == null) {
        print('Table is null');
        return [];
      }

      if (table.rows.isEmpty) {
        print('Table has no rows');
        return [];
      }

      print('Table has ${table.rows.length} rows');
      final result = <List<dynamic>>[];

      for (int i = 0; i < table.rows.length; i++) {
        final row = table.rows[i];
        final processedRow = <dynamic>[];
        for (int j = 0; j < row.length; j++) {
          final cell = row[j];
          processedRow.add(cell?.value?.toString() ?? '');
        }
        result.add(processedRow);
      }

      print('Excel parsing completed, returning ${result.length} rows');
      return result;
    } catch (e, stackTrace) {
      print('Excel isolate parsing error: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<void> _uploadTeachers() async {
    print('_uploadTeachers called');
    print('_parsedData is null: ${_parsedData == null}');
    print('_parsedData length: ${_parsedData?.length ?? 0}');

    if (_parsedData != null && _parsedData!.isNotEmpty) {
      print('First few rows of parsed data:');
      for (int i = 0; i < _parsedData!.length && i < 3; i++) {
        print('Row $i: ${_parsedData![i]}');
      }
    }

    if (_parsedData == null || _parsedData!.length < 2) {
      _showErrorSnackBar(
        'No valid data to upload. Expected format: Name, Email, Phone, Designation, Department, Qualification, Specialization, Joining Date, Experience, Password (optional)',
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      print('Starting to upload ${_parsedData!.length - 1} teachers');
      final batch = FirebaseFirestore.instance.batch();
      int successCount = 0;

      for (int i = 1; i < _parsedData!.length; i++) {
        final row = _parsedData![i];
        print('Processing row $i: $row');

        if (row.length >= 3) {
          // At least name, email, phone
          final teacherData = {
            'name': row[0]?.toString().trim() ?? '',
            'email': row[1]?.toString().trim() ?? '',
            'phone': row[2]?.toString().trim() ?? '',
            'designation':
                row.length > 3 ? row[3]?.toString().trim() ?? '' : '',
            'department': row.length > 4 ? row[4]?.toString().trim() ?? '' : '',
            'qualification':
                row.length > 5 ? row[5]?.toString().trim() ?? '' : '',
            'specialization':
                row.length > 6 ? row[6]?.toString().trim() ?? '' : '',
            'joiningDate':
                row.length > 7 ? row[7]?.toString().trim() ?? '' : '',
            'experience': row.length > 8 ? row[8]?.toString().trim() ?? '' : '',
            'password':
                row.length > 9
                    ? row[9]?.toString().trim() ?? ''
                    : 'teacher123', // Default password if not provided
            'subjects': [],
            'createdAt': FieldValue.serverTimestamp(),
          };

          // Validate required fields
          if (teacherData['name'].toString().isEmpty ||
              teacherData['email'].toString().isEmpty) {
            print('Skipping row $i: missing required fields');
            continue;
          }

          final docRef =
              FirebaseFirestore.instance.collection('teachers').doc();
          batch.set(docRef, teacherData);
          successCount++;
        } else {
          print('Skipping row $i: insufficient data (${row.length} columns)');
        }
      }

      if (successCount > 0) {
        await batch.commit();
        _showSuccessSnackBar('$successCount teachers uploaded successfully!');
        Navigator.pop(context);
        widget.onUploadCompleted();
      } else {
        _showErrorSnackBar('No valid teachers found to upload');
      }
    } catch (e) {
      print('Upload error: $e');
      _showErrorSnackBar('Error uploading teachers: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }
}

// Teacher Details Dialog
class TeacherDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> teacher;

  const TeacherDetailsDialog({super.key, required this.teacher});

  // Helper function to get subject display name
  String _getSubjectDisplayName(dynamic subject) {
    if (subject is String) {
      return subject;
    } else if (subject is Map) {
      final name = subject['name']?.toString() ?? '';
      final code = subject['code']?.toString() ?? '';
      if (code.isNotEmpty) {
        return '$name ($code)';
      }
      return name;
    }
    return subject.toString();
  }

  @override
  Widget build(BuildContext context) {
    final subjects = teacher['subjects'] as List<dynamic>? ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.5,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF4CAF50),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher['name'] ?? 'Unknown Name',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      Text(
                        teacher['designation'] ?? 'No designation',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow('Department', teacher['department']),
            _buildDetailRow('Email', teacher['email']),
            _buildDetailRow('Phone', teacher['phone']),
            _buildDetailRow('Qualification', teacher['qualification']),
            _buildDetailRow('Specialization', teacher['specialization']),
            _buildDetailRow('Date of Joining', teacher['joiningDate']),
            _buildDetailRow('Experience', teacher['experience']),
            _buildPasswordRow('Password', teacher['password']),
            if (subjects.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Assigned Subjects:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    subjects.map((subject) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF4CAF50).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _getSubjectDisplayName(subject),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ],
            // Display assigned groups
            Builder(
              builder: (context) {
                final assignedGroups =
                    teacher['assignedGroups'] as List<dynamic>? ?? [];
                if (assignedGroups.isEmpty) return const SizedBox();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Assigned Groups:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children:
                          assignedGroups.map((group) {
                            final groupName =
                                group is Map
                                    ? group['name'] ?? 'Unnamed Group'
                                    : group.toString();
                            final department =
                                group is Map ? group['department'] ?? '' : '';

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9C27B0).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(
                                    0xFF9C27B0,
                                  ).withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    groupName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6A1B9A),
                                    ),
                                  ),
                                  if (department.isNotEmpty)
                                    Text(
                                      department,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Text(
                  '•' * 8, // Show masked password
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Text(
                    'Set',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Manage Subjects Dialog
class ManageSubjectsDialog extends StatefulWidget {
  final Map<String, dynamic> teacher;
  final VoidCallback onSubjectsUpdated;

  const ManageSubjectsDialog({
    super.key,
    required this.teacher,
    required this.onSubjectsUpdated,
  });

  @override
  State<ManageSubjectsDialog> createState() => _ManageSubjectsDialogState();
}

class _ManageSubjectsDialogState extends State<ManageSubjectsDialog> {
  final _subjectController = TextEditingController();
  final _subjectCodeController = TextEditingController();
  List<Map<String, String>> _subjects = [];
  List<Map<String, String>> _availableSubjects = [];
  bool _isLoading = false;
  bool _isLoadingAvailableSubjects = false;

  @override
  void initState() {
    super.initState();
    // Convert existing subjects from string to map format
    final existingSubjects = widget.teacher['subjects'] ?? [];
    _subjects =
        existingSubjects.map<Map<String, String>>((subject) {
          if (subject is String) {
            return {'name': subject, 'code': ''};
          } else if (subject is Map) {
            return {
              'name': subject['name']?.toString() ?? '',
              'code': subject['code']?.toString() ?? '',
            };
          }
          return {'name': '', 'code': ''};
        }).toList();

    // Load available subjects from assigned groups' timetables
    _loadAvailableSubjectsFromTimetables();
  }

  Future<void> _loadAvailableSubjectsFromTimetables() async {
    setState(() => _isLoadingAvailableSubjects = true);

    try {
      final assignedGroups =
          widget.teacher['assignedGroups'] as List<dynamic>? ?? [];

      if (assignedGroups.isEmpty) {
        setState(() => _availableSubjects = []);
        return;
      }

      // Get group IDs
      final groupIds =
          assignedGroups
              .map((group) {
                if (group is Map) return group['id']?.toString() ?? '';
                return group.toString();
              })
              .where((id) => id.isNotEmpty)
              .toList();

      if (groupIds.isEmpty) {
        setState(() => _availableSubjects = []);
        return;
      }

      // Query timetables for these groups
      final timetablesSnapshot =
          await FirebaseFirestore.instance
              .collection('timetables')
              .where('groupId', whereIn: groupIds)
              .get();

      final subjectSet = <String>{};

      // Extract subjects from timetables
      for (final timetableDoc in timetablesSnapshot.docs) {
        final timetableData = timetableDoc.data();
        final schedule =
            timetableData['schedule'] as Map<String, dynamic>? ?? {};

        // Iterate through days and periods to collect subjects
        for (final daySchedule in schedule.values) {
          if (daySchedule is Map<String, dynamic>) {
            for (final periodData in daySchedule.values) {
              if (periodData is Map<String, dynamic>) {
                final subject = periodData['subject']?.toString().trim();
                if (subject != null &&
                    subject.isNotEmpty &&
                    subject != 'Break' &&
                    subject != 'Lunch') {
                  subjectSet.add(subject);
                }
              }
            }
          }
        }
      }

      // Convert to list of maps for consistency
      final availableSubjects =
          subjectSet
              .map(
                (subject) => {
                  'name': subject,
                  'code': '', // Will be filled when user selects
                },
              )
              .toList();

      availableSubjects.sort((a, b) => a['name']!.compareTo(b['name']!));

      setState(() => _availableSubjects = availableSubjects);
    } catch (e) {
      print('Error loading available subjects: $e');
      setState(() => _availableSubjects = []);
    } finally {
      setState(() => _isLoadingAvailableSubjects = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: screenWidth > 600 ? screenWidth * 0.5 : screenWidth * 0.9,
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.9,
          minHeight: 300,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.book, color: Color(0xFF4CAF50)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Manage Subjects - ${widget.teacher['name']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Available subjects from assigned groups' timetables
            if (_availableSubjects.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          color: Color(0xFF4CAF50),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Available Subjects from Assigned Groups\' Timetables',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        if (_isLoadingAvailableSubjects)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF4CAF50),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _availableSubjects.map((subject) {
                            final isAlreadyAdded = _subjects.any(
                              (s) =>
                                  s['name']?.toLowerCase() ==
                                  subject['name']?.toLowerCase(),
                            );

                            return GestureDetector(
                              onTap:
                                  isAlreadyAdded
                                      ? null
                                      : () {
                                        setState(() {
                                          _subjectController.text =
                                              subject['name'] ?? '';
                                          _subjectCodeController
                                              .clear(); // User will need to enter code
                                        });
                                      },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isAlreadyAdded
                                          ? Colors.grey.withOpacity(0.3)
                                          : const Color(
                                            0xFF4CAF50,
                                          ).withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color:
                                        isAlreadyAdded
                                            ? Colors.grey
                                            : const Color(0xFF4CAF50),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isAlreadyAdded ? Icons.check : Icons.add,
                                      size: 16,
                                      color:
                                          isAlreadyAdded
                                              ? Colors.grey[600]
                                              : Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      subject['name'] ?? '',
                                      style: TextStyle(
                                        color:
                                            isAlreadyAdded
                                                ? Colors.grey[600]
                                                : Colors.white,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    if (_availableSubjects.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Tap on a subject to select it, then add a subject code below',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF666666),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New Subject',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Subject Name *',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF424242),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _subjectController,
                        decoration: InputDecoration(
                          hintText: 'e.g., Internet of Things',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF4CAF50),
                              width: 2,
                            ),
                          ),
                          prefixIcon: const Icon(
                            Icons.book,
                            color: Color(0xFF4CAF50),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onSubmitted: (_) => _addSubject(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Subject Code *',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF424242),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _subjectCodeController,
                        decoration: InputDecoration(
                          hintText: 'e.g., 22CSL40',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF4CAF50),
                              width: 2,
                            ),
                          ),
                          prefixIcon: const Icon(
                            Icons.code,
                            color: Color(0xFF4CAF50),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onSubmitted: (_) => _addSubject(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _addSubject,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'Add Subject',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Assigned Subjects:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Flexible(
              child:
                  _subjects.isEmpty
                      ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.book_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No subjects assigned',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add subjects using the form above',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      : ListView.builder(
                        itemCount: _subjects.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF4CAF50).withOpacity(0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF4CAF50,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.book,
                                    color: Color(0xFF4CAF50),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _subjects[index]['name'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                      if (_subjects[index]['code']
                                              ?.isNotEmpty ==
                                          true) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF4CAF50,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            'Code: ${_subjects[index]['code']}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF4CAF50),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _removeSubject(index),
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveSubjects,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text(
                            'Save',
                            style: TextStyle(color: Colors.white),
                          ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addSubject() {
    final subjectName = _subjectController.text.trim();
    final subjectCode = _subjectCodeController.text.trim();

    if (subjectName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter subject name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (subjectCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter subject code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final newSubject = {'name': subjectName, 'code': subjectCode};

    // Check if subject with same name or code already exists
    final existingByName = _subjects.indexWhere(
      (subject) => subject['name']?.toLowerCase() == subjectName.toLowerCase(),
    );

    final existingByCode = _subjects.indexWhere(
      (subject) => subject['code']?.toLowerCase() == subjectCode.toLowerCase(),
    );

    if (existingByName != -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subject name "$subjectName" already exists'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } else if (existingByCode != -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subject code "$subjectCode" already exists'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      setState(() {
        _subjects.add(newSubject);
        _subjectController.clear();
        _subjectCodeController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subject "$subjectName" added successfully'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    }
  }

  void _removeSubject(int index) {
    setState(() {
      _subjects.removeAt(index);
    });
  }

  Future<void> _saveSubjects() async {
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('teachers')
          .doc(widget.teacher['id'])
          .update({
            'subjects': _subjects,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      _showSuccessSnackBar('Subjects updated successfully');
      Navigator.pop(context);
      widget.onSubjectsUpdated();
    } catch (e) {
      _showErrorSnackBar('Error updating subjects: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _subjectCodeController.dispose();
    super.dispose();
  }
}

// Manage Groups Dialog
class ManageGroupsDialog extends StatefulWidget {
  final Map<String, dynamic> teacher;
  final VoidCallback onGroupsUpdated;

  const ManageGroupsDialog({
    super.key,
    required this.teacher,
    required this.onGroupsUpdated,
  });

  @override
  State<ManageGroupsDialog> createState() => _ManageGroupsDialogState();
}

class _ManageGroupsDialogState extends State<ManageGroupsDialog> {
  List<Map<String, dynamic>> _allGroups = [];
  List<String> _assignedGroupIds = [];
  List<Map<String, dynamic>> _availableGroups = [];
  bool _isLoading = true;
  bool _isLoadingAvailableGroups = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadGroupsAndAssignments();
    _loadAvailableGroupsFromTimetables();
  }

  Future<void> _loadAvailableGroupsFromTimetables() async {
    setState(() => _isLoadingAvailableGroups = true);

    try {
      // Get teacher's assigned subjects
      final assignedSubjects =
          widget.teacher['subjects'] as List<dynamic>? ?? [];
      if (assignedSubjects.isEmpty) {
        setState(() => _availableGroups = []);
        return;
      }

      final subjectNames =
          assignedSubjects
              .map((subject) {
                if (subject is String) return subject.toLowerCase();
                if (subject is Map) {
                  return (subject['name']?.toString() ?? '').toLowerCase();
                }
                return '';
              })
              .where((name) => name.isNotEmpty)
              .toSet();

      // Get all timetables
      final timetablesSnapshot =
          await FirebaseFirestore.instance.collection('timetables').get();

      final Map<String, Map<String, dynamic>> groupsWithSubjects = {};

      // Analyze each timetable to find groups with matching subjects
      for (final timetableDoc in timetablesSnapshot.docs) {
        final timetableData = timetableDoc.data();
        final groupId = timetableData['groupId']?.toString();
        final schedule =
            timetableData['schedule'] as Map<String, dynamic>? ?? {};

        if (groupId == null) continue;

        // Check if this timetable has any of the teacher's subjects
        bool hasMatchingSubjects = false;
        for (final daySchedule in schedule.values) {
          if (daySchedule is Map<String, dynamic>) {
            for (final periodData in daySchedule.values) {
              if (periodData is Map<String, dynamic>) {
                final subject =
                    periodData['subject']?.toString().toLowerCase().trim();
                if (subject != null && subjectNames.contains(subject)) {
                  hasMatchingSubjects = true;
                  break;
                }
              }
            }
            if (hasMatchingSubjects) break;
          }
        }

        if (hasMatchingSubjects) {
          // Get group details
          try {
            final groupDoc =
                await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(groupId)
                    .get();

            if (groupDoc.exists) {
              final groupData = groupDoc.data()!;
              groupData['id'] = groupDoc.id;
              groupsWithSubjects[groupId] = groupData;
            }
          } catch (e) {
            // Continue if group doesn't exist
          }
        }
      }

      setState(() => _availableGroups = groupsWithSubjects.values.toList());
    } catch (e) {
      print('Error loading available groups from timetables: $e');
    } finally {
      setState(() => _isLoadingAvailableGroups = false);
    }
  }

  Future<void> _loadGroupsAndAssignments() async {
    setState(() => _isLoading = true);

    try {
      // Get teacher's assigned subjects
      final assignedSubjects =
          widget.teacher['subjects'] as List<dynamic>? ?? [];
      final subjectNames =
          assignedSubjects
              .map((subject) {
                if (subject is String) return subject.toLowerCase();
                if (subject is Map) {
                  return (subject['name']?.toString() ?? '').toLowerCase();
                }
                return '';
              })
              .where((name) => name.isNotEmpty)
              .toSet();

      // Load all groups from Firestore
      final groupsSnapshot =
          await FirebaseFirestore.instance
              .collection('groups')
              .orderBy('name')
              .get();

      List<Map<String, dynamic>> allGroups =
          groupsSnapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

      // If teacher has assigned subjects, filter groups that have those subjects in their timetables
      if (subjectNames.isNotEmpty) {
        final filteredGroups = <Map<String, dynamic>>[];

        for (final group in allGroups) {
          // Check if this group has any timetables with the teacher's subjects
          final timetablesSnapshot =
              await FirebaseFirestore.instance
                  .collection('timetables')
                  .where('groupId', isEqualTo: group['id'])
                  .get();

          bool hasMatchingSubjects = false;

          for (final timetableDoc in timetablesSnapshot.docs) {
            final timetableData = timetableDoc.data();
            final schedule =
                timetableData['schedule'] as Map<String, dynamic>? ?? {};

            // Check if any period has a matching subject
            for (final daySchedule in schedule.values) {
              if (daySchedule is Map<String, dynamic>) {
                for (final periodData in daySchedule.values) {
                  if (periodData is Map<String, dynamic>) {
                    final subject =
                        periodData['subject']?.toString().toLowerCase().trim();
                    if (subject != null && subjectNames.contains(subject)) {
                      hasMatchingSubjects = true;
                      break;
                    }
                  }
                }
                if (hasMatchingSubjects) break;
              }
            }
            if (hasMatchingSubjects) break;
          }

          if (hasMatchingSubjects) {
            filteredGroups.add(group);
          }
        }

        _allGroups = filteredGroups;
      } else {
        // If no subjects assigned, show all groups
        _allGroups = allGroups;
      }

      // Get currently assigned groups for this teacher
      final assignedGroups =
          widget.teacher['assignedGroups'] as List<dynamic>? ?? [];
      _assignedGroupIds =
          assignedGroups
              .map((group) {
                if (group is String) return group;
                if (group is Map) return group['id']?.toString() ?? '';
                return '';
              })
              .where((id) => id.isNotEmpty)
              .toList();
    } catch (e) {
      _showErrorSnackBar('Error loading groups: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: screenWidth > 600 ? screenWidth * 0.6 : screenWidth * 0.9,
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.8,
          minHeight: 400,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _isLoading ? _buildLoadingState() : _buildGroupsList(),
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF9C27B0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.groups_rounded,
            color: Color(0xFF9C27B0),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Manage Groups',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'Assign groups to ${widget.teacher['name'] ?? 'Teacher'}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey[100],
            foregroundColor: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Expanded(
      child: Center(child: CircularProgressIndicator(color: Color(0xFF9C27B0))),
    );
  }

  Widget _buildGroupsList() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Available Groups from Timetables Section
          _buildAvailableGroupsSection(),

          const SizedBox(height: 16),

          // Main Groups List
          if (_allGroups.isEmpty)
            _buildEmptyGroupsState()
          else
            _buildMainGroupsList(),
        ],
      ),
    );
  }

  Widget _buildAvailableGroupsSection() {
    final assignedSubjects = widget.teacher['subjects'] as List<dynamic>? ?? [];

    if (assignedSubjects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Assign subjects first to see groups with those subjects in their timetables',
                style: TextStyle(color: Colors.orange[700], fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule, color: Color(0xFF9C27B0), size: 20),
            const SizedBox(width: 8),
            const Text(
              'Groups from Timetables',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9C27B0),
              ),
            ),
            if (_isLoadingAvailableGroups) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF9C27B0),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Groups that have your assigned subjects in their timetables',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 12),

        if (_availableGroups.isEmpty && !_isLoadingAvailableGroups)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              'No groups found with your assigned subjects in their timetables',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          )
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    _availableGroups.map((group) {
                      final isAlreadyAssigned = _assignedGroupIds.contains(
                        group['id'],
                      );
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(group['name'] ?? 'Unnamed Group'),
                          selected: isAlreadyAssigned,
                          onSelected:
                              isAlreadyAssigned
                                  ? null
                                  : (selected) {
                                    if (selected) {
                                      setState(() {
                                        _assignedGroupIds.add(group['id']);
                                      });
                                    }
                                  },
                          selectedColor: const Color(
                            0xFF9C27B0,
                          ).withOpacity(0.2),
                          checkmarkColor: const Color(0xFF9C27B0),
                          backgroundColor:
                              isAlreadyAssigned ? Colors.grey[200] : null,
                          labelStyle: TextStyle(
                            color:
                                isAlreadyAssigned
                                    ? Colors.grey[600]
                                    : _assignedGroupIds.contains(group['id'])
                                    ? const Color(0xFF9C27B0)
                                    : null,
                            fontWeight:
                                isAlreadyAssigned
                                    ? FontWeight.normal
                                    : FontWeight.w500,
                          ),
                          avatar:
                              isAlreadyAssigned
                                  ? const Icon(Icons.check, size: 18)
                                  : null,
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyGroupsState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Groups Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create groups first to assign them to teachers',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainGroupsList() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'All Available Groups (${_allGroups.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _allGroups.length,
              itemBuilder: (context, index) {
                final group = _allGroups[index];
                final isAssigned = _assignedGroupIds.contains(group['id']);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: isAssigned ? 3 : 1,
                  color:
                      isAssigned
                          ? const Color(0xFF9C27B0).withOpacity(0.1)
                          : null,
                  child: CheckboxListTile(
                    value: isAssigned,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _assignedGroupIds.add(group['id']);
                        } else {
                          _assignedGroupIds.remove(group['id']);
                        }
                      });
                    },
                    activeColor: const Color(0xFF9C27B0),
                    title: Text(
                      group['name'] ?? 'Unnamed Group',
                      style: TextStyle(
                        fontWeight:
                            isAssigned ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Department: ${group['department'] ?? 'N/A'}'),
                        Text(
                          'Students: ${group['maxStudents'] ?? 0} • Subjects: ${(group['subjects'] as List?)?.length ?? 0}',
                        ),
                      ],
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
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

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveGroupAssignments,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9C27B0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child:
              _isSaving
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Text(
                    'Save Changes',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
        ),
      ],
    );
  }

  Future<void> _saveGroupAssignments() async {
    setState(() => _isSaving = true);

    try {
      // Prepare the assigned groups data with group details
      final assignedGroups =
          _assignedGroupIds.map((groupId) {
            final group = _allGroups.firstWhere((g) => g['id'] == groupId);
            return {
              'id': groupId,
              'name': group['name'],
              'department': group['department'],
            };
          }).toList();

      // Update teacher document with assigned groups
      await FirebaseFirestore.instance
          .collection('teachers')
          .doc(widget.teacher['id'])
          .update({
            'assignedGroups': assignedGroups,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      _showSuccessSnackBar('Groups assigned successfully');
      Navigator.pop(context);
      widget.onGroupsUpdated();
    } catch (e) {
      _showErrorSnackBar('Error assigning groups: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF9C27B0),
      ),
    );
  }
}
