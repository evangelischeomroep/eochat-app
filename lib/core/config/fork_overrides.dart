/// Fork-specific runtime overrides, ideally kept small for easy upstream merges.
///
/// Values can be overridden per build using `--dart-define`.
class ForkOverrides {
  ForkOverrides._();

  static const bool preconfigureServer = bool.fromEnvironment(
    'PRECONFIGURE_SERVER',
    defaultValue: true,
  );

  static const String preconfiguredServerUrl = String.fromEnvironment(
    'PRECONFIGURED_SERVER_URL',
    defaultValue: 'https://chat.eo.nl',
  );

  static const bool skipSetupScreenWhenPreconfigured = bool.fromEnvironment(
    'SKIP_SETUP_SCREEN_WHEN_PRECONFIGURED',
    defaultValue: true,
  );

  static const bool forceSsoOnly = bool.fromEnvironment(
    'FORCE_SSO_ONLY',
    defaultValue: true,
  );

  static const bool enableStartupLoadingWatchdog = bool.fromEnvironment(
    'ENABLE_STARTUP_LOADING_WATCHDOG',
    defaultValue: true,
  );

  static const int startupLoadingTimeoutMs = int.fromEnvironment(
    'STARTUP_LOADING_TIMEOUT_MS',
    defaultValue: 12000,
  );

  static const String preferredSsoProvider = String.fromEnvironment(
    'PREFERRED_SSO_PROVIDER',
    defaultValue: 'microsoft',
  );

  static String get defaultServerId => 'nl.eo.eochat.default_server';

  static bool get hasPreconfiguredServer =>
      preconfigureServer && preconfiguredServerUrl.trim().isNotEmpty;

  static String get normalizedPreconfiguredServerUrl {
    final trimmed = preconfiguredServerUrl.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
