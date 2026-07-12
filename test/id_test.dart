import 'package:flutter_test/flutter_test.dart';
import 'package:timedart/data/id.dart';

// IdGenerator is the source of the text primary keys for sync (Phase 2c). It
// must produce well-formed, unique, roughly time-ordered UUIDv7 strings.
void main() {
  const gen = IdGenerator();

  // 8-4-4-4-12 hex, with version nibble 7 and RFC-4122 variant (8/9/a/b).
  final v7 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('newId is a well-formed UUIDv7', () {
    expect(gen.newId(), matches(v7));
  });

  test('ids are unique across many draws', () {
    final ids = {for (var i = 0; i < 10000; i++) gen.newId()};
    expect(ids, hasLength(10000));
  });

  test('ids are roughly time-ordered (v7 timestamp prefix)', () async {
    final first = gen.newId();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final later = gen.newId();
    // Lexical string order tracks time because the 48-bit ms timestamp leads.
    expect(first.compareTo(later), lessThan(0));
  });

  test('the shared idGen produces valid ids too', () {
    expect(idGen.newId(), matches(v7));
  });
}
