import 'package:flutter_test/flutter_test.dart';

import 'package:barber_app/firebase_options.dart';

/// Guards against shipping the placeholder values that `flutterfire configure`
/// leaves behind. Passing them to `Firebase.initializeApp` produced an opaque
/// platform error instead of naming the platform that was unconfigured.
void main() {
  test('android options are real, not placeholders', () {
    expect(DefaultFirebaseOptions.isPlaceholder(DefaultFirebaseOptions.android),
        isFalse);
    expect(DefaultFirebaseOptions.android.projectId, 'barber-book-lycb');
  });

  test('ios options are real, not placeholders', () {
    expect(DefaultFirebaseOptions.isPlaceholder(DefaultFirebaseOptions.ios), isFalse);
  });

  test('unconfigured platforms are detected as placeholders', () {
    expect(DefaultFirebaseOptions.isPlaceholder(DefaultFirebaseOptions.web), isTrue);
    expect(DefaultFirebaseOptions.isPlaceholder(DefaultFirebaseOptions.macos), isTrue);
  });

  test('the current test platform resolves to a configured target', () {
    // Runs on the VM, so currentPlatform falls back to android.
    expect(() => DefaultFirebaseOptions.requireConfigured(), returnsNormally);
  });

  test('a descriptive error names the unconfigured platform', () {
    expect(
      () => DefaultFirebaseOptions.requireConfiguredFor(
        DefaultFirebaseOptions.web,
        platformName: 'web',
      ),
      throwsA(isA<UnsupportedError>().having(
        (e) => e.message,
        'message',
        allOf(contains('web'), contains('flutterfire configure')),
      )),
    );
  });
}