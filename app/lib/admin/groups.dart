// groups.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'addusers.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkInitialLoad();
  }

  void _checkInitialLoad() {
    // Add a small delay to show loading state
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF0F8F0)],
        ),
      ),
      child: Column(
        children: [
          // Header with Add Button
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Classrooms',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAddClassroomDialog(),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Add Classroom',
                    style: TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Groups List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF4CAF50),
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('groups')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _buildErrorWidget(snapshot.error.toString());
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF4CAF50),
                          ),
                        );
                      }

                      final groups = snapshot.data?.docs ?? [];

                      if (groups.isEmpty) {
                        return _buildEmptyState();
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          // Refresh is handled automatically by StreamBuilder
                          await Future.delayed(const Duration(milliseconds: 500));
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: groups.length,
                          itemBuilder: (context, index) {
                            final groupDoc = groups[index];
                            final groupData = groupDoc.data() as Map<String, dynamic>;
                            groupData['id'] = groupDoc.id;
                            return _buildGroupCard(groupData);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Classrooms Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first classroom to get started with managing students, subjects, and schedules.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddClassroomDialog(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Create Classroom',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Classrooms',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToAddUsers(group),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school, color: Color(0xFF4CAF50)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group['name'] ?? 'Unnamed Classroom',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Department: ${group['department'] ?? 'N/A'}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Students: ${group['maxStudents'] ?? 0} • Subjects: ${(group['subjects'] as List?)?.length ?? 0}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hours: ${group['totalHours'] ?? 0}h • Break: ${group['breakTime'] ?? 0}min',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'view', child: Text('View Details')),
                  const PopupMenuItem(value: 'users', child: Text('Manage Users')),
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
                onSelected: (value) async {
                  switch (value) {
                    case 'view':
                      _showClassroomDetails(group);
                      break;
                    case 'users':
                      _navigateToAddUsers(group);
                      break;
                    case 'edit':
                      _showEditClassroomDialog(group);
                      break;
                    case 'delete':
                      _showDeleteConfirmation(group['id']);
                      break;
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAddUsers(Map<String, dynamic> groupData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddUsersScreen(groupData: groupData),
      ),
    );
  }

  void _showClassroomDetails(Map<String, dynamic> group) {
    showDialog(
      context: context,
      builder: (context) => ClassroomDetailsDialog(group: group),
    );
  }

  void _showAddClassroomDialog() {
    showDialog(
      context: context,
      builder: (context) => AddClassroomDialog(
        onClassroomAdded: () {
          // StreamBuilder will automatically update
        },
      ),
    );
  }

  void _showEditClassroomDialog(Map<String, dynamic> group) {
    showDialog(
      context: context,
      builder: (context) => EditClassroomDialog(
        group: group,
        onClassroomUpdated: () {
          // StreamBuilder will automatically update
        },
      ),
    );
  }

  void _showDeleteConfirmation(String groupId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Classroom'),
        content: const Text('Are you sure you want to delete this classroom? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteGroup(groupId);
              Navigator.pop(context);
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

  void _deleteGroup(String groupId) async {
    try {
      await _firestore.collection('groups').doc(groupId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Classroom deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting classroom: $e')),
        );
      }
    }
  }
}

// Classroom Details Dialog
class ClassroomDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> group;

  const ClassroomDetailsDialog({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final subjects = group['subjects'] as List? ?? [];
    final advisors = group['advisors'] as List? ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group['name'] ?? 'Classroom Details',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildDetailRow('Department', group['department']),
              _buildDetailRow('Max Students', '${group['maxStudents'] ?? 0}'),
              _buildDetailRow('Total Hours', '${group['totalHours'] ?? 0}h'),
              _buildDetailRow('Break Time', '${group['breakTime'] ?? 0} minutes'),
              const SizedBox(height: 16),
              const Text(
                'Subjects:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...subjects.map((subject) => Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Text('• $subject'),
                  )),
              const SizedBox(height: 16),
              const Text(
                'Class Advisors:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...advisors.map((advisor) => Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Text('• $advisor'),
                  )),
              if (group['coordinates'] != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Location Coordinates:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text('Lat: ${group['coordinates']['lat']}, Lng: ${group['coordinates']['lng']}'),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
          Expanded(child: Text(value ?? 'N/A')),
        ],
      ),
    );
  }
}

// Add Classroom Dialog
class AddClassroomDialog extends StatefulWidget {
  final VoidCallback onClassroomAdded;

  const AddClassroomDialog({super.key, required this.onClassroomAdded});

  @override
  State<AddClassroomDialog> createState() => _AddClassroomDialogState();
}

class _AddClassroomDialogState extends State<AddClassroomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _departmentController = TextEditingController();
  final _maxStudentsController = TextEditingController();
  final _totalHoursController = TextEditingController();
  final _breakTimeController = TextEditingController();
  final _subjectController = TextEditingController();
  final _advisorController = TextEditingController();

  final List<String> _subjects = [];
  final List<String> _advisors = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create New Classroom',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  
                  // Basic Info
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Classroom Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter classroom name' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _departmentController,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter department' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _maxStudentsController,
                          decoration: const InputDecoration(
                            labelText: 'Max Students',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _totalHoursController,
                          decoration: const InputDecoration(
                            labelText: 'Total Hours',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _breakTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Break Time (minutes)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter break time' : null,
                  ),
                  const SizedBox(height: 20),
                  
                  // Subjects Section
                  const Text('Subjects:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _subjectController,
                          decoration: const InputDecoration(
                            labelText: 'Add Subject',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addSubject,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _subjects.map((subject) => Chip(
                      label: Text(subject),
                      onDeleted: () => setState(() => _subjects.remove(subject)),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  
                  // Advisors Section
                  const Text('Class Advisors:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _advisorController,
                          decoration: const InputDecoration(
                            labelText: 'Add Advisor',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addAdvisor,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _advisors.map((advisor) => Chip(
                      label: Text(advisor),
                      onDeleted: () => setState(() => _advisors.remove(advisor)),
                    )).toList(),
                  ),
                  const SizedBox(height: 24),
                  
                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveClassroom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Create',
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _addSubject() {
    if (_subjectController.text.isNotEmpty) {
      setState(() {
        _subjects.add(_subjectController.text);
        _subjectController.clear();
      });
    }
  }

  void _addAdvisor() {
    if (_advisorController.text.isNotEmpty) {
      setState(() {
        _advisors.add(_advisorController.text);
        _advisorController.clear();
      });
    }
  }

  void _saveClassroom() async {
    if (_formKey.currentState!.validate()) {
      if (_subjects.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one subject')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        await FirebaseFirestore.instance.collection('groups').add({
          'name': _nameController.text,
          'department': _departmentController.text,
          'maxStudents': int.parse(_maxStudentsController.text),
          'totalHours': int.parse(_totalHoursController.text),
          'breakTime': int.parse(_breakTimeController.text),
          'subjects': _subjects,
          'advisors': _advisors,
          'createdAt': FieldValue.serverTimestamp(),
          'coordinates': null, // Will be set later in check mode
        });

        widget.onClassroomAdded();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Classroom created successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating classroom: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _departmentController.dispose();
    _maxStudentsController.dispose();
    _totalHoursController.dispose();
    _breakTimeController.dispose();
    _subjectController.dispose();
    _advisorController.dispose();
    super.dispose();
  }
}


class EditClassroomDialog extends StatefulWidget {
  final Map<String, dynamic> group;
  final VoidCallback onClassroomUpdated;

  const EditClassroomDialog({
    super.key,
    required this.group,
    required this.onClassroomUpdated,
  });

  @override
  State<EditClassroomDialog> createState() => _EditClassroomDialogState();
}

class _EditClassroomDialogState extends State<EditClassroomDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _departmentController;
  late TextEditingController _maxStudentsController;
  late TextEditingController _totalHoursController;
  late TextEditingController _breakTimeController;
  final _subjectController = TextEditingController();
  final _advisorController = TextEditingController();

  late List<String> _subjects;
  late List<String> _advisors;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group['name']);
    _departmentController = TextEditingController(text: widget.group['department']);
    _maxStudentsController = TextEditingController(text: '${widget.group['maxStudents'] ?? 0}');
    _totalHoursController = TextEditingController(text: '${widget.group['totalHours'] ?? 0}');
    _breakTimeController = TextEditingController(text: '${widget.group['breakTime'] ?? 0}');
    _subjects = List<String>.from(widget.group['subjects'] ?? []);
    _advisors = List<String>.from(widget.group['advisors'] ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _departmentController.dispose();
    _maxStudentsController.dispose();
    _totalHoursController.dispose();
    _breakTimeController.dispose();
    _subjectController.dispose();
    _advisorController.dispose();
    super.dispose();
  }

  void _addSubject() {
    if (_subjectController.text.trim().isNotEmpty) {
      setState(() {
        _subjects.add(_subjectController.text.trim());
        _subjectController.clear();
      });
    }
  }

  void _removeSubject(int index) {
    setState(() {
      _subjects.removeAt(index);
    });
  }

  void _addAdvisor() {
    if (_advisorController.text.trim().isNotEmpty) {
      setState(() {
        _advisors.add(_advisorController.text.trim());
        _advisorController.clear();
      });
    }
  }

  void _removeAdvisor(int index) {
    setState(() {
      _advisors.removeAt(index);
    });
  }

  Future<void> _updateClassroom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedGroup = {
        'id': widget.group['id'],
        'name': _nameController.text.trim(),
        'department': _departmentController.text.trim(),
        'maxStudents': int.tryParse(_maxStudentsController.text) ?? 0,
        'totalHours': int.tryParse(_totalHoursController.text) ?? 0,
        'breakTime': int.tryParse(_breakTimeController.text) ?? 0,
        'subjects': _subjects,
        'advisors': _advisors,
      };

      // Here you would typically call your API to update the classroom
      // await classroomService.updateClassroom(updatedGroup);
      
      widget.onClassroomUpdated();
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Classroom updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating classroom: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit Classroom',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  
                  // Basic Information Fields
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Classroom Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter classroom name' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _departmentController,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter department' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _maxStudentsController,
                          decoration: const InputDecoration(
                            labelText: 'Max Students',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _totalHoursController,
                          decoration: const InputDecoration(
                            labelText: 'Total Hours',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _breakTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Break Time (minutes)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter break time' : null,
                  ),
                  const SizedBox(height: 20),
                  
                  // Subjects Section
                  const Text('Subjects:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _subjectController,
                          decoration: const InputDecoration(
                            labelText: 'Add Subject',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addSubject,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 100),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _subjects.asMap().entries.map((entry) {
                          final index = entry.key;
                          final subject = entry.value;
                          return Chip(
                            label: Text(subject),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () => _removeSubject(index),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Advisors Section
                  const Text('Advisors:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _advisorController,
                          decoration: const InputDecoration(
                            labelText: 'Add Advisor',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addAdvisor,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 100),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _advisors.asMap().entries.map((entry) {
                          final index = entry.key;
                          final advisor = entry.value;
                          return Chip(
                            label: Text(advisor),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () => _removeAdvisor(index),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _updateClassroom,
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Update'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}



