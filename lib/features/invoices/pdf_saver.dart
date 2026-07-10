// Platform-agnostic PDF save.
//
// Desktop writes the bytes to a user-chosen path via a native save dialog;
// web triggers a browser download. The conditional export picks the impl so
// callers stay free of `dart:io` (which the web build can't compile).
export 'pdf_saver_io.dart' if (dart.library.js_interop) 'pdf_saver_web.dart';
