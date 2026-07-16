import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:timedart/features/docs/docs_catalog.dart';

// The Flutter side of the docs seam: discover the bundled markdown pages from
// the asset manifest and load them into a pure [DocsCatalog]. Kept apart from
// docs_catalog.dart so the catalogue's parsing/ordering stays Flutter-free and
// unit-testable. Nothing here is fetched — pages are bundled, so docs work
// fully offline.

/// Asset directory the docs (and their `assets/` images) are bundled under. The
/// markdown's relative image paths resolve against this — see docs_screen.dart.
const String docsAssetDir = 'docs/content';

/// Load every bundled docs page and build the catalogue. Reads the asset
/// manifest so a page added to docs/content is picked up without a code change.
Future<DocsCatalog> loadDocsCatalog() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  // Top-level markdown files under docsAssetDir only — images live in the
  // `assets/` subdirectory and aren't pages.
  final prefix = '$docsAssetDir/';
  final paths = manifest
      .listAssets()
      .where(
        (p) =>
            p.startsWith(prefix) &&
            p.endsWith('.md') &&
            !p.substring(prefix.length).contains('/'),
      )
      .toList();

  final sources = <String, String>{};
  for (final path in paths) {
    sources[path] = await rootBundle.loadString(path);
  }
  return DocsCatalog.fromSources(sources);
}
