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

  if (mode == KaraokeMode.karaokeEasy) return null;

  final tokens = tokenizeKaraokeText(line.text);
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

bool _isOpeningPunctuation(String grapheme) => const {
  '(',
  '[',
  '{',
  '<',
  '«',
  '‹',
  '“',
  '‘',
  '「',
  '『',
  '（',
  '［',
  '｛',
  '【',
  '《',
  '〈',
  '〔',
  '〖',
  '〘',
  '〚',
}.contains(grapheme);

bool _isPunctuation(String grapheme) {
  final rune = grapheme.runes.singleOrNull;
  if (rune == null) return false;
  return (rune >= 0x21 && rune <= 0x2f) ||
      (rune >= 0x3a && rune <= 0x40) ||
      (rune >= 0x5b && rune <= 0x60) ||
      (rune >= 0x7b && rune <= 0x7e) ||
      (rune >= 0x2000 && rune <= 0x206f) ||
      (rune >= 0x3000 && rune <= 0x303f) ||
      (rune >= 0xfe10 && rune <= 0xfe1f) ||
      (rune >= 0xfe30 && rune <= 0xfe6f) ||
      (rune >= 0xff01 && rune <= 0xff0f) ||
      (rune >= 0xff1a && rune <= 0xff20) ||
      (rune >= 0xff3b && rune <= 0xff40) ||
      (rune >= 0xff5b && rune <= 0xff65);
}

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
