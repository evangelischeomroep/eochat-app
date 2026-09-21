import '../../core/models/model.dart';

/// Fork: the model description Open WebUI admins write under
/// `info.meta.description`, reduced to one line for list subtitles.
///
/// Live payloads carry it under `info.meta`, cached or normalized ones may
/// have it at the top level or under `meta`; the first non-empty wins.
/// Markdown headings, bullets and quotes are stripped from the first line so
/// the subtitle reads as prose next to the model name.
String? singleLineModelDescription(Model model) {
  final candidates = <dynamic>[
    model.description,
    _dig(model.metadata, ['info', 'meta', 'description']),
    _dig(model.metadata, ['meta', 'description']),
    _dig(model.metadata, ['description']),
  ];
  for (final candidate in candidates) {
    if (candidate is! String) continue;
    final line = _firstProseLine(candidate);
    if (line != null) return line;
  }
  return null;
}

String? _firstProseLine(String raw) {
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final trimmed = line
        .replaceFirst(RegExp(r'^\s*(?:#{1,6}\s+|[-*+]\s+|>\s+|\d+\.\s+)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

dynamic _dig(dynamic value, List<String> path) {
  var current = value;
  for (final key in path) {
    if (current is! Map) return null;
    current = current[key];
  }
  return current;
}
