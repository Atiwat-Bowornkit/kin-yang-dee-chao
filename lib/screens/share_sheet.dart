import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/recipe.dart';
import '../services/share_service.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../widgets/recipe_share_card.dart';

/// แผ่นแชร์สูตร: ตัวอย่างการ์ด + แชร์เป็นรูป / แชร์เป็นข้อความ
Future<void> showRecipeShareSheet(
  BuildContext context,
  Recipe recipe, {
  required int servings,
  ShareService share = const ShareService(),
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _ShareSheet(recipe: recipe, servings: servings, share: share),
  );
}

class _ShareSheet extends StatefulWidget {
  final Recipe recipe;
  final int servings;
  final ShareService share;

  const _ShareSheet({
    required this.recipe,
    required this.servings,
    required this.share,
  });

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _cardKey = GlobalKey();
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (kDebugMode) debugPrint('share failed: $e');
      if (mounted) setState(() => _error = 'แชร์ไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareImage() => _run(() async {
    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw StateError('no boundary');
    await widget.share.shareBoundaryImage(
      boundary,
      fileName: 'kinyangdeechao_${widget.recipe.id}',
      text: widget.recipe.nameTh,
    );
  });

  Future<void> _shareText() => _run(
    () => widget.share.shareText(
      recipeShareText(widget.recipe, servings: widget.servings),
      subject: widget.recipe.nameTh,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final p = context.palette;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.screen),
            child: Text('แชร์สูตร', style: t.titleLarge),
          ),
          const SizedBox(height: Space.md),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: Space.screen),
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: p.line),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.lg),
                    child: FittedBox(
                      child: RepaintBoundary(
                        key: _cardKey,
                        child: RecipeShareCard(
                          recipe: widget.recipe,
                          servings: widget.servings,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: t.bodyMedium!.copyWith(color: p.error),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.screen,
                Space.md,
                Space.screen,
                Space.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _shareText,
                      icon: const Icon(Icons.notes),
                      label: const Text('แชร์ข้อความ'),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _shareImage,
                      icon: _busy
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: p.onAccent,
                              ),
                            )
                          : const Icon(Icons.image_outlined),
                      label: const Text('แชร์รูปการ์ด'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
