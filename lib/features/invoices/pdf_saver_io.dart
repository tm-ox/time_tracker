import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

/// Native save: prompts for a location and writes the PDF there.
///
/// Returns the saved path, or null if the user cancelled the dialog.
Future<String?> savePdf(Uint8List bytes, String suggestedName) async {
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: const [
      XTypeGroup(label: 'PDF', extensions: ['pdf']),
    ],
  );
  if (location == null) return null; // cancelled
  await File(location.path).writeAsBytes(bytes);
  return location.path;
}
