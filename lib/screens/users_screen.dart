import 'package:flutter/material.dart';

import '../services/permission_service.dart';
import '../theme/app_theme.dart';

/// Users and permission levels: who is using the app, the special password,
/// and, for Admins, adding users and changing their levels.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _password = TextEditingController();
  PermissionLevel _newLevel = PermissionLevel.viewer;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _attempt(Future<void> Function() action) async {
    try {
      await action();
    } on StateError catch (error) {
      _show(error.message);
    }
  }

  Future<String?> _askPassword(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Special password'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _switchTo(TroopUser user) async {
    final now = PermissionService.state.value;
    var password = '';
    if (user.level != PermissionLevel.viewer &&
        now.hasPassword &&
        !now.canAdmin) {
      final typed = await _askPassword('Switch to ${user.name}');
      if (typed == null) return;
      password = typed;
    }
    final switched = await PermissionService.selectUser(
      user.id,
      password: password,
    );
    if (!mounted) return;
    _show(switched ? 'Now using the app as ${user.name}' : 'Wrong password');
  }

  Future<void> _unlock() async {
    final typed = await _askPassword('Unlock editing');
    if (typed == null) return;
    final unlocked = await PermissionService.unlock(typed);
    if (!mounted) return;
    _show(
      unlocked
          ? 'Editing unlocked until you lock it or close the app'
          : 'Wrong password',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PermissionState>(
      valueListenable: PermissionService.state,
      builder: (context, state, _) => Scaffold(
        appBar: AppBar(title: const Text('Users & Permissions')),
        body: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            if (state.setupMode) _buildSetupCard() else _buildYouCard(state),
            if (!state.setupMode) _buildUsersCard(state),
            if (state.canAdmin) _buildAddCard(state),
            if (state.canAdmin && !state.setupMode) _buildPasswordCard(state),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Permissions stop people changing things by accident. They are '
                'not a lock on scout data: anyone with this computer and some '
                'know-how can read or change what is stored.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.scoutingWarmGray,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: AppTheme.scoutingDarkBlue,
    ),
  );

  Widget _buildSetupCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading('Permissions are off'),
            const SizedBox(height: 6),
            const Text(
              'Everyone can change everything until you add a user. '
              'The first user you add becomes an Admin.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYouCard(PermissionState state) {
    final user = state.current;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(
              'You are ${user?.name ?? 'nobody'} (${state.level.label})',
            ),
            const SizedBox(height: 6),
            Text(
              state.canEdit
                  ? state.unlocked && state.level == PermissionLevel.viewer
                        ? 'Editing is unlocked with the special password.'
                        : 'You can make changes.'
                  : 'You can look at everything but not change it.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (state.hasPassword && !state.unlocked)
                  OutlinedButton.icon(
                    onPressed: _unlock,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Unlock with password'),
                  ),
                if (state.unlocked)
                  OutlinedButton.icon(
                    onPressed: PermissionService.lock,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Lock'),
                  ),
              ],
            ),
            if (user != null && state.canChangeOwnLevel && !state.canAdmin) ...[
              const SizedBox(height: 10),
              _levelPicker(
                label: 'Your level',
                value: user.level,
                onChanged: (level) =>
                    _attempt(() => PermissionService.setLevel(user.id, level)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _levelPicker({
    required String label,
    required PermissionLevel value,
    required ValueChanged<PermissionLevel>? onChanged,
  }) {
    return DropdownButtonFormField<PermissionLevel>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [
        for (final level in PermissionLevel.values)
          DropdownMenuItem(value: level, child: Text(level.label)),
      ],
      onChanged: onChanged == null
          ? null
          : (level) {
              if (level != null) onChanged(level);
            },
    );
  }

  Widget _buildUsersCard(PermissionState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading('Users'),
            for (final user in state.users)
              ListTile(
                key: ValueKey(user.id),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  user.id == state.currentId
                      ? Icons.person
                      : Icons.person_outline,
                ),
                title: Text(user.name),
                subtitle: state.canAdmin
                    ? SizedBox(
                        width: 160,
                        child: DropdownButton<PermissionLevel>(
                          key: ValueKey('level-${user.id}-${user.level.name}'),
                          value: user.level,
                          isDense: true,
                          items: [
                            for (final level in PermissionLevel.values)
                              DropdownMenuItem(
                                value: level,
                                child: Text(level.label),
                              ),
                          ],
                          onChanged: (level) {
                            if (level == null) return;
                            _attempt(
                              () => PermissionService.setLevel(user.id, level),
                            );
                          },
                        ),
                      )
                    : Text(user.level.label),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user.id != state.currentId)
                      TextButton(
                        onPressed: () => _switchTo(user),
                        child: const Text('Use'),
                      ),
                    if (state.canAdmin)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: AppTheme.scoutingRed,
                        tooltip: 'Remove ${user.name}',
                        onPressed: () => _attempt(
                          () => PermissionService.removeUser(user.id),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCard(PermissionState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(state.setupMode ? 'Add the first Admin' : 'Add a user'),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name',
                isDense: true,
              ),
            ),
            if (!state.setupMode) ...[
              const SizedBox(height: 8),
              _levelPicker(
                label: 'Level',
                value: _newLevel,
                onChanged: (level) => setState(() => _newLevel = level),
              ),
            ],
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () {
                if (_name.text.trim().isEmpty) return;
                _attempt(() async {
                  await PermissionService.addUser(_name.text, _newLevel);
                  _name.clear();
                });
              },
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add user'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordCard(PermissionState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading('Special password'),
            const SizedBox(height: 6),
            Text(
              state.hasPassword
                  ? 'A password is set. It unlocks editing, lets someone change '
                        'their own level, and is needed to switch to an Editor or '
                        'Admin.'
                  : 'No password is set yet. Set one so Viewers can\'t switch to '
                        'an Admin.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: state.hasPassword ? 'New password' : 'Password',
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: () {
                    if (_password.text.isEmpty) return;
                    _attempt(() async {
                      await PermissionService.setPassword(_password.text);
                      _password.clear();
                      _show('Password saved');
                    });
                  },
                  child: const Text('Save password'),
                ),
                if (state.hasPassword)
                  TextButton(
                    onPressed: () => _attempt(() async {
                      await PermissionService.setPassword('');
                      _show('Password removed');
                    }),
                    child: const Text('Remove password'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
