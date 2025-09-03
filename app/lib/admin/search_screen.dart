import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  
  final List<String> _filters = ['All', 'Users', 'Groups', 'Locations'];
  
  final List<Map<String, dynamic>> _allResults = [
    {
      'type': 'user',
      'name': 'John Doe',
      'email': 'john@example.com',
      'role': 'Student',
      'group': 'Computer Science',
    },
    {
      'type': 'user',
      'name': 'Jane Smith',
      'email': 'jane@example.com',
      'role': 'Faculty',
      'group': 'Mathematics',
    },
    {
      'type': 'group',
      'name': 'Computer Science',
      'members': 25,
      'description': 'CS Department Group',
    },
    {
      'type': 'location',
      'name': 'Main Campus',
      'coordinates': '11.0168, 76.9558',
      'radius': 100.0,
    },
  ];

  List<Map<String, dynamic>> get _filteredResults {
    List<Map<String, dynamic>> results = _allResults;
    
    if (_selectedFilter != 'All') {
      results = results.where((item) {
        switch (_selectedFilter) {
          case 'Users':
            return item['type'] == 'user';
          case 'Groups':
            return item['type'] == 'group';
          case 'Locations':
            return item['type'] == 'location';
          default:
            return true;
        }
      }).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      results = results.where((item) {
        return item['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
               (item['email'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF0F8F0)],
          ),
        ),
        child: Column(
          children: [
            // Search Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search Field
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search users, groups, locations...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF4CAF50)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Filter Chips
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      itemBuilder: (context, index) {
                        final filter = _filters[index];
                        final isSelected = _selectedFilter == filter;
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedFilter = filter;
                              });
                            },
                            selectedColor: const Color(0xFF4CAF50).withOpacity(0.2),
                            checkmarkColor: const Color(0xFF4CAF50),
                            labelStyle: TextStyle(
                              color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade700,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // Results
            Expanded(
              child: _filteredResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'Start typing to search...'
                                : 'No results found for "$_searchQuery"',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredResults.length,
                      itemBuilder: (context, index) {
                        final result = _filteredResults[index];
                        return _buildResultCard(result);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result) {
    IconData icon;
    Color iconColor;
    
    switch (result['type']) {
      case 'user':
        icon = Icons.person;
        iconColor = const Color(0xFF2196F3);
        break;
      case 'group':
        icon = Icons.group;
        iconColor = const Color(0xFF4CAF50);
        break;
      case 'location':
        icon = Icons.location_on;
        iconColor = const Color(0xFFFF9800);
        break;
      default:
        icon = Icons.help;
        iconColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          result['name'],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: _buildSubtitle(result),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showResultActions(result),
        ),
      ),
    );
  }

  Widget _buildSubtitle(Map<String, dynamic> result) {
    switch (result['type']) {
      case 'user':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result['email']),
            Text(
              '${result['role']} - ${result['group']}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        );
      case 'group':
        return Text('${result['members']} members - ${result['description']}');
      case 'location':
        return Text('${result['coordinates']} - Radius: ${result['radius']}m');
      default:
        return const Text('Unknown type');
    }
  }

  void _showResultActions(Map<String, dynamic> result) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                _showDetails(result);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _editItem(result);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteItem(result);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result['name']),
        content: Text('Details for ${result['name']} will be shown here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _editItem(Map<String, dynamic> result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Edit ${result['name']}')),
    );
  }

  void _deleteItem(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${result['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _allResults.remove(result);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${result['name']} deleted')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
