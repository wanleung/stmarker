import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const stmarkerVersion = '1.0.0';
const stmarkerRepositoryUri = 'https://github.com/wanleung/stmarker';
typedef UrlLauncher = Future<bool> Function(Uri uri, {LaunchMode mode});

void showStmarkerAboutDialog(
  BuildContext context, {
  UrlLauncher launcher = launchUrl,
}) {
  showAboutDialog(
    context: context,
    applicationName: 'Subtitle Marker',
    applicationVersion: stmarkerVersion,
    applicationIcon: const Icon(Icons.subtitles, size: 48),
    applicationLegalese:
        'Copyright © 2026 Subtitle Marker contributors\nGPL-3.0-or-later',
    children: [
      const SizedBox(height: 16),
      const Text(
        'A local desktop tool for timing subtitles and lyrics against video '
        'or audio, exporting SRT files, and creating subtitled videos with '
        'FFmpeg.',
      ),
      const SizedBox(height: 12),
      const Text('Author: Wan Leung Wong'),
      Tooltip(
        message: 'Open the Subtitle Marker repository on GitHub',
        child: TextButton(
          onPressed: () async {
            try {
              final opened = await launcher(
                Uri.parse(stmarkerRepositoryUri),
                mode: LaunchMode.externalApplication,
              );
              if (!opened && context.mounted) {
                _showRepositoryLaunchError(context);
              }
            } on Exception {
              if (context.mounted) _showRepositoryLaunchError(context);
            }
          },
          child: const Text('github.com/wanleung/stmarker'),
        ),
      ),
      const SizedBox(height: 12),
      const Text('Built with Flutter, media_kit, libmpv, and FFmpeg.'),
      const SizedBox(height: 12),
      const Text(
        'Bundled Noto fonts are copyright their respective authors and are '
        'provided under the SIL Open Font License 1.1.',
      ),
    ],
  );
}

void _showRepositoryLaunchError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Could not open the GitHub repository.')),
  );
}
