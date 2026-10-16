// Fork-only (EOchat): the Opknapper game page, in the sidebar's shell beside
// chat, notes and channels.
//
// Sign-in: ai.eo.nl sits behind App Service Authentication with Entra ID, so
// the page needs no sign-in of its own. The web view shares the app's
// default website data store with the SSO sign-in that signed the colleague
// in to EOchat, so Microsoft's session is usually still there and the game
// opens signed in without a prompt. When it isn't, the authorize request gets
// the colleague's EO address as `login_hint` (and `domain_hint=eo.nl`), so
// Microsoft skips the account picker and asks at most for the password.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:conduit/l10n/app_localizations.dart';
import 'package:conduit/shared/widgets/platform_ui/platform_ui.dart';
import 'package:conduit_core/features/auth/providers/unified_auth_providers.dart';
import 'package:conduit_core/features/navigation/models/sidebar_navigation_model.dart';
import 'package:conduit_core/features/navigation/providers/sidebar_active_tab_provider.dart';
import 'package:conduit_core/utils/debug_logger.dart';

import '../../../platform/app_intents_service.dart';
import '../../../platform/webview_cookie_helper.dart';
import '../../../shared/theme/theme_extensions.dart';
import '../../../shared/utils/external_link_launcher.dart';
import '../../../shared/widgets/adaptive_route_shell.dart';
import '../../../shared/services/navigation_service.dart';
import '../opknapper_availability.dart';
import '../opknapper_config.dart';
import '../services/opknapper_bridge.dart';
import '../services/opknapper_reminders.dart';

const String _scope = 'opknapper/page';

/// Same mobile browser identity the SSO sign-in uses, so Microsoft treats
/// both web views alike, with a suffix the game can read.
String _userAgent() {
  const suffix = ' EOchatApp/Opknapper';
  if (Platform.isIOS) {
    return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
        'Mobile/15E148 Safari/604.1$suffix';
  }
  return 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36$suffix';
}

/// The address the page opens on; [open] asks the game to show something
/// first, such as the postvakjes after a reminder was tapped.
Uri opknapperStartUri({String? open}) {
  final base = OpknapperConfig.gameUri;
  if (open == null || open.isEmpty) return base;
  return base.replace(queryParameters: {...base.queryParameters, 'open': open});
}

/// Adds the colleague's address to Microsoft's authorize request, unless the
/// request already names an account. Returns null when nothing changes.
Uri? opknapperAuthorizeWithHint(Uri uri, String? email) {
  if (!OpknapperConfig.isMicrosoftAuthorize(uri)) return null;
  final address = email?.trim() ?? '';
  if (address.isEmpty || !address.contains('@')) return null;
  final params = Map<String, String>.from(uri.queryParameters);
  if (params.containsKey('login_hint')) return null;
  params['login_hint'] = address;
  params.putIfAbsent('domain_hint', () => address.split('@').last);
  return uri.replace(queryParameters: params);
}

class OpknapperPage extends ConsumerStatefulWidget {
  const OpknapperPage({super.key, this.open});

  /// Passed on to the game as `?open=`; see [opknapperStartUri].
  final String? open;

  @override
  ConsumerState<OpknapperPage> createState() => _OpknapperPageState();
}

class _OpknapperPageState extends ConsumerState<OpknapperPage> {
  InAppWebViewController? _controller;
  late final OpknapperBridge _bridge = OpknapperBridge(
    ref,
    shareOrigin: _shareOrigin,
  );

  /// The middle of the page, for the share sheet's popover on an iPad.
  Rect? _shareOrigin() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final centre = box.localToGlobal(box.size.center(Offset.zero));
    return Rect.fromCenter(center: centre, width: 1, height: 1);
  }

  late final OpknapperGameOpen _gameOpen;

  /// The last navigation we cancelled to load another in its place.
  String? _replacedNavigation;
  bool _loading = true;
  bool _failed = false;
  bool _ready = false;

  /// Bumped to build a fresh web view: Android's can't be reused once its
  /// render process is gone.
  int _webViewGeneration = 0;

  @override
  void dispose() {
    // After this frame: the drawer shell is rebuilding as the page leaves.
    final gameOpen = _gameOpen;
    Future.microtask(() => gameOpen.set(false));
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _gameOpen = ref.read(opknapperGameOpenProvider.notifier);
    Future.microtask(() => _gameOpen.set(true));
    // Opening the game renews the reminder window (see OpknapperReminders).
    unawaited(ref.read(opknapperRemindersProvider.notifier).markSeen());
    // A logout purge still running must finish before the web view starts,
    // or it would erase the game's fresh session. And until it's released,
    // the game is there only in beta mode: anyone else who lands here (an old
    // reminder, a link) goes back to chat.
    unawaited(() async {
      await WebViewCookieHelper.waitForPendingDataOperations();
      await ref.read(betaModeProvider.notifier).ready();
      if (!mounted) return;
      if (!ref.read(opknapperAvailableProvider)) {
        NavigationService.router.go(Routes.chat);
        return;
      }
      setState(() => _ready = true);
    }());
  }

  @override
  void didUpdateWidget(covariant OpknapperPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final open = widget.open;
    if (open != null && open != oldWidget.open) {
      // Already open: tell the game rather than reloading it.
      unawaited(
        _controller?.evaluateJavascript(
          source:
              "window.dispatchEvent(new CustomEvent('eochat:open', "
              "{detail: {open: ${jsonEncode(open)}}}));",
        ),
      );
    }
  }

  Future<void> _reload() async {
    setState(() {
      _failed = false;
      _loading = true;
    });
    final controller = _controller;
    if (controller == null) return;
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri.uri(opknapperStartUri())),
    );
  }

  Future<NavigationActionPolicy> _onNavigation(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final url = action.request.url;
    if (url == null) return NavigationActionPolicy.ALLOW;
    final uri = Uri.tryParse(url.toString());
    if (uri == null) return NavigationActionPolicy.CANCEL;
    if (uri.scheme == 'about' || uri.scheme == 'blob' || uri.scheme == 'data') {
      return NavigationActionPolicy.ALLOW;
    }

    if (action.isForMainFrame) {
      final hinted = opknapperAuthorizeWithHint(
        uri,
        ref.read(currentUserProvider2)?.email,
      );
      if (hinted != null) {
        _replacedNavigation = uri.toString();
        unawaited(
          controller.loadUrl(urlRequest: URLRequest(url: WebUri.uri(hinted))),
        );
        return NavigationActionPolicy.CANCEL;
      }
    }

    if (OpknapperConfig.isInGameHost(uri)) return NavigationActionPolicy.ALLOW;

    // Sub-frames (an embedded video, a sign-in iframe) stay inside.
    if (!action.isForMainFrame) return NavigationActionPolicy.ALLOW;

    // A guide's start link to EOchat opens a new chat here, prompt typed.
    if (OpknapperConfig.isEOchatWebLink(uri)) {
      final prompt = uri.queryParameters['q'];
      unawaited(
        ref
            .read(appIntentCoordinatorProvider.notifier)
            .openChatFromExternal(
              prompt: prompt,
              focusComposer: true,
              resetChat: true,
            ),
      );
      return NavigationActionPolicy.CANCEL;
    }

    unawaited(launchExternalLink(uri.toString(), scope: _scope));
    return NavigationActionPolicy.CANCEL;
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
    controller.addJavaScriptHandler(
      handlerName: OpknapperConfig.bridgeHandlerName,
      callback: (JavaScriptHandlerFunctionData data) => _bridge.handle(
        data.args,
        origin: data.origin.toString(),
        isMainFrame: data.isMainFrame,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.conduitTheme;
    // Beta mode turned off while the game is open: back to chat.
    ref.listen<bool>(opknapperAvailableProvider, (previous, next) {
      if (!next) NavigationService.router.go(Routes.chat);
    });
    return AdaptiveRouteShell(
      // Black behind the game: the strip and the safe area read as one.
      backgroundColor: _gameBackground,
      bodySafeArea: true,
      body: !isWebViewSupported
          ? _buildMessage(context, OpknapperStrings.loadFailed, retry: false)
          : Column(
              children: [
                _buildCloseStrip(context),
                Expanded(child: _buildGameStack(context, theme)),
              ],
            ),
    );
  }

  static const Color _gameBackground = Color(0xFF000000);

  Widget _buildGameStack(BuildContext context, ConduitThemeExtension theme) {
    return Stack(
      children: [
        if (_ready)
          Positioned.fill(child: _buildWebView(context))
        else
          const SizedBox.shrink(),
        if (_loading && !_failed)
          Positioned.fill(
            child: ColoredBox(
              color: _gameBackground,
              child: const Center(child: CircularProgressIndicator.adaptive()),
            ),
          ),
        if (_failed)
          Positioned.fill(
            child: ColoredBox(
              color: _gameBackground,
              child: _buildMessage(
                context,
                OpknapperStrings.loadFailed,
                retry: true,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWebView(BuildContext context) {
    return InAppWebView(
      key: ValueKey<int>(_webViewGeneration),
      initialUrlRequest: URLRequest(
        url: WebUri.uri(opknapperStartUri(open: widget.open)),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useShouldOverrideUrlLoading: true,
        userAgent: _userAgent(),
        // The game is a three.js world with sound: no gesture needed to
        // start it, inline video, no zoom or rubber band, no swipe-back.
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        supportZoom: false,
        disallowOverScroll: true,
        allowsBackForwardNavigationGestures: false,
        javaScriptCanOpenWindowsAutomatically: false,
        supportMultipleWindows: false,
        transparentBackground: false,
        useHybridComposition: true,
      ),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: opknapperBridgeBootstrapScript(
            platform: Platform.operatingSystem,
          ),
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ]),
      onWebViewCreated: _onWebViewCreated,
      shouldOverrideUrlLoading: _onNavigation,
      onLoadStop: (controller, url) {
        if (!mounted) return;
        // Microsoft's sign-in pages count as loaded too: show them. A page
        // that loads has outlived any error from a navigation we replaced.
        setState(() {
          _loading = false;
          _failed = false;
        });
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame != true) return;
        // A navigation we cancelled ourselves isn't a failure. WebKit reports
        // that as "frame load interrupted" (WebKitErrorDomain 102), not as a
        // cancellation, when the login hint replaces Microsoft's request.
        if (error.type == WebResourceErrorType.CANCELLED) return;
        final url = request.url.toString();
        if (url == _replacedNavigation ||
            error.description.contains('code=102')) {
          return;
        }
        DebugLogger.warning(
          'load-error',
          scope: _scope,
          data: {
            'type': error.type.toString(),
            'description': error.description,
            'url': request.url.toString(),
          },
        );
        if (mounted) setState(() => _failed = true);
      },
      onRenderProcessGone: (controller, detail) {
        // A crashed WebGL page leaves a dead view (Android): build a new one.
        if (!mounted) return;
        setState(() {
          _controller = null;
          _webViewGeneration++;
          _failed = false;
          _loading = true;
        });
      },
      onWebContentProcessDidTerminate: (controller) {
        unawaited(_reload());
      },
    );
  }

  /// Leaves the game for the chat tab.
  void _close() {
    ref.read(sidebarActiveTabProvider.notifier).set(SidebarTabId.chats);
    NavigationService.router.go(Routes.chat);
  }

  /// A slim strip above the game with just the way out. The game sits below
  /// it, inside the safe area, so it never runs behind the status bar.
  Widget _buildCloseStrip(BuildContext context) {
    final theme = context.conduitTheme;
    return SizedBox(
      height: 44,
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          key: const ValueKey<String>('opknapper-close'),
          tooltip: AppLocalizations.of(context)!.close,
          onPressed: _close,
          icon: Icon(
            Platform.isIOS ? CupertinoIcons.xmark : Icons.close,
            size: 22,
            color: theme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(
    BuildContext context,
    String text, {
    required bool retry,
  }) {
    final theme = context.conduitTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTypography.bodyLargeStyle.copyWith(
                color: theme.textSecondary,
              ),
            ),
            if (retry) ...[
              const SizedBox(height: Spacing.md),
              AdaptiveButton(
                label: OpknapperStrings.retry,
                onPressed: () => unawaited(_reload()),
              ),
              const SizedBox(height: Spacing.sm),
              AdaptiveButton(
                label: OpknapperStrings.openInBrowser,
                style: AdaptiveButtonStyle.plain,
                onPressed: () => unawaited(
                  launchExternalLink(
                    opknapperStartUri().toString(),
                    scope: _scope,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
