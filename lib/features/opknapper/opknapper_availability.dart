// Fork-only (EOchat): who sees Opknapper.
//
// Until it's released, Opknapper is there only in beta mode: a hidden switch
// a tester turns on by tapping the app version on the About page seven times
// in a row (Instellingen → Over). The same seven taps turn it off again, and
// while it's on the About page shows a visible switch for it too.
//
// Releasing it to everyone is one line: `ForkOverrides.opknapperReleased`
// to true (or `--dart-define=OPKNAPPER_RELEASED=true` for one build).
// Beta mode then changes nothing for the game, and stays the place for the
// next feature that wants testing in the production app first.

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
