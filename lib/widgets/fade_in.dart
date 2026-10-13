import 'package:flutter/material.dart';

/// เฟดเข้าพร้อมเลื่อนขึ้นเล็กน้อย หน่วงเวลาตามลำดับ ([index]) เพื่อให้รายการทยอยปรากฏ
/// (หน่วงด้วย Interval ของแอนิเมชันเดียว ไม่ใช้ Timer)
class FadeIn extends StatefulWidget {
  final Widget child;
  final int index;

  const FadeIn({super.key, required this.child, this.index = 0});

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  static const _base = 360;
  static const _step = 45;

  late final int _delay = _step * widget.index.clamp(0, 8);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _base + _delay),
  )..forward();
  late final Animation<double> _curve = CurvedAnimation(
    parent: _c,
    curve: Interval(_delay / (_base + _delay), 1, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // เคารพการตั้งค่า "ลดการเคลื่อนไหว" ของระบบ
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - _curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
