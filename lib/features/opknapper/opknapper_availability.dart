// Fork-only (EOchat): who sees Opknapper.
//
// Opknapper is released to everyone by default. Beta mode stays available
// for testing other features in the production app.
//
// With `--dart-define=OPKNAPPER_RELEASED=false`, the game exists only in beta
// mode: a hidden switch a tester toggles by tapping the app version seven
// times in a row (Instellingen → Over). While beta mode is on, the About page
// also shows a visible switch to turn it off.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:conduit_core/utils/debug_logger.dart';

import '../../core/config/fork_overrides.dart';

/// Beta mode, kept per device. Off unless a tester turned it on.
final betaModeProvider = NotifierProvider<BetaMode, bool>(BetaMode.new);

/// Whether Opknapper's tab, page and reminders exist on this device.
final opknapperAvailableProvider = Provider<bool>(
  (ref) => ForkOverrides.opknapperReleased || ref.watch(betaModeProvider),
);

/// True while the game page is on screen. The drawer shell turns its swipe
/// to open off then, so only the page's close button leaves the game.
final opknapperGameOpenProvider = NotifierProvider<OpknapperGameOpen, bool>(
  OpknapperGameOpen.new,
);

class OpknapperGameOpen extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool open) => state = open;
}

class BetaMode extends Notifier<bool> {
  static const String _key = 'eochat.betaMode';

  /// Taps on the version that turn beta mode on or off.
  static const int unlockTaps = 7;

  /// The taps count as one sequence when each follows the last this soon.
  static const Duration tapWindow = Duration(milliseconds: 1500);

  Future<void>? _loading;
  int _taps = 0;
  DateTime? _lastTap;

  @override
  bool build() {
    _loading = _load();
    return false;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_key) ?? false;
      if (ref.mounted && stored != state) state = stored;
    } catch (error) {
      DebugLogger.warning(
        'beta-mode-load-failed',
        scope: 'beta',
        data: {'error': error.toString()},
      );
    }
  }

  /// Resolves once the stored choice has been read.
  Future<bool> ready() async {
    await (_loading ??= _load());
    return state;
  }

  Future<void> setEnabled(bool enabled) async {
    await ready();
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, enabled);
    } catch (error) {
      DebugLogger.warning(
        'beta-mode-save-failed',
        scope: 'beta',
        data: {'error': error.toString()},
      );
    }
    DebugLogger.log('beta-mode', scope: 'beta', data: {'enabled': enabled});
  }

  /// One tap on the version. Returns the new state when this tap completed
  /// the sequence and flipped beta mode, or null otherwise.
  Future<bool?> registerTap() async {
    final now = DateTime.now();
    final last = _lastTap;
    _taps = last != null && now.difference(last) <= tapWindow ? _taps + 1 : 1;
    _lastTap = now;
    if (_taps < unlockTaps) return null;
    _taps = 0;
    _lastTap = null;
    final next = !(await ready());
    await setEnabled(next);
    return next;
  }
}
