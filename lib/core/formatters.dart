const _thaiMonths = [
  'ม.ค.',
  'ก.พ.',
  'มี.ค.',
  'เม.ย.',
  'พ.ค.',
  'มิ.ย.',
  'ก.ค.',
  'ส.ค.',
  'ก.ย.',
  'ต.ค.',
  'พ.ย.',
  'ธ.ค.',
];

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// เวลาแบบสัมพัทธ์ภาษาไทย เช่น "เมื่อสักครู่", "2 ชม.ที่แล้ว", "เมื่อวาน 14:05", "3 ต.ค. 2569"
String formatRelativeThai(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.isNegative || diff.inMinutes < 1) return 'เมื่อสักครู่';
  if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';

  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(time.year, time.month, time.day);
  final days = today.difference(day).inDays;

  if (days == 0) return '${diff.inHours} ชม.ที่แล้ว';
  if (days == 1) return 'เมื่อวาน ${_hhmm(time)}';
  if (days < 7) return '$days วันที่แล้ว';
  return '${time.day} ${_thaiMonths[time.month - 1]} ${time.year + 543}';
}
