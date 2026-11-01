const Duration _wibOffset = Duration(hours: 7);

DateTime? parseWibDateTime(dynamic value) {
  if (value == null) return null;

  final raw = value.toString().trim();
  if (raw.isEmpty) return null;

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;

  // Jika timestamp memiliki zona waktu (Z atau +00:00),
  // konversikan instant-nya ke WIB.
  final hasTimezone = RegExp(
    r'(Z|[+-]\d{2}:?\d{2})$',
    caseSensitive: false,
  ).hasMatch(raw);

  if (hasTimezone) {
    return parsed.toUtc().add(_wibOffset);
  }

  // Jika tidak memiliki zona waktu, anggap nilainya sudah WIB.
  return parsed;
}