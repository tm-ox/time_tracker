import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timedart/constants/layout.dart';
import 'package:timedart/constants/tokens.dart';

/// The Settings-mode content pane before a Template or Profile has been
/// selected from the side panel. Also the home for future non-invoicing
/// settings once there's more than Templates/Profiles to navigate to.
class SettingsHome extends StatelessWidget {
  const SettingsHome({super.key});

  // Bumped alongside pubspec; shown in the About line. Hardcoded for now — swap
  // for package_info_plus if we want it read straight from the build.
  static const _version = 'v0.9.0-beta';
  static final _websiteUri = Uri.parse('https://timedart.app');

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final narrow = context.isNarrow;
    return Column(
      children: [
        // Logo + instruction stay centred in the space above the footer.
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/logo/timedart_logo_stacked.svg',
                  height: narrow ? 140 : 200,
                ),
                const SizedBox(height: AppTokens.spaceXl),
                Text(
                  // Narrow opens the list from the bottom menu, not a side panel.
                  'Select an item from the ${narrow ? 'menu' : 'panel'} to edit.',
                  style: t.textTheme.bodyLarge?.copyWith(
                    color: t.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Links + version pinned to the baseline.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: () => launchUrl(_websiteUri),
              icon: const Icon(Icons.public, size: AppTokens.iconSm),
              label: const Text('Visit website'),
            ),
            const SizedBox(width: AppTokens.spaceSm),
            // Docs don't exist yet — present but disabled so the affordance is
            // there and lights up the day they land.
            Tooltip(
              message: 'Documentation coming soon',
              child: TextButton.icon(
                onPressed: null,
                icon: const Icon(
                  Icons.menu_book_outlined,
                  size: AppTokens.iconSm,
                ),
                label: const Text('Documentation'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceMd),
        Text(
          'timedart · $_version',
          style: t.textTheme.labelSmall?.copyWith(
            color: t.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
