import 'package:flutter/material.dart';

import '../karaoke/karaoke_models.dart';

@immutable
final class KaraokeSettings {
  const KaraokeSettings({required this.mode, required this.preDisplay});

  final KaraokeMode mode;
  final KaraokePreDisplay preDisplay;
}

Future<KaraokeSettings?> showKaraokeSettingsDialog(
  BuildContext context, {
  required KaraokeSettings initial,
}) => showDialog<KaraokeSettings>(
  context: context,
  builder: (_) => _KaraokeSettingsDialog(initial: initial),
);

class _KaraokeSettingsDialog extends StatefulWidget {
  const _KaraokeSettingsDialog({required this.initial});
  final KaraokeSettings initial;

  @override
  State<_KaraokeSettingsDialog> createState() => _KaraokeSettingsDialogState();
}

class _KaraokeSettingsDialogState extends State<_KaraokeSettingsDialog> {
  late KaraokeMode _mode = widget.initial.mode;
  late KaraokePreDisplay _preDisplay = widget.initial.preDisplay;

  @override
  Widget build(BuildContext context) {
    final preDisplayEnabled = _mode != KaraokeMode.standard;
    return AlertDialog(
      title: const Text('Karaoke settings'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mode', style: Theme.of(context).textTheme.titleSmall),
              RadioGroup<KaraokeMode>(
                key: const ValueKey('karaoke-mode'),
                groupValue: _mode,
                onChanged: (value) => setState(() => _mode = value!),
                child: const Column(
                  children: [
                    RadioListTile(
                      value: KaraokeMode.standard,
                      title: Text('Standard'),
                    ),
                    RadioListTile(
                      value: KaraokeMode.karaokeEasy,
                      title: Text('Karaoke Easy'),
                    ),
                    RadioListTile(
                      value: KaraokeMode.karaokeAdvanced,
                      title: Text('Karaoke Advanced'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Text(
                'Pre-display',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              IgnorePointer(
                key: preDisplayEnabled
                    ? null
                    : const ValueKey('karaoke-pre-display-disabled'),
                ignoring: !preDisplayEnabled,
                child: Opacity(
                  opacity: preDisplayEnabled ? 1 : 0.45,
                  child: RadioGroup<KaraokePreDisplay>(
                    key: const ValueKey('karaoke-pre-display'),
                    groupValue: _preDisplay,
                    onChanged: (value) => setState(() => _preDisplay = value!),
                    child: const Column(
                      children: [
                        RadioListTile(
                          value: KaraokePreDisplay.off,
                          title: Text('Off'),
                        ),
                        RadioListTile(
                          value: KaraokePreDisplay.seconds3,
                          title: Text('3 seconds'),
                        ),
                        RadioListTile(
                          value: KaraokePreDisplay.seconds4,
                          title: Text('4 seconds'),
                        ),
                        RadioListTile(
                          value: KaraokePreDisplay.seconds5,
                          title: Text('5 seconds'),
                        ),
                        RadioListTile(
                          value: KaraokePreDisplay.oneLineAhead,
                          title: Text('One line ahead'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('karaoke-settings-save'),
          onPressed: () => Navigator.pop(
            context,
            KaraokeSettings(mode: _mode, preDisplay: _preDisplay),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
