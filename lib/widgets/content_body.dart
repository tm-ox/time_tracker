import 'package:flutter/material.dart';
import 'package:timedart/constants/layout.dart';
import 'package:timedart/constants/tokens.dart';

class ContentBody extends StatelessWidget {
  final Widget child;
  const ContentBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppTokens.maxContentWidth),
      child: Padding(
        // Trim the bottom inset on narrow: the bottom nav bar below already
        // supplies separation, so the full spaceLg reads loose against it.
        padding: EdgeInsets.fromLTRB(
          AppTokens.spaceLg,
          AppTokens.spaceLg,
          AppTokens.spaceLg,
          context.isNarrow ? AppTokens.spaceMd : AppTokens.spaceLg,
        ),
        child: child,
      ),
    ),
  );
}
