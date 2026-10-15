// Fork-only (EOchat): Opknapper's daily-letter reminders.
//
// The game's dagbrief comes each working day (ai-hub-webapp, T32's first
// step). A web view can't take Web Push, so the app schedules the reminders
// itself, as local notifications, and asks no server for anything.
//
// The schedule is a rolling window: the next five working days at the
// colleague's chosen time, rebuilt whenever the game is opened or a letter is
// answered. So a letter answered today drops today's reminder, and a colleague
// who stays away for a week stops hearing from the app until they come back —
// an invitation, never a broadcast (R49: being away costs a moment, never a
// lesson).

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show TimeOfDay;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:conduit_core/utils/debug_logger.dart';

import '../opknapper_availability.dart';
import '../../../shared/services/navigation_service.dart';
import '../../notifications/services/local_notification_service.dart';
import '../opknapper_config.dart';

const String _scope = 'opknapper/reminders';

/// The colleague's reminder choice.
class OpknapperReminderSettings {
  const OpknapperReminderSettings({
    required this.enabled,
    required this.time,
    this.loaded = false,
  });

  /// Off until the colleague turns it on, in the tab or from the game.
  static const OpknapperReminderSettings initial = OpknapperReminderSettings(
    enabled: false,
    time: TimeOfDay(hour: 8, minute: 45),
  );

  final bool enabled;
  final TimeOfDay time;

  /// False until the stored choice has been read.
  final bool loaded;

  String get timeLabel =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  OpknapperReminderSettings copyWith({bool? enabled, TimeOfDay? time}) =>
      OpknapperReminderSettings(
        enabled: enabled ?? this.enabled,
        time: time ?? this.time,
        loaded: true,
      );

  Map<String, Object?> toJson() => {'enabled': enabled, 'time': timeLabel};

  /// Parses `HH:mm`, as the page sends it.
  static TimeOfDay? parseTime(Object? value) {
    if (value is! String) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }
}

/// Taps on an Opknapper reminder, routed past the message-notification
/// decoder (whose [NotificationTap] only knows chat and channel kinds).
abstract final class OpknapperNotificationTaps {
  static const String kind = 'opknapper';

  static final StreamController<Map<String, Object?>> _taps =
      StreamController<Map<String, Object?>>.broadcast();

  static Stream<Map<String, Object?>> get stream => _taps.stream;

  static String encode({String open = 'post'}) =>
      jsonEncode({'kind': kind, 'open': open});

  static Map<String, Object?>? decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final map = jsonDecode(payload);
      if (map is Map && map['kind'] == kind) {
        return Map<String, Object?>.from(map);
      }
    } catch (_) {}
    return null;
  }

  /// Called first by `LocalNotificationService` for every tap. Returns true
  /// when the tap was Opknapper's, so the message router never sees it.
  static bool consume(String? payload) {
    final tap = decode(payload);
    if (tap == null) return false;
    if (!_taps.isClosed) _taps.add(tap);
    return true;
  }
}

final opknapperRemindersProvider =
    NotifierProvider<OpknapperReminders, OpknapperReminderSettings>(
      OpknapperReminders.new,
    );

class OpknapperReminders extends Notifier<OpknapperReminderSettings> {
  static const String _enabledKey = 'opknapper.reminders.enabled';
  static const String _minutesKey = 'opknapper.reminders.minutes';
  static const String _answeredDayKey = 'opknapper.reminders.answeredDay';
  static const String _channelId = 'opknapper';

  /// How many working days ahead are scheduled.
  static const int windowDays = 5;

  /// Reminder ids are this base plus the day's number since 1 Jan 2026, so
  /// each day has one id and ours never collide with the message counter,
  /// which counts up from 1.
  static const int _idBase = 0x4F500000;
  static const int _idSpan = 100000;

  static final DateTime _epoch = DateTime.utc(2026, 1, 1);

  /// EO works in one time zone; the reminder follows the Dutch clock,
  /// summer time included.
  static const String _zoneName = 'Europe/Amsterdam';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _zonesReady = false;
  StreamSubscription<Map<String, Object?>>? _tapSub;
  bool _started = false;

  /// The one read of the stored choice; [_ready] waits on it rather than
  /// reading again, so a late first read can't overwrite a newer choice.
  Future<void>? _loading;

  /// Rebuilds run one at a time, so a `seen` racing an `answered` can't put
  /// today's reminder back after it was dropped.
  Future<void> _refreshTail = Future<void>.value();

  @override
  OpknapperReminderSettings build() {
    ref.onDispose(() => _tapSub?.cancel());
    // Beta mode turned off (or on): the reminders follow at once.
    ref.listen<bool>(opknapperAvailableProvider, (previous, next) {
      if (previous == next) return;
      if (next) {
        unawaited(start());
      } else {
        unawaited(refresh());
      }
    });
    _loading = _load();
    return OpknapperReminderSettings.initial;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_enabledKey) ?? false;
      final minutes = prefs.getInt(_minutesKey);
      if (!ref.mounted) return;
      state = state.copyWith(
        enabled: enabled,
        time: minutes == null
            ? null
            : TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60),
      );
    } catch (error) {
      DebugLogger.warning(
        'load-failed',
        scope: _scope,
        data: {'error': error.toString()},
      );
      if (ref.mounted) state = state.copyWith();
    }
  }

  Future<OpknapperReminderSettings> _ready() async {
    if (!state.loaded) await (_loading ??= _load());
    return state;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, state.enabled);
    await prefs.setInt(_minutesKey, state.time.hour * 60 + state.time.minute);
  }

  /// Once per signed-in start: routes reminder taps, opens the game when a
  /// reminder cold-launched the app, and renews the window.
  Future<void> start() async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    await ref.read(betaModeProvider.notifier).ready();
    if (!ref.mounted || !ref.read(opknapperAvailableProvider)) return;
    if (!_started) {
      _started = true;
      _tapSub = OpknapperNotificationTaps.stream.listen(_openFromTap);
      try {
        await ref.read(localNotificationServiceProvider).initialize();
        final details = await _plugin.getNotificationAppLaunchDetails();
        final tap = details?.didNotificationLaunchApp == true
            ? OpknapperNotificationTaps.decode(
                details?.notificationResponse?.payload,
              )
            : null;
        if (tap != null) _openFromTap(tap);
      } catch (error) {
        DebugLogger.warning(
          'launch-tap-failed',
          scope: _scope,
          data: {'error': error.toString()},
        );
      }
    }
    await refresh();
  }

  void _openFromTap(Map<String, Object?> tap) {
    final open = tap['open'];
    final location = Uri(
      path: OpknapperConfig.routePath,
      queryParameters: open is String && open.isNotEmpty
          ? {'open': open}
          : null,
    ).toString();
    try {
      NavigationService.router.go(location);
    } catch (error) {
      DebugLogger.warning(
        'tap-route-failed',
        scope: _scope,
        data: {'error': error.toString()},
      );
    }
  }

  /// Turns the reminder on or off. Turning it on asks for permission; returns
  /// whether reminders can be shown.
  Future<bool> setEnabled(bool enabled, {TimeOfDay? time}) async {
    await _ready();
    var granted = true;
    if (enabled) {
      granted = await ref
          .read(localNotificationServiceProvider)
          .requestPermissions();
    }
    state = state.copyWith(enabled: enabled && granted, time: time);
    await _persist();
    await refresh();
    return state.enabled;
  }

  Future<void> setTime(TimeOfDay time) async {
    await _ready();
    state = state.copyWith(time: time);
    await _persist();
    await refresh();
  }

  /// The game was opened: the window starts again from today.
  Future<void> markSeen() => refresh();

  /// Today's letter is answered: no reminder for it later today, also when
  /// the game is opened again later that day.
  Future<void> markAnswered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _dayKey(tz.TZDateTime.now(_zone()));
      await prefs.setString(_answeredDayKey, today);
    } catch (error) {
      DebugLogger.warning(
        'answered-save-failed',
        scope: _scope,
        data: {'error': error.toString()},
      );
    }
    await refresh(skipToday: true);
  }

  static String _dayKey(tz.TZDateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// Rebuilds the window: cancels every pending Opknapper reminder and, when
  /// on, schedules the next [windowDays] working days.
  Future<void> refresh({bool skipToday = false}) {
    final run = _refreshTail.then((_) => _refresh(skipToday: skipToday));
    _refreshTail = run.catchError((Object _) {});
    return run;
  }

  Future<void> _refresh({required bool skipToday}) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    final settings = await _ready();
    try {
      await ref.read(localNotificationServiceProvider).initialize();
      await _cancelPending();
      await ref.read(betaModeProvider.notifier).ready();
      if (!settings.enabled || !ref.read(opknapperAvailableProvider)) return;
      if (Platform.isAndroid) await _ensureAndroidChannel();

      final zone = _zone();
      final now = tz.TZDateTime.now(zone);
      if (!skipToday) {
        final prefs = await SharedPreferences.getInstance();
        skipToday = prefs.getString(_answeredDayKey) == _dayKey(now);
      }
      var day = tz.TZDateTime(zone, now.year, now.month, now.day);
      var scheduled = 0;
      var guard = 0;
      while (scheduled < windowDays && guard < 14) {
        guard++;
        final at = tz.TZDateTime(
          zone,
          day.year,
          day.month,
          day.day,
          settings.time.hour,
          settings.time.minute,
        );
        final isToday =
            day.year == now.year &&
            day.month == now.month &&
            day.day == now.day;
        final workingDay =
            day.weekday >= DateTime.monday && day.weekday <= DateTime.friday;
        if (workingDay && at.isAfter(now) && !(isToday && skipToday)) {
          await _schedule(at);
          scheduled++;
        }
        day = tz.TZDateTime(zone, day.year, day.month, day.day + 1);
      }
      DebugLogger.log(
        'window-scheduled',
        scope: _scope,
        data: {'count': scheduled, 'time': settings.timeLabel},
      );
    } catch (error, stackTrace) {
      DebugLogger.error(
        'refresh-failed',
        scope: _scope,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  tz.Location _zone() {
    if (!_zonesReady) {
      tzdata.initializeTimeZones();
      _zonesReady = true;
    }
    return tz.getLocation(_zoneName);
  }

  int _idFor(tz.TZDateTime day) {
    final days = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(_epoch).inDays;
    return _idBase + (days % _idSpan + _idSpan) % _idSpan;
  }

  static bool _isOurs(int id) => id >= _idBase && id < _idBase + _idSpan;

  Future<void> _cancelPending() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (_isOurs(request.id)) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  Future<void> _ensureAndroidChannel() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            OpknapperStrings.channelName,
            description: OpknapperStrings.channelDescription,
            importance: Importance.defaultImportance,
          ),
        );
  }

  Future<void> _schedule(tz.TZDateTime at) async {
    final lines = OpknapperStrings.reminders;
    final (title, body) = lines[at.day % lines.length];
    await _plugin.zonedSchedule(
      id: _idFor(at),
      title: title,
      body: body,
      scheduledDate: at,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          OpknapperStrings.channelName,
          channelDescription: OpknapperStrings.channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
          threadIdentifier: 'opknapper',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: OpknapperNotificationTaps.encode(),
    );
  }
}
