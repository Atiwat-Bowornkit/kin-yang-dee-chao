import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'brand_logo.dart';

/// โลโก้แบรนด์ที่เต้นเบาๆ พร้อมข้อความและแถบความคืบหน้าแบบบาง
class BrandLoading extends StatefulWidget {
  final String message;
  final String? hint;
  final double logoSize;

  const BrandLoading({
    super.key,
    required this.message,
    this.hint,
    this.logoSize = 120,
  });

  @override
  State<BrandLoading> createState() => _BrandLoadingState();
}

class _BrandLoadingState extends State<BrandLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _curve,
          builder: (context, child) => Opacity(
            opacity: 0.75 + 0.25 * _curve.value,
            child: Transform.scale(
              scale: 0.94 + 0.08 * _curve.value,
              child: child,
            ),
          ),
          child: BrandLogo(size: widget.logoSize),
        ),
        const SizedBox(height: 28),
        Text(
          widget.message,
          textAlign: TextAlign.center,
          style: context.text.titleMedium!.copyWith(
            fontWeight: FontWeight.w400,
          ),
        ),
        if (widget.hint != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.hint!,
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: 96,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              minHeight: 3,
              color: p.accent,
              backgroundColor: p.line,
            ),
          ),
        ),
      ],
    );
  }
}
