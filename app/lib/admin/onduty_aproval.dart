import 'package:flutter/material.dart';
import 'student_applications_list.dart';

class OnDutyApprovalScreen extends StatefulWidget {
  final StudentApplication studentApplication;
  final String groupName;

  const OnDutyApprovalScreen({
    super.key,
    required this.studentApplication,
    required this.groupName,
  });

  @override
  _OnDutyApprovalScreenState createState() => _OnDutyApprovalScreenState();
}

class _OnDutyApprovalScreenState extends State<OnDutyApprovalScreen> {
  final TextEditingController _remarksController = TextEditingController();
  String _selectedAction = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2563EB),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'On-Duty Approval',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Head of Department View',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student Details Card
                  _buildStudentDetailsCard(),
                  const SizedBox(height: 16),
                  
                  // OD Request Information Card
                  _buildODRequestCard(),
                  const SizedBox(height: 16),
                  
                  // Supporting Documents Card
                  _buildDocumentsCard(),
                  const SizedBox(height: 16),
                  
                  // Remarks Card
                  _buildRemarksCard(),
                  const SizedBox(height: 100), // Space for bottom buttons
                ],
              ),
            ),
          ),
          
          // Fixed Bottom Action Buttons
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildStudentDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: const Color(0xFF2563EB),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Student Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildDetailRow('Student Name', widget.studentApplication.studentName),
            const SizedBox(height: 12),
            _buildDetailRow('Register Number', widget.studentApplication.rollNumber),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildDetailRow('Class', widget.groupName),
                ),
                Expanded(
                  child: _buildDetailRow('Year', '2024-25'),
                ),
                Expanded(
                  child: _buildDetailRow('Section', 'CSE-A'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildODRequestCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event_note_outlined,
                  color: const Color(0xFF2563EB),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'OD Request Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.studentApplication.status == 'Pending' 
                        ? Colors.amber[100] 
                        : widget.studentApplication.status == 'Approved'
                            ? Colors.green[100]
                            : Colors.red[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.studentApplication.status == 'Pending' 
                        ? Colors.amber[300]! 
                        : widget.studentApplication.status == 'Approved'
                            ? Colors.green[300]!
                            : Colors.red[300]!),
                  ),
                  child: Text(
                    widget.studentApplication.status,
                    style: TextStyle(
                      color: widget.studentApplication.status == 'Pending' 
                          ? Colors.amber[800] 
                          : widget.studentApplication.status == 'Approved'
                              ? Colors.green[800]
                              : Colors.red[800],
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildDetailRow('Date(s) of OD', 
                '${_formatDate(widget.studentApplication.fromDate)} - ${_formatDate(widget.studentApplication.toDate)}'),
            const SizedBox(height: 12),
            _buildDetailRow('Purpose/Reason', widget.studentApplication.reason),
            const SizedBox(height: 12),
            _buildDetailRow('Place/Organization', 'Not specified'),
            const SizedBox(height: 12),
            _buildDetailRow('Duration', '${widget.studentApplication.toDate.difference(widget.studentApplication.fromDate).inDays + 1} Days'),
            const SizedBox(height: 12),
            _buildDetailRow('Applied On', _formatDate(widget.studentApplication.appliedDate)),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.attachment_outlined,
                  color: const Color(0xFF2563EB),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Supporting Documents',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildDocumentItem('Conference Invitation Letter', 'invitation_letter.pdf'),
            const SizedBox(height: 8),
            _buildDocumentItem('Paper Acceptance Certificate', 'acceptance_cert.pdf'),
            const SizedBox(height: 8),
            _buildDocumentItem('Travel Itinerary', 'travel_details.pdf'),
          ],
        ),
      ),
    );
  }

  Widget _buildRemarksCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.comment_outlined,
                  color: const Color(0xFF2563EB),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Remarks',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _remarksController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Add remarks...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF2563EB)),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _handleAction('reject'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.close, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Reject',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _handleAction('approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Approve',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentItem(String name, String fileName) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.picture_as_pdf,
            color: Colors.red[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _viewDocument(fileName),
            icon: Icon(
              Icons.visibility_outlined,
              color: const Color(0xFF2563EB),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  void _handleAction(String action) {
    setState(() {
      _selectedAction = action;
    });
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            '${action == 'approve' ? 'Approve' : 'Reject'} Request',
            style: TextStyle(
              color: action == 'approve' ? const Color(0xFF16A34A) : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to ${action} this OD request?',
            style: TextStyle(color: Colors.grey[700]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showSuccessMessage(action);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: action == 'approve' ? const Color(0xFF16A34A) : Colors.red,
              ),
              child: Text(
                action == 'approve' ? 'Approve' : 'Reject',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _viewDocument(String fileName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening $fileName...'),
        backgroundColor: const Color(0xFF2563EB),
      ),
    );
  }

  void _showSuccessMessage(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Request ${action}d successfully!',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: action == 'approve' ? const Color(0xFF16A34A) : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }
}