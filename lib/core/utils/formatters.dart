String formatRinggit(num value, {bool compact = false}) {
  if (compact && value >= 1000000) {
    return 'RM ${(value / 1000000).toStringAsFixed(2)}M';
  }
  if (compact && value >= 1000) {
    return 'RM ${(value / 1000).toStringAsFixed(0)}K';
  }
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  return 'RM $buffer';
}

String formatCount(num value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(2)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(0)}K';
  }
  return value.round().toString();
}
