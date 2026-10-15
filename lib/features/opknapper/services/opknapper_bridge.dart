// Fork-only (EOchat): what the Opknapper page may ask of the app.
//
// The page calls
//   await window.flutter_inappwebview.callHandler('eochat', {action, ...})
// once `flutterInAppWebViewPlatformReady` has fired, and gets a JSON-able
// answer back. `window.EOchatApp` is set before the page's own scripts run,
// so the page knows synchronously that it's inside the app. The contract is
// versioned (`bridge`); an unknown action answers `{ok: false}` rather than
// throwing, so a newer page keeps working in an older app.
//
// Actions:
//   hello                       → {ok, app, version, platform, bridge, reminders}
//   seen                        → the game was opened; renews the reminders
//   answered                    → today's dagbrief is in; drops today's reminder
//   reminders {enabled, time?}  → turns the reminder on or off ('HH:mm')
//   haptic {style}              → light | medium | heavy | selection |
//                                 success | warning | error
//   openChat {prompt}           → a new EOchat chat with the prompt typed
//   openExternal {url}          → the system browser
//   shareFile {name, base64, mime?}
//                               → the share sheet, to save or send a file the
//                                 page made (the bewijs van deelname as PDF):
//                                 a web view can't download a blob itself

import 'dart:convert';
import 'dart:io' show Directory, File, Platform;
import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:conduit_core/utils/debug_logger.dart';

import '../../../core/services/haptic_service.dart';
import '../../../platform/app_intents_service.dart';
import '../../../shared/utils/external_link_launcher.dart';
import '../opknapper_config.dart';
import 'opknapper_reminders.dart';

const String _scope = 'opknapper/bridge';

/// Set at document start, before the page's scripts.
String opknapperBridgeBootstrapScript({required String platform}) =>
    '''
(function () {
  if (window.EOchatApp) return;
  window.EOchatApp = Object.freeze({
    bridge: ${OpknapperConfig.bridgeVersion},
    platform: '$platform',
    handler: '${OpknapperConfig.bridgeHandlerName}'
  });
  var root = document.documentElement;
  if (root) root.classList.add('in-eochat-app');
})();
''';

class OpknapperBridge {
  OpknapperBridge(this._ref, {Rect? Function()? shareOrigin})
    : _shareOrigin = shareOrigin;

  final WidgetRef _ref;

  /// Where the share sheet points from on an iPad; required there.
  final Rect? Function()? _shareOrigin;

  /// Files the page may hand over, in bytes; a certificate is ~300 kB.
  static const int _maxShareBytes = 15 * 1024 * 1024;

  /// Handles one call from the page. [origin] is the calling frame's origin;
  /// anything but the game's own main frame is refused.
  Future<Map<String, Object?>> handle(
    List<dynamic> args, {
    required String? origin,
    required bool isMainFrame,
  }) async {
    if (!isMainFrame || !_sameOrigin(origin)) {
      DebugLogger.warning(
        'refused',
        scope: _scope,
        data: {'origin': origin, 'mainFrame': isMainFrame},
      );
      return const {'ok': false, 'error': 'origin'};
    }
    final message = args.isNotEmpty && args.first is Map
        ? Map<String, Object?>.from(args.first as Map)
        : const <String, Object?>{};
    final action = message['action'];
    try {
      switch (action) {
        case 'hello':
          return await _hello();
        case 'seen':
          await _reminders.markSeen();
          return _withReminders();
        case 'answered':
          await _reminders.markAnswered();
          return _withReminders();
        case 'reminders':
          final enabled = message['enabled'] == true;
          final time = OpknapperReminderSettings.parseTime(message['time']);
          final granted = await _reminders.setEnabled(enabled, time: time);
          return {..._withReminders(), 'granted': granted};
        case 'haptic':
          final style = message['style'];
          final type = HapticType.values
              .where((t) => t.name == style)
              .firstOrNull;
          await ConduitHaptics.trigger(type ?? HapticType.light);
          return const {'ok': true};
        case 'openChat':
          final prompt = message['prompt'];
          await _ref
              .read(appIntentCoordinatorProvider.notifier)
              .openChatFromExternal(
                prompt: prompt is String ? prompt : null,
                focusComposer: true,
                resetChat: true,
              );
          return const {'ok': true};
        case 'shareFile':
          return {'ok': await _shareFile(message)};
        case 'openExternal':
          final url = message['url'];
          final launched = url is String && await launchExternalLink(url);
          return {'ok': launched};
        default:
          return {'ok': false, 'error': 'unknown-action', 'action': action};
      }
    } catch (error, stackTrace) {
      DebugLogger.error(
        'action-failed',
        scope: _scope,
        error: error,
        stackTrace: stackTrace,
        data: {'action': action},
      );
      return const {'ok': false, 'error': 'failed'};
    }
  }

  Future<bool> _shareFile(Map<String, Object?> message) async {
    final data = message['base64'];
    final rawName = message['name'];
    if (data is! String || data.isEmpty) return false;
    // Only a plain file name, never a path.
    final name = rawName is String && rawName.trim().isNotEmpty
        ? path.basename(rawName.trim())
        : 'opknapper.pdf';
    final mime = message['mime'] is String
        ? message['mime'] as String
        : 'application/pdf';
    final bytes = base64Decode(
      data.contains(',') ? data.split(',').last : data,
    );
    if (bytes.isEmpty || bytes.length > _maxShareBytes) return false;
    final base = await getTemporaryDirectory();
    final dir = Directory(
      path.join(
        base.path,
        'opknapper-share',
        DateTime.now().microsecondsSinceEpoch.toString(),
      ),
    );
    await dir.create(recursive: true);
    final file = File(path.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path, mimeType: mime, name: name)],
        sharePositionOrigin: _shareOrigin?.call(),
      ),
    );
    return true;
  }

  OpknapperReminders get _reminders =>
      _ref.read(opknapperRemindersProvider.notifier);

  Map<String, Object?> _withReminders() => {
    'ok': true,
    'reminders': _ref.read(opknapperRemindersProvider).toJson(),
  };

  Future<Map<String, Object?>> _hello() async {
    String? version;
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {}
    return {
      ..._withReminders(),
      'app': 'EOchat',
      'version': version,
      'platform': Platform.operatingSystem,
      'bridge': OpknapperConfig.bridgeVersion,
    };
  }

  static bool _sameOrigin(String? origin) {
    if (origin == null || origin.isEmpty) return false;
    final actual = Uri.tryParse(origin);
    final expected = OpknapperConfig.gameUri;
    // Compared by scheme and host: WebKit reports the origin with or without
    // a trailing slash and an explicit default port, depending on version.
    return actual != null &&
        actual.scheme.toLowerCase() == expected.scheme.toLowerCase() &&
        actual.host.toLowerCase() == expected.host.toLowerCase();
  }
}
