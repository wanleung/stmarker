import 'package:flutter/widgets.dart' show StringCharacters;

import '../models/subtitle_line.dart';
import 'karaoke_models.dart';

final class KaraokeToken {
  const KaraokeToken({required this.text, required this.identity});

  final String text;
  final String identity;
}

final class KaraokeSegment {
  const KaraokeSegment({
    required this.text,
    required this.startMs,
    required this.endMs,
  });

  final String text;
  final int startMs;
  final int endMs;
}

enum KaraokeTimingIssue {
  invalidLineRange,
  missingMarks,
  staleMarks,
  nonIncreasingMarks,
  markOutsideLine,
  nonPositiveUnitDuration,
}

List<KaraokeToken> tokenizeKaraokeText(String source) {
  if (source.isEmpty) {
    return const [KaraokeToken(text: '', identity: '')];
  }

  final drafts = <_TokenDraft>[];
  var pending = '';
  _TokenDraft? activeWestern;

  void finishWestern() => activeWestern = null;

  for (final grapheme in source.characters) {
    if (_isWhitespace(grapheme)) {
      finishWestern();
      pending += grapheme;
      continue;
    }

    if (_isOpeningPunctuation(grapheme)) {
      finishWestern();
      pending += grapheme;
      continue;
    }

    if (_isPunctuation(grapheme)) {
      if (activeWestern != null) {
        activeWestern!.text += grapheme;
      } else if (drafts.isNotEmpty && pending.isEmpty) {
        drafts.last.text += grapheme;
      } else {
        pending += grapheme;
      }
      continue;
    }

    if (_isCjk(grapheme)) {
      finishWestern();
      drafts.add(_TokenDraft(text: '$pending$grapheme', identity: grapheme));
      pending = '';
      continue;
    }

    if (activeWestern == null || pending.isNotEmpty) {
      finishWestern();
      activeWestern = _TokenDraft(
        text: '$pending$grapheme',
        identity: grapheme,
      );
      drafts.add(activeWestern!);
      pending = '';
    } else {
      activeWestern!.text += grapheme;
      activeWestern!.identity += grapheme;
    }
  }

  if (pending.isNotEmpty) {
    if (drafts.isEmpty) {
      drafts.add(_TokenDraft(text: pending, identity: ''));
    } else {
      drafts.last.text += pending;
    }
  }

  return [
    for (final draft in drafts)
      KaraokeToken(text: draft.text, identity: draft.identity),
  ];
}

KaraokeTimingIssue? karaokeTimingIssue(SubtitleLine line, KaraokeMode mode) {
  if (mode == KaraokeMode.standard) return null;

  final startMs = line.startMs;
  final endMs = line.endMs;
  if (startMs == null || endMs == null || startMs < 0 || endMs <= startMs) {
    return KaraokeTimingIssue.invalidLineRange;
  }

  final tokens = tokenizeKaraokeText(line.text);
  if (mode == KaraokeMode.karaokeEasy) {
    final durationMs = endMs - startMs;
    for (var index = 0; index < tokens.length; index++) {
      final unitStartMs = startMs + (durationMs * index ~/ tokens.length);
      final unitEndMs = index == tokens.length - 1
          ? endMs
          : startMs + (durationMs * (index + 1) ~/ tokens.length);
      if (unitEndMs <= unitStartMs) {
        return KaraokeTimingIssue.nonPositiveUnitDuration;
      }
    }
    return null;
  }

  final marks = line.karaokeMarks;
  if (marks.isEmpty || marks.length != tokens.length) {
    return KaraokeTimingIssue.missingMarks;
  }

  for (var index = 0; index < marks.length; index++) {
    if (marks[index].unitText != tokens[index].identity) {
      return KaraokeTimingIssue.staleMarks;
    }
  }

  for (var index = 1; index < marks.length; index++) {
    if (marks[index].startMs <= marks[index - 1].startMs) {
      return KaraokeTimingIssue.nonIncreasingMarks;
    }
  }

  for (final mark in marks) {
    if (mark.startMs < startMs || mark.startMs > endMs) {
      return KaraokeTimingIssue.markOutsideLine;
    }
  }

  for (var index = 0; index < marks.length; index++) {
    final unitEndMs = index + 1 < marks.length
        ? marks[index + 1].startMs
        : endMs;
    if (unitEndMs <= marks[index].startMs) {
      return KaraokeTimingIssue.nonPositiveUnitDuration;
    }
  }

  return null;
}

List<KaraokeSegment> resolveKaraokeSegments(
  SubtitleLine line,
  KaraokeMode mode,
) {
  if (mode == KaraokeMode.standard || karaokeTimingIssue(line, mode) != null) {
    return const [];
  }

  final tokens = tokenizeKaraokeText(line.text);
  final startMs = line.startMs!;
  final endMs = line.endMs!;

  if (mode == KaraokeMode.karaokeEasy) {
    final durationMs = endMs - startMs;
    return [
      for (var index = 0; index < tokens.length; index++)
        KaraokeSegment(
          text: tokens[index].text,
          startMs: startMs + (durationMs * index ~/ tokens.length),
          endMs: index == tokens.length - 1
              ? endMs
              : startMs + (durationMs * (index + 1) ~/ tokens.length),
        ),
    ];
  }

  return [
    for (var index = 0; index < tokens.length; index++)
      KaraokeSegment(
        text: tokens[index].text,
        startMs: line.karaokeMarks[index].startMs,
        endMs: index == tokens.length - 1
            ? endMs
            : line.karaokeMarks[index + 1].startMs,
      ),
  ];
}

final class _TokenDraft {
  _TokenDraft({required this.text, required this.identity});

  String text;
  String identity;
}

bool _isWhitespace(String grapheme) =>
    RegExp(r'^\s+$', unicode: true).hasMatch(grapheme);

final _openingPunctuation = RegExp(r'^[\p{Ps}\p{Pi}]\p{M}*$', unicode: true);
final _punctuation = RegExp(r'^\p{P}\p{M}*$', unicode: true);

bool _isOpeningPunctuation(String grapheme) =>
    _openingPunctuation.hasMatch(grapheme);

bool _isPunctuation(String grapheme) => _punctuation.hasMatch(grapheme);

bool _isCjk(String grapheme) {
  final rune = grapheme.runes.first;
  return (rune >= 0x3400 && rune <= 0x4dbf) ||
      (rune >= 0x4e00 && rune <= 0x9fff) ||
      (rune >= 0xf900 && rune <= 0xfaff) ||
      (rune >= 0x20000 && rune <= 0x3134f) ||
      (rune >= 0x3040 && rune <= 0x30ff) ||
      (rune >= 0x31f0 && rune <= 0x31ff) ||
      (rune >= 0xac00 && rune <= 0xd7af) ||
      (rune >= 0x1100 && rune <= 0x11ff);
}
