const _persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

/// Arabic thousands separator (U+066C), e.g. ۱۰۵٬۰۰۰٬۰۰۰
const thousandsSeparator = '٬';

/// Replaces ASCII digits 0-9 with Persian digits.
String toPersianDigits(String input) {
  final buffer = StringBuffer();
  for (final unit in input.codeUnits) {
    if (unit >= 0x30 && unit <= 0x39) {
      buffer.write(_persianDigits[unit - 0x30]);
    } else {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}

/// Formats an integer with Persian digits and thousands separators.
String formatPersianNumber(Object value) {
  final raw = value.toString();
  final negative = raw.startsWith('-');
  final digits = negative ? raw.substring(1) : raw;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(thousandsSeparator);
    buffer.write(digits[i]);
  }
  return (negative ? '-' : '') + toPersianDigits(buffer.toString());
}

/// "۱۰۵٬۰۰۰٬۰۰۰ تومان"
String formatToman(BigInt amount, String currencyLabel) =>
    '${formatPersianNumber(amount)} $currencyLabel';

/// "1405-08-22" → "۱۴۰۵/۰۸/۲۲", isolated left-to-right so the parts are not
/// reordered inside right-to-left text.
String formatPersianDate(String isoLike) =>
    '\u2066${toPersianDigits(isoLike.replaceAll('-', '/'))}\u2069';
