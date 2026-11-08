import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The three permission levels. There are deliberately no others.
enum PermissionLevel { viewer, editor, admin }

extension PermissionLevelName on PermissionLevel {
  String get label => switch (this) {
    PermissionLevel.viewer => 'Viewer',
    PermissionLevel.editor => 'Editor',
    PermissionLevel.admin => 'Admin',
  };
}

class TroopUser {
  final String id;
  final String name;
  final PermissionLevel level;

  const TroopUser({required this.id, required this.name, required this.level});

  TroopUser withLevel(PermissionLevel level) =>
      TroopUser(id: id, name: name, level: level);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'level': level.name,
  };

  factory TroopUser.fromJson(Map<String, dynamic> json) => TroopUser(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    level: PermissionLevel.values.firstWhere(
      (level) => level.name == json['level'],
      orElse: () => PermissionLevel.viewer,
    ),
  );
}

/// Who is using the app and what they may do.
class PermissionState {
  final List<TroopUser> users;
  final String? currentId;

  /// True after the special password was entered this session.
  final bool unlocked;
  final bool hasPassword;

  const PermissionState({
    this.users = const [],
    this.currentId,
    this.unlocked = false,
    this.hasPassword = false,
  });

  /// With no users set up yet, everyone can do everything, so the app works
  /// as it did before permissions existed.
  bool get setupMode => users.isEmpty;

  TroopUser? get current {
    for (final user in users) {
      if (user.id == currentId) return user;
    }
    return null;
  }

  PermissionLevel get level => current?.level ?? PermissionLevel.viewer;

  /// Viewers can't edit anything. Editors and Admins can, and so can anyone
  /// who entered the special password.
  bool get canEdit => setupMode || unlocked || level != PermissionLevel.viewer;

  /// Only Admins can change other users' permissions.
  bool get canAdmin => setupMode || level == PermissionLevel.admin;

  /// The special password lets a user change their own level.
  bool get canChangeOwnLevel => setupMode || unlocked || canAdmin;
}

/// Users and permission levels, stored on this device.
///
/// This keeps honest people from changing things by accident. It is not
/// security: anyone with the browser's developer tools can change the stored
/// data, so it doesn't protect scout data from someone determined.
class PermissionService {
  static const String _usersKey = 'users';
  static const String _currentKey = 'current_user';
  static const String _passwordKey = 'permission_password';

  static final ValueNotifier<PermissionState> state = ValueNotifier(
    const PermissionState(),
  );

  static String _hash(String password) =>
      sha256.convert(utf8.encode('troop-manager|$password')).toString();

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usersKey);
    final users = raw == null || raw.isEmpty
        ? <TroopUser>[]
        : (jsonDecode(raw) as List)
              .map(
                (u) => TroopUser.fromJson(Map<String, dynamic>.from(u as Map)),
              )
              .toList();
    var currentId = prefs.getString(_currentKey);
    if (!users.any((user) => user.id == currentId)) {
      currentId = users.isEmpty ? null : users.first.id;
    }
    state.value = PermissionState(
      users: users,
      currentId: currentId,
      hasPassword: (prefs.getString(_passwordKey) ?? '').isNotEmpty,
    );
  }

  static Future<void> _store(
    List<TroopUser> users,
    String? currentId, {
    bool? unlocked,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _usersKey,
      jsonEncode(users.map((u) => u.toJson()).toList()),
    );
    if (currentId == null) {
      await prefs.remove(_currentKey);
    } else {
      await prefs.setString(_currentKey, currentId);
    }
    state.value = PermissionState(
      users: users,
      currentId: currentId,
      unlocked: unlocked ?? state.value.unlocked,
      hasPassword: state.value.hasPassword,
    );
  }

  static void _require(bool allowed, String what) {
    if (!allowed) throw StateError('Only an Admin can $what.');
  }

  static int _admins(List<TroopUser> users) =>
      users.where((user) => user.level == PermissionLevel.admin).length;

  /// Adds a user. The first user is always an Admin, and becomes the current
  /// user, which turns permissions on.
  static Future<void> addUser(String name, PermissionLevel level) async {
    final now = state.value;
    _require(now.canAdmin, 'add users');
    final first = now.users.isEmpty;
    // The clock alone can repeat when two users are added quickly, so add a
    // random part and make sure the id is unused.
    final random = Random();
    String id;
    do {
      id =
          '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 30)}';
    } while (now.users.any((user) => user.id == id));
    final user = TroopUser(
      id: id,
      name: name.trim(),
      level: first ? PermissionLevel.admin : level,
    );
    await _store([...now.users, user], first ? user.id : now.currentId);
  }

  static Future<void> removeUser(String id) async {
    final now = state.value;
    _require(now.canAdmin, 'remove users');
    final users = now.users.where((user) => user.id != id).toList();
    if (users.isNotEmpty && _admins(users) == 0) {
      throw StateError('There must always be at least one Admin.');
    }
    await _store(
      users,
      id == now.currentId ? users.firstOrNull?.id : now.currentId,
      unlocked: false,
    );
  }

  /// Admins can change anyone's level. Anyone who entered the special
  /// password can change their own.
  static Future<void> setLevel(String id, PermissionLevel level) async {
    final now = state.value;
    final own = id == now.currentId;
    if (!(now.canAdmin || (own && now.canChangeOwnLevel))) {
      throw StateError('Only an Admin can change other users\' permissions.');
    }
    final users = [
      for (final user in now.users)
        user.id == id ? user.withLevel(level) : user,
    ];
    if (_admins(users) == 0) {
      throw StateError('There must always be at least one Admin.');
    }
    await _store(users, now.currentId);
  }

  /// Switches who is using the app. Becoming an Editor or Admin needs the
  /// special password once one is set, so a Viewer can't just switch up.
  static Future<bool> selectUser(String id, {String password = ''}) async {
    final now = state.value;
    final target = now.users.firstWhere((user) => user.id == id);
    if (target.level != PermissionLevel.viewer &&
        now.hasPassword &&
        !now.canAdmin &&
        !await _matches(password)) {
      return false;
    }
    await _store(now.users, id, unlocked: false);
    return true;
  }

  static Future<bool> _matches(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_passwordKey) ?? '';
    return saved.isNotEmpty && saved == _hash(password);
  }

  static Future<void> setPassword(String password) async {
    _require(state.value.canAdmin, 'set the special password');
    final prefs = await SharedPreferences.getInstance();
    if (password.isEmpty) {
      await prefs.remove(_passwordKey);
    } else {
      await prefs.setString(_passwordKey, _hash(password));
    }
    final now = state.value;
    state.value = PermissionState(
      users: now.users,
      currentId: now.currentId,
      unlocked: now.unlocked,
      hasPassword: password.isNotEmpty,
    );
  }

  /// Unlocks editing for this session if [password] is right.
  static Future<bool> unlock(String password) async {
    if (!await _matches(password)) return false;
    final now = state.value;
    state.value = PermissionState(
      users: now.users,
      currentId: now.currentId,
      unlocked: true,
      hasPassword: now.hasPassword,
    );
    return true;
  }

  static void lock() {
    final now = state.value;
    state.value = PermissionState(
      users: now.users,
      currentId: now.currentId,
      hasPassword: now.hasPassword,
    );
  }

  @visibleForTesting
  static void reset() => state.value = const PermissionState();
}
