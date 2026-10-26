import 'package:conduit/features/navigation/widgets/sidebar_tab_registry.dart';
import 'package:conduit_core/features/navigation/models/sidebar_navigation_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const availability = SidebarTabAvailability(
    hermesOnly: false,
    hasOpenWebUi: true,
    hermesEnabled: false,
    notesEnabled: true,
    terminalEnabled: true,
    channelsEnabled: true,
  );

  tearDown(() => debugShowChannelsTab = true);

  test('EOchat hides the Channels tab even when the server enables it', () {
    debugShowChannelsTab = false;

    expect(
      visibleSidebarTabIds(availability),
      isNot(contains(SidebarTabId.channels)),
    );
  });

  test('the terminal tab is presented as Files with a folder', () {
    final descriptor = sidebarTabDescriptor(SidebarTabId.terminal);

    expect(descriptor.sfSymbol, 'folder');
    expect(descriptor.selectedSfSymbol, 'folder.fill');
  });
}
