import 'package:flutter/material.dart';
import 'package:time_tracker/data/database.dart';
import 'package:time_tracker/tokens.dart';

class SelectionPanel extends StatefulWidget {
  const SelectionPanel({
    super.key,
    required this.db,
    this.selectedJobId,
    this.onSelect,
  });
  final AppDatabase db;
  final int? selectedJobId;
  final void Function(int)? onSelect;

  @override
  State<SelectionPanel> createState() => _SelectionPanelState();
}

class _SelectionPanelState extends State<SelectionPanel> {
  late final Stream<List<JobWithRate>> _jobsStream = widget.db
      .watchJobsWithRate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JobWithRate>>(
      stream: _jobsStream,
      builder: (context, snap) {
        final rows = snap.data ?? [];
        return ListView(
          children: [
            for (final r in rows)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: kRowInset,
                ),

                title: Text(r.job.code),
                subtitle: Text(r.job.title),

                selected: r.job.id == widget.selectedJobId, // highlight current
                onTap: () => widget.onSelect?.call(r.job.id), // selection up
              ),
          ],
        );
      },
    );
  }
}
