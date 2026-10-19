import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:conduit/core/config/fork_overrides.dart';
import 'package:conduit/features/opknapper/opknapper_availability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => OpknapperReleased.now = DateTime.now);

  test('release moment is 25 Oct 2026 18:00 Dutch winter time', () {
    expect(
      ForkOverrides.opknapperReleaseAt,
      DateTime.parse('2026-10-25T18:00:00+01:00'),
    );
  });

  test('not released before the moment', () {
    OpknapperReleased.now = () => DateTime.utc(2026, 10, 25, 16, 59, 59);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(opknapperReleasedProvider), isFalse);
  });

  test('released from the moment on', () {
    OpknapperReleased.now = () => DateTime.utc(2026, 10, 25, 17);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(opknapperReleasedProvider), isTrue);
  });

  test('flips to released while the app is running', () {
    fakeAsync((async) {
      final start = DateTime.utc(2026, 10, 25, 16, 59);
      OpknapperReleased.now = () => start.add(async.elapsed);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final seen = <bool>[];
      container.listen<bool>(
        opknapperReleasedProvider,
        (_, next) => seen.add(next),
        fireImmediately: true,
      );
      async.elapse(const Duration(seconds: 59));
      expect(seen, [false]);
      async.elapse(const Duration(seconds: 1));
      expect(seen, [false, true]);
    });
  });
}
