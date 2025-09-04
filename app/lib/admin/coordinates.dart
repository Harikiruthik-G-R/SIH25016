import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CoordinatesScreen extends StatefulWidget {
  const CoordinatesScreen({super.key});

  @override
  State<CoordinatesScreen> createState() => _CoordinatesScreenState();
}

class _CoordinatesScreenState extends State<CoordinatesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _activeCoordinates = [];
  bool _isLoading = true;

  // Predefined location coordinates for college departments
  final Map<String, Map<String, double>> _predefinedLocations = {
    'IT Park': {
      'topLeftLat': 11.0170,
      'topLeftLng': 76.9560,
      'bottomRightLat': 11.0168,
      'bottomRightLng': 76.9562,
    },
    'Library': {
      'topLeftLat': 11.0172,
      'topLeftLng': 76.9558,
      'bottomRightLat': 11.0170,
      'bottomRightLng': 76.9560,
    },
    'Admin Block': {
      'topLeftLat': 11.0174,
      'topLeftLng': 76.9556,
      'bottomRightLat': 11.0172,
      'bottomRightLng': 76.9558,
    },
    'S & H': {
      'topLeftLat': 11.0176,
      'topLeftLng': 76.9554,
      'bottomRightLat': 11.0174,
      'bottomRightLng': 76.9556,
    },
    'ECE': {
      'topLeftLat': 11.0178,
      'topLeftLng': 76.9552,
      'bottomRightLat': 11.0176,
      'bottomRightLng': 76.9554,
    },
    'EEE': {
      'topLeftLat': 11.0180,
      'topLeftLng': 76.9550,
      'bottomRightLat': 11.0178,
      'bottomRightLng': 76.9552,
    },
    'MTS': {
      'topLeftLat': 11.0182,
      'topLeftLng': 76.9548,
      'bottomRightLat': 11.0180,
      'bottomRightLng': 76.9550,
    },
    'Mech': {
      'topLeftLat': 11.0184,
      'topLeftLng': 76.9546,
      'bottomRightLat': 11.0182,
      'bottomRightLng': 76.9548,
    },
  };

  @override
  void initState() {
    super.initState();
    _loadGroups();
    _loadActiveCoordinates();
  }

  Future<void> _loadGroups() async {
    try {
      setState(() => _isLoading = true);
      final querySnapshot = await _firestore.collection('groups').get();
      
      setState(() {
        _groups = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unknown Group',
            'department': data['department'] ?? '',
            'advisors': data['advisors'] ?? [],
            'maxStudents': data['maxStudents'] ?? 0,
            'subjects': data['subjects'] ?? [],
            'totalHours': data['totalHours'] ?? 0,
            'createdAt': data['createdAt'],
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error loading groups: $e');
    }
  }

  Future<void> _loadActiveCoordinates() async {
    try {
      final querySnapshot = await _firestore.collection('coordinates').get();
      
      setState(() {
        _activeCoordinates = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
      });
    } catch (e) {
      _showErrorSnackBar('Error loading coordinates: $e');
    }
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
                const Text(
                  'Set Coordinates',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _showGroupSelectionDialog,
                  icon: const Icon(Icons.add_location, color: Colors.white),
                  label: const Text(
                    'Add Coordinates',
                    style: TextStyle(color: Colors.white),
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
          // Active Coordinates List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _activeCoordinates.isEmpty
                    ? const Center(
                        child: Text(
                          'No coordinates set yet.\nClick "Add Coordinates" to get started.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadActiveCoordinates,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _activeCoordinates.length,
                          itemBuilder: (context, index) {
                            final coordinate = _activeCoordinates[index];
                            return _buildCoordinateCard(coordinate);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinateCard(Map<String, dynamic> coordinate) {
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
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    coordinate['applyToStudents'] == true 
                        ? Icons.people 
                        : Icons.group_work,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coordinate['groupName'] ?? 'Unknown Group',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Location: ${coordinate['locationName'] ?? 'Unknown'}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        coordinate['applyToStudents'] == true 
                            ? 'Applied to Students' 
                            : 'Applied to Whole Group',
                        style: TextStyle(
                          color: coordinate['applyToStudents'] == true 
                              ? Colors.blue.shade600 
                              : Colors.orange.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: coordinate['isActive'] ?? true,
                  activeColor: const Color(0xFF4CAF50),
                  onChanged: (value) => _toggleCoordinateStatus(coordinate['id'], value),
                ),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'view', child: Text('View Details')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'view':
                        _showCoordinateDetails(coordinate);
                        break;
                      case 'edit':
                        _showEditCoordinateDialog(coordinate);
                        break;
                      case 'delete':
                        _showDeleteConfirmation(coordinate['id']);
                        break;
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bounds: (${coordinate['topLeftLat']?.toStringAsFixed(4)}, ${coordinate['topLeftLng']?.toStringAsFixed(4)}) to (${coordinate['bottomRightLat']?.toStringAsFixed(4)}, ${coordinate['bottomRightLng']?.toStringAsFixed(4)})',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (coordinate['createdAt'] != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Created: ${_formatTimestamp(coordinate['createdAt'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupSelectionDialog() {
    if (_groups.isEmpty) {
      _showErrorSnackBar('No groups available. Please create groups first.');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => GroupSelectionDialog(
        groups: _groups,
        onGroupSelected: _showTargetSelectionDialog,
      ),
    );
  }

  void _showTargetSelectionDialog(Map<String, dynamic> group) {
    showDialog(
      context: context,
      builder: (context) => TargetSelectionDialog(
        group: group,
        onTargetSelected: (applyToStudents) => 
            _showLocationSelectionDialog(group, applyToStudents),
      ),
    );
  }

  void _showLocationSelectionDialog(Map<String, dynamic> group, bool applyToStudents) {
    showDialog(
      context: context,
      builder: (context) => LocationSelectionDialog(
        group: group,
        applyToStudents: applyToStudents,
        predefinedLocations: _predefinedLocations,
        onLocationSelected: _saveCoordinates,
      ),
    );
  }

  Future<void> _saveCoordinates(Map<String, dynamic> coordinateData) async {
    try {
      await _firestore.collection('coordinates').add({
        ...coordinateData,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      _loadActiveCoordinates();
      _showSuccessSnackBar('Coordinates saved successfully!');
    } catch (e) {
      _showErrorSnackBar('Error saving coordinates: $e');
    }
  }

  Future<void> _toggleCoordinateStatus(String coordinateId, bool isActive) async {
    try {
      await _firestore.collection('coordinates').doc(coordinateId).update({
        'isActive': isActive,
      });

      _loadActiveCoordinates();
      _showSuccessSnackBar(isActive ? 'Coordinates activated' : 'Coordinates deactivated');
    } catch (e) {
      _showErrorSnackBar('Error updating status: $e');
    }
  }

  void _showCoordinateDetails(Map<String, dynamic> coordinate) {
    showDialog(
      context: context,
      builder: (context) => CoordinateDetailsDialog(coordinate: coordinate),
    );
  }

  void _showEditCoordinateDialog(Map<String, dynamic> coordinate) {
    showDialog(
      context: context,
      builder: (context) => EditCoordinateDialog(
        coordinate: coordinate,
        predefinedLocations: _predefinedLocations,
        onCoordinateUpdated: _updateCoordinate,
      ),
    );
  }

  Future<void> _updateCoordinate(String coordinateId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('coordinates').doc(coordinateId).update(updates);
      
      _loadActiveCoordinates();
      _showSuccessSnackBar('Coordinates updated successfully!');
    } catch (e) {
      _showErrorSnackBar('Error updating coordinates: $e');
    }
  }

  void _showDeleteConfirmation(String coordinateId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Coordinates'),
        content: const Text('Are you sure you want to delete these coordinates?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCoordinate(coordinateId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCoordinate(String coordinateId) async {
    try {
      await _firestore.collection('coordinates').doc(coordinateId).delete();
      
      _loadActiveCoordinates();
      _showSuccessSnackBar('Coordinates deleted successfully!');
    } catch (e) {
      _showErrorSnackBar('Error deleting coordinates: $e');
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
      return timestamp.toString();
    } catch (e) {
      return 'Invalid date';
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}

// Group Selection Dialog
class GroupSelectionDialog extends StatelessWidget {
  final List<Map<String, dynamic>> groups;
  final Function(Map<String, dynamic>) onGroupSelected;

  const GroupSelectionDialog({
    super.key,
    required this.groups,
    required this.onGroupSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Group',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF4CAF50),
                        child: Text(
                          group['name'].toString().substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(group['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Department: ${group['department']}'),
                          Text('Students: ${group['maxStudents']}'),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        onGroupSelected(group);
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

// Target Selection Dialog
class TargetSelectionDialog extends StatelessWidget {
  final Map<String, dynamic> group;
  final Function(bool) onTargetSelected;

  const TargetSelectionDialog({
    super.key,
    required this.group,
    required this.onTargetSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Apply Coordinates To',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              'Selected Group: ${group['name']}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onTargetSelected(true);
                    },
                    icon: const Icon(Icons.people, color: Colors.white),
                    label: const Text(
                      'Students Only',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onTargetSelected(false);
                    },
                    icon: const Icon(Icons.group_work, color: Colors.white),
                    label: const Text(
                      'Whole Group',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

// Location Selection Dialog
class LocationSelectionDialog extends StatefulWidget {
  final Map<String, dynamic> group;
  final bool applyToStudents;
  final Map<String, Map<String, double>> predefinedLocations;
  final Function(Map<String, dynamic>) onLocationSelected;

  const LocationSelectionDialog({
    super.key,
    required this.group,
    required this.applyToStudents,
    required this.predefinedLocations,
    required this.onLocationSelected,
  });

  @override
  State<LocationSelectionDialog> createState() => _LocationSelectionDialogState();
}

class _LocationSelectionDialogState extends State<LocationSelectionDialog> {
  String? _selectedLocation;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Location',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              'Group: ${widget.group['name']}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Text(
              'Target: ${widget.applyToStudents ? 'Students Only' : 'Whole Group'}',
              style: TextStyle(
                fontSize: 12,
                color: widget.applyToStudents ? Colors.blue : Colors.orange,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: widget.predefinedLocations.keys.length,
                itemBuilder: (context, index) {
                  final locationName = widget.predefinedLocations.keys.elementAt(index);
                  final coordinates = widget.predefinedLocations[locationName]!;
                  
                  return Card(
                    color: _selectedLocation == locationName 
                        ? const Color(0xFF4CAF50).withOpacity(0.1) 
                        : null,
                    child: ListTile(
                      leading: Icon(
                        Icons.location_on,
                        color: _selectedLocation == locationName 
                            ? const Color(0xFF4CAF50) 
                            : Colors.grey,
                      ),
                      title: Text(locationName),
                      subtitle: Text(
                        'Bounds: (${coordinates['topLeftLat']}, ${coordinates['topLeftLng']}) to (${coordinates['bottomRightLat']}, ${coordinates['bottomRightLng']})',
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: _selectedLocation == locationName,
                      onTap: () {
                        setState(() {
                          _selectedLocation = locationName;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectedLocation == null ? null : _saveLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                  child: const Text(
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

  void _saveLocation() {
    if (_selectedLocation == null) return;

    final coordinates = widget.predefinedLocations[_selectedLocation]!;
    final coordinateData = {
      'groupId': widget.group['id'],
      'groupName': widget.group['name'],
      'department': widget.group['department'],
      'locationName': _selectedLocation,
      'applyToStudents': widget.applyToStudents,
      'topLeftLat': coordinates['topLeftLat'],
      'topLeftLng': coordinates['topLeftLng'],
      'bottomRightLat': coordinates['bottomRightLat'],
      'bottomRightLng': coordinates['bottomRightLng'],
    };

    Navigator.pop(context);
    widget.onLocationSelected(coordinateData);
  }
}

// Coordinate Details Dialog
class CoordinateDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> coordinate;

  const CoordinateDetailsDialog({
    super.key,
    required this.coordinate,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Coordinate Details',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildDetailRow('Group Name', coordinate['groupName'] ?? 'N/A'),
            _buildDetailRow('Department', coordinate['department'] ?? 'N/A'),
            _buildDetailRow('Location', coordinate['locationName'] ?? 'N/A'),
            _buildDetailRow(
              'Target',
              coordinate['applyToStudents'] == true ? 'Students Only' : 'Whole Group',
            ),
            _buildDetailRow(
              'Status',
              coordinate['isActive'] == true ? 'Active' : 'Inactive',
            ),
            const Divider(),
            const Text(
              'Coordinates',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildDetailRow('Top Left', '${coordinate['topLeftLat']}, ${coordinate['topLeftLng']}'),
            _buildDetailRow('Bottom Right', '${coordinate['bottomRightLat']}, ${coordinate['bottomRightLng']}'),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
class EditCoordinateDialog extends StatefulWidget {
  final Map<String, dynamic> coordinate;
  final Map<String, Map<String, dynamic>> predefinedLocations;
  final Function(String id, Map<String, dynamic> updates) onCoordinateUpdated;

  const EditCoordinateDialog({
    super.key,
    required this.coordinate,
    required this.predefinedLocations,
    required this.onCoordinateUpdated,
  });

  @override
  State<EditCoordinateDialog> createState() => _EditCoordinateDialogState();
}

class _EditCoordinateDialogState extends State<EditCoordinateDialog> {
  late String _selectedLocation;
  late bool _applyToStudents;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.coordinate['locationName'] ?? '';
    _applyToStudents = widget.coordinate['applyToStudents'] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit Coordinates',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Group Name
              Text(
                'Group: ${widget.coordinate['groupName']}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),

              // Target Selection
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Apply To:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Students Only',
                                style: TextStyle(fontSize: 14)),
                            value: true,
                            groupValue: _applyToStudents,
                            onChanged: (value) =>
                                setState(() => _applyToStudents = value!),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Whole Group',
                                style: TextStyle(fontSize: 14)),
                            value: false,
                            groupValue: _applyToStudents,
                            onChanged: (value) =>
                                setState(() => _applyToStudents = value!),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Predefined Locations Dropdown
              DropdownButtonFormField<String>(
                value: _selectedLocation.isNotEmpty
                    ? _selectedLocation
                    : null, // fallback if no selection
                items: widget.predefinedLocations.keys.map((loc) {
                  return DropdownMenuItem<String>(
                    value: loc,
                    child: Text(loc),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedLocation = value ?? '');
                },
                decoration: InputDecoration(
                  labelText: 'Select Location',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () {
                      final coords =
                          widget.predefinedLocations[_selectedLocation]!;
                      final updates = {
                        'locationName': _selectedLocation,
                        'applyToStudents': _applyToStudents,
                        'topLeftLat': coords['topLeftLat'],
                        'topLeftLng': coords['topLeftLng'],
                        'bottomRightLat': coords['bottomRightLat'],
                        'bottomRightLng': coords['bottomRightLng'],
                        'updatedAt': FieldValue.serverTimestamp(),
                      };

                      widget.onCoordinateUpdated(
                          widget.coordinate['id'], updates);
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}