import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/branding_service.dart';
import '../theme/app_theme.dart';
import '../utils/image_utils.dart';

class BrandingScreen extends StatefulWidget {
  @override
  _BrandingScreenState createState() => _BrandingScreenState();
}

class _BrandingScreenState extends State<BrandingScreen> {
  final TextEditingController _patrolController = TextEditingController();
  final TextEditingController _troopNameController = TextEditingController();
  final TextEditingController _troopWebsiteController = TextEditingController();
  TroopLogo? _troopLogo;
  Map<String, PatrolEmblem> _emblems = {};
  List<String> _patrols = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _patrolController.dispose();
    _troopNameController.dispose();
    _troopWebsiteController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final logo = await BrandingService.loadTroopLogo();
    final emblems = await BrandingService.loadAllPatrolEmblems();
    final patrols = await BrandingService.uniquePatrols();
    final troopName = await BrandingService.loadTroopName() ?? '';
    final troopWebsite = await BrandingService.loadTroopWebsite() ?? '';
    if (!mounted) return;
    setState(() {
      _troopLogo = logo;
      _emblems = emblems;
      _patrols = patrols;
      _troopNameController.text = troopName;
      _troopWebsiteController.text = troopWebsite;
      _loading = false;
    });
  }

  Future<Uint8List?> _pickImageBytes(String label) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
        dialogTitle: label,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _showMessage('Could not read the selected file.');
        return null;
      }
      return await ImageUtils.downscale(bytes);
    } catch (error) {
      _showMessage('Upload failed: $error');
      return null;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _uploadTroopLogo() async {
    final bytes = await _pickImageBytes('Select troop logo');
    if (bytes == null) return;
    await BrandingService.saveTroopLogo(name: 'troop_logo', bytes: bytes);
    _showMessage('Troop logo uploaded');
    _refresh();
  }

  Future<void> _uploadPatrolEmblem(String patrol) async {
    final bytes = await _pickImageBytes('Select $patrol emblem');
    if (bytes == null) return;
    await BrandingService.savePatrolEmblem(
        patrol: patrol, name: '${patrol}_emblem', bytes: bytes);
    _showMessage('$patrol emblem uploaded');
    _refresh();
  }

  Future<void> _addPatrol() async {
    await BrandingService.addPatrolName(_patrolController.text);
    _patrolController.clear();
    _refresh();
  }

  Widget _emblem(PatrolEmblem? emblem, {double size = 48, bool circle = true}) {
    final fallback = circle
        ? CircleAvatar(
            radius: size / 2,
            backgroundColor: AppTheme.scoutingTan,
            child: Icon(Icons.groups, size: size * 0.5, color: AppTheme.scoutingBlue),
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppTheme.scoutingTan,
              borderRadius: BorderRadius.circular(size * 0.18),
            ),
            child: Icon(Icons.face_3,
                size: size * 0.5, color: AppTheme.scoutingBlue),
          );
    if (emblem == null || emblem.dataBase64.isEmpty) return fallback;
    final content = Padding(
      padding: EdgeInsets.all(size * 0.1),
      child: Image.memory(
        emblem.bytes,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
    if (circle) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.white,
        child: content,
      );
    }
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.18),
      ),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Branding & Patrols')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Troop Logo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.scoutingDarkBlue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _emblem(
                              _troopLogo == null
                                  ? null
                                  : PatrolEmblem(_troopLogo!.name, _troopLogo!.dataBase64),
                              size: 88,
                              circle: false,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _troopLogo == null
                                        ? 'No logo uploaded'
                                        : _troopLogo!.name,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: _uploadTroopLogo,
                                        icon: const Icon(Icons.upload_file),
                                        label: const Text('Upload'),
                                      ),
                                      if (_troopLogo != null) ...[
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: () async {
                                            await BrandingService.removeTroopLogo();
                                            _refresh();
                                          },
                                          icon: const Icon(Icons.delete_outline),
                                          label: const Text('Remove'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppTheme.scoutingRed,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _troopNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Troop name',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                await BrandingService.saveTroopName(
                                    _troopNameController.text);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Troop name saved')),
                                );
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _troopWebsiteController,
                                keyboardType: TextInputType.url,
                                decoration: const InputDecoration(
                                  labelText: 'Troop website URL',
                                  hintText: 'https://example.org',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                await BrandingService.saveTroopWebsite(
                                    _troopWebsiteController.text);
                                _troopWebsiteController.text =
                                    await BrandingService.loadTroopWebsite() ??
                                        '';
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Troop website saved')),
                                );
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Patrol Emblems',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.scoutingDarkBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Upload an emblem for each patrol in the troop.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        if (_patrols.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No patrols yet. Add scouts with a patrol '
                                'name or register one below.'),
                          )
                        else
                          ..._patrols.map((patrol) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: _emblem(_emblems[patrol]),
                              title: Text(patrol),
                              subtitle: _emblems[patrol] == null
                                  ? const Text('No emblem')
                                  : Text(_emblems[patrol]!.name),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.upload_file),
                                    tooltip: 'Upload emblem',
                                    onPressed: () => _uploadPatrolEmblem(patrol),
                                  ),
                                  if (_emblems[patrol] != null)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: 'Remove emblem',
                                      color: AppTheme.scoutingRed,
                                      onPressed: () async {
                                        await BrandingService.removePatrolEmblem(patrol);
                                        _refresh();
                                      },
                                    ),
                                ],
                              ),
                            );
                          }),
                        const Divider(),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _patrolController,
                                decoration: const InputDecoration(
                                  labelText: 'New patrol name',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _addPatrol,
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}