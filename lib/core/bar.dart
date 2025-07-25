import 'dart:math';

import 'package:animations/animations.dart';
import 'package:dartx/dartx_io.dart';
import 'package:fl_linux_window_manager/models/screen_edge.dart';
import 'package:fl_linux_window_manager/widgets/input_region.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:waywing/widgets/docked_rounded_corners_clipper.dart';
import 'package:waywing/core/feather.dart';
import 'package:waywing/core/config.dart';
import 'package:waywing/widgets/winged_popover.dart';

class Bar extends StatefulWidget {
  const Bar({super.key});

  @override
  State<Bar> createState() => _BarState();
}

class _BarState extends State<Bar> {
  // adding global keys to feathers ensures their state
  // won't be lost when reloading config, including popover and tooltip state
  Map<String, List<GlobalKey>> featherGlobalKeys = {};

  @override
  void didUpdateWidget(covariant Bar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // remove global keys for feathers no longer declared
    final allFeathers = [...config.barStartFeathers, ...config.barCenterFeathers, ...config.barEndFeathers];
    for (final key in featherGlobalKeys.keys) {
      final count = allFeathers.count((e) => e.name == key);
      if (count == 0) {
        featherGlobalKeys.remove(key);
      } else if (featherGlobalKeys[key]!.length > count) {
        featherGlobalKeys[key] = featherGlobalKeys[key]!.sublist(0, count);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // For our calculations on high scale screens, devicePixelRatio needs to be
    // applied only to the sides that span the full screen.
    // For bar crossAxis, since it is unbound, the compositor will give it more
    // physical space so we can use the same amount of DIP (at least in hyprland).
    // For sides that span the full monitor (like bar mainAxis), we actually have
    // less physical space now, so we need to asjust our DIP amounts or it will
    // overflow the screen (because the same amount of DIP now translates to more
    // physical pixels). For scale < 1 it should also work with the same logic.
    final originalMonitorSize = PlatformDispatcher.instance.views.first.display.size;
    final monitorSize = MediaQuery.sizeOf(context);
    // Get actual devicePixelRatio (scale) by comparing the original monitor size to the current one.
    // The devicePixelRatio reported by flutter is different for some reason.
    final devicePixelRatio = originalMonitorSize.width / monitorSize.width;
    final barCrossSize = config.barSize.toDouble();
    final outerRoundedEdgeMainSize = config.barRadiusOutMain;
    double? width, height, top, bottom, left, right;
    Alignment barAlignment, startAlignment, endAlignment;
    if (config.isBarVertical) {
      startAlignment = Alignment.topCenter;
      endAlignment = Alignment.bottomCenter;
      width = barCrossSize;
      top = config.barMarginTop / devicePixelRatio - outerRoundedEdgeMainSize;
      bottom = config.barMarginBottom / devicePixelRatio - outerRoundedEdgeMainSize;
      // don't allow setting an anchor to the opossite of dockSide, doing this would break the Stack widget
      if (config.barSide == ScreenEdge.left) {
        barAlignment = Alignment.centerLeft;
        left = 0; // config.barMarginLeft;
      } else {
        barAlignment = Alignment.centerRight;
        right = 0; // config.barMarginRight;
      }
    } else {
      startAlignment = Alignment.centerLeft;
      endAlignment = Alignment.centerRight;
      height = barCrossSize;
      left = config.barMarginLeft / devicePixelRatio - outerRoundedEdgeMainSize;
      right = config.barMarginRight / devicePixelRatio - outerRoundedEdgeMainSize;
      // don't allow setting an anchor to the opossite of dockSide, doing this would break the Stack widget
      if (config.barSide == ScreenEdge.top) {
        barAlignment = Alignment.topCenter;
        top = 0; // config.barMarginTop;
      } else {
        barAlignment = Alignment.bottomCenter;
        bottom = 0; // config.barMarginBottom;
      }
    }

    Map<String, int> feathersCount = {};
    return Positioned.fill(
      child: AnimatedAlign(
        duration: config.animationDuration,
        curve: config.animationCurve,
        alignment: barAlignment,
        child: AnimatedContainer(
          duration: config.animationDuration,
          curve: config.animationCurve,
          width: width ?? monitorSize.width,
          height: height ?? monitorSize.height,
          padding: EdgeInsets.only(
            top: top?.coerceAtLeast(0) ?? 0,
            bottom: bottom?.coerceAtLeast(0) ?? 0,
            left: left?.coerceAtLeast(0) ?? 0,
            right: right?.coerceAtLeast(0) ?? 0,
          ),
          child: InputRegion(
            child: Material(
              animationDuration: config.animationDuration * 1.5,
              color: Theme.of(context).canvasColor,
              clipBehavior: Clip.antiAliasWithSaveLayer,
              elevation: 6, // TODO: 2 expose bar elevation theme option to user
              shape: DockedRoundedCornersBorder(
                dockedSide: config.barSide,
                radiusInCross: config.barRadiusInCross,
                radiusInMain: config.barRadiusInMain,
                radiusOutCross: config.barRadiusOutCross,
                radiusOutMain: config.barRadiusOutMain,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: endAlignment,
                    child: buildLayoutWidget(
                      context,
                      buildFeatherWidgets(context, config.barEndFeathers, feathersCount),
                    ),
                  ),

                  Align(
                    alignment: Alignment.center,
                    child: buildLayoutWidget(
                      context,
                      buildFeatherWidgets(context, config.barCenterFeathers, feathersCount),
                    ),
                  ),

                  Align(
                    alignment: startAlignment,
                    child: buildLayoutWidget(
                      context,
                      buildFeatherWidgets(context, config.barStartFeathers, feathersCount),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildLayoutWidget(BuildContext context, List<Widget> children) {
    final outerRoundedEdgeMainSize = config.barRadiusOutMain;
    final mainAxisPadding = outerRoundedEdgeMainSize + config.barItemSize * 0.2;
    // TODO: 1 implement a proper layout that handles gracefully when widgets overflow
    // this should also solve the issue of widgets being disposed when switching vertical
    // to horizontal bar (or viceversa) because we switched Row / Column
    if (config.isBarVertical) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: mainAxisPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
    } else {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: mainAxisPadding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
    }
  }

  List<Widget> buildFeatherWidgets(BuildContext context, List<Feather> feathers, Map<String, int> feathersCount) {
    final result = <Widget>[];
    for (final feather in feathers) {
      // TODO: 3 maybe add some visual indication that widgets belong to the same feather
      for (final component in feather.components) {
        if (component.buildIndicators == null) continue;
        feathersCount[feather.name] ??= 0;
        final featherIndex = feathersCount[feather.name]!;
        feathersCount[feather.name] = featherIndex + 1;
        featherGlobalKeys[feather.name] ??= [GlobalKey()];
        while (featherGlobalKeys[feather.name]!.length <= featherIndex) {
          featherGlobalKeys[feather.name]!.add(GlobalKey());
        }
        final key = featherGlobalKeys[feather.name]![featherIndex];

        // TODO: 1 add tooltip

        var widget = _buildPopover(
          context: context,
          component: component,
          builder: (context, popover) {
            final indicators = component.buildIndicators!(context, popover, null);
            if (config.isBarVertical) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: indicators,
              );
            } else {
              return Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: indicators,
              );
            }
          },
        );

        // TODO: 2 listen to component.enabled to have some kind of different decoration?

        // TODO: 2 PERFORMANCE maybe pass a builder instead if a Widget to _buildVisibility
        // so children aren't build unnecessarily for hidden feathers
        widget = _buildVisibility(context, component, widget);

        result.add(KeyedSubtree(key: key, child: widget));
      }
    }
    return result;
  }

  Widget _buildPopover({
    required BuildContext context,
    required FeatherComponent component,
    required PopoverBuilder builder,
  }) {
    if (component.buildPopover == null) {
      return builder(context, null);
    }
    final barRadiusIn = config.barRadiusInMain;
    final popoverAlignment = switch (config.barSide) {
      ScreenEdge.top => Alignment.bottomCenter,
      ScreenEdge.right => Alignment.centerLeft,
      ScreenEdge.bottom => Alignment.topCenter,
      ScreenEdge.left => Alignment.centerRight,
    };
    return ValueListenableBuilder(
      valueListenable: component.isPopoverEnabled,
      builder: (context, isEnabled, child) {
        final rng = Random(); // TODO: 2 remove randomness once testing on animations is done
        final vertMult = rng.nextDouble();
        final horMult = rng.nextDouble();
        final shape = DockedRoundedCornersBorder(
          dockedSide: config.barSide,
          isVertical: config.isBarVertical,
          radiusInCross: config.barRadiusInCross * rng.nextDouble() * 3,
          radiusInMain: config.barRadiusInMain * rng.nextDouble() * 3,
          radiusOutCross: config.barRadiusOutCross * rng.nextDouble() * 5,
          radiusOutMain: config.barRadiusOutMain * rng.nextDouble() * 1,
        );
        return WingedPopover(
          enabled: isEnabled,
          containerId: 'BarPopover',
          // TODO: 3 briefly document how zIndex is used and what the default values are for Bar and other core widgets
          zIndex: -10,
          popupAlignment: popoverAlignment,
          anchorAlignment: popoverAlignment,
          screenPadding: EdgeInsets.only(
            left: config.isBarVertical ? 0 : config.barMarginLeft + barRadiusIn,
            right: config.isBarVertical ? 0 : config.barMarginRight + barRadiusIn,
            top: !config.isBarVertical ? 0 : config.barMarginTop + barRadiusIn,
            bottom: !config.isBarVertical ? 0 : config.barMarginBottom + barRadiusIn,
          ),
          builder: (context, popover, _) => builder(context, popover),
          popoverBuilder: (context) {
            return Padding(
              padding: shape.dimensions.add(
                EdgeInsets.symmetric(
                  vertical: 128 * vertMult,
                  horizontal: 64 * horMult,
                ),
              ),
              child: component.buildPopover!(context),
            );
          },
          popoverContainerBuilder: (context, child) {
            return buildPopoverContainer(context, child, shape);
          },
          popoverClosedContainerBuilder: (context, child) {
            return buildPopoverContainer(context, child, null);
          },
        );
      },
    );
  }

  Widget buildPopoverContainer(BuildContext context, Widget child, ShapeBorder? shape) {
    shape ??= DockedRoundedCornersBorder(
      dockedSide: config.barSide,
      isVertical: config.isBarVertical,
      radiusInCross: 0,
      radiusInMain: 0,
      radiusOutCross: 0,
      radiusOutMain: 0,
    );
    return Material(
      animationDuration: config.animationDuration * 1.5,
      color: Theme.of(context).canvasColor,
      elevation: 4, // TODO: 2 expose popover elevation theme option to user
      clipBehavior: Clip.antiAliasWithSaveLayer,
      shape: shape,
      child: InputRegion(
        child: PageTransitionSwitcher(
          transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
            return SharedAxisTransition(
              animation: primaryAnimation,
              secondaryAnimation: secondaryAnimation,
              transitionType: config.isBarVertical
                  ? SharedAxisTransitionType.vertical
                  : SharedAxisTransitionType.horizontal,
              fillColor: Colors.transparent,
              child: child,
            );
          },
          child: child,
        ),
      ),
    );
  }

  /// hides widget if component.isIndicatorsVisible is false
  Widget _buildVisibility(
    BuildContext context,
    FeatherComponent component,
    Widget child,
  ) {
    return ValueListenableBuilder(
      valueListenable: component.isIndicatorsVisible,
      child: child,
      builder: (context, isVisible, child) {
        if (!isVisible) return SizedBox.shrink();
        // TODO: 2 maybe add animation to featherComponent visibility change (size and opacity)
        return child!;
      },
    );
  }
}

typedef PopoverBuilder = Widget Function(BuildContext context, WingedPopoverController? controller);
