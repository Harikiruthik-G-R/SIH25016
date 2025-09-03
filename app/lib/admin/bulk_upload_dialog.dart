import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel_pkg;

// Enhanced Bulk Upload Dialog for CSV/Excel files
class BulkUploadDialog extends StatefulWidget {
  final String groupId;
  final Map<String, dynamic> groupData;

  const BulkUploadDialog({
    super.key,
    required this.groupId,
    required this.groupData,
  });

  @override
  State<BulkUploadDialog> createState() => _BulkUploadDialogState();
}

class _BulkUploadDialogState extends State<BulkUploadDialog>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _selectedFileName;
  List<Map<String, dynamic>> _parsedStudents = [];
  bool _fileProcessed = false;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(_slideAnimation),
        child: FadeTransition(
          opacity: _slideAnimation,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.92,
            constraints: const BoxConstraints(maxHeight: 750, maxWidth: 600),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Section
                _buildHeader(),

                // Content Section
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // File Format Information
                        _buildFileFormatInfo(),
                        const SizedBox(height: 24),

                        // File Selection
                        _buildFileSelection(),

                        if (_fileProcessed) ...[
                          const SizedBox(height: 24),
                          _buildStudentPreview(),
                        ],

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // Footer with buttons
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF4CAF50), const Color(0xFF45A049)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.cloud_upload_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bulk Upload Students',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add multiple students to ${widget.groupData['name']}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileFormatInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.withOpacity(0.05), Colors.blue.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'File Format Requirements',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRequirementItem('Roll Number', true),
          _buildRequirementItem('Name', true),
          _buildRequirementItem('Email', true),
          _buildRequirementItem('Phone', true),
          _buildRequirementItem('Department', false, 'defaults to CSE'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Colors.amber.shade700,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Students will be added without biometric registration. Biometric setup can be done individually later.',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String field, bool required, [String? note]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            required ? Icons.check_circle : Icons.radio_button_unchecked,
            color: required ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            field,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          if (required) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Required',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          if (note != null) ...[
            const SizedBox(width: 8),
            Text(
              '($note)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileSelection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:
            _selectedFileName == null
                ? Colors.grey.shade50
                : Colors.green.withOpacity(0.05),
        border: Border.all(
          color:
              _selectedFileName == null
                  ? Colors.grey.shade300
                  : Colors.green.withOpacity(0.3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (_selectedFileName == null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_upload_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select CSV or Excel File',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your file to upload student data',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _selectedFileName!.endsWith('.csv')
                    ? Icons.description_rounded
                    : Icons.table_chart_rounded,
                size: 48,
                color: const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFileName!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            if (_fileProcessed) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_parsedStudents.length} students found',
                  style: const TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _selectFile,
              icon:
                  _isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Icon(
                        _selectedFileName == null
                            ? Icons.folder_open_rounded
                            : Icons.refresh_rounded,
                        color: Colors.white,
                      ),
              label: Text(
                _isLoading
                    ? 'Processing...'
                    : _selectedFileName == null
                    ? 'Choose File'
                    : 'Choose Different File',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentPreview() {
    if (_parsedStudents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_rounded, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No valid student data found in the file. Please check the format and try again.',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
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
            Icon(Icons.preview_rounded, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              'Preview (${_parsedStudents.length} students)',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      flex: 2,
                      child: Text(
                        'Name',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Roll No',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const Expanded(
                      flex: 2,
                      child: Text(
                        'Email',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Student list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _parsedStudents.length,
                  itemBuilder: (context, index) {
                    final student = _parsedStudents[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(
                              0xFF4CAF50,
                            ).withOpacity(0.1),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4CAF50),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Text(
                              student['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              student['rollNumber'] ?? 'N/A',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              student['email'] ?? 'No email',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed:
                (_isLoading || !_fileProcessed || _parsedStudents.isEmpty)
                    ? null
                    : _uploadStudents,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
                    : Text(
                      'Upload ${_parsedStudents.length} Students',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  // File processing methods remain the same as in original code
  Future<void> _selectFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFileName = result.files.single.name;
          _isLoading = true;
          _fileProcessed = false;
          _parsedStudents = [];
        });

        await _processFile(result.files.single.path!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processFile(String filePath) async {
    try {
      List<Map<String, dynamic>> students = [];

      if (filePath.endsWith('.csv')) {
        students = await _parseCSV(filePath);
      } else if (filePath.endsWith('.xlsx') || filePath.endsWith('.xls')) {
        students = await _parseExcel(filePath);
      }

      setState(() {
        _parsedStudents = students;
        _fileProcessed = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _fileProcessed = true;
        _parsedStudents = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _parseCSV(String filePath) async {
    final file = File(filePath);
    final csvString = await file.readAsString();
    final csvData = const CsvToListConverter().convert(csvString);

    if (csvData.isEmpty) throw Exception('CSV file is empty');

    final headers =
        csvData[0].map((h) => h.toString().toLowerCase().trim()).toList();
    final students = <Map<String, dynamic>>[];

    for (int i = 1; i < csvData.length; i++) {
      final row = csvData[i];
      if (row.isEmpty) continue;

      final student = <String, dynamic>{};
      for (int j = 0; j < headers.length && j < row.length; j++) {
        final header = headers[j];
        final value = row[j]?.toString().trim() ?? '';

        if (header.contains('roll')) {
          student['rollNumber'] = value;
        } else if (header.contains('name')) {
          student['name'] = value;
        } else if (header.contains('email')) {
          student['email'] = value;
        } else if (header.contains('phone')) {
          student['phone'] = value;
        } else if (header.contains('department')) {
          student['department'] = value;
        }
      }

      // Validate required fields
      if (student['rollNumber']?.isNotEmpty == true &&
          student['name']?.isNotEmpty == true &&
          student['email']?.isNotEmpty == true &&
          student['phone']?.isNotEmpty == true) {
        student['department'] ??= 'Computer Science and Engineering';
        students.add(student);
      }
    }

    return students;
  }

  Future<List<Map<String, dynamic>>> _parseExcel(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    final excel = excel_pkg.Excel.decodeBytes(bytes);
    final students = <Map<String, dynamic>>[];

    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null || sheet.rows.isEmpty) continue;

      final headers =
          sheet.rows[0]
              .map((cell) => cell?.value?.toString().toLowerCase().trim() ?? '')
              .toList();

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty) continue;

        final student = <String, dynamic>{};
        for (int j = 0; j < headers.length && j < row.length; j++) {
          final header = headers[j];
          final value = row[j]?.value?.toString().trim() ?? '';

          if (header.contains('roll')) {
            student['rollNumber'] = value;
          } else if (header.contains('name')) {
            student['name'] = value;
          } else if (header.contains('email')) {
            student['email'] = value;
          } else if (header.contains('phone')) {
            student['phone'] = value;
          } else if (header.contains('department')) {
            student['department'] = value;
          }
        }

        // Validate required fields
        if (student['rollNumber']?.isNotEmpty == true &&
            student['name']?.isNotEmpty == true &&
            student['email']?.isNotEmpty == true &&
            student['phone']?.isNotEmpty == true) {
          student['department'] ??= 'Computer Science and Engineering';
          students.add(student);
        }
      }

      // Process only the first sheet
      break;
    }

    return students;
  }

  Future<void> _uploadStudents() async {
    setState(() => _isLoading = true);

    try {
      int successCount = 0;
      int errorCount = 0;
      List<String> errors = [];

      // Show enhanced progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: Color(0xFF4CAF50),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Uploading Students',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Processing ${_parsedStudents.length} students...',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
      );

      for (final studentData in _parsedStudents) {
        try {
          // Check for duplicates
          final existingRollNumber =
              await FirebaseFirestore.instance
                  .collection('groups')
                  .doc(widget.groupId)
                  .collection('students')
                  .where('rollNumber', isEqualTo: studentData['rollNumber'])
                  .get();

          if (existingRollNumber.docs.isNotEmpty) {
            errors.add(
              'Roll number ${studentData['rollNumber']} already exists',
            );
            errorCount++;
            continue;
          }

          final existingEmail =
              await FirebaseFirestore.instance
                  .collection('groups')
                  .doc(widget.groupId)
                  .collection('students')
                  .where('email', isEqualTo: studentData['email'])
                  .get();

          if (existingEmail.docs.isNotEmpty) {
            errors.add('Email ${studentData['email']} already exists');
            errorCount++;
            continue;
          }

          // Add student to Firestore
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .collection('students')
              .add({
                'rollNumber': studentData['rollNumber'],
                'name': studentData['name'],
                'email': studentData['email'],
                'phone': studentData['phone'],
                'department': studentData['department'],
                'biometricRegistered': false,
                'createdAt': FieldValue.serverTimestamp(),
                'groupId': widget.groupId,
                'groupName': widget.groupData['name'],
                'bulkUploaded': true,
              });

          successCount++;
        } catch (e) {
          errors.add('Error adding ${studentData['name']}: $e');
          errorCount++;
        }
      }

      // Close progress dialog
      if (mounted) Navigator.pop(context);

      // Show enhanced results dialog
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        successCount > 0 ? Icons.check_circle : Icons.error,
                        color: successCount > 0 ? Colors.green : Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Upload Complete',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Successfully added: $successCount students'),
                      if (errorCount > 0) ...[
                        Text('Errors: $errorCount'),
                        const SizedBox(height: 12),
                        if (errors.isNotEmpty) ...[
                          const Text(
                            'Error details:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 100,
                            width: double.maxFinite,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.05),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.2),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                errors.join('\n'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // Close results dialog
                            Navigator.pop(context); // Close bulk upload dialog
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'OK',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
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
    } catch (e) {
      // Close progress dialog if still open
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during upload: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
