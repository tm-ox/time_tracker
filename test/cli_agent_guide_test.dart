import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timedart/cli/agent_guide_text.g.dart';

// Anti-drift guard (issue #283): `timedart guide` prints the bundled
// `kAgentGuideMarkdown` constant, generated from docs/cli/agent-guide.md by
// `tool/gen_agent_guide.dart`. If someone edits the markdown without
// re-running the generator, the binary would silently serve stale docs —
// this test fails loudly instead. Same discipline as
// `cli_json_contract_test.dart` pins the JSON contract against the guide.
void main() {
  test('bundled agent guide matches docs/cli/agent-guide.md byte-for-byte', () {
    final source = File('docs/cli/agent-guide.md').readAsStringSync();
    expect(
      kAgentGuideMarkdown,
      source,
      reason:
          'lib/cli/agent_guide_text.g.dart is stale — run '
          '`dart run tool/gen_agent_guide.dart` after editing '
          'docs/cli/agent-guide.md.',
    );
  });

  test('bundled guide mentions both self-onboarding entry points', () {
    expect(kAgentGuideMarkdown, contains('timedart guide'));
    expect(kAgentGuideMarkdown, contains('timedart help --json'));
  });
}
