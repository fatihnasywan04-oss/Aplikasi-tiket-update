String formatRupiah(num? amount) {
  if (amount == null) return '-';

  final digits = amount.round().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }

    buffer.write(digits[i]);
  }

  return 'Rp $buffer';
}
