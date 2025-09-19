import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _isLoading = false;
  late StudentApplication _currentApplication;

  @override
  void initState() {
    super.initState();
    _currentApplication = widget.studentApplication;
    _remarksController.text = _currentApplication.remarks ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF4CAF50),
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
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                if (_currentApplication.status == 'Pending')
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
                  color: const Color(0xFF4CAF50),
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
            
            _buildDetailRow('Student Name', _currentApplication.studentName),
            const SizedBox(height: 12),
            _buildDetailRow('Register Number', _currentApplication.rollNumber),
            const SizedBox(height: 12),
            _buildDetailRow('Email', _currentApplication.studentEmail),
            const SizedBox(height: 12),
            
            if (_currentApplication.studentPhone.isNotEmpty) ...[
              _buildDetailRow('Phone', _currentApplication.studentPhone),
              const SizedBox(height: 12),
            ],
            
            if (_currentApplication.parentPhone.isNotEmpty) ...[
              _buildDetailRow('Parent Phone', _currentApplication.parentPhone),
              const SizedBox(height: 12),
            ],
            
            Row(
              children: [
                Expanded(
                  child: _buildDetailRow('Class', widget.groupName),
                ),
                if (_currentApplication.address.isNotEmpty)
                  Expanded(
                    flex: 2,
                    child: _buildDetailRow('Address', _currentApplication.address),
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
                _buildStatusBadge(),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildDetailRow('Date(s) of OD', 
                '${_formatDate(_currentApplication.fromDate)} - ${_formatDate(_currentApplication.toDate)}'),
            const SizedBox(height: 12),
            
            _buildDetailRow('Time', 
                '${_currentApplication.fromTime} - ${_currentApplication.toTime}'),
            const SizedBox(height: 12),
            
            _buildDetailRow('Purpose/Reason', _currentApplication.reason),
            const SizedBox(height: 12),
            
            if (_currentApplication.detailedReason.isNotEmpty) ...[
              _buildDetailRow('Detailed Reason', _currentApplication.detailedReason),
              const SizedBox(height: 12),
            ],
            
            _buildDetailRow('Duration', '${_currentApplication.totalDays} ${_currentApplication.totalDays == 1 ? 'Day' : 'Days'}'),
            const SizedBox(height: 12),
            
            _buildDetailRow('Applied On', _formatDate(_currentApplication.appliedDate)),
            
            if (_currentApplication.isEmergency) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.priority_high, color: Colors.red[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Emergency Application',
                      style: TextStyle(
                        color: Colors.red[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (_currentApplication.emergencyContact.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDetailRow('Emergency Contact', _currentApplication.emergencyContact),
            ],
            
            if (_currentApplication.approvedBy != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow('Approved By', _currentApplication.approvedBy!),
            ],
            
            if (_currentApplication.approvedDate != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow('Approved On', _formatDate(_currentApplication.approvedDate!)),
            ],
            
            if (_currentApplication.rejectionReason != null && _currentApplication.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDetailRow('Rejection Reason', _currentApplication.rejectionReason!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    IconData icon;
    
    switch (_currentApplication.status) {
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
            _currentApplication.status,
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

  Widget _buildDocumentsCard() {
    final hasAttachments = _currentApplication.attachments.isNotEmpty;
    final hasProofDocs = _currentApplication.proofDocuments.isNotEmpty;
    
    if (!hasAttachments && !hasProofDocs) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
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
              Text(
                'No documents attached',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
            
            // Show attachments
            if (hasAttachments) ...[
              Text(
                'Attachments:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...(_currentApplication.attachments.asMap().entries.map((entry) {
                final index = entry.key;
                final url = entry.value;
                return Padding(
                  padding: EdgeInsets.only(bottom: index < _currentApplication.attachments.length - 1 ? 8 : 0),
                  child: _buildDocumentItem('Attachment ${index + 1}', url, isUrl: true),
                );
              }).toList()),
            ],
            
            // Show proof documents
            if (hasProofDocs) ...[
              if (hasAttachments) const SizedBox(height: 16),
              Text(
                'Proof Documents:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...(_currentApplication.proofDocuments.asMap().entries.map((entry) {
                final index = entry.key;
                final docName = entry.value;
                return Padding(
                  padding: EdgeInsets.only(bottom: index < _currentApplication.proofDocuments.length - 1 ? 8 : 0),
                  child: _buildDocumentItem(docName, docName, isUrl: false),
                );
              }).toList()),
            ],
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
            
            if (_currentApplication.status != 'Pending')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  _currentApplication.remarks?.isEmpty == true || _currentApplication.remarks == null
                      ? 'No remarks added'
                      : _currentApplication.remarks!,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              )
            else
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
              onPressed: _isLoading ? null : () => _handleAction('reject'),
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
              onPressed: _isLoading ? null : () => _handleAction('approve'),
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

  Widget _buildDocumentItem(String name, String fileNameOrUrl, {required bool isUrl}) {
    final isImage = isUrl && (fileNameOrUrl.contains('.jpg') || 
                             fileNameOrUrl.contains('.jpeg') || 
                             fileNameOrUrl.contains('.png') || 
                             fileNameOrUrl.contains('.gif'));
    
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
            isImage ? Icons.image : Icons.picture_as_pdf,
            color: isImage ? Colors.blue[600] : Colors.red[600],
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
                  isUrl ? 'View Document' : fileNameOrUrl,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _viewDocument(fileNameOrUrl, isUrl),
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

  Future<void> _handleAction(String action) async {
    setState(() {
      _selectedAction = action;
    });
    
    final confirmed = await showDialog<bool>(
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
            'Are you sure you want to $action this OD request?',
            style: TextStyle(color: Colors.grey[700]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
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

    if (confirmed == true) {
      await _updateApplicationStatus(action);
    }
  }

  Future<void> _updateApplicationStatus(String action) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      final updateData = {
        'status': action == 'approve' ? 'approved' : 'rejected',
        'updatedAt': Timestamp.fromDate(now),
        'remarks': _remarksController.text.trim(),
      };

      if (action == 'approve') {
        updateData['approvedDate'] = Timestamp.fromDate(now);
        updateData['approvedBy'] = 'HOD'; // You can get actual user info here
      } else {
        updateData['rejectionReason'] = _remarksController.text.trim().isEmpty 
            ? 'No reason provided' 
            : _remarksController.text.trim();
      }

      await FirebaseFirestore.instance
          .collection('onduty')
          .doc(_currentApplication.id)
          .update(updateData);

      // Update local state
      setState(() {
        _currentApplication = StudentApplication(
          id: _currentApplication.id,
          studentName: _currentApplication.studentName,
          rollNumber: _currentApplication.rollNumber,
          reason: _currentApplication.reason,
          detailedReason: _currentApplication.detailedReason,
          fromDate: _currentApplication.fromDate,
          toDate: _currentApplication.toDate,
          fromTime: _currentApplication.fromTime,
          toTime: _currentApplication.toTime,
          status: action == 'approve' ? 'Approved' : 'Rejected',
          appliedDate: _currentApplication.appliedDate,
          approvedDate: action == 'approve' ? now : null,
          approvedBy: action == 'approve' ? 'HOD' : null,
          rejectionReason: action == 'reject' ? (_remarksController.text.trim().isEmpty 
              ? 'No reason provided' 
              : _remarksController.text.trim()) : null,
          remarks: _remarksController.text.trim(),
          address: _currentApplication.address,
          emergencyContact: _currentApplication.emergencyContact,
          parentPhone: _currentApplication.parentPhone,
          studentPhone: _currentApplication.studentPhone,
          studentEmail: _currentApplication.studentEmail,
          isEmergency: _currentApplication.isEmergency,
          totalDays: _currentApplication.totalDays,
          attachments: _currentApplication.attachments,
          proofDocuments: _currentApplication.proofDocuments,
          imageUrl: _currentApplication.imageUrl,
        );
      });

      _showSuccessMessage(action);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _viewDocument(String fileNameOrUrl, bool isUrl) async {
    if (isUrl) {
      // Show document viewer dialog for URL
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Document Viewer',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.launch, color: Colors.white),
                          onPressed: () => _launchUrl(fileNameOrUrl),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      child: _buildDocumentViewer(fileNameOrUrl),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document: $fileNameOrUrl'),
          backgroundColor: const Color(0xFF2563EB),
        ),
      );
    }
  }

  Widget _buildDocumentViewer(String url) {
    final isImage = url.contains('.jpg') || url.contains('.jpeg') || 
                   url.contains('.png') || url.contains('.gif');
    
    if (isImage) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Failed to load image'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _launchUrl(url),
              child: const Text('Open in Browser'),
            ),
          ],
        ),
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('PDF Document', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _launchUrl(url),
            child: const Text('Open Document'),
          ),
        ],
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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