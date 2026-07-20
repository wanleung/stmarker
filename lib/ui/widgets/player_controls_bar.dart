import 'package:flutter/material.dart';

import '../../player/playback_controls.dart';
import '../format_timestamp.dart';

class PlayerControlsBar extends StatelessWidget {
  const PlayerControlsBar({super.key, required this.controls});

  final PlaybackControls controls;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controls,
      builder: (context, _) {
        final duration = controls.durationMs;
        final maxValue = duration > 0 ? duration.toDouble() : 1.0;
        final position = controls.positionMs
            .clamp(0, duration > 0 ? duration : 1)
            .toDouble();
        return Row(
          children: [
            IconButton(
              key: const ValueKey('play-pause-button'),
              icon: Icon(controls.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () =>
                  controls.isPlaying ? controls.pause() : controls.play(),
            ),
            Text(
              formatDisplayTimestamp(position.round(), includeMillis: false),
            ),
            Expanded(
              child: Slider(
                key: const ValueKey('scrubber'),
                min: 0,
                max: maxValue,
                value: position,
                onChanged: (value) => controls.seek(value.round()),
              ),
            ),
            Text(formatDisplayTimestamp(duration, includeMillis: false)),
            DropdownButton<double>(
              key: const ValueKey('rate-dropdown'),
              value: controls.playbackRate,
              items: const [0.5, 0.75, 1.0, 1.25, 1.5]
                  .map(
                    (rate) =>
                        DropdownMenuItem(value: rate, child: Text('${rate}x')),
                  )
                  .toList(),
              onChanged: (rate) {
                if (rate != null) controls.setRate(rate);
              },
            ),
          ],
        );
      },
    );
  }
}
