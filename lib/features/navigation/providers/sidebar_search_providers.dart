import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sidebar_search_providers.g.dart';

/// Whether the sidebar header search field is expanded.
@Riverpod(keepAlive: true)
class SidebarHeaderSearchExpanded extends _$SidebarHeaderSearchExpanded {
  @override
  bool build() => false;

  void setExpanded(bool value) => state = value;
}

/// Shared search input for every searchable sidebar destination.
///
/// Wrapped in [Raw] because this intentionally returns a long-lived
/// TextEditingController singleton that riverpod_generator doesn't manage
/// itself - disposal is handled explicitly via [Ref.onDispose] below.
@Riverpod(keepAlive: true)
Raw<TextEditingController> sidebarSearchFieldController(Ref ref) {
  final controller = TextEditingController();
  ref.onDispose(controller.dispose);
  return controller;
}

/// Wrapped in [Raw] for the same reason as [sidebarSearchFieldController].
@Riverpod(keepAlive: true)
Raw<FocusNode> sidebarSearchFieldFocusNode(Ref ref) {
  final node = FocusNode(debugLabel: 'sidebar_header_search');
  ref.onDispose(node.dispose);
  return node;
}

void openSidebarSearch(WidgetRef ref) {
  ref.read(sidebarHeaderSearchExpandedProvider.notifier).setExpanded(true);
  final focusNode = ref.read(sidebarSearchFieldFocusNodeProvider);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (focusNode.context != null) focusNode.requestFocus();
  });
}

void closeSidebarSearch(WidgetRef ref) {
  ref.read(sidebarSearchFieldControllerProvider).clear();
  ref.read(sidebarSearchFieldFocusNodeProvider).unfocus();
  ref.read(sidebarHeaderSearchExpandedProvider.notifier).setExpanded(false);
}
