import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

// Enum for Application Status
enum ApplicationStatus {
  pending,
  approved,
  rejected,
}

// StudentApplication model class
class StudentApplication {
  final String id;
  final String studentId;
  final String studentName;
  final String rollNumber;
  final String groupId;
  final String groupName;
  final String reason;
  final String detailedReason;
  final DateTime applicationDate;
  final DateTime fromDate;
  final DateTime toDate;
  final String fromTime;
  final String toTime;
  final ApplicationStatus status;
  final String? approvedBy;
  final DateTime? approvedDate;
  final String? rejectionReason;
  final String? remarks;
  final String studentEmail;
  final String studentPhone;
  final String parentPhone;
  final String emergencyContact;
  final String address;
  final List<String> attachments;
  final bool isEmergency;
  final int totalDays;
  final List<String> proofDocuments;

  StudentApplication({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.rollNumber,
    required this.groupId,
    required this.groupName,
    required this.reason,
    required this.detailedReason,
    required this.applicationDate,
    required this.fromDate,
    required this.toDate,
    required this.fromTime,
    required this.toTime,
    required this.status,
    this.approvedBy,
    this.approvedDate,
    this.rejectionReason,
    this.remarks,
    required this.studentEmail,
    required this.studentPhone,
    required this.parentPhone,
    required this.emergencyContact,
    required this.address,
    required this.attachments,
    required this.isEmergency,
    required this.totalDays,
    required this.proofDocuments,
  });
}

class OnDutyApplyPage extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String rollNumber;
  final String groupId;
  final String groupName;
  final String department;

  const OnDutyApplyPage({
    Key? key,
    required this.userName,
    required this.userEmail,
    required this.rollNumber,
    required this.groupId,
    required this.groupName,
    required this.department,
  }) : super(key: key);

  @override
  State<OnDutyApplyPage> createState() => _OnDutyApplyPageState();
}

class _OnDutyApplyPageState extends State<OnDutyApplyPage> with TickerProviderStateMixin {
  // Color theme
  static const Color primaryColor = Colors.green;
  static const Color secondaryColor = Colors.green;
  static const Color backgroundColor = Color(0xFFF5F5F5);

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _detailedReasonController = TextEditingController();
  final _addressController = TextEditingController();

  // Tab Controller
  late TabController _tabController;

  // Form state variables
  String? _selectedReason;
  DateTime? _fromDate;
  DateTime? _toDate;
  TimeOfDay? _fromTime;
  TimeOfDay? _toTime;
  bool _isEmergency = false;
  List<PlatformFile> _selectedFiles = [];
  bool _isLoading = false;

  // Reason dropdown options
  final List<String> _reasonOptions = ['Seminar', 'Workshop', 'Sports', 'Others'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _detailedReasonController.dispose();
    _addressController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Method to fetch student applications
  Stream<List<Map<String, dynamic>>> _fetchStudentApplications() {
    return FirebaseFirestore.instance
        .collection('onduty')
        .where('rollNumber', isEqualTo: widget.rollNumber)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            }).toList());
  }

  // Upload files to Firebase Storage
  Future<List<String>> _uploadFiles() async {
    List<String> downloadUrls = [];
    
    for (PlatformFile file in _selectedFiles) {
      try {
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('onduty_documents')
            .child(widget.rollNumber)
            .child(fileName);

        if (file.bytes != null) {
          // For web platform
          final UploadTask uploadTask = storageRef.putData(file.bytes!);
          final TaskSnapshot snapshot = await uploadTask;
          final String downloadUrl = await snapshot.ref.getDownloadURL();
          downloadUrls.add(downloadUrl);
        } else if (file.path != null) {
          // For mobile platforms
          final File fileToUpload = File(file.path!);
          final UploadTask uploadTask = storageRef.putFile(fileToUpload);
          final TaskSnapshot snapshot = await uploadTask;
          final String downloadUrl = await snapshot.ref.getDownloadURL();
          downloadUrls.add(downloadUrl);
        }
      } catch (e) {
        print('Error uploading file ${file.name}: $e');
        throw Exception('Failed to upload file: ${file.name}');
      }
    }
    
    return downloadUrls;
  }

  // Upload application to Firestore
  Future<void> _uploadToFirestore(StudentApplication application, List<String> documentUrls) async {
    try {
      await FirebaseFirestore.instance.collection('onduty').add({
        'id': application.id,
        'studentId': application.studentId,
        'studentName': application.studentName,
        'rollNumber': application.rollNumber,
        'groupId': application.groupId,
        'groupName': application.groupName,
        'reason': application.reason,
        'detailedReason': application.detailedReason,
        'applicationDate': application.applicationDate.toIso8601String(),
        'fromDate': application.fromDate.toIso8601String(),
        'toDate': application.toDate.toIso8601String(),
        'fromTime': application.fromTime,
        'toTime': application.toTime,
        'status': application.status.toString().split('.').last,
        'approvedBy': application.approvedBy,
        'approvedDate': application.approvedDate?.toIso8601String(),
        'rejectionReason': application.rejectionReason,
        'remarks': application.remarks,
        'studentEmail': application.studentEmail,
        'studentPhone': application.studentPhone,
        'parentPhone': application.parentPhone,
        'emergencyContact': application.emergencyContact,
        'address': application.address,
        'attachments': documentUrls,
        'isEmergency': application.isEmergency,
        'totalDays': application.totalDays,
        'proofDocuments': application.proofDocuments,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error uploading to Firestore: $e');
      throw Exception('Failed to submit application to database');
    }
  }

  // Date picker
  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          // Clear to date if it's before from date
          if (_toDate != null && _toDate!.isBefore(picked)) {
            _toDate = null;
          }
        } else {
          _toDate = picked;
        }
      });
    }
  }

  // Time picker
  Future<void> _selectTime(BuildContext context, bool isFromTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        if (isFromTime) {
          _fromTime = picked;
        } else {
          _toTime = picked;
        }
      });
    }
  }

  // File picker
  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking files: $e')),
      );
    }
  }

  // Remove file
  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  // Calculate total days
  int _calculateTotalDays() {
    if (_fromDate != null && _toDate != null) {
      return _toDate!.difference(_fromDate!).inDays + 1;
    }
    return 0;
  }

  // Validate dates
  String? _validateDateSelection() {
    if (_fromDate == null) return 'Please select from date';
    if (_toDate == null) return 'Please select to date';
    if (_toDate!.isBefore(_fromDate!)) return 'To date cannot be before from date';
    return null;
  }

  // Validate times
  String? _validateTimeSelection() {
    if (_fromTime == null) return 'Please select from time';
    if (_toTime == null) return 'Please select to time';
    
    // If same date, check time logic
    if (_fromDate != null && _toDate != null && 
        _fromDate!.isAtSameMomentAs(_toDate!)) {
      final fromMinutes = _fromTime!.hour * 60 + _fromTime!.minute;
      final toMinutes = _toTime!.hour * 60 + _toTime!.minute;
      if (toMinutes <= fromMinutes) {
        return 'To time must be after from time';
      }
    }
    return null;
  }

  // Submit form
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Additional validations
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reason')),
      );
      return;
    }

    final dateError = _validateDateSelection();
    if (dateError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dateError)),
      );
      return;
    }

    final timeError = _validateTimeSelection();
    if (timeError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(timeError)),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload files to Firebase Storage first
      List<String> documentUrls = [];
      if (_selectedFiles.isNotEmpty) {
        documentUrls = await _uploadFiles();
      }

      // Create StudentApplication object
      final application = StudentApplication(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        studentId: widget.rollNumber,
        studentName: widget.userName,
        rollNumber: widget.rollNumber,
        groupId: widget.groupId,
        groupName: widget.groupName,
        reason: _selectedReason!,
        detailedReason: _detailedReasonController.text.trim(),
        applicationDate: DateTime.now(),
        fromDate: _fromDate!,
        toDate: _toDate!,
        fromTime: _fromTime!.format(context),
        toTime: _toTime!.format(context),
        status: ApplicationStatus.pending,
        studentEmail: widget.userEmail,
        studentPhone: '', // Empty since contact info removed
        parentPhone: '', // Empty since contact info removed
        emergencyContact: '', // Empty since contact info removed
        address: _addressController.text.trim(),
        attachments: documentUrls,
        isEmergency: _isEmergency,
        totalDays: _calculateTotalDays(),
        proofDocuments: _selectedFiles.map((file) => file.name).toList(),
      );

      // Upload to Firestore
      await _uploadToFirestore(application, documentUrls);

      // Show success message and clear form
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OnDuty application submitted successfully!'),
            backgroundColor: primaryColor,
            duration: Duration(seconds: 3),
          ),
        );

        // Clear form and switch to history tab
        _clearForm();
        _tabController.animateTo(0);
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting application: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Clear form after successful submission
  void _clearForm() {
    setState(() {
      _selectedReason = null;
      _fromDate = null;
      _toDate = null;
      _fromTime = null;
      _toTime = null;
      _isEmergency = false;
      _selectedFiles.clear();
    });
    _detailedReasonController.clear();
    _addressController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please wait while application is being submitted'),
            ),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text(
            'On Duty Applications',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          backgroundColor: primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(
                icon: Icon(Icons.history),
                text: 'My Applications',
              ),
              Tab(
                icon: Icon(Icons.add_circle_outline),
                text: 'Apply New',
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildApplicationsHistoryTab(),
            _buildApplicationFormTab(),
          ],
        ),
      ),
    );
  }

  // Applications History Tab
  Widget _buildApplicationsHistoryTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _fetchStudentApplications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text('Error loading applications: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final applications = snapshot.data ?? [];

        if (applications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No applications yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your submitted applications will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _tabController.animateTo(1),
                  icon: const Icon(Icons.add),
                  label: const Text('Apply Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final app = applications[index];
            return _buildApplicationCard(app);
          },
        );
      },
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> app) {
    final status = app['status'] ?? 'pending';
    final reason = app['reason'] ?? '';
    final detailedReason = app['detailedReason'] ?? '';
    final fromDate = app['fromDate'] ?? '';
    final toDate = app['toDate'] ?? '';
    final totalDays = app['totalDays'] ?? 0;
    final isEmergency = app['isEmergency'] ?? false;
    
    Color statusColor;
    IconData statusIcon;
    
    switch (status.toLowerCase()) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    reason,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isEmergency) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.priority_high, size: 14, color: Colors.red),
                    SizedBox(width: 4),
                    Text(
                      'EMERGENCY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              detailedReason,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Duration',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalDays ${totalDays == 1 ? 'day' : 'days'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'From Date',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDisplayDate(fromDate),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'To Date',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDisplayDate(toDate),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDisplayDate(String dateString) {
    try {
      final DateTime date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  // Application Form Tab
  Widget _buildApplicationFormTab() {
    return _isLoading
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
                SizedBox(height: 16),
                Text(
                  'Submitting your application...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Please wait while we upload your documents',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student Info Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Student Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('Name', widget.userName),
                          _buildInfoRow('Email', widget.userEmail),
                          _buildInfoRow('Roll Number', widget.rollNumber),
                          _buildInfoRow('Group', widget.groupName),
                          _buildInfoRow('Department', widget.department),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Application Details
                  _buildSectionTitle('Application Details'),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            decoration: _buildInputDecoration('Reason *'),
                            value: _selectedReason,
                            items: _reasonOptions.map((String reason) {
                              return DropdownMenuItem<String>(
                                value: reason,
                                child: Text(reason),
                              );
                            }).toList(),
                            onChanged: (String? value) {
                              setState(() {
                                _selectedReason = value;
                              });
                            },
                            validator: (value) => value == null ? 'Please select a reason' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _detailedReasonController,
                            decoration: _buildInputDecoration('Detailed Reason *'),
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please provide detailed reason';
                              }
                              if (value.trim().length < 10) {
                                return 'Please provide at least 10 characters';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Date and Time Selection
                  _buildSectionTitle('Date & Time'),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateTimeField(
                                  'From Date *',
                                  _fromDate == null ? 'Select Date' : 
                                    '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}',
                                  () => _selectDate(context, true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDateTimeField(
                                  'To Date *',
                                  _toDate == null ? 'Select Date' : 
                                    '${_toDate!.day}/${_toDate!.month}/${_toDate!.year}',
                                  () => _selectDate(context, false),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateTimeField(
                                  'From Time *',
                                  _fromTime == null ? 'Select Time' : _fromTime!.format(context),
                                  () => _selectTime(context, true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDateTimeField(
                                  'To Time *',
                                  _toTime == null ? 'Select Time' : _toTime!.format(context),
                                  () => _selectTime(context, false),
                                ),
                              ),
                            ],
                          ),
                          if (_fromDate != null && _toDate != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.calendar_today, color: primaryColor, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Total Days: ${_calculateTotalDays()}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Address
                  _buildSectionTitle('Additional Information'),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _addressController,
                            decoration: _buildInputDecoration('Address *'),
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please provide address';
                              }
                              if (value.trim().length < 10) {
                                return 'Please provide a complete address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Emergency Switch
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Emergency Application?',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      'Mark if this is urgent',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: _isEmergency,
                                  onChanged: (value) {
                                    setState(() {
                                      _isEmergency = value;
                                    });
                                  },
                                  activeColor: primaryColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Proof Documents
                  _buildSectionTitle('Proof Documents'),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isLoading ? null : _pickFiles,
                                icon: const Icon(Icons.attach_file),
                                label: const Text('Add Documents'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'PDF, JPG, PNG, DOC files only',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_selectedFiles.isNotEmpty) ...[
                            const Text(
                              'Selected Files:',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 150),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _selectedFiles.length,
                                itemBuilder: (context, index) {
                                  final file = _selectedFiles[index];
                                  final fileSizeKB = file.size / 1024;
                                  final fileSizeText = fileSizeKB > 1024 
                                      ? '${(fileSizeKB / 1024).toStringAsFixed(1)} MB'
                                      : '${fileSizeKB.toStringAsFixed(1)} KB';
                                  
                                  return Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _getFileIcon(file.extension ?? ''),
                                          size: 20,
                                          color: primaryColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                file.name,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                fileSizeText,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: _isLoading ? null : () => _removeFile(index),
                                          icon: const Icon(Icons.close, color: Colors.red),
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No documents selected',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLoading ? Colors.grey : primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                      child: _isLoading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Submitting...',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            )
                          : const Text(
                              'Submit Application',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
  }

  // Helper method to get appropriate icon for file type
  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.attach_file;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildDateTimeField(String label, String text, VoidCallback onTap) {
    final bool isSelected = !text.contains('Select');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _isLoading ? null : onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? primaryColor.withOpacity(0.5) : Colors.grey.shade400,
              ),
              borderRadius: BorderRadius.circular(8),
              color: _isLoading ? Colors.grey.shade100 : Colors.white,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.grey.shade600,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
                Icon(
                  label.contains('Date') ? Icons.calendar_today : Icons.access_time,
                  size: 16,
                  color: isSelected ? primaryColor : Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String labelText) {
    return InputDecoration(
      labelText: labelText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      enabled: !_isLoading,
    );
  }
}