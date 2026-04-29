import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/unified_auth_providers.dart';
import 'fork_overrides.dart';

/// Tracks prolonged startup loading in fork mode to avoid indefinite splash.
final startupAuthStuckProvider =
    NotifierProvider<_StartupAuthWatchdogNotifier, bool>(
      _StartupAuthWatchdogNotifier.new,
    );

class _StartupAuthWatchdogNotifier extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());

    if (!ForkOverrides.enableStartupLoadingWatchdog ||
        !ForkOverrides.hasPreconfiguredServer) {
      return false;
    }

    final navState = ref.read(authNavigationStateProvider);
    _sync(navState);

    ref.listen<AuthNavigationState>(authNavigationStateProvider, (prev, next) {
      _sync(next);
    });

    return false;
  }

  void _sync(AuthNavigationState navState) {
    if (navState == AuthNavigationState.loading) {
      _timer ??= Timer(
        Duration(milliseconds: ForkOverrides.startupLoadingTimeoutMs),
        () {
          if (ref.mounted &&
              ref.read(authNavigationStateProvider) ==
                  AuthNavigationState.loading) {
            state = true;
          }
        },
      );
      return;
    }

    _timer?.cancel();
    _timer = null;
    if (state) {
      state = false;
    }
  }
}
