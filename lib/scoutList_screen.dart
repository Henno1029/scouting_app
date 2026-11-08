import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/advancement_service.dart';
import 'services/branding_service.dart';
import 'services/permission_service.dart';
import 'services/scout_service.dart';
import 'services/troop_report_pdf_service.dart';
import 'services/troop_stats_service.dart';
import 'theme/app_theme.dart';
import 'utils/app_dates.dart';

class ScoutListScreen extends StatefulWidget {
  @override
  _ScoutListScreenState createState() => _ScoutListScreenState();
}

class _ScoutListScreenState extends State<ScoutListScreen> {
  static const String _newPatrolValue = '__new__';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _patrolController = TextEditingController();
  String _selectedRank = 'Tenderfoot';
  String _selectedPatrol = '';
  bool _addingNewPatrol = false;
  List<Map<String, String>> _scouts = [];
  List<String> _patrols = [];
  Map<String, PatrolEmblem> _emblems = {};

  @override
  void initState() {
    super.initState();
    _loadScouts();
  }

  Future<void> _loadScouts() async {
    final emblems = await BrandingService.loadAllPatrolEmblems();
    final scouts = await ScoutService.load();
    final patrols = await BrandingService.uniquePatrols();
    if (!mounted) return;
    setState(() {
      _emblems = emblems;
      _scouts = scouts;
      _patrols = patrols;
    });
  }

  Future<void> _saveScouts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('scouts', jsonEncode(_scouts));
  }

  void _addScout() {
    if (_nameController.text.trim().isEmpty) return;
    final patrol = _addingNewPatrol
        ? _patrolController.text.trim()
        : _selectedPatrol;
    setState(() {
      _scouts.add({
        'name': _nameController.text.trim(),
        'rank': _selectedRank,
        'patrol': patrol,
      });
      _nameController.clear();
      _patrolController.clear();
      _selectedPatrol = '';
      _addingNewPatrol = false;
    });
    _saveScouts();
    if (patrol.isNotEmpty) {
      BrandingService.addPatrolName(patrol);
    }
    _reloadPatrols();
  }

  Future<void> _reloadPatrols() async {
    final patrols = await BrandingService.uniquePatrols();
    if (!mounted) return;
    setState(() => _patrols = patrols);
  }

  void _deleteScout(int index) {
    setState(() {
      _scouts.removeAt(index);
    });
    _saveScouts();
  }

  Future<void> _printRoster() async {
    if (_scouts.isEmpty) {
      _showMessage('Add some scouts first.');
      return;
    }
    try {
      final index = await AdvancementIndex.load();
      final logo = await BrandingService.loadTroopLogo();
      final bytes = await TroopReportPdfService.buildRoster(
        scouts: [
          for (final scout in _scouts)
            RosterEntry(
              name: scout['name'] ?? '',
              rank:
                  index.rank(
                    scout['name'] ?? '',
                    memberId: scout['memberId'] ?? '',
                  ) ??
                  scout['rank'] ??
                  '',
              patrol: scout['patrol'] ?? '',
              memberId: scout['memberId'] ?? '',
              birthday: AppDates.parse(scout['birthday'] ?? ''),
            ),
        ],
        troopName: await BrandingService.loadTroopName() ?? 'Troop Manager',
        printedOn: DateTime.now(),
        logoBytes: logo?.bytes,
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'scout_roster.pdf',
      );
    } catch (error) {
      _showMessage('Printing failed: $error');
    }
  }

  Future<void> _printStatistics() async {
    final now = DateTime.now();
    final since = await showDatePicker(
      context: context,
      helpText: 'Show statistics since',
      initialDate: DateTime(now.year, 1, 1),
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (since == null) return;
    try {
      final logo = await BrandingService.loadTroopLogo();
      final bytes = await TroopReportPdfService.buildStatistics(
        stats: await TroopStatsService.build(since: since),
        troopName: await BrandingService.loadTroopName() ?? 'Troop Manager',
        logoBytes: logo?.bytes,
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'troop_statistics.pdf',
      );
    } catch (error) {
      _showMessage('Printing failed: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
            if (PermissionService.state.value.canEdit) ...[
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
                items:
                    <String>[
                      'Scout',
                      'Tenderfoot',
                      'Second Class',
                      'First Class',
                      'Star',
                      'Life',
                      'Eagle',
                    ].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
              ),
              DropdownButtonFormField<String>(
                value: _addingNewPatrol ? _newPatrolValue : _selectedPatrol,
                onChanged: (String? newValue) {
                  setState(() {
                    _addingNewPatrol = newValue == _newPatrolValue;
                    _selectedPatrol = _addingNewPatrol ? '' : (newValue ?? '');
                  });
                },
                decoration: const InputDecoration(labelText: 'Patrol Name'),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('No patrol'),
                  ),
                  ..._patrols.map(
                    (patrol) => DropdownMenuItem<String>(
                      value: patrol,
                      child: Text(patrol),
                    ),
                  ),
                  const DropdownMenuItem<String>(
                    value: _newPatrolValue,
                    child: Text('New patrol…'),
                  ),
                ],
              ),
              if (_addingNewPatrol) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _patrolController,
                  decoration: const InputDecoration(
                    labelText: 'New Patrol Name',
                  ),
                ),
              ],
              ElevatedButton(
                onPressed: _addScout,
                child: Text('Add Scout'),
                style: ElevatedButton.styleFrom(minimumSize: Size(200, 50)),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _printRoster,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print Scout Roster'),
                ),
                OutlinedButton.icon(
                  onPressed: _printStatistics,
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('Print out Statistics'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Scouts',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.scoutingDarkBlue,
                  ),
                ),
                Text(
                  '${_scouts.length} ${_scouts.length == 1 ? 'scout' : 'scouts'}',
                  style: const TextStyle(color: AppTheme.scoutingWarmGray),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _scouts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.groups_outlined,
                              size: 48,
                              color: AppTheme.scoutingWarmGray,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No scouts yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.scoutingWarmGray,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Add your first scout above to get started.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.scoutingWarmGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _scouts.length,
                      itemBuilder: (context, index) {
                        // ScoutService.updateScout drops blank fields from storage,
                        // so patrol and rank may be missing.
                        final rank = _scouts[index]['rank'] ?? '';
                        final patrol = _scouts[index]['patrol'] ?? '';
                        final birthday = AppDates.parse(
                          _scouts[index]['birthday'] ?? '',
                        );
                        final age = birthday == null
                            ? null
                            : AppDates.ageOn(birthday, DateTime.now());
                        return ListTile(
                          leading: _patrolEmblem(patrol),
                          title: Text(_scouts[index]['name'] ?? ''),
                          subtitle: Text(
                            [
                              if (rank.isNotEmpty) rank,
                              if (patrol.isNotEmpty) patrol,
                              if (age != null) 'Age $age',
                            ].join(' • '),
                          ),
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/scoutDetail',
                            arguments: _scouts[index],
                          ).then((_) => _loadScouts()),
                          trailing: !PermissionService.state.value.canEdit
                              ? null
                              : IconButton(
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
