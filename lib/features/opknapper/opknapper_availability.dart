// Fork-only (EOchat): who sees Opknapper.
//
// Opknapper is released to everyone at `ForkOverrides.opknapperReleaseAt`
// (25 Oct 2026 18:00). Until then it is there only in beta mode, a hidden
// switch a tester toggles by tapping the app version seven times in a row
// (Instellingen → Over), and in debug builds. While beta mode is on, the
// About page also shows a visible switch to turn it off.
//
// An app left open across the release moment shows the tab when it passes,
// or on its next return to the foreground. After the release beta mode
// changes nothing for the game and stays the place for the next feature.

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:conduit_core/utils/debug_logger.dart';

import '../../core/config/fork_overrides.dart';

/// Beta mode, kept per device. Off unless a tester turned it on.
final betaModeProvider = NotifierProvider<BetaMode, bool>(BetaMode.new);

/// Whether Opknapper's tab, page and reminders exist on this device.
final opknapperAvailableProvider = Provider<bool>(
  (ref) =>
      ref.watch(opknapperReleasedProvider) ||
      kDebugMode ||
      ref.watch(betaModeProvider),
);

/// Whether the release moment has passed. Flips to true on its own while
/// the app is running.
final opknapperReleasedProvider = NotifierProvider<OpknapperReleased, bool>(
  OpknapperReleased.new,
);

class OpknapperReleased extends Notifier<bool> {
  /// The clock, swappable in tests.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  @override
  bool build() {
    ref.onDispose(_stopWatching);
    if (_released()) return true;
    _scheduleTimer();
    // The timer's clock can stand still while the app is suspended, so look
    // again whenever it comes back.
    _lifecycle = AppLifecycleListener(onResume: _check);
    return false;
  }

  void _scheduleTimer() {
    _timer?.cancel();
    _timer = Timer(
      ForkOverrides.opknapperReleaseAt.difference(now().toUtc()),
      _check,
    );
  }

  bool _released() =>
      ForkOverrides.opknapperReleased ||
      !now().toUtc().isBefore(ForkOverrides.opknapperReleaseAt);

  void _check() {
    if (!ref.mounted || state) return;
    if (!_released()) {
      _scheduleTimer();
      return;
    }
    _stopWatching();
    state = true;
  }

  void _stopWatching() {
    _timer?.cancel();
    _timer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}

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
