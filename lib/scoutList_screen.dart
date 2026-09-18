import 'package:flutter/material.dart';

class ScoutListScreen extends StatefulWidget {
  @override
  _ScoutListScreenState createState() => _ScoutListScreenState();
}

class _ScoutListScreenState extends State<ScoutListScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _patrolController = TextEditingController();
  String _selectedRank = 'Tenderfoot';
  List<Map<String, String>> _scouts = [];

  void _addScout() {
    if (_nameController.text.trim().isEmpty) return;
    setState(() {
      _scouts.add({
        'name': _nameController.text.trim(),
        'rank': _selectedRank,
        'patrol': _patrolController.text.trim(),
      });
      _nameController.clear();
      _patrolController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scout List')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Scout\'s Name'),
            ),
            DropdownButtonFormField<String>(
              value: _selectedRank,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedRank = newValue!;
                });
              },
              items: <String>[
                'Scout',
                'Tenderfoot',
                'Second Class',
                'First Class',
                'Star',
                'Life',
                'Eagle'
              ].map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            TextField(
              controller: _patrolController,
              decoration: InputDecoration(labelText: 'Patrol Name'),
            ),
            ElevatedButton(
              onPressed: _addScout,
              child: Text('Add Scout'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(200, 50),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _scouts.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_scouts[index]['name']!),
                    subtitle: Text(_scouts[index]['patrol']!.isEmpty
                        ? _scouts[index]['rank']!
                        : '${_scouts[index]['rank']} • ${_scouts[index]['patrol']}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}