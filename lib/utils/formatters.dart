/// 14999 -> "₹14,999" (Indian digit grouping: 1,23,456).
String rupees(int n) {
  final s = n.toString();
  if (s.length <= 3) return '\u20B9$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '\u20B9${parts.join(',')},$last3';
}
