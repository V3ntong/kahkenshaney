import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_account.dart';

/// Local on-device storage for the "saved accounts" list shown on the login
/// screen. Only non-secret profile references are persisted (no passwords or
/// auth tokens). Cleared automatically when the user clears app data or
/// uninstalls, since it lives in the app's shared preferences.
class SavedAccountsStore {
  SavedAccountsStore({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _prefs;

  static const String _key = 'saved_accounts_v1';

  /// Loads all saved accounts, most recently used first.
  Future<List<SavedAccount>> loadAccounts() async {
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => SavedAccount.fromJson(e as Map<String, dynamic>))
          .where((a) => a.uid.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[SavedAccountsStore] loadAccounts error: $e');
      return const [];
    }
  }

  /// Upserts [account] at the front of the list (most recent first).
  /// Duplicate UIDs collapse into a single entry.
  Future<List<SavedAccount>> saveAccount(SavedAccount account) async {
    final accounts = await loadAccounts();
    final updated = [
      account,
      ...accounts.where((a) => a.uid != account.uid),
    ];
    await _write(updated);
    return updated;
  }

  /// Removes the account with [uid] locally. Never touches the server-side
  /// account — only this device's reference is cleared.
  Future<List<SavedAccount>> removeAccount(String uid) async {
    final accounts = await loadAccounts();
    final updated = accounts.where((a) => a.uid != uid).toList();
    await _write(updated);
    return updated;
  }

  Future<void> _write(List<SavedAccount> accounts) async {
    try {
      final prefs = await _prefs();
      final encoded =
          jsonEncode(accounts.map((a) => a.toJson()).toList());
      await prefs.setString(_key, encoded);
    } catch (e) {
      debugPrint('[SavedAccountsStore] write error: $e');
    }
  }
}