import 'package:flutter/material.dart';
import 'package:timedart/constants/tokens.dart';
import 'package:timedart/widgets/entity_editor.dart';

// App-styled date picker. The stock Material date dialog can't be made to match
// the app: its header gap, action-row padding and button styles are hardcoded
// and not exposed through DatePickerThemeData. So we present a plain
// [CalendarDatePicker] (which DOES pick up the app's datePickerTheme colours)
// inside the shared [showEntityEditor] chrome — same surface, border, corner
// and padding as every other modal — with our own header and Cancel/OK row.
// Returns the chosen date, or null on cancel/dismiss.
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) => showEntityEditor<DateTime>(
  context,
  builder: (ctx) => _AppDatePicker(
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  ),
);

class _AppDatePicker extends StatefulWidget {
  const _AppDatePicker({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_AppDatePicker> createState() => _AppDatePickerState();
}

class _AppDatePickerState extends State<_AppDatePicker> {
  late DateTime _selected = widget.initialDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = MaterialLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Eyebrow sits tight above the date, which is the modal title (Raleway
        // italic primary — the shared dialog-title style).
        Text(loc.datePickerHelpText, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppTokens.space3xs),
        Text(loc.formatMediumDate(_selected), style: theme.textTheme.titleLarge),
        const SizedBox(height: AppTokens.spaceLg),
        CalendarDatePicker(
          initialDate: _selected,
          firstDate: widget.firstDate,
          lastDate: widget.lastDate,
          onDateChanged: (d) => setState(() => _selected = d),
        ),
        const SizedBox(height: AppTokens.spaceXl),
        Row(
          children: [
            const Spacer(),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: AppTokens.spaceSm),
            FilledButton(
              onPressed: () => Navigator.pop(context, _selected),
              child: const Text('OK'),
            ),
          ],
        ),
      ],
    );
  }
}
