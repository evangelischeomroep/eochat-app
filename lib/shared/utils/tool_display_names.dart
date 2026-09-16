import 'package:conduit/l10n/app_localizations.dart';

/// Fork-owned helper that turns raw tool identifiers (`search_web`,
/// `fetch_url`, `get_current_timestamp`) into short human labels for the
/// collapsed "Explored …" summary line above an assistant message.
///
/// Kept out of the upstream renderer/status widgets so the mapping survives
/// upstream syncs; those widgets only call [summarize].
class ToolDisplayNames {
  ToolDisplayNames._();

  /// Housekeeping tools that add nothing for the reader. Dropped from the
  /// summary unless they are the only tools that ran.
  static const Set<String> _hidden = <String>{
    'get_current_timestamp',
    'get_current_time',
    'get_current_date',
    'get_current_datetime',
    'get_time',
    'get_date',
    'get_datetime',
    'current_time',
    'current_date',
  };

  static const Set<String> _webSearch = <String>{
    'search_web',
    'web_search',
    'websearch',
    'search',
    'duckduckgo_search',
    'google_search',
    'brave_search',
    'tavily_search',
    'searxng_search',
    'bing_search',
  };

  static const Set<String> _fetchUrl = <String>{
    'fetch_url',
    'fetch_page',
    'fetch_webpage',
    'read_url',
    'read_webpage',
    'open_url',
    'get_url',
    'get_webpage',
    'web_fetch',
    'web_scrape',
    'scrape_url',
    'scrape_webpage',
    'browse',
  };

  static const Set<String> _codeExecution = <String>{
    'code_interpreter',
    'execute_code',
    'run_code',
    'execute_python',
    'run_python',
    'python',
  };

  static final RegExp _identifier = RegExp(
    r'^[A-Za-z0-9]+(?:[_-][A-Za-z0-9]+)+$',
  );

  /// Label to show for [rawName], or `null` when the tool should be hidden.
  static String? labelFor(String rawName, AppLocalizations l10n) {
    final key = rawName.trim().toLowerCase();
    if (_hidden.contains(key)) return null;
    if (_webSearch.contains(key)) return l10n.toolSummaryWebSearch;
    if (_fetchUrl.contains(key)) return l10n.toolSummaryFetchUrl;
    if (_codeExecution.contains(key)) return l10n.toolSummaryCodeExecution;
    return humanize(rawName);
  }

  /// `search_web` -> `search web`. Names that are not snake/kebab-case
  /// identifiers (free-text descriptions, already-friendly names) pass
  /// through untouched.
  static String humanize(String raw) {
    final trimmed = raw.trim();
    if (!_identifier.hasMatch(trimmed)) return trimmed;
    return trimmed.replaceAll(RegExp(r'[_-]+'), ' ').toLowerCase();
  }

  /// Comma-separated summary with repeat counts, e.g.
  /// `web search (20), pages read`. Hidden tools are dropped unless nothing
  /// else ran, in which case their humanised names are shown instead.
  static String summarize(Iterable<String> rawNames, AppLocalizations l10n) {
    final counts = <String, int>{};
    final hiddenCounts = <String, int>{};
    for (final raw in rawNames) {
      final label = labelFor(raw, l10n);
      if (label == null) {
        final fallback = humanize(raw);
        hiddenCounts[fallback] = (hiddenCounts[fallback] ?? 0) + 1;
        continue;
      }
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final source = counts.isEmpty ? hiddenCounts : counts;
    return source.entries
        .map(
          (entry) =>
              entry.value > 1 ? '${entry.key} (${entry.value})' : entry.key,
        )
        .join(', ');
  }
}
