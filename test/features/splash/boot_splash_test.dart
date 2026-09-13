import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/app/theme/app_fonts.dart';
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
      status: 'Opening storage...',
      onFinished: () {},
    )));
    await tester.pump(const Duration(milliseconds: 200));

    // The wordmark is two spans in different cuts of the family, so it is
    // matched by its semantics label rather than as a single text run.
    expect(find.bySemanticsLabel('QUICKDOOM'), findsOneWidget);
    expect(find.text('RIP AND TEAR, INSTANTLY'), findsOneWidget);
    expect(find.text('Opening storage...'), findsOneWidget);
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

    // The content fades in, and a fully transparent subtree exposes no
    // semantics, so give it a frame before looking for the wordmark.
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.bySemanticsLabel('QUICKDOOM'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 200));
    expect(finished, isTrue);
  });

  testWidgets('renders the wordmark as mirrored left and right cuts',
      (tester) async {
    await tester.pumpWidget(wrap(BootSplash(
      bootComplete: false,
      onFinished: () {},
    )));
    await tester.pump(const Duration(milliseconds: 200));

    final wordmark = tester.widget<RichText>(
      find.descendant(
        of: find.bySemanticsLabel('QUICKDOOM'),
        matching: find.byType(RichText),
      ),
    );

    final spans = <InlineSpan>[];
    wordmark.text.visitChildren((span) {
      spans.add(span);
      return true;
    });
    final textSpans = spans.whereType<TextSpan>().where((s) => s.text != null);

    expect(
      textSpans.map((s) => s.text),
      ['QUICK', 'DOOM'],
      reason: 'the lockup is split so the bevels mirror around the middle',
    );
    expect(
      textSpans.map((s) => s.style?.fontFamily),
      [AppFonts.doomLeft, AppFonts.doomRight],
    );
  });

  testWidgets('renders smaller copy in the upright cut', (tester) async {
    await tester.pumpWidget(wrap(BootSplash(
      bootComplete: false,
      status: 'Opening storage...',
      onFinished: () {},
    )));
    await tester.pump(const Duration(milliseconds: 200));

    for (final label in ['RIP AND TEAR, INSTANTLY', 'Opening storage...']) {
      final widget = tester.widget<Text>(find.text(label));
      expect(widget.style?.fontFamily, AppFonts.doomText, reason: label);
    }
  });

  testWidgets('boot status avoids the glyph the family does not have',
      (tester) async {
    // Doom 2016 has no U+2026, so an ellipsis must be spelled out or it
    // renders as tofu.
    await tester.pumpWidget(wrap(BootSplash(
      bootComplete: false,
      onFinished: () {},
    )));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Starting...'), findsOneWidget);
    expect(find.textContaining('\u2026'), findsNothing);
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
