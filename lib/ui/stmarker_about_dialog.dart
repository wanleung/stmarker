import 'package:flutter/material.dart';

const stmarkerVersion = '1.0.0';

void showStmarkerAboutDialog(BuildContext context) {
  showAboutDialog(
    context: context,
    applicationName: 'stmarker',
    applicationVersion: stmarkerVersion,
    applicationIcon: const Icon(Icons.subtitles, size: 48),
    applicationLegalese:
        'Copyright © 2026 stmarker contributors\nGPL-3.0-or-later',
    children: const [
      SizedBox(height: 16),
      Text(
        'A local desktop tool for timing subtitles and lyrics against video '
        'or audio, exporting SRT files, and creating subtitled videos with '
        'FFmpeg.',
      ),
      SizedBox(height: 12),
      Text('Built with Flutter, media_kit, libmpv, and FFmpeg.'),
    ],
  );
}
