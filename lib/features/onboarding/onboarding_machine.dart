// The onboarding wizard's step machine (PRD #133). Pure Dart — no Flutter or
// drift — so the wizard's navigation is unit-testable in isolation and the UI
// (phase d) is a thin view over this state. It owns the ordered step list, the
// current position, the forward/back/skip transitions, and a *latched*
// "complete" flag: reaching the end (by finishing the last step or skipping the
// rest) marks onboarding complete exactly once and never un-marks it.
//
// Persistence (writing the profile, setting the DB flag) is deliberately NOT
// here — it's wired at the root gate (phase c), which observes [isComplete].
// Keeping this module effect-free is what makes the transition tests meaningful.

/// The ordered steps of the first-run flow. Orientation (welcome, howItWorks)
/// comes before any input (business, region); [done] is the closing screen
/// whose "→ tracker" action completes the flow.
enum OnboardingStep { welcome, howItWorks, business, region, done }

class OnboardingMachine {
  OnboardingMachine({List<OnboardingStep>? steps})
    : steps = steps ?? OnboardingStep.values,
      assert((steps ?? OnboardingStep.values).isNotEmpty);

  /// The steps in display order. Injectable so tests can use a shorter list.
  final List<OnboardingStep> steps;

  int _index = 0;
  bool _complete = false;

  /// Zero-based position in [steps].
  int get index => _index;

  /// The step currently shown.
  OnboardingStep get current => steps[_index];

  /// On the first step (no [back] target).
  bool get isFirst => _index == 0;

  /// On the last step ([OnboardingStep.done]) — [next] here finishes the flow.
  bool get isLast => _index == steps.length - 1;

  /// Onboarding has finished (last step advanced past, or [skipAll]). Latched:
  /// once true it stays true, so [back] can't reopen a completed flow.
  bool get isComplete => _complete;

  /// Advance one step. On the last step this marks the flow complete instead of
  /// moving. Idempotent once complete (so a double-tap can't over-shoot).
  void next() {
    if (_complete) return;
    if (isLast) {
      _complete = true;
      return;
    }
    _index++;
  }

  /// Skip the current (input) step. Same forward movement as [next]; the caller
  /// simply doesn't capture this step's input. Named distinctly so the wizard's
  /// "Skip" and "Next" intents read clearly and the seeded defaults are kept.
  void skipStep() => next();

  /// Go back one step. Clamps at the first step and never un-completes.
  void back() {
    if (_complete) return;
    if (_index > 0) _index--;
  }

  /// Abandon the remaining steps and finish now (the persistent "Skip setup"
  /// affordance). Latches [isComplete]; the seeded defaults are left untouched.
  void skipAll() => _complete = true;
}
