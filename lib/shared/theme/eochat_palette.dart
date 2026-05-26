import 'package:flutter/material.dart';

import 'tweakcn_themes.dart';

/// EOchat brand palette — kept in its own file so the upstream
/// `tweakcn_themes.dart` stays close to vanilla and future merges are cheap.
///
/// To tweak EOchat colours, edit this file only. To register additional fork
/// palettes, add them here and they will be picked up by [eochatPalettes].
class EOchatBrand {
  EOchatBrand._();

  // Screen/RGB brand colours from the EO brand guidelines.
  static const Color purple = Color(0xFF8820F9);
  static const Color red = Color(0xFFFF5A5A);
  static const Color yellow = Color(0xFFEDDD68);
  static const Color peach = Color(0xFFFEF8F8);
  static const Color purpleTint = Color(0xFF6423BE);
}

final TweakcnThemeVariant _eochatLight = TweakcnThemeVariant(
  background: const Color(0xFFFFFFFF),
  foreground: const Color(0xFF1F1235),
  card: EOchatBrand.peach,
  cardForeground: const Color(0xFF1F1235),
  popover: const Color(0xFFFFFFFF),
  popoverForeground: const Color(0xFF1F1235),
  primary: EOchatBrand.purple,
  primaryForeground: const Color(0xFFFFFFFF),
  secondary: const Color(0xFFF5ECEC),
  secondaryForeground: const Color(0xFF1F1235),
  muted: const Color(0xFFF8F3F3),
  mutedForeground: const Color(0xFF7B5AB5),
  accent: EOchatBrand.yellow,
  accentForeground: const Color(0xFF2B213D),
  destructive: EOchatBrand.red,
  destructiveForeground: const Color(0xFFFFFFFF),
  border: const Color(0xFFE4CFCF),
  input: const Color(0xFFFFFFFF),
  ring: EOchatBrand.purple,
  sidebarBackground: EOchatBrand.peach,
  sidebarForeground: const Color(0xFF1F1235),
  sidebarPrimary: EOchatBrand.purple,
  sidebarPrimaryForeground: const Color(0xFFFFFFFF),
  sidebarAccent: const Color(0xFFF5DADA),
  sidebarAccentForeground: const Color(0xFF1F1235),
  sidebarBorder: const Color(0xFFFCEDED),
  sidebarRing: EOchatBrand.purple,
  success: const Color(0xFF34C759),
  successForeground: const Color(0xFF003018),
  warning: EOchatBrand.yellow,
  warningForeground: const Color(0xFF2B213D),
  info: EOchatBrand.purpleTint,
  infoForeground: const Color(0xFFFFFFFF),
  radius: 10,
  fontSans: _fontSans,
  fontSerif: _fontSerif,
  fontMono: _fontMono,
);

final TweakcnThemeVariant _eochatDark = TweakcnThemeVariant(
  background: const Color(0xFF140A24),
  foreground: const Color(0xFFF5EEFF),
  card: const Color(0xFF1D1033),
  cardForeground: const Color(0xFFF5EEFF),
  popover: const Color(0xFF25113F),
  popoverForeground: const Color(0xFFF5EEFF),
  primary: EOchatBrand.purple,
  primaryForeground: const Color(0xFFFFFFFF),
  secondary: const Color(0xFF25113F),
  secondaryForeground: const Color(0xFFF5EEFF),
  muted: const Color(0xFF2B164A),
  mutedForeground: const Color(0xFFC6AFEA),
  accent: EOchatBrand.yellow,
  accentForeground: const Color(0xFF2B213D),
  destructive: EOchatBrand.red,
  destructiveForeground: const Color(0xFFFFFFFF),
  border: const Color(0xFF3A1F63),
  input: const Color(0xFF3A1F63),
  ring: EOchatBrand.purple,
  sidebarBackground: const Color(0xFF351973),
  sidebarForeground: const Color(0xFFF5EEFF),
  sidebarPrimary: EOchatBrand.yellow,
  sidebarPrimaryForeground: const Color(0xFF2B213D),
  sidebarAccent: const Color(0xFF25113F),
  sidebarAccentForeground: const Color(0xFFD4B8F5),
  sidebarBorder: const Color(0xFF3A1F63),
  sidebarRing: EOchatBrand.purple,
  success: const Color(0xFF30D158),
  successForeground: const Color(0xFF001A00),
  warning: EOchatBrand.yellow,
  warningForeground: const Color(0xFF2B213D),
  info: const Color(0xFFB07EFF),
  infoForeground: const Color(0xFF1A0030),
  radius: 10,
  fontSans: _fontSans,
  fontSerif: _fontSerif,
  fontMono: _fontMono,
);

const _fontSans = <String>[
  'ui-sans-serif',
  'system-ui',
  '-apple-system',
  'BlinkMacSystemFont',
  'Segoe UI',
  'Roboto',
  'Helvetica Neue',
  'Arial',
  'Noto Sans',
  'sans-serif',
  'Apple Color Emoji',
  'Segoe UI Emoji',
  'Segoe UI Symbol',
  'Noto Color Emoji',
];

const _fontSerif = <String>[
  'ui-serif',
  'Georgia',
  'Cambria',
  'Times New Roman',
  'Times',
  'serif',
];

const _fontMono = <String>[
  'ui-monospace',
  'SFMono-Regular',
  'SF Mono',
  'Menlo',
  'Monaco',
  'Consolas',
  'Liberation Mono',
  'Courier New',
  'monospace',
];

/// Public palette definition used by `TweakcnThemes`.
final TweakcnThemeDefinition eochatPalette = TweakcnThemeDefinition(
  id: 'eochat',
  labelBuilder: (_) => 'EOchat',
  descriptionBuilder: (_) => 'EO brand palette',
  light: _eochatLight,
  dark: _eochatDark,
  preview: const <Color>[
    EOchatBrand.purple,
    EOchatBrand.red,
    EOchatBrand.yellow,
  ],
);
