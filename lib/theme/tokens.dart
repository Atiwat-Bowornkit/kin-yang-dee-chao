/// โทเคนดีไซน์กลาง (ระยะห่าง มุมโค้ง และจังหวะแอนิเมชัน)
class Space {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// ขอบซ้าย-ขวามาตรฐานของหน้าจอ
  static const double screen = 20;
}

class Radii {
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;
}

class Motion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 350);
}

/// ความกว้างสูงสุดของเนื้อหา (กันเลย์เอาต์ยืดเกินไปบนจอใหญ่/แท็บเล็ต)
const double kMaxContentWidth = 600;
