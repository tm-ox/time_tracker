import 'package:flutter/material.dart';
import 'package:time_tracker/data/database.dart';
import 'package:time_tracker/features/onboarding/onboarding_controller.dart';
import 'package:time_tracker/features/onboarding/onboarding_flow.dart';
import 'package:time_tracker/features/shell/adaptive_shell.dart';

// The app's root gate (PRD #133, phase c). Replaces main.dart's direct
// [AdaptiveShell] mount: it seeds the defaults, then decides between the
// first-run onboarding flow and the tracker based on the persisted
// onboarding-complete flag. Also owns "Re-run setup" — the Settings action
// that replays onboarding (and doubles as the dev/test reset).
//
// The startup intro animation (phase e) will slot in ahead of this decision;
// for now the gate goes straight to the flag check after a brief bootstrap.
class RootGate extends StatefulWidget {
  const RootGate({super.key, required this.db});
  final AppDatabase db;

  @override
  State<RootGate> createState() => _RootGateState();
}

enum _Mode { loading, onboarding, shell }

class _RootGateState extends State<RootGate> {
  _Mode _mode = _Mode.loading;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  // Seed defaults first (so the default profile exists before the wizard can
  // edit it), then route by the persisted flag.
  Future<void> _bootstrap() async {
    await widget.db.ensureDefaultProject();
    await widget.db.ensureInvoiceDefaults();
    final complete = await widget.db.isOnboardingComplete();
    if (mounted) {
      setState(() => _mode = complete ? _Mode.shell : _Mode.onboarding);
    }
  }

  Future<void> _finish(OnboardingInputs inputs) async {
    await applyOnboarding(widget.db, inputs);
    if (mounted) setState(() => _mode = _Mode.shell);
  }

  // Settings → "Re-run setup": clear the flag and replay the wizard in place
  // (a fresh OnboardingFlow, so its step machine starts over).
  Future<void> _rerun() async {
    await widget.db.setOnboardingComplete(false);
    if (mounted) setState(() => _mode = _Mode.onboarding);
  }

  @override
  Widget build(BuildContext context) => switch (_mode) {
    // Brief bootstrap: a blank branded surface (no spinner flash for a
    // sub-frame DB read).
    _Mode.loading => const Scaffold(body: SizedBox.expand()),
    _Mode.onboarding => OnboardingFlow(onDone: _finish),
    _Mode.shell => AdaptiveShell(db: widget.db, onRerunOnboarding: _rerun),
  };
}
