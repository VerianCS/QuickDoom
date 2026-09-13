import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/features/splash/presentation/widgets/boot_splash.dart';

void main() {
  // The splash runs a looping animation, so these tests pump explicit
  // durations; pumpAndSettle would never return.

  Widget wrap(Widget child, {bool disableAnimations = false}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MaterialApp(home: child),
    );
  }

  testWidgets('renders the title, tagline and boot status', (tester) async {
    await tester.pumpWidget(wrap(BootSplash(
      bootComplete: false,
      status: 'Opening storage…',
      onFinished: () {},
    )));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('QUICKDOOM'), findsOneWidget);
    expect(find.text('RIP AND TEAR, INSTANTLY'), findsOneWidget);
    expect(find.text('Opening storage…'), findsOneWidget);
  });

  testWidgets('stays up while the boot is still running', (tester) async {
    var finished = false;

    await tester.pumpWidget(wrap(BootSplash(
      bootComplete: false,
      onFinished: () => finished = true,
    )));
    await tester.pump(const Duration(seconds: 3));

    expect(finished, isFalse, reason: 'boot has not completed yet');
  });

  testWidgets('holds for the minimum duration before finishing',
      (tester) async {
    var finished = false;

    await tester.pumpWidget(wrap(BootSplash(
      bootComplete: true,
      minimumDuration: const Duration(milliseconds: 800),
      fadeOutDuration: const Duration(milliseconds: 200),
      onFinished: () => finished = true,
    )));

    await tester.pump(const Duration(milliseconds: 500));
    expect(finished, isFalse, reason: 'minimum display time has not elapsed');

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(finished, isTrue);
  });

  testWidgets('finishes once the boot completes after the minimum',
      (tester) async {
    var finished = false;

    Widget build(bool bootComplete) => wrap(BootSplash(
          bootComplete: bootComplete,
          minimumDuration: const Duration(milliseconds: 100),
          fadeOutDuration: const Duration(milliseconds: 100),
          onFinished: () => finished = true,
        ));

    await tester.pumpWidget(build(false));
    await tester.pump(const Duration(milliseconds: 400));
    expect(finished, isFalse);

    await tester.pumpWidget(build(true));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 200));
    expect(finished, isTrue);
  });

  testWidgets('still completes when animations are disabled', (tester) async {
    var finished = false;

    await tester.pumpWidget(wrap(
      BootSplash(
        bootComplete: true,
        minimumDuration: const Duration(milliseconds: 100),
        fadeOutDuration: const Duration(milliseconds: 100),
        onFinished: () => finished = true,
      ),
      disableAnimations: true,
    ));

    expect(find.text('QUICKDOOM'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 200));
    expect(finished, isTrue);
  });

  testWidgets('disposes cleanly while still animating', (tester) async {
    await tester.pumpWidget(wrap(BootSplash(
      bootComplete: false,
      onFinished: () {},
    )));
    await tester.pump(const Duration(milliseconds: 300));

    // Tearing the splash down mid-animation must not leave a live ticker.
    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });
}
