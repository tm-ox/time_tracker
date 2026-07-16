import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import 'package:timedart/constants/layout.dart';
import 'package:timedart/constants/text_styles.dart';
import 'package:timedart/constants/tokens.dart';
import 'package:timedart/features/docs/docs_assets.dart';
import 'package:timedart/features/docs/docs_catalog.dart';

// The in-app documentation screen (#252): an offline, themed reader over the
// bundled [DocsCatalog]. The loader shell ([DocsScreen]) fetches the catalogue
// from assets; [DocsView] is the pure UI over an already-built catalogue, so a
// widget test can drive it from an in-memory catalogue with no rootBundle.

/// Push the documentation screen. The app is otherwise dialog/panel-based, but
/// docs are a content surface of their own, so they get a full route.
Future<void> openDocs(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => const DocsScreen()));

/// Loader shell: reads the bundled catalogue, then hands off to [DocsView].
class DocsScreen extends StatefulWidget {
  const DocsScreen({super.key});

  @override
  State<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends State<DocsScreen> {
  late final Future<DocsCatalog> _catalog = loadDocsCatalog();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocsCatalog>(
      future: _catalog,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Documentation')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.space2xl),
                child: Text(
                  "Documentation couldn't be loaded.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Documentation')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return DocsView(catalog: snapshot.data!);
      },
    );
  }
}

/// The documentation reader over a built [catalog]: a section/page sidebar and
/// the selected page, with prev/next navigation across the reading order. Wide
/// shows both side by side; narrow shows the index, then the page with a back.
class DocsView extends StatefulWidget {
  const DocsView({super.key, required this.catalog, this.initialSlug});

  final DocsCatalog catalog;

  /// Page to open on first show; defaults to the first page in reading order.
  final String? initialSlug;

  @override
  State<DocsView> createState() => _DocsViewState();
}

class _DocsViewState extends State<DocsView> {
  String? _slug;

  // On narrow layouts the index and the page are separate screens; this tracks
  // which the user is on. Ignored on wide (both are always visible).
  bool _showingPage = false;

  @override
  void initState() {
    super.initState();
    final pages = widget.catalog.pages;
    _slug = widget.initialSlug ?? (pages.isEmpty ? null : pages.first.slug);
    _showingPage = widget.initialSlug != null;
  }

  void _select(String slug, {required bool fromIndex}) {
    setState(() {
      _slug = slug;
      if (fromIndex) _showingPage = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.catalog.pages;
    if (pages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Documentation')),
        body: Center(
          child: Text(
            'No documentation is available yet.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    final page =
        (_slug == null ? null : widget.catalog.getPage(_slug!)) ?? pages.first;
    final narrow = context.isNarrow;

    if (narrow) {
      // Index and page as two steps: the back arrow returns to the index rather
      // than closing the screen while a page is open.
      if (_showingPage) {
        return Scaffold(
          appBar: AppBar(
            leading: BackButton(
              onPressed: () => setState(() => _showingPage = false),
            ),
            title: Text(page.title),
          ),
          body: _DocPageBody(
            catalog: widget.catalog,
            page: page,
            onSelect: _select,
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Documentation')),
        body: _Sidebar(
          catalog: widget.catalog,
          selected: page.slug,
          onSelect: (slug) => _select(slug, fromIndex: true),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Documentation')),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 260,
            child: _Sidebar(
              catalog: widget.catalog,
              selected: page.slug,
              onSelect: (slug) => _select(slug, fromIndex: false),
            ),
          ),
          const VerticalDivider(width: AppTokens.strokeThin),
          Expanded(
            child: _DocPageBody(
              catalog: widget.catalog,
              page: page,
              onSelect: _select,
            ),
          ),
        ],
      ),
    );
  }
}

/// The section/page list. Groups are headers; pages are selectable rows.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.catalog,
    required this.selected,
    required this.onSelect,
  });

  final DocsCatalog catalog;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = theme.extension<AppTextStyles>()!;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceSm),
      children: [
        for (final group in catalog.groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceLg,
              AppTokens.spaceSm,
              AppTokens.spaceLg,
              AppTokens.space3xs,
            ),
            child: Text(
              group.title,
              style: styles.sectionHeader.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          for (final page in group.pages)
            _PageRow(
              title: page.title,
              selected: page.slug == selected,
              onTap: () => onSelect(page.slug),
            ),
        ],
      ],
    );
  }
}

class _PageRow extends StatelessWidget {
  const _PageRow({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? theme.colorScheme.surfaceContainerHighest : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceLg,
          vertical: AppTokens.spaceXs,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontFamily: AppTokens.fontFamily,
            fontSize: AppTokens.fontSizeSm,
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// A rendered page: title, optional summary lede, the markdown body, and the
/// prev/next controls across the reading order.
class _DocPageBody extends StatelessWidget {
  const _DocPageBody({
    required this.catalog,
    required this.page,
    required this.onSelect,
  });

  final DocsCatalog catalog;
  final DocPage page;
  // fromIndex is always false here — selecting from within a page (a body link
  // or prev/next) stays in the page view.
  final void Function(String slug, {required bool fromIndex}) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adjacent = catalog.prevNext(page.slug);
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppTokens.maxContentWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space2xl,
              vertical: AppTokens.spaceXl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (page.summary != null && page.summary!.isNotEmpty) ...[
                  Text(page.summary!, style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppTokens.spaceLg),
                ],
                MarkdownBody(
                  data: page.body,
                  styleSheet: _styleSheet(theme),
                  imageBuilder: _imageBuilder,
                  builders: {'blockquote': _AdmonitionBuilder()},
                  onTapLink: (text, href, title) => _onTapLink(context, href),
                ),
                const SizedBox(height: AppTokens.space2xl),
                _PrevNext(
                  previous: adjacent.previous,
                  next: adjacent.next,
                  onSelect: (slug) => onSelect(slug, fromIndex: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onTapLink(BuildContext context, String? href) {
    if (href == null) return;
    // External links open in the browser; an in-docs link (a bare or /docs/
    // slug) selects that page.
    if (href.startsWith('http://') || href.startsWith('https://')) {
      launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
      return;
    }
    final slug = href
        .replaceFirst(RegExp(r'^/?(docs/)?'), '')
        .replaceAll('/', '');
    if (catalog.getPage(slug) != null) onSelect(slug, fromIndex: false);
  }
}

/// Prev/next controls over the reading order. The first page shows no previous;
/// the last shows no next.
class _PrevNext extends StatelessWidget {
  const _PrevNext({
    required this.previous,
    required this.next,
    required this.onSelect,
  });

  final DocPage? previous;
  final DocPage? next;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (previous == null && next == null) return const SizedBox.shrink();
    return Row(
      children: [
        if (previous != null)
          Expanded(
            child: _NavCard(
              label: 'Previous',
              title: previous!.title,
              alignEnd: false,
              onTap: () => onSelect(previous!.slug),
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: AppTokens.spaceMd),
        if (next != null)
          Expanded(
            child: _NavCard(
              label: 'Next',
              title: next!.title,
              alignEnd: true,
              onTap: () => onSelect(next!.slug),
            ),
          )
        else
          const Spacer(),
      ],
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.label,
    required this.title,
    required this.alignEnd,
    required this.onTap,
  });

  final String label;
  final String title;
  final bool alignEnd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMd,
          vertical: AppTokens.spaceSm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          border: Border.all(color: AppTokens.colorBorder),
        ),
        child: Column(
          crossAxisAlignment: alignEnd
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!alignEnd)
                  const Icon(Icons.chevron_left, size: AppTokens.iconSm),
                Text(label, style: theme.textTheme.bodySmall),
                if (alignEnd)
                  const Icon(Icons.chevron_right, size: AppTokens.iconSm),
              ],
            ),
            const SizedBox(height: AppTokens.space3xs),
            Text(
              title,
              textAlign: alignEnd ? TextAlign.end : TextAlign.start,
              style: TextStyle(
                fontFamily: AppTokens.fontFamily,
                fontSize: AppTokens.fontSizeSm,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders a bundled image referenced by a relative path (`assets/foo.png`) as
/// an asset under [docsAssetDir]. Falls back to the alt text if it can't load.
Widget _imageBuilder(Uri uri, String? title, String? alt) {
  final path = '$docsAssetDir/${uri.path}';
  return Image.asset(
    path,
    errorBuilder: (context, error, stackTrace) =>
        Text(alt ?? '', style: Theme.of(context).textTheme.bodySmall),
  );
}

/// Markdown theming from the app's design tokens. Built from the ambient theme,
/// then nudged so headings, code, links, and spacing read like the rest of the
/// app rather than flutter_markdown's Material defaults.
MarkdownStyleSheet _styleSheet(ThemeData theme) {
  final scheme = theme.colorScheme;
  final base = TextStyle(
    fontFamily: AppTokens.fontFamily,
    fontSize: AppTokens.fontSizeSm,
    height: AppTokens.fontHeightDefault,
    color: scheme.onSurface,
  );
  final heading = TextStyle(
    fontFamily: AppTokens.fontFamilyHeading,
    fontStyle: FontStyle.italic,
    color: scheme.primary,
  );
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: base,
    listBullet: base,
    h1: heading.copyWith(fontSize: 28, fontWeight: FontWeight.w500),
    h2: heading.copyWith(fontSize: 22, fontWeight: FontWeight.w500),
    h3: heading.copyWith(fontSize: 18, fontWeight: FontWeight.w500),
    a: base.copyWith(
      color: AppTokens.colorAccentText,
      decoration: TextDecoration.underline,
    ),
    code: TextStyle(
      fontFamily: 'monospace',
      fontSize: AppTokens.fontSizeXs,
      color: scheme.onSurface,
      backgroundColor: scheme.surfaceContainerHighest,
    ),
    codeblockDecoration: BoxDecoration(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      border: Border.all(color: AppTokens.colorBorder),
    ),
    tableBorder: TableBorder.all(color: AppTokens.colorBorder),
    tableHead: base.copyWith(fontWeight: FontWeight.w600),
    blockquotePadding: EdgeInsets.zero,
  );
}

/// One admonition kind (the callout convention): its leading marker, label,
/// icon, and accent colour.
enum _Admonition {
  note('Note', Icons.info_outline),
  tip('Tip', Icons.lightbulb_outline),
  warning('Warning', Icons.warning_amber_outlined);

  const _Admonition(this.label, this.icon);
  final String label;
  final IconData icon;

  Color color(ColorScheme scheme) => switch (this) {
    _Admonition.note => scheme.primary,
    _Admonition.tip => AppTokens.colorAccentText,
    _Admonition.warning => const Color(0xFFE0A82E),
  };

  static _Admonition? fromLead(String lead) => switch (lead.toLowerCase()) {
    'note' => _Admonition.note,
    'tip' => _Admonition.tip,
    'warning' => _Admonition.warning,
    _ => null,
  };
}

/// Renders blockquotes. A blockquote whose text begins with `Note:` / `Tip:` /
/// `Warning:` (the callout convention — the marker is bolded in source, which
/// the parser flattens into the leading text) becomes a styled admonition;
/// any other blockquote falls back to a plain quoted block.
class _AdmonitionBuilder extends MarkdownElementBuilder {
  static final _lead = RegExp(r'^(Note|Tip|Warning):\s*', caseSensitive: false);

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = element.textContent.trim();
    final match = _lead.firstMatch(text);
    final kind = match == null ? null : _Admonition.fromLead(match.group(1)!);

    if (kind == null) {
      // A generic blockquote: a muted, left-ruled block.
      return Container(
        margin: const EdgeInsets.symmetric(vertical: AppTokens.spaceXs),
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceMd,
          AppTokens.spaceXs,
          AppTokens.spaceMd,
          AppTokens.spaceXs,
        ),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: AppTokens.colorBorder, width: 3),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: AppTokens.fontFamily,
            fontSize: AppTokens.fontSizeSm,
            fontStyle: FontStyle.italic,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final color = kind.color(scheme);
    final body = text.substring(match!.end);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppTokens.spaceSm),
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(kind.icon, size: AppTokens.iconSm, color: color),
          const SizedBox(width: AppTokens.spaceSm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${kind.label}: ',
                    style: TextStyle(fontWeight: FontWeight.w600, color: color),
                  ),
                  TextSpan(text: body),
                ],
                style: TextStyle(
                  fontFamily: AppTokens.fontFamily,
                  fontSize: AppTokens.fontSizeSm,
                  height: AppTokens.fontHeightDefault,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
