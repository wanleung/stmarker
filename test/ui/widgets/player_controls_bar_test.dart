import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/ui/widgets/player_controls_bar.dart';

import '../../support/fake_playback_controls.dart';

void main() {
  testWidgets('tapping play/pause toggles playback', (tester) async {
    final controls = FakePlaybackControls();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlayerControlsBar(controls: controls)),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('play-pause-button')));
    await tester.pump();
    expect(controls.playingValue, isTrue);

    await tester.tap(find.byKey(const ValueKey('play-pause-button')));
    await tester.pump();
    expect(controls.playingValue, isFalse);
  });

  testWidgets('selecting a rate calls setRate', (tester) async {
    final controls = FakePlaybackControls();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlayerControlsBar(controls: controls)),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('rate-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5x').last);
    await tester.pumpAndSettle();

    expect(controls.lastRate, 1.5);
  });
}
