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

  /// When false, the upstream "Support Conduit" donation tiles are hidden
  /// (profile page + sidebar native sheet). Off by default for EOchat builds.
  static const bool showDonationLinks = bool.fromEnvironment(
    'SHOW_DONATION_LINKS',
    defaultValue: false,
  );

  /// When false, the upstream in-app release notes banner/sheet (added in
  /// conduit 4.0.1) never presents. Off by default for EOchat builds: its
  /// copy is written in cogwheel0's first-person voice about "Conduit" and
  /// its review-prompt button links to upstream's own App Store/Play Store
  /// listings (release_links.dart), not EOchat's.
  static const bool showReleaseNotesBanner = bool.fromEnvironment(
    'SHOW_RELEASE_NOTES_BANNER',
    defaultValue: false,
  );

  /// Brand name shown in accessibility labels and a handful of UI strings.
  /// Empty means "use the upstream default".
  static const String _brandName = String.fromEnvironment(
    'BRAND_NAME',
    defaultValue: 'EOchat',
  );

  static const String _brandDescription = String.fromEnvironment(
    'BRAND_DESCRIPTION',
    defaultValue: 'Beveiligd en afgeschermde AI',
  );

  static String? get brandNameOverride =>
      _brandName.isEmpty ? null : _brandName;

  static String? get brandDescriptionOverride =>
      _brandDescription.isEmpty ? null : _brandDescription;

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
