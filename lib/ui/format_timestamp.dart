String formatDisplayTimestamp(int? milliseconds, {bool includeMillis = true}) {
  if (milliseconds == null) return '—';

  final duration = Duration(milliseconds: milliseconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  final prefix = hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';
  if (!includeMillis) return '$prefix$minutes:$seconds';

  final millis = duration.inMilliseconds
      .remainder(1000)
      .toString()
      .padLeft(3, '0');
  return '$prefix$minutes:$seconds.$millis';
}
