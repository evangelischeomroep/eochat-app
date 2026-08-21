import 'package:conduit/shared/widgets/platform_ui/platform_ui.dart';
import 'package:conduit/shared/theme/theme_extensions.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

import 'adaptive_toolbar_components.dart';
import 'chrome_gradient_fade.dart';

const double _nativeTabBarPlaceholderHeight = 50;

/// iOS 26 sidebar shell backed by cupertino_native_better chrome.
///
/// Wrapped in a [CupertinoTheme] override so the native iOS chrome (tab bar,
/// nav bar) picks up EOchat's sidebar brand color, while [body] keeps the
/// original app theme.
class SidebarIos26Scaffold extends StatelessWidget {
  const SidebarIos26Scaffold({
    super.key,
    this.bottomNavigationBar,
    required this.body,
    this.leading,
    this.actions,
    this.showNativeView = true,
  });

  final AdaptiveBottomNavigationBar? bottomNavigationBar;
  final Widget body;
  final Widget? leading;
  final List<AdaptiveAppBarAction>? actions;
  final bool showNativeView;

  @override
  Widget build(BuildContext context) {
    // The native iOS 26 UITabBar reads its tint from
    // CupertinoTheme.of(context).primaryColor (not from any parameter we can
    // pass). Override the CupertinoTheme so the active tab uses the
    // sidebar-specific primary color, then restore the original primaryColor
    // around the body so other Cupertino widgets in the tab content are
    // unaffected.
    final originalCupertinoTheme = CupertinoTheme.of(context);
    final sidebarPrimary = context.conduitTheme.sidebarPrimary;

    final route = ModalRoute.of(context);
    final routeAllowsNativeView =
        (route?.isCurrent ?? true) ||
        route?.animation?.status == AnimationStatus.reverse;
    final composeNativeViews = showNativeView && routeAllowsNativeView;
    final navigation = bottomNavigationBar;
    final safePadding = MediaQuery.paddingOf(context);
    final renderedBottomNavigation = switch (navigation) {
      final navigation?
          when navigation.items.length >= 2 && navigation.items.length <= 5 =>
        navigation.renderer == AdaptiveBottomNavigationRenderer.fullWidth
            ? buildAdaptiveCupertinoTabBar(navigation)
            : composeNativeViews
            ? buildAdaptiveNativeTabBar(
                navigation,
                tint:
                    navigation.selectedItemColor ??
                    CupertinoTheme.of(context).primaryColor,
              )
            : SizedBox(
                height: safePadding.bottom + _nativeTabBarPlaceholderHeight,
              ),
      _ => null,
    };
    final hasBottomNavigation = renderedBottomNavigation != null;
    final textColor = CupertinoColors.label.resolveFrom(context);
    final hasNavigationBar = leading != null || actions?.isNotEmpty == true;
    final toolbarActions = actions ?? const <AdaptiveAppBarAction>[];
    final toolbarActionsWidth = toolbarActions.isEmpty
        ? 0.0
        : (toolbarActions.length * TouchTarget.minimum) +
              ((toolbarActions.length - 1) * Spacing.sm);

return CupertinoTheme(
      data: originalCupertinoTheme.copyWith(primaryColor: sidebarPrimary),
      child: CupertinoPageScaffold(
        resizeToAvoidBottomInset: !hasBottomNavigation,
        navigationBar: hasNavigationBar
            ? ConduitAdaptiveCupertinoNavigationBar(
                textScaler: MediaQuery.textScalerOf(context),
                leading: leading ?? const SizedBox.shrink(),
                trailing: toolbarActions.isEmpty
                    ? null
                    : SizedBox(
                        width: toolbarActionsWidth,
                        height: TouchTarget.minimum,
                        child: composeNativeViews
                            ? _NativeToolbarActions(actions: toolbarActions)
                            : null,
                      ),
              )
            : null,
        child: Stack(
          children: [
            DefaultTextStyle(
              style: TextStyle(color: textColor, fontSize: 17),
              child: CupertinoTheme(data: originalCupertinoTheme, child: body),
            ),
            if (hasNavigationBar)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: ConduitChromeGradientFade.top(
                  contentHeight:
                      safePadding.top +
                      conduitAdaptiveToolbarHeightOf(context),
                ),
              ),
            if (renderedBottomNavigation != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: renderedBottomNavigation,
              ),
          ],
        ),
      ),
    );
  }
}

class _NativeToolbarActions extends StatelessWidget {
  const _NativeToolbarActions({required this.actions});

  final List<AdaptiveAppBarAction> actions;

  @override
  Widget build(BuildContext context) {
    return CNGlassButtonGroup.fromWidgets(
      spacing: 8,
      spacingForGlass: 36,
      buttonWidgets: [
        for (final action in actions)
          if (action.title case final title?)
            CNButton(
              label: title,
              onPressed: action.onPressed,
              tint: action.tintColor,
              config: CNButtonConfig(
                minHeight: TouchTarget.minimum,
                shrinkWrap: true,
                style: action.prominent
                    ? CNButtonStyle.prominentGlass
                    : CNButtonStyle.glass,
              ),
            )
          else
            CNButton.icon(
              icon: action.iosSymbol == null
                  ? null
                  : CNSymbol(
                      action.iosSymbol!,
                      size: kCupertinoNativeControlSymbolExtent,
                    ),
              customIcon: action.iosSymbol == null ? action.icon : null,
              onPressed: action.onPressed,
              tint: action.tintColor,
              config: CNButtonConfig(
                minHeight: TouchTarget.minimum,
                width: TouchTarget.minimum,
                style: action.prominent
                    ? CNButtonStyle.prominentGlass
                    : CNButtonStyle.glass,
              ),
            ),
      ],
    );
  }
}
