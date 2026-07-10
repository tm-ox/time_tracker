import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web save: hands the bytes to the browser as a download.
///
/// There is no cancel affordance on web, so this always returns the filename.
Future<String?> savePdf(Uint8List bytes, String suggestedName) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = suggestedName
    ..click();
  web.URL.revokeObjectURL(url);
  return suggestedName;
}
