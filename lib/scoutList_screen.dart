import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/branding_service.dart';
import 'theme/app_theme.dart';

class ScoutListScreen extends StatefulWidget {
  @override
  _ScoutListScreenState createState() => _ScoutListScreenState();
}

class _ScoutListScreenState extends State<ScoutListScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _patrolController = TextEditingController();
  String _selectedRank = 'Tenderfoot';
  List<Map<String, String>> _scouts = [];
  Map<String, PatrolEmblem> _emblems = {};

  @override
  void initState() {
    super.initState();
    _loadScouts();
  }

  Future<void> _loadScouts() async {
    final prefs = await SharedPreferences.getInstance();
    final emblems = await BrandingService.loadAllPatrolEmblems();
    final json = prefs.getString('scouts');
    setState(() {
      _emblems = emblems;
      if (json != null) {
        _scouts = (jsonDecode(json) as List)
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
      }
    });
  }

  Future<void> _saveScouts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('scouts', jsonEncode(_scouts));
  }

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
    _saveScouts();
  }

  void _deleteScout(int index) {
    setState(() {
      _scouts.removeAt(index);
    });
    _saveScouts();
  }

  Widget _patrolEmblem(String patrol) {
    final fallback = CircleAvatar(
      backgroundColor: AppTheme.scoutingTan,
      child: const Icon(Icons.groups, size: 22, color: AppTheme.scoutingBlue),
    );
    final emblem = _emblems[patrol];
    if (emblem == null || emblem.dataBase64.isEmpty) return fallback;
    return CircleAvatar(
      backgroundColor: Colors.white,
      child: ClipOval(
        child: Image.memory(
          emblem.bytes,
          fit: BoxFit.cover,
          width: 40,
          height: 40,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
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
                    leading: _patrolEmblem(_scouts[index]['patrol'] ?? ''),
                    title: Text(_scouts[index]['name']!),
                    subtitle: Text(_scouts[index]['patrol']!.isEmpty
                        ? _scouts[index]['rank']!
                        : '${_scouts[index]['rank']} • ${_scouts[index]['patrol']}'),
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/scoutDetail',
                      arguments: _scouts[index],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _deleteScout(index),
                    ),
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