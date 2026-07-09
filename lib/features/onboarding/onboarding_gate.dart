import 'package:flutter/material.dart';
import 'package:time_tracker/data/database.dart';
import 'package:time_tracker/features/onboarding/onboarding_controller.dart';
import 'package:time_tracker/features/onboarding/onboarding_flow.dart';
import 'package:time_tracker/features/shell/adaptive_shell.dart';

// The app's root gate (PRD #133, phase c). Replaces main.dart's direct
// [AdaptiveShell] mount: it seeds the defaults, then decides between the
// first-run onboarding flow and the tracker based on the persisted
// onboarding-complete flag.
//
// The startup intro animation (phase e) will slot in ahead of this decision;
// for now the gate goes straight to the flag check after a brief bootstrap.
class RootGate extends StatefulWidget {
  const RootGate({super.key, required this.db});
  final AppDatabase db;

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  // Resolves to whether onboarding is already complete. Nested defaults-seeding
  // runs first so the default profile exists before the wizard can edit it.
  late Future<bool> _bootstrap;

  // Once the user finishes onboarding we flip to the tracker without re-reading
  // the DB (the flag is now set; a re-read would race the write).
  bool _completedThisSession = false;

  @override
  void initState() {
    super.initState();
    _bootstrap = _seedThenCheck();
  }

  Future<bool> _seedThenCheck() async {
    await widget.db.ensureDefaultProject();
    await widget.db.ensureInvoiceDefaults();
    return widget.db.isOnboardingComplete();
  }

  Future<void> _finish(OnboardingInputs inputs) async {
    await applyOnboarding(widget.db, inputs);
    if (mounted) setState(() => _completedThisSession = true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _bootstrap,
      builder: (context, snap) {
        // Brief bootstrap: a blank branded surface (no spinner flash for a
        // sub-frame DB read).
        if (!snap.hasData) {
          return const Scaffold(body: SizedBox.expand());
        }
        final complete = snap.data! || _completedThisSession;
        if (complete) return AdaptiveShell(db: widget.db);
        return OnboardingFlow(onDone: _finish);
      },
    );
  }
}
