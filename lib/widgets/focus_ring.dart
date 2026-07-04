import 'package:flutter/material.dart';
import 'package:time_tracker/constants/tokens.dart';

/// A thin rectangular ring drawn around the row a keyboard cursor sits on.
/// Square corners so it hugs the row edges; transparent when unfocused so the
/// layout doesn't shift as the cursor moves. Shared by the side panel and the
/// tracker's entry list so both cursors look identical.
class FocusRing extends StatelessWidget {
  final bool focused;
  final Widget child;
  const FocusRing({super.key, required this.focused, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: focused
              ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
              : Colors.transparent,
          width: AppTokens.strokeThin,
        ),
      ),
      child: child,
    );
  }
}
