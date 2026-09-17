/// How the timestamp of an entry is written.
enum TimestampFormat {
  /// `14:03:09.120`
  time,

  /// `2026-09-13 14:03:09.120`
  datetime,

  /// `2026-09-13T05:03:09.120Z`, in UTC
  iso,
}

String _pad(int value, [int length = 2]) => value.toString().padLeft(length, '0');

/// Formats a time in local time, or in UTC for [TimestampFormat.iso].
String formatTimestamp(DateTime time, [TimestampFormat format = TimestampFormat.time]) {
  if (format == TimestampFormat.iso) {
    return time.toUtc().toIso8601String().replaceFirst(RegExp(r'(\.\d{3})\d*Z?$'), r'$1Z');
  }

  final DateTime local = time.toLocal();
  final String clock =
      '${_pad(local.hour)}:${_pad(local.minute)}:${_pad(local.second)}'
      '.${_pad(local.millisecond, 3)}';

  if (format == TimestampFormat.datetime) {
    return '${local.year}-${_pad(local.month)}-${_pad(local.day)} $clock';
  }

  return clock;
}
