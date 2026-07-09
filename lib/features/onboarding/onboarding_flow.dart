import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.spaceXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Welcome to timedart',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: AppTokens.spaceSm),
                Text(
                  'Track time against your projects and send invoices that look '
                  'like you.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppTokens.spaceXl),
                FilledButton(
                  onPressed: () => onDone(OnboardingInputs.empty),
                  child: const Text('Get started'),
                ),
                const SizedBox(height: AppTokens.spaceXs),
                TextButton(
                  onPressed: () => onDone(OnboardingInputs.empty),
                  child: const Text('Skip for now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
