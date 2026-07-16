// The in-app documentation catalogue (issue #252). Docs are plain CommonMark
// files with YAML frontmatter, bundled as assets and rendered offline. The same
// files feed the marketing site, so the frontmatter shape and ordering rules are
// a shared contract — see docs/content and the docs-contract SSOT.
//
// Deliberately pure — no Flutter/rootBundle imports — so the parsing, ordering,
// and navigation logic is unit-testable from in-memory strings. Asset loading
// lives behind a seam in docs_assets.dart, which hands this a
// {filename: contents} map to build from.

/// One documentation page: its frontmatter metadata plus the markdown body with
/// the frontmatter stripped off.
class DocPage {
  final String slug;
  final String title;
  final String group;
  final int order;
  final String? summary;

  /// The markdown body, frontmatter removed — handed as-is to the renderer.
  final String body;

  const DocPage({
    required this.slug,
    required this.title,
    required this.group,
    required this.order,
    required this.summary,
    required this.body,
  });
}

/// One sidebar section: a group label and its pages in display order.
class DocGroup {
  final String title;
  final List<DocPage> pages;
  const DocGroup(this.title, this.pages);
}

/// Thrown when a page's frontmatter is absent or malformed. Carries the source
/// name so a bad bundled file names itself in the failure.
class DocParseException implements Exception {
  final String message;
  const DocParseException(this.message);
  @override
  String toString() => 'DocParseException: $message';
}

/// The parsed, ordered documentation set. Build it with [DocsCatalog.fromSources]
/// from a map of file name → raw file contents; the slug is derived from the
/// file name (`getting-started.md` → `getting-started`).
class DocsCatalog {
  /// Sidebar sections, ordered by the minimum [DocPage.order] among their pages,
  /// ties broken by group title.
  final List<DocGroup> groups;

  /// Every page in flattened reading order (group order, then in-group order) —
  /// the sequence [prevNext] steps through.
  final List<DocPage> pages;

  final Map<String, DocPage> _bySlug;

  DocsCatalog._(this.groups, this.pages, this._bySlug);

  /// Parse and order a set of docs. Keys are file names (a leading path is
  /// tolerated and stripped); values are the raw file contents. Throws
  /// [DocParseException] if any file's frontmatter is missing or malformed.
  factory DocsCatalog.fromSources(Map<String, String> filesByName) {
    final parsed = <DocPage>[];
    for (final entry in filesByName.entries) {
      parsed.add(_parse(entry.key, entry.value));
    }

    // Bucket by group, preserving nothing about insertion order — the sort
    // rules below are the sole source of order.
    final byGroup = <String, List<DocPage>>{};
    for (final page in parsed) {
      byGroup.putIfAbsent(page.group, () => []).add(page);
    }

    // Pages within a group: by order, ties by title.
    for (final list in byGroup.values) {
      list.sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.title.compareTo(b.title);
      });
    }

    // Groups: by the minimum order among their pages, ties by group title.
    int minOrder(List<DocPage> list) =>
        list.map((p) => p.order).reduce((a, b) => a < b ? a : b);
    final groups = byGroup.entries.map((e) => DocGroup(e.key, e.value)).toList()
      ..sort((a, b) {
        final byOrder = minOrder(a.pages).compareTo(minOrder(b.pages));
        return byOrder != 0 ? byOrder : a.title.compareTo(b.title);
      });

    final pages = [for (final g in groups) ...g.pages];
    final bySlug = {for (final p in pages) p.slug: p};
    return DocsCatalog._(groups, pages, bySlug);
  }

  /// The page for [slug], or null if there's no such page.
  DocPage? getPage(String slug) => _bySlug[slug];

  /// The pages either side of [slug] in reading order. The first page has no
  /// previous; the last has no next; an unknown slug yields both null.
  ({DocPage? previous, DocPage? next}) prevNext(String slug) {
    final i = pages.indexWhere((p) => p.slug == slug);
    if (i < 0) return (previous: null, next: null);
    return (
      previous: i > 0 ? pages[i - 1] : null,
      next: i < pages.length - 1 ? pages[i + 1] : null,
    );
  }

  // ── Parsing ──

  static final _fence = RegExp(r'^---[ \t]*$', multiLine: true);

  static DocPage _parse(String fileName, String raw) {
    final slug = _slugOf(fileName);
    // Frontmatter is a `---` fenced block at the very top. Normalise line
    // endings first so a CRLF file parses the same as an LF one.
    final text = raw.replaceAll('\r\n', '\n');
    final open = _fence.firstMatch(text);
    if (open == null || text.substring(0, open.start).trim().isNotEmpty) {
      throw DocParseException('$fileName: missing frontmatter block');
    }
    final close = _fence.firstMatch(text.substring(open.end));
    if (close == null) {
      throw DocParseException('$fileName: unterminated frontmatter block');
    }
    final frontmatter = text.substring(open.end, open.end + close.start);
    // Drop the blank line(s) between the closing fence and the first content
    // line, so the body starts at the markdown proper.
    final body = text
        .substring(open.end + close.end)
        .replaceFirst(RegExp(r'^\n+'), '');

    final fields = _parseFrontmatter(fileName, frontmatter);
    final title = fields['title'];
    final group = fields['group'];
    final orderRaw = fields['order'];
    if (title == null || group == null || orderRaw == null) {
      throw DocParseException(
        '$fileName: frontmatter needs title, group, and order',
      );
    }
    final order = int.tryParse(orderRaw);
    if (order == null) {
      throw DocParseException('$fileName: order must be an integer');
    }
    return DocPage(
      slug: slug,
      title: title,
      group: group,
      order: order,
      summary: fields['summary'],
      body: body,
    );
  }

  /// Slug from file name: drop any leading path and the `.md` extension.
  static String _slugOf(String fileName) {
    final base = fileName.split('/').last;
    return base.endsWith('.md') ? base.substring(0, base.length - 3) : base;
  }

  /// Parse the flat `key: value` frontmatter subset the contract allows. Blank
  /// lines are skipped; a non-blank line without a colon is malformed. Values
  /// are trimmed and unwrapped from matching surrounding quotes.
  static Map<String, String> _parseFrontmatter(String fileName, String block) {
    final fields = <String, String>{};
    for (final line in block.split('\n')) {
      if (line.trim().isEmpty) continue;
      final colon = line.indexOf(':');
      if (colon < 0) {
        throw DocParseException(
          '$fileName: malformed frontmatter line "$line"',
        );
      }
      final key = line.substring(0, colon).trim();
      fields[key] = _unquote(line.substring(colon + 1).trim());
    }
    return fields;
  }

  static String _unquote(String value) {
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }
}
