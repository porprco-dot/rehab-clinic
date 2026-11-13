/// Exact rational arithmetic on [BigInt], so diyeh amounts never suffer
/// floating-point error. Only the final amount is rounded (half up).
class Fraction implements Comparable<Fraction> {
  final BigInt numerator;
  final BigInt denominator; // always > 0

  Fraction._(this.numerator, this.denominator);

  factory Fraction(BigInt numerator, [BigInt? denominator]) {
    var d = denominator ?? BigInt.one;
    if (d == BigInt.zero) {
      throw ArgumentError('denominator must not be zero');
    }
    var n = numerator;
    if (d.isNegative) {
      n = -n;
      d = -d;
    }
    final g = n.gcd(d);
    if (g > BigInt.one) {
      n = n ~/ g;
      d = d ~/ g;
    }
    return Fraction._(n, d);
  }

  factory Fraction.fromInts(int numerator, [int denominator = 1]) =>
      Fraction(BigInt.from(numerator), BigInt.from(denominator));

  static final Fraction zero = Fraction._(BigInt.zero, BigInt.one);
  static final Fraction one = Fraction._(BigInt.one, BigInt.one);

  static final RegExp _pattern = RegExp(r'^(\d+)(?:/(\d+))?$');

  /// Parses "1/20" or "1". Returns null for anything else
  /// (decimals, signs, spaces, zero denominators).
  static Fraction? tryParse(Object? text) {
    if (text is! String) return null;
    final m = _pattern.firstMatch(text);
    if (m == null) return null;
    final n = BigInt.parse(m.group(1)!);
    final d = m.group(2) == null ? BigInt.one : BigInt.parse(m.group(2)!);
    if (d == BigInt.zero) return null;
    return Fraction(n, d);
  }

  static Fraction parse(String text) {
    final f = tryParse(text);
    if (f == null) throw FormatException('invalid fraction', text);
    return f;
  }

  Fraction operator +(Fraction o) => Fraction(
      numerator * o.denominator + o.numerator * denominator,
      denominator * o.denominator);

  Fraction operator -(Fraction o) => Fraction(
      numerator * o.denominator - o.numerator * denominator,
      denominator * o.denominator);

  Fraction operator *(Fraction o) =>
      Fraction(numerator * o.numerator, denominator * o.denominator);

  Fraction timesInt(int n) => Fraction(numerator * BigInt.from(n), denominator);

  bool get isZero => numerator == BigInt.zero;

  /// Rounds to the nearest integer, halves up. Amounts are never negative.
  BigInt roundHalfUp() {
    if (numerator.isNegative) {
      throw StateError('roundHalfUp is only defined for non-negative values');
    }
    return (numerator * BigInt.two + denominator) ~/ (denominator * BigInt.two);
  }

  @override
  int compareTo(Fraction o) =>
      (numerator * o.denominator).compareTo(o.numerator * denominator);

  bool operator <(Fraction o) => compareTo(o) < 0;
  bool operator >=(Fraction o) => compareTo(o) >= 0;

  @override
  bool operator ==(Object other) =>
      other is Fraction &&
      other.numerator == numerator &&
      other.denominator == denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() =>
      denominator == BigInt.one ? '$numerator' : '$numerator/$denominator';
}
