import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:time_tracker/constants/tokens.dart';

/// The logo bar at the top of the content pane (wide layout). It mirrors the
/// side-panel's search field: same fill and height, sitting at the same top
/// inset so the two bars bracket the divider.
///
/// Its left edge lands on the content pane's inset (matching [ContentBody]'s
/// centred, [AppTokens.maxContentWidth]-capped block) and its right edge runs
/// to the divider. The rounded corner is on the left — the edge away from the
/// divider — mirroring the search field, whose rounded corner is on the right.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, c) {
        // Reproduce ContentBody's geometry to find the content pane's left
        // inset: the block is centred and capped at maxContentWidth, then inset
        // by spaceLg.
        final region = c.maxWidth;
        final block = region < AppTokens.maxContentWidth
            ? region
            : AppTokens.maxContentWidth;
        final leftInset = (region - block) / 2 + AppTokens.spaceLg;

        return Padding(
          // Top/bottom inset matches the search field so the bars line up and
          // the gap below them equals the gap above; right runs to the divider.
          padding: EdgeInsets.only(
            left: leftInset,
            top: AppTokens.spaceLg,
            bottom: AppTokens.spaceLg,
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceSm,
              vertical: AppTokens.spaceXs,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(AppTokens.radiusSm),
              ),
            ),
            // The horizontal logo already carries the "timedart" wordmark.
            child: SvgPicture.asset(
              'assets/logo/timedart_logo_horizontal.svg',
              height: 18,
            ),
          ),
        );
      },
    );
  }
}
