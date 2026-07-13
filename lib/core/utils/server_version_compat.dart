/// Compatibility gate for the Open WebUI server this app talks to.
///
/// Conduit tracks the Open WebUI API surface via the vendored `openwebui-src/`
/// submodule. When the upstream server jumps ahead of what this build has been
/// validated against, endpoints and payloads can drift in ways that silently
/// break the app. Rather than fail in confusing ways deep in a feature, the app
/// surfaces a clear compatibility warning for servers newer than
/// [maxSupportedVersion] while still allowing the user to continue.
///
/// This is a pure leaf utility with no Flutter dependencies so it can be unit
/// tested in isolation and reused from models, providers, and views alike.
class ServerVersionCompat {
  ServerVersionCompat._();

  /// The newest Open WebUI server version this app build is known to support.
  ///
  /// Servers reporting a `/api/config` `version` with a higher **minor** (or
  /// major) component than this are gated off. Patch-only differences are
  /// intentionally ignored — a server on `0.10.3` is treated as compatible
  /// with a max of `0.10.2` because patch releases are expected to be
  /// backwards-compatible. Bump this (and re-verify against `openwebui-src/`)
  /// whenever a newer minor or major server release is validated.
  static const String maxSupportedVersion = '0.10.2';

  /// Parsed [maxSupportedVersion] components: `[major, minor, patch]`.
  static const List<int> _maxSupported = [0, 10, 2];

  /// Whether [rawVersion] is within the supported range.
  ///
  /// Compatibility is checked at the **minor** version level only — patch
  /// differences are ignored. A server on `0.10.3` is treated as supported
  /// when the max is `0.10.2`; a server on `0.11.0` is not.
  ///
  /// Fails open: a `null`, empty, or unparseable version is treated as
  /// supported so the gate never locks users out of a server whose version
  /// string we simply don't understand. The gate only triggers when we can
  /// confidently determine the server is a newer minor or major release.
  static bool isSupported(String? rawVersion) {
    final parsed = _parse(rawVersion);
    if (parsed == null) return true; // fail open on unknown versions
    // Compare only major + minor; ignore patch to avoid false alarms on
    // backwards-compatible server patch releases.
    final serverMajorMinor = [parsed[0], parsed.length > 1 ? parsed[1] : 0];
    final maxMajorMinor = [_maxSupported[0], _maxSupported[1]];
    return _comparePartial(serverMajorMinor, maxMajorMinor) <= 0;
  }

  /// Convenience inverse of [isSupported] for readable call sites.
  static bool isUnsupported(String? rawVersion) => !isSupported(rawVersion);

  /// Parses a semantic-ish version string into up to three numeric components.
  ///
  /// Tolerates a leading `v`/`V` and drops any pre-release or build metadata
  /// suffix (e.g. `0.10.2-dev`, `0.10.2+build.5`). Returns `null` when no
  /// leading numeric component can be found.
  static List<int>? _parse(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('v') || s.startsWith('V')) {
      s = s.substring(1);
    }
    // Strip pre-release / build metadata so `0.10.2-rc1` compares as `0.10.2`.
    final cut = s.indexOf(RegExp(r'[-+ ]'));
    if (cut != -1) {
      s = s.substring(0, cut);
    }
    final match = RegExp(r'^(\d+)(?:\.(\d+))?(?:\.(\d+))?').firstMatch(s);
    if (match == null) return null;
    final major = int.tryParse(match.group(1) ?? '');
    if (major == null) return null;
    final minor = int.tryParse(match.group(2) ?? '0') ?? 0;
    final patch = int.tryParse(match.group(3) ?? '0') ?? 0;
    return [major, minor, patch];
  }

  /// Compares two numeric component lists of equal length, returning -1/0/1.
  static int _comparePartial(List<int> a, List<int> b) {
    final len = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1;
    }
    return 0;
  }
}
