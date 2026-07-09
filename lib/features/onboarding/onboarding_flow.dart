import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:time_tracker/constants/tokens.dart';
import 'package:time_tracker/features/onboarding/onboarding_controller.dart';

// PLACEHOLDER wizard shell (PRD #133, phase c). The real stepped wizard — the
// welcome / how-it-works / business / region / done screens built on
// [OnboardingMachine] — is phase (d), which replaces this widget's body. For
// now it's a single full-screen panel that lets the flow complete so the root
// gate is exercisable end-to-end: "Get started" and "Skip for now" both finish
// with no captured input (seeded defaults kept). [onDone] carries the captured
// [OnboardingInputs] up to the gate, which persists them via [applyOnboarding].
class OnboardingFlow extends StatelessWidget {
  const OnboardingFlow({super.key, required this.onDone});

  /// Called when onboarding finishes, with whatever was captured. Phase (c)
  /// only ever passes [OnboardingInputs.empty]; phase (d) will fill it in.
  final ValueChanged<OnboardingInputs> onDone;

  // Both action buttons share one narrow width so they line up.
  static const double _buttonWidth = 140;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Match the app-wide button corner (radiusSm) so the text button's hover
    // fill isn't the M3 stadium default.
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
    );
    // Shrink the logo on narrow (mobile) windows so it doesn't dominate.
    final narrow =
        MediaQuery.sizeOf(context).width < AppTokens.breakpointMd;
    final logoHeight = narrow ? 140.0 : 240.0;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.spaceXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/logo/timedart_logo_stacked.svg',
                  height: logoHeight,
                ),
                const SizedBox(height: AppTokens.spaceXl),
                Text(
                  'Welcome',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: AppTokens.spaceMd),
                Text(
                  'Track time against your projects and send '
                  'invoices tailored to your brand.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppTokens.space2xl),
                SizedBox(
                  width: _buttonWidth,
                  child: FilledButton(
                    onPressed: () => onDone(OnboardingInputs.empty),
                    child: const Text('Get started'),
                  ),
                ),
                const SizedBox(height: AppTokens.spaceXs),
                SizedBox(
                  width: _buttonWidth,
                  child: TextButton(
                    onPressed: () => onDone(OnboardingInputs.empty),
                    style: TextButton.styleFrom(shape: buttonShape),
                    child: const Text('Skip for now'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
