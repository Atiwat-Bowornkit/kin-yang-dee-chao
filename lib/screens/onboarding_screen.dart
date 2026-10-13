import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../widgets/brand_logo.dart';
import '../widgets/content_width.dart';

class _Page {
  final IconData icon;
  final String title;
  final String body;

  const _Page(this.icon, this.title, this.body);
}

const _pages = [
  _Page(
    Icons.photo_camera_outlined,
    'ถ่ายภาพวัตถุดิบ',
    'ถ่ายหรือเลือกรูปวัตถุดิบที่คุณมี\nวางไว้ด้วยกันหลายอย่างก็ได้ หรือจะเลือกเองก็ได้',
  ),
  _Page(
    Icons.restaurant_menu_outlined,
    'ตรวจให้ตรง แล้วเลือกเมนู',
    'AI อาจตอบผิด จึงให้คุณแก้และยืนยันรายการก่อน\nแล้วดูว่าแต่ละเมนูมีอะไรครบ ขาดอะไร และทำไมถึงแนะนำ',
  ),
  _Page(
    Icons.shopping_basket_outlined,
    'ซื้อของไม่ลืม',
    'เพิ่มของที่ขาดลงรายการซื้อของในแตะเดียว\nบันทึกเมนูโปรด และแชร์สูตรให้เพื่อนได้',
  ),
];

/// แนะนำการใช้งาน 3 หน้า + หน้าตั้งค่า AI (ข้ามได้) แสดงครั้งแรก และเปิดดูซ้ำได้จากตั้งค่า
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  final _key = TextEditingController();
  int _index = 0;

  /// แสดงหน้าตั้งค่า AI เฉพาะเมื่อยังไม่มี key ใช้งานได้
  late final bool _askKey = !AppScope.read(context).ai.hasKey;
  int get _count => _pages.length + (_askKey ? 1 : 0);
  bool get _isLast => _index == _count - 1;

  @override
  void dispose() {
    _controller.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final scope = AppScope.read(context);
    scope.settings.selection();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final key = _key.text.trim();
    if (key.isNotEmpty && !await scope.ai.setApiKey(key)) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'บันทึก API key ไม่สำเร็จ ใส่ใหม่ได้ที่ ตั้งค่า › การเชื่อมต่อ AI',
          ),
        ),
      );
    }
    widget.onDone();
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      AppScope.read(context).settings.selection();
      _controller.nextPage(duration: Motion.normal, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final onKeyPage = _askKey && _isLast;
    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.screen,
                  Space.sm,
                  Space.sm,
                  0,
                ),
                child: Row(
                  children: [
                    const BrandLogo(size: 56),
                    const Spacer(),
                    AnimatedOpacity(
                      duration: Motion.fast,
                      opacity: _isLast ? 0 : 1,
                      child: TextButton(
                        onPressed: _isLast ? null : _finish,
                        child: Text('ข้าม', style: TextStyle(color: p.muted)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _count,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => i < _pages.length
                      ? _OnboardingPage(page: _pages[i])
                      : _KeyPage(controller: _key),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _count; i++)
                    AnimatedContainer(
                      duration: Motion.normal,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? p.accent : p.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(Space.screen),
                child: ListenableBuilder(
                  listenable: _key,
                  builder: (context, _) => FilledButton(
                    onPressed: _next,
                    child: Text(
                      !_isLast
                          ? 'ถัดไป'
                          : onKeyPage && _key.text.trim().isEmpty
                          ? 'ข้ามไปก่อน เริ่มใช้งาน'
                          : 'เริ่มใช้งาน',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _Page page;

  const _OnboardingPage({required this.page});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    // เลื่อนได้เมื่อพื้นที่ไม่พอ (จอเล็ก/ขยายตัวอักษร) แต่จัดกึ่งกลางเมื่อพอ
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Space.screen),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [p.accentSoft, p.goldSoft],
                  ),
                ),
                child: Icon(page.icon, size: 60, color: p.accent),
              ),
              const SizedBox(height: Space.xxxl),
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: t.headlineMedium,
              ),
              const SizedBox(height: Space.md),
              Text(
                page.body,
                textAlign: TextAlign.center,
                style: t.bodyLarge!.copyWith(color: p.muted, height: 1.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyPage extends StatefulWidget {
  final TextEditingController controller;

  const _KeyPage({required this.controller});

  @override
  State<_KeyPage> createState() => _KeyPageState();
}

class _KeyPageState extends State<_KeyPage> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Space.screen),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: p.goldSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.key_outlined, size: 52, color: p.ink),
              ),
              const SizedBox(height: Space.xl),
              Text(
                'เชื่อมต่อ AI',
                textAlign: TextAlign.center,
                style: t.headlineMedium,
              ),
              const SizedBox(height: Space.sm),
              Text(
                'ใส่ API key ของบริการ AI เพื่อให้วิเคราะห์รูปได้\nไม่มีตอนนี้ก็ข้ามได้ ใส่ภายหลังในหน้าตั้งค่า',
                textAlign: TextAlign.center,
                style: t.bodyMedium!.copyWith(color: p.muted, height: 1.6),
              ),
              const SizedBox(height: Space.xl),
              TextField(
                controller: widget.controller,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  hintText: 'API key (ไม่บังคับ)',
                  prefixIcon: const Icon(Icons.key_outlined),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'แสดง key' : 'ซ่อน key',
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
