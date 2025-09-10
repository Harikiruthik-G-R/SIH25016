import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'dart:io';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _timetables = [];
  List<Map<String, dynamic>> _locations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _loadGroups();
      await _loadTimetables();
      await _loadLocations(); // Load locations after timetables since they depend on timetable data
    } catch (e) {
      _showErrorSnackBar('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGroups() async {
    try {
      final snapshot = await _firestore.collection('groups').get();
      setState(() {
        _groups =
            snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList();
      });
    } catch (e) {
      _showErrorSnackBar('Error loading groups: $e');
    }
  }

  Future<void> _loadTimetables() async {
    try {
      final snapshot = await _firestore.collection('timetables').get();
      setState(() {
        _timetables =
            snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList();
      });
      print('Loaded ${_timetables.length} timetables');
      for (final timetable in _timetables) {
        print('Timetable: ${timetable['name']}, ID: ${timetable['id']}');
        final locations = timetable['locations'];
        if (locations != null) {
          print('  Locations: ${locations.runtimeType} - $locations');
        }
      }
    } catch (e) {
      print('Error in _loadTimetables: $e');
      _showErrorSnackBar('Error loading timetables: $e');
    }
  }

  Future<void> _loadLocations() async {
    try {
      // Extract unique locations from all timetables
      final locationMap = <String, Map<String, dynamic>>{};

      print('Loading locations from ${_timetables.length} timetables');

      for (final timetable in _timetables) {
        final timetableLocations =
            timetable['locations'] as Map<String, dynamic>?;
        print(
          'Timetable ${timetable['name']}: ${timetableLocations?.keys.toList()}',
        );

        if (timetableLocations != null) {
          for (final entry in timetableLocations.entries) {
            final locationName = entry.key;
            final locationData = entry.value as Map<String, dynamic>?;

            if (locationData == null) {
              print('Warning: null location data for $locationName');
              continue;
            }

            if (locationMap.containsKey(locationName)) {
              // Location exists, add timetable to the list
              final existingLocation = locationMap[locationName]!;
              final timetableList = List<String>.from(
                existingLocation['timetables'],
              );
              final timetableIdList = List<String>.from(
                existingLocation['timetableIds'],
              );

              if (!timetableList.contains(timetable['name'])) {
                timetableList.add(timetable['name']);
              }
              if (!timetableIdList.contains(timetable['id'])) {
                timetableIdList.add(timetable['id']);
              }

              // Update the location with new lists
              locationMap[locationName] = {
                ...existingLocation,
                'timetables': timetableList,
                'timetableIds': timetableIdList,
              };
            } else {
              // New location, create entry
              locationMap[locationName] = {
                'id': locationName, // Use location name as ID
                'name': locationName,
                'bounds':
                    locationData['bounds'], // This could be null, that's okay
                'timetables': <String>[
                  timetable['name'],
                ], // List of timetable names using this location
                'timetableIds': <String>[
                  timetable['id'],
                ], // List of timetable IDs for editing
              };
            }
          }
        }
      }

      print(
        'Extracted ${locationMap.length} unique locations: ${locationMap.keys.toList()}',
      );

      setState(() {
        _locations = locationMap.values.toList();
      });
    } catch (e) {
      print('Error in _loadLocations: $e');
      _showErrorSnackBar('Error loading locations: $e');
    }
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
        child:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                )
                : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildEnhancedHeader(),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > 900) {
                              // Wide screen - side by side layout
                              return SizedBox(
                                height: 600, // Fixed height for wide screens
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildTimetablesList(),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 1,
                                      child: _buildLocationsList(),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              // Narrow screen - stacked layout
                              return Column(
                                children: [
                                  SizedBox(
                                    height: 400,
                                    child: _buildTimetablesList(),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    height: 300,
                                    child: _buildLocationsList(),
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildEnhancedHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4CAF50),
            const Color(0xFF66BB6A),
            const Color(0xFF4CAF50).withOpacity(0.9),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.schedule,
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
                        'Timetable Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage schedules and locations',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showUploadTimetableDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4CAF50),
                      elevation: 8,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.upload_file),
                    label: const Text(
                      'Upload Timetable',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showLocationInfoDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.info_outline),
                    label: const Text(
                      'Location Info',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimetablesList() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, const Color(0xFFF8FDF8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4CAF50).withOpacity(0.1),
                  const Color(0xFF4CAF50).withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.schedule,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Timetables',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_timetables.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _timetables.isEmpty
                    ? _buildEmptyTimetablesState()
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _timetables.length,
                      itemBuilder: (context, index) {
                        return _buildEnhancedTimetableCard(
                          _timetables[index],
                          index,
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationsList() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, const Color(0xFFF0F8FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.1),
                  Colors.blue.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Locations',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_locations.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _locations.isEmpty
                    ? _buildEmptyLocationsState()
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _locations.length,
                      itemBuilder: (context, index) {
                        return _buildEnhancedLocationCard(
                          _locations[index],
                          index,
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedTimetableCard(
    Map<String, dynamic> timetable,
    int index,
  ) {
    final groupName = timetable['groupName'] ?? 'Unknown Group';
    final timetableName = timetable['name'] ?? 'Unnamed Timetable';

    // Handle both old and new data structures
    int periodsCount = 0;
    int daysCount = 0;

    final periods = timetable['periods'];
    final schedule = timetable['schedule'];

    if (periods is List) {
      periodsCount = periods.length;
    }

    if (schedule is Map) {
      daysCount = schedule.keys.length;

      // If it's the new structure, count periods differently
      if (schedule.values.isNotEmpty && schedule.values.first is Map) {
        // New structure: each day has a map of periods
        if (periods is! List || periods.isEmpty) {
          // If periods array is empty, count from the schedule
          final allPeriods = <String>{};
          for (final dayData in schedule.values) {
            if (dayData is Map) {
              allPeriods.addAll(dayData.keys.cast<String>());
            }
          }
          periodsCount = allPeriods.length;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, const Color(0xFFF8FDF8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showTimetableDetails(timetable),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4CAF50),
                            const Color(0xFF66BB6A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4CAF50).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.schedule,
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
                            timetableName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Group: $groupName',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.more_vert, size: 20),
                      ),
                      itemBuilder:
                          (context) => [
                            const PopupMenuItem(
                              value: 'view',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.visibility, size: 16),
                                  SizedBox(width: 8),
                                  Text('View'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit, size: 16),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.delete,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                      onSelected:
                          (value) => _handleTimetableAction(
                            value.toString(),
                            timetable,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: const Color(0xFF4CAF50),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$periodsCount periods',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        color: const Color(0xFF4CAF50).withOpacity(0.3),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: const Color(0xFF4CAF50),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$daysCount days',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2E7D32),
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
        ),
      ),
    );
  }

  Widget _buildEnhancedLocationCard(Map<String, dynamic> location, int index) {
    final name = location['name'] ?? 'Unknown Location';
    final bounds = location['bounds'] as Map<String, dynamic>?;
    final timetables = location['timetables'] as List<String>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, const Color(0xFFF0F8FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.blue.withOpacity(0.2), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue, Colors.blue.shade400],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on,
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
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bounds != null ? 'Coordinates set' : 'No coordinates',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.more_vert, size: 20),
                    ),
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, size: 16),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.delete, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                    onSelected:
                        (value) =>
                            _handleLocationAction(value.toString(), location),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Show timetables using this location
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Used in ${timetables.length} timetable${timetables.length != 1 ? 's' : ''}:',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1565C0),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children:
                          timetables.map((timetableName) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                timetableName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1565C0),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),
              if (bounds != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.my_location, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lat: ${_safeSubstring(bounds['topLeftLat']?.toString())}, '
                          'Lng: ${_safeSubstring(bounds['topLeftLng']?.toString())}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E7D32),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildEmptyTimetablesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Timetables',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload a CSV or Excel file to create timetables',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLocationsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Locations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add locations for timetable periods',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadTimetableDialog() {
    showDialog(
      context: context,
      builder:
          (context) => UploadTimetableDialog(
            groups: _groups,
            onTimetableUploaded: () async {
              await _loadTimetables();
              await _loadLocations(); // Reload locations after timetables
            },
          ),
    );
  }

  void _showLocationInfoDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF4CAF50)),
                SizedBox(width: 8),
                Text('Location Management'),
              ],
            ),
            content: const Text(
              'Locations are automatically created when you upload timetables. '
              'You can edit existing location coordinates, but new locations '
              'should be added through timetable uploads.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _handleTimetableAction(String action, Map<String, dynamic> timetable) {
    switch (action) {
      case 'view':
        _showTimetableDetails(timetable);
        break;
      case 'edit':
        _showEditTimetableDialog(timetable);
        break;
      case 'delete':
        _showDeleteTimetableConfirmation(timetable['id']);
        break;
    }
  }

  void _handleLocationAction(String action, Map<String, dynamic> location) {
    switch (action) {
      case 'edit':
        _showEditLocationDialog(location);
        break;
      case 'delete':
        _showDeleteLocationConfirmation(location['id']);
        break;
    }
  }

  void _showTimetableDetails(Map<String, dynamic> timetable) {
    showDialog(
      context: context,
      builder: (context) => TimetableDetailsDialog(timetable: timetable),
    );
  }

  void _showEditTimetableDialog(Map<String, dynamic> timetable) {
    // Implementation for editing timetable
  }

  void _showEditLocationDialog(Map<String, dynamic> location) {
    showDialog(
      context: context,
      builder:
          (context) => AddLocationDialog(
            location: location,
            onLocationAdded: () async {
              await _loadTimetables();
              await _loadLocations(); // Reload locations after timetables
            },
          ),
    );
  }

  void _showDeleteTimetableConfirmation(String timetableId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Timetable'),
            content: const Text(
              'Are you sure you want to delete this timetable? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _deleteTimetable(timetableId);
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

  void _showDeleteLocationConfirmation(String locationId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Location'),
            content: const Text(
              'Are you sure you want to delete this location? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _deleteLocation(locationId);
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

  Future<void> _deleteTimetable(String timetableId) async {
    try {
      await _firestore.collection('timetables').doc(timetableId).delete();
      _showSuccessSnackBar('Timetable deleted successfully');
      _loadTimetables();
    } catch (e) {
      _showErrorSnackBar('Error deleting timetable: $e');
    }
  }

  Future<void> _deleteLocation(String locationId) async {
    try {
      // Find the location by its name (locationId is actually the location name)
      final locationToDelete = _locations.firstWhere(
        (loc) => loc['id'] == locationId,
        orElse: () => {},
      );

      if (locationToDelete.isEmpty) {
        _showErrorSnackBar('Location not found');
        return;
      }

      final locationName = locationToDelete['name'];
      final timetableIds =
          locationToDelete['timetableIds'] as List<String>? ?? [];

      // Remove location from all affected timetables
      final batch = FirebaseFirestore.instance.batch();

      for (final timetableId in timetableIds) {
        final timetableRef = FirebaseFirestore.instance
            .collection('timetables')
            .doc(timetableId);

        batch.update(timetableRef, {
          'locations.$locationName': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      _showSuccessSnackBar('Location deleted from all timetables');
      _loadTimetables(); // Reload timetables first
      _loadLocations(); // Then reload locations
    } catch (e) {
      _showErrorSnackBar('Error deleting location: $e');
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

  String _safeSubstring(String? value) {
    if (value == null || value.isEmpty) return 'N/A';
    return value.length > 7 ? value.substring(0, 7) : value;
  }
}

// Upload Timetable Dialog
class UploadTimetableDialog extends StatefulWidget {
  final List<Map<String, dynamic>> groups;
  final VoidCallback onTimetableUploaded;

  const UploadTimetableDialog({
    super.key,
    required this.groups,
    required this.onTimetableUploaded,
  });

  @override
  State<UploadTimetableDialog> createState() => _UploadTimetableDialogState();
}

class _UploadTimetableDialogState extends State<UploadTimetableDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedGroupId;
  String? _selectedFileName;
  List<List<dynamic>>? _parsedData;
  bool _isLoading = false;
  bool _isProcessing = false;
  Map<String, dynamic>? _processedTimetable;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDialogHeader(),
              const SizedBox(height: 24),
              _buildFormFields(),
              const SizedBox(height: 16),
              _buildFileUploadSection(),
              if (_processedTimetable != null) ...[
                const SizedBox(height: 16),
                _buildPreviewSection(),
              ],
              const Spacer(),
              _buildActionButtons(),
            ],
          ),
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
            'Upload Timetable',
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

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Timetable Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.schedule),
          ),
          validator:
              (value) => value?.isEmpty ?? true ? 'Please enter a name' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedGroupId,
          decoration: const InputDecoration(
            labelText: 'Select Group',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.group),
          ),
          items:
              widget.groups.map((group) {
                return DropdownMenuItem<String>(
                  value: group['id'],
                  child: Text(group['name'] ?? 'Unnamed Group'),
                );
              }).toList(),
          onChanged: (value) => setState(() => _selectedGroupId = value),
          validator: (value) => value == null ? 'Please select a group' : null,
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
              fontWeight:
                  _selectedFileName != null
                      ? FontWeight.w500
                      : FontWeight.normal,
              color: _selectedFileName != null ? Colors.black87 : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isLoading ? null : _selectFile,
            child:
                _isLoading
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Select CSV/Excel File'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
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
            const Text(
              'Timetable Preview',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(child: _buildTimetablePreview()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimetablePreview() {
    if (_processedTimetable == null) return const SizedBox();

    final schedule = _processedTimetable!['schedule'] as Map<String, dynamic>;
    final periods = _processedTimetable!['periods'] as List<dynamic>;
    final locations = _processedTimetable!['locations'] as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Periods: ${periods.length}'),
        const SizedBox(height: 8),
        Text('Days: ${schedule.keys.length}'),
        const SizedBox(height: 8),
        Text('Locations: ${locations.keys.length}'),
        const SizedBox(height: 16),
        ...schedule.entries.map((entry) {
          final daySchedule = entry.value as Map<String, dynamic>;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...daySchedule.entries.map((periodEntry) {
                    final periodData =
                        periodEntry.value as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Period ${periodEntry.key}: ${periodData['subject']} (${periodData['time']}) at ${periodData['location']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
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
              (_processedTimetable != null && !_isProcessing)
                  ? _uploadTimetable
                  : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
          ),
          child:
              _isProcessing
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Text('Upload', style: TextStyle(color: Colors.white)),
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
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;

        setState(() => _selectedFileName = fileName);

        if (fileName.endsWith('.csv')) {
          await _parseCSV(file);
        } else {
          await _parseExcel(file);
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _parseCSV(File file) async {
    try {
      final content = await file.readAsString();
      print('Raw CSV content length: ${content.length}');
      print(
        'First 200 chars: ${content.substring(0, content.length > 200 ? 200 : content.length)}',
      );

      // Split content by lines manually to handle different line endings
      final lines =
          content
              .split(RegExp(r'\r?\n'))
              .where((line) => line.trim().isNotEmpty)
              .toList();
      print('Found ${lines.length} lines in CSV');

      if (lines.isEmpty) {
        _showErrorSnackBar('CSV file is empty');
        return;
      }

      // Parse each line as CSV
      final fields = <List<dynamic>>[];
      for (int i = 0; i < lines.length; i++) {
        try {
          final row = const CsvToListConverter().convert(lines[i]);
          if (row.isNotEmpty) {
            fields.addAll(row);
          }
        } catch (e) {
          print('Error parsing line $i: ${lines[i]}');
          print('Error: $e');
        }
      }

      print('Parsed ${fields.length} rows from CSV');
      _parsedData = fields;
      _processTimetableData();
    } catch (e) {
      _showErrorSnackBar('Error parsing CSV: $e');
    }
  }

  Future<void> _parseExcel(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final excel = excel_pkg.Excel.decodeBytes(bytes);

      final table = excel.tables[excel.tables.keys.first];
      if (table != null) {
        _parsedData =
            table.rows.map((row) {
              return row.map((cell) => cell?.value?.toString() ?? '').toList();
            }).toList();

        _processTimetableData();
      }
    } catch (e) {
      _showErrorSnackBar('Error parsing Excel: $e');
    }
  }

  void _processTimetableData() {
    if (_parsedData == null || _parsedData!.isEmpty) return;

    try {
      print('Processing CSV with ${_parsedData!.length} rows');

      // Print all rows for debugging
      for (int i = 0; i < _parsedData!.length && i < 10; i++) {
        print('Row $i: ${_parsedData![i]}');
      }

      // Special handling: if we have only 2 rows and the second row is a long concatenated string
      if (_parsedData!.length == 2 && _parsedData![1].length == 1) {
        final concatenatedData = _parsedData![1][0].toString();
        print('Detected concatenated data, splitting...');

        // Split the concatenated string by common patterns
        final dataLines =
            concatenatedData
                .split(
                  RegExp(
                    r'(?=Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)',
                  ),
                )
                .where((line) => line.trim().isNotEmpty)
                .toList();

        print('Split into ${dataLines.length} data lines');

        // Reconstruct _parsedData with proper rows
        _parsedData = [_parsedData![0]]; // Keep header

        for (final line in dataLines) {
          final cleanLine = line.trim().replaceAll(RegExp(r'\s+'), ' ');
          final parts = cleanLine.split(', ');
          if (parts.length >= 5) {
            _parsedData!.add(parts);
            print('Added row: $parts');
          }
        }

        print('Reconstructed CSV with ${_parsedData!.length} rows');
      }

      // Validate CSV structure
      if (_parsedData!.isEmpty || _parsedData![0].length < 5) {
        _showErrorSnackBar(
          'Invalid CSV format. Expected: Day,Period,Subject,Time,Location,...',
        );
        return;
      }

      // Expected format: Day,Period,Subject,Time,Location,topLeftLat,topLeftLng,bottomRightLat,bottomRightLng
      final days = <String, Map<String, Map<String, dynamic>>>{};
      final periods = <String>{};
      final locations = <String, Map<String, dynamic>>{};

      // Process each row of data (skip header row)
      for (int i = 1; i < _parsedData!.length; i++) {
        final row = _parsedData![i];
        print('Processing row $i: $row (length: ${row.length})');

        if (row.length < 5) {
          print('Skipping incomplete row $i: $row');
          continue;
        }

        final day = row[0].toString().trim();
        final period = row[1].toString().trim();
        final subject = row[2].toString().trim();
        final time = row[3].toString().trim();
        final location = row[4].toString().trim();

        print(
          'Parsed: Day=$day, Period=$period, Subject=$subject, Time=$time, Location=$location',
        );

        // Add period to the set
        periods.add(period);

        // Initialize day if not exists
        if (!days.containsKey(day)) {
          days[day] = <String, Map<String, dynamic>>{};
        }

        // Add period data for the day
        days[day]![period] = {
          'subject': subject,
          'time': time,
          'location': location,
        };

        // Process location coordinates if present
        if (row.length >= 9 && location.isNotEmpty) {
          try {
            final topLeftLat = double.tryParse(row[5].toString()) ?? 0.0;
            final topLeftLng = double.tryParse(row[6].toString()) ?? 0.0;
            final bottomRightLat = double.tryParse(row[7].toString()) ?? 0.0;
            final bottomRightLng = double.tryParse(row[8].toString()) ?? 0.0;

            locations[location] = {
              'name': location,
              'bounds': {
                'topLeftLat': topLeftLat,
                'topLeftLng': topLeftLng,
                'bottomRightLat': bottomRightLat,
                'bottomRightLng': bottomRightLng,
              },
            };
          } catch (e) {
            print('Error parsing coordinates for location $location: $e');
          }
        }
      }

      // Convert periods set to sorted list
      final periodsList =
          periods.toList()..sort((a, b) {
            // Try to parse as numbers for proper sorting
            final aNum = int.tryParse(a);
            final bNum = int.tryParse(b);
            if (aNum != null && bNum != null) {
              return aNum.compareTo(bNum);
            }
            return a.compareTo(b);
          });

      // Debug prints
      print('Processed timetable data:');
      print('Days: ${days.keys.toList()}');
      print('Periods: $periodsList');
      print('Locations: ${locations.keys.toList()}');
      print(
        'Sample day schedule: ${days.values.isNotEmpty ? days.values.first : "No days"}',
      );

      setState(() {
        _processedTimetable = {
          'schedule': days,
          'periods': periodsList,
          'locations': locations,
        };
      });
    } catch (e) {
      _showErrorSnackBar('Error processing timetable data: $e');
    }
  }

  Future<void> _uploadTimetable() async {
    if (!_formKey.currentState!.validate() || _processedTimetable == null) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final selectedGroup = widget.groups.firstWhere(
        (g) => g['id'] == _selectedGroupId,
      );

      final timetableData = {
        'name': _nameController.text,
        'groupId': _selectedGroupId,
        'groupName': selectedGroup['name'],
        'schedule': _processedTimetable!['schedule'],
        'periods': _processedTimetable!['periods'],
        'locations': _processedTimetable!['locations'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save timetable
      await FirebaseFirestore.instance
          .collection('timetables')
          .add(timetableData);

      Navigator.pop(context);
      widget.onTimetableUploaded();
      _showSuccessSnackBar('Timetable uploaded successfully');
    } catch (e) {
      _showErrorSnackBar('Error uploading timetable: $e');
    } finally {
      setState(() => _isProcessing = false);
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

// Add Location Dialog
class AddLocationDialog extends StatefulWidget {
  final Map<String, dynamic>? location;
  final VoidCallback onLocationAdded;

  const AddLocationDialog({
    super.key,
    this.location,
    required this.onLocationAdded,
  });

  @override
  State<AddLocationDialog> createState() => _AddLocationDialogState();
}

class _AddLocationDialogState extends State<AddLocationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _topLeftLatController = TextEditingController();
  final _topLeftLngController = TextEditingController();
  final _bottomRightLatController = TextEditingController();
  final _bottomRightLngController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.location != null) {
      _nameController.text = widget.location!['name'] ?? '';
      final bounds = widget.location!['bounds'] as Map<String, dynamic>?;
      if (bounds != null) {
        _topLeftLatController.text = bounds['topLeftLat']?.toString() ?? '';
        _topLeftLngController.text = bounds['topLeftLng']?.toString() ?? '';
        _bottomRightLatController.text =
            bounds['bottomRightLat']?.toString() ?? '';
        _bottomRightLngController.text =
            bounds['bottomRightLng']?.toString() ?? '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.location != null ? 'Edit Location' : 'Add Location',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Location Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator:
                    (value) =>
                        value?.isEmpty ?? true ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'Coordinates',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _topLeftLatController,
                      decoration: const InputDecoration(
                        labelText: 'Top Left Latitude',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator:
                          (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _topLeftLngController,
                      decoration: const InputDecoration(
                        labelText: 'Top Left Longitude',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator:
                          (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bottomRightLatController,
                      decoration: const InputDecoration(
                        labelText: 'Bottom Right Latitude',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator:
                          (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _bottomRightLngController,
                      decoration: const InputDecoration(
                        labelText: 'Bottom Right Longitude',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator:
                          (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Text(
                              widget.location != null ? 'Update' : 'Save',
                              style: const TextStyle(color: Colors.white),
                            ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveLocation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newLocationData = {
        'topLeftLat': double.parse(_topLeftLatController.text),
        'topLeftLng': double.parse(_topLeftLngController.text),
        'bottomRightLat': double.parse(_bottomRightLatController.text),
        'bottomRightLng': double.parse(_bottomRightLngController.text),
      };

      if (widget.location != null) {
        // Editing existing location - update in all timetables that use it
        final locationName = widget.location!['name'];
        final timetableIds =
            widget.location!['timetableIds'] as List<String>? ?? [];

        // Update location in all affected timetables
        final batch = FirebaseFirestore.instance.batch();

        for (final timetableId in timetableIds) {
          final timetableRef = FirebaseFirestore.instance
              .collection('timetables')
              .doc(timetableId);

          batch.update(timetableRef, {
            'locations.$locationName.bounds': newLocationData,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated in all timetables'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      } else {
        // Adding new location - this functionality might be removed since locations
        // are now managed through timetable uploads
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'New locations should be added through timetable uploads',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      Navigator.pop(context);
      widget.onLocationAdded();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _topLeftLatController.dispose();
    _topLeftLngController.dispose();
    _bottomRightLatController.dispose();
    _bottomRightLngController.dispose();
    super.dispose();
  }
}

// Timetable Details Dialog
class TimetableDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> timetable;

  const TimetableDetailsDialog({super.key, required this.timetable});

  @override
  Widget build(BuildContext context) {
    final schedule = timetable['schedule'] as Map<String, dynamic>;
    final periods = timetable['periods'] as List<dynamic>;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, color: Color(0xFF4CAF50)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    timetable['name'] ?? 'Timetable Details',
                    style: const TextStyle(
                      fontSize: 20,
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
            const SizedBox(height: 16),
            Text('Group: ${timetable['groupName']}'),
            Text('Periods: ${periods.length}'),
            Text('Days: ${schedule.keys.length}'),
            const SizedBox(height: 24),
            const Text(
              'Schedule',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children:
                      schedule.entries.map((entry) {
                        final daySchedule = entry.value as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF4CAF50),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(1),
                                    1: FlexColumnWidth(2),
                                    2: FlexColumnWidth(1.5),
                                    3: FlexColumnWidth(1.5),
                                  },
                                  children: [
                                    const TableRow(
                                      decoration: BoxDecoration(
                                        color: Color(0xFFF5F5F5),
                                      ),
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            'Period',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            'Subject',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            'Time',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            'Location',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    ...daySchedule.entries.map((periodEntry) {
                                      final periodData =
                                          periodEntry.value
                                              as Map<String, dynamic>;
                                      return TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(periodEntry.key),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              periodData['subject'] ?? 'N/A',
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              periodData['time'] ?? 'N/A',
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              periodData['location'] ?? 'N/A',
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
