import 'package:flutter_test/flutter_test.dart';
import 'package:kinyangdeechao/data/favorites_repository.dart';
import 'package:kinyangdeechao/data/history_repository.dart';
import 'package:kinyangdeechao/data/recipe_repository.dart';
import 'package:kinyangdeechao/data/shopping_repository.dart';
import 'package:kinyangdeechao/models/recipe.dart';
import 'package:kinyangdeechao/models/scan_record.dart';
import 'package:kinyangdeechao/models/shopping_item.dart';
import 'package:kinyangdeechao/state/favorites_controller.dart';
import 'package:kinyangdeechao/state/history_controller.dart';
import 'package:kinyangdeechao/state/shopping_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

/// การเขียนล้มเหลวได้ 2 แบบ: คืน false หรือ throw
enum Fault { none, returnFalse, throwError }

Future<bool> _write(Fault f, void Function() commit) async {
  switch (f) {
    case Fault.returnFalse:
      return false;
    case Fault.throwError:
      throw Exception('disk full');
    case Fault.none:
      commit();
      return true;
  }
}

/// repository ปลอมที่เก็บ "สถานะที่เขียนลงเครื่องจริง" แยกจากหน่วยความจำของ controller
class FaultyHistoryRepository extends HistoryRepository {
  FaultyHistoryRepository(
    super.prefs, {
    List<ScanRecord> records = const [],
    this.durableDraft,
  }) : durable = List.of(records);

  List<ScanRecord> durable;
  ScanRecord? durableDraft;
  Fault historyFault = Fault.none;
  Fault draftFault = Fault.none;

  @override
  List<ScanRecord> load() => List.of(durable);

  @override
  ScanRecord? loadDraft() => durableDraft;

  @override
  Future<bool> save(List<ScanRecord> records) =>
      _write(historyFault, () => durable = List.of(records));

  @override
  Future<bool> saveDraft(ScanRecord? draft) =>
      _write(draftFault, () => durableDraft = draft);
}

class FaultyFavoritesRepository extends FavoritesRepository {
  FaultyFavoritesRepository(super.prefs, [List<Recipe> initial = const []])
    : durable = List.of(initial);

  List<Recipe> durable;
  Fault fault = Fault.none;

  @override
  List<Recipe> load() => List.of(durable);

  @override
  Future<bool> save(List<Recipe> recipes) =>
      _write(fault, () => durable = List.of(recipes));
}

class FaultyShoppingRepository extends ShoppingRepository {
  FaultyShoppingRepository(super.prefs, [List<ShoppingItem> initial = const []])
    : durable = List.of(initial);

  List<ShoppingItem> durable;
  Fault fault = Fault.none;

  @override
  List<ShoppingItem> load() => List.of(durable);

  @override
  Future<bool> save(List<ShoppingItem> items) =>
      _write(fault, () => durable = List.of(items));
}

ScanRecord rec(String id) => ScanRecord(
  id: id,
  createdAt: DateTime(2026, 1, 1),
  imageFile: '$id.jpg',
  ingredients: const [egg],
);

ScanRecord draftRec(String id) => rec(id).copyWith(status: ScanStatus.draft);

class HistoryFixture {
  HistoryFixture(this.repo, this.images, this.controller);
  final FaultyHistoryRepository repo;
  final FakeImageStore images;
  HistoryController controller;

  /// เปิดแอปใหม่: controller ใหม่จากสิ่งที่ "เขียนลงเครื่องจริง" เท่านั้น
  HistoryController restart() => HistoryController(repo, images);
}

Future<HistoryFixture> history({
  List<ScanRecord> records = const [],
  ScanRecord? draft,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final images = FakeImageStore();
  images.files.addAll([
    for (final r in records) r.imageFile!,
    ?draft?.imageFile,
  ]);
  final repo = FaultyHistoryRepository(
    prefs,
    records: records,
    durableDraft: draft,
  );
  return HistoryFixture(repo, images, HistoryController(repo, images));
}

void main() {
  for (final fault in [Fault.returnFalse, Fault.throwError]) {
    group('HistoryController write failure ($fault)', () {
      test(
        'add overflow: oldest image survives while the write is not durable',
        () async {
          final old = [
            for (var i = 99; i >= 0; i--) rec('r$i'),
          ]; // r99 อยู่ก่อน, r0 เก่าสุด
          final h = await history(records: old);
          h.repo.historyFault = fault;

          final ok = await h.controller.add(rec('new'));
          expect(ok, isFalse);
          expect(h.controller.lastSaveFailed, isTrue);
          expect(
            h.images.files,
            contains('r0.jpg'),
            reason: 'ในเครื่องยังมี r0 อยู่ รูปต้องไม่ถูกลบ',
          );
          expect(h.images.deleted, isEmpty);

          // เปิดแอปใหม่ → ข้อมูลเดิมครบ รูปเดิมอยู่ครบ
          final again = h.restart();
          expect(again.records.length, 100);
          expect(again.byId('r0'), isNotNull);

          // เขียนสำเร็จภายหลัง → ค่อยลบรูปที่หลุดจากประวัติจริง
          h.repo.historyFault = Fault.none;
          expect(await h.controller.add(rec('new2')), isTrue);
          expect(h.images.files, isNot(contains('r0.jpg')));
          expect(h.images.files, isNot(contains('r1.jpg')));
          expect(h.images.files, contains('r2.jpg'));
        },
      );

      test(
        'saveDraft replace keeps the old draft image until durable',
        () async {
          final h = await history(draft: draftRec('A'));
          h.repo.draftFault = fault;
          h.images.files.add('B.jpg');

          expect(await h.controller.saveDraft(draftRec('B')), isFalse);
          expect(h.images.files, contains('A.jpg'));
          final again = h.restart();
          expect(again.draft!.id, 'A', reason: 'ร่างเดิมในเครื่องกู้คืนได้');

          h.repo.draftFault = Fault.none;
          expect(await h.controller.saveDraft(draftRec('B')), isTrue);
          expect(h.images.files, isNot(contains('A.jpg')));
          expect(h.images.files, contains('B.jpg'));
        },
      );

      test(
        'updateDraft reports the failure and keeps the last durable draft',
        () async {
          final h = await history(draft: draftRec('A'));
          h.repo.draftFault = fault;
          final edited = h.controller.draft!.copyWith(kitchen: {'oil'});
          expect(await h.controller.updateDraft(edited), isFalse);
          expect(h.repo.durableDraft!.kitchen, isNot(contains('oil')));
          h.repo.draftFault = Fault.none;
          expect(await h.controller.updateDraft(edited), isTrue);
          expect(h.repo.durableDraft!.kitchen, contains('oil'));
        },
      );

      test(
        'discardDraft failure: draft and image come back, nothing deleted',
        () async {
          final h = await history(draft: draftRec('A'));
          h.repo.draftFault = fault;
          expect(await h.controller.discardDraft(), isFalse);
          expect(h.controller.draft?.id, 'A');
          expect(h.images.files, contains('A.jpg'));
          expect(h.images.deleted, isEmpty);
          expect(h.restart().draft?.id, 'A');

          h.repo.draftFault = Fault.none;
          expect(await h.controller.discardDraft(), isTrue);
          expect(h.controller.draft, isNull);
          expect(h.images.files, isNot(contains('A.jpg')));
        },
      );

      test(
        'confirm: history write fails → draft is not dropped anywhere',
        () async {
          final h = await history(draft: draftRec('A'));
          h.repo.historyFault = fault;
          final ok = await h.controller.confirm(
            'A',
            ingredients: const [egg],
            renames: const [],
            kitchen: const {'oil'},
          );
          expect(ok, isFalse);
          expect(h.controller.draft?.id, 'A', reason: 'ผู้ใช้ยืนยันใหม่ได้');
          expect(h.controller.records, isEmpty);
          expect(h.repo.durableDraft?.id, 'A');
          expect(h.images.files, contains('A.jpg'));
          final again = h.restart();
          expect(again.draft?.id, 'A');
          expect(again.records, isEmpty);

          h.repo.historyFault = Fault.none;
          expect(
            await h.controller.confirm(
              'A',
              ingredients: const [egg],
              renames: const [],
              kitchen: const {},
            ),
            isTrue,
          );
          expect(h.controller.draft, isNull);
          expect(h.repo.durable.single.id, 'A');
          expect(h.images.files, contains('A.jpg'));
        },
      );

      test('confirm: history saved but draft key not cleared → no duplicate, '
          'image kept, later cleanup clears the leftover', () async {
        final h = await history(draft: draftRec('A'));
        h.repo.draftFault = fault;
        final ok = await h.controller.confirm(
          'A',
          ingredients: const [egg],
          renames: const [],
          kitchen: const {},
        );
        expect(ok, isTrue, reason: 'ฉบับยืนยันบันทึกแล้ว');
        expect(h.repo.durable.single.id, 'A');
        expect(h.repo.durableDraft?.id, 'A', reason: 'key ร่างค้างอยู่');
        expect(h.images.files, contains('A.jpg'));

        final again = h.restart();
        expect(again.records.map((r) => r.id), ['A']);
        expect(again.draft, isNull, reason: 'ฉบับที่ยืนยันแล้วชนะ ไม่ซ้ำ');

        h.repo.draftFault = Fault.none;
        await again.cleanupOrphans();
        expect(h.repo.durableDraft, isNull);
        expect(h.images.files, contains('A.jpg'));
      });

      test(
        'confirm on an existing record restores it when the write fails',
        () async {
          final h = await history(records: [rec('a')]);
          h.repo.historyFault = fault;
          final ok = await h.controller.confirm(
            'a',
            ingredients: const [tomato],
            renames: const [],
            kitchen: const {},
          );
          expect(ok, isFalse);
          expect(h.controller.byId('a')!.ingredients, const [egg]);
        },
      );

      test(
        'remove: failure brings the record back; image is never deleted',
        () async {
          final h = await history(records: [rec('b'), rec('a')]);
          h.repo.historyFault = fault;
          final saved = h.controller.remove('a');
          expect(
            h.controller.records.map((r) => r.id),
            ['b'],
            reason: 'ส่วน sync ลบทันที (Dismissible)',
          );
          expect(await saved, isFalse);
          expect(h.controller.records.map((r) => r.id), ['b', 'a']);
          await h.controller.finalizeRemoval('a'); // snackbar ปิดช้า
          expect(h.images.files, contains('a.jpg'));
          expect(h.images.deleted, isEmpty);
          expect(h.restart().byId('a'), isNotNull);
        },
      );

      test(
        'finalizeRemoval deletes the image once the removal is durable',
        () async {
          final h = await history(records: [rec('a')]);
          expect(await h.controller.remove('a'), isTrue);
          expect(h.images.files, contains('a.jpg'), reason: 'ยังเลิกทำได้');
          h.repo.historyFault =
              fault; // เขียนครั้งหลังล้มเหลวก็ไม่เกี่ยวกับรูปนี้
          await h.controller.finalizeRemoval('a');
          expect(h.images.files, isNot(contains('a.jpg')));
          expect(h.repo.durable, isEmpty);
        },
      );

      test(
        'undo write failure is reported but the record is not lost this session',
        () async {
          final h = await history(records: [rec('a')]);
          await h.controller.remove('a');
          h.repo.historyFault = fault;
          expect(await h.controller.undoRemoval('a'), isFalse);
          expect(h.controller.byId('a'), isNotNull);
          expect(h.images.files, contains('a.jpg'));
          // รูปยังถูกอ้างถึงจากหน่วยความจำ แม้ finalizeRemoval ช้ามาทีหลัง
          await h.controller.finalizeRemoval('a');
          expect(h.images.files, contains('a.jpg'));
        },
      );

      test('clear: nothing is deleted when the history write fails', () async {
        final h = await history(
          records: [rec('b'), rec('a')],
          draft: draftRec('d'),
        );
        h.repo.historyFault = fault;
        final ok = await h.controller.clear();
        expect(ok, isFalse);
        expect(h.controller.records.map((r) => r.id), ['b', 'a']);
        expect(h.images.files, containsAll(['a.jpg', 'b.jpg']));
        // draft ลบสำเร็จ (key แยก) จึงลบรูปของ draft ได้
        expect(h.controller.draft, isNull);
        expect(h.images.files, isNot(contains('d.jpg')));
        expect(h.restart().records.length, 2);
      });

      test(
        'clear: draft key failure restores the draft and its image',
        () async {
          final h = await history(records: [rec('a')], draft: draftRec('d'));
          h.repo.draftFault = fault;
          final ok = await h.controller.clear();
          expect(ok, isFalse);
          expect(h.controller.draft?.id, 'd');
          expect(h.images.files, contains('d.jpg'));
          expect(
            h.images.files,
            isNot(contains('a.jpg')),
            reason: 'ประวัติถูกลบจริงแล้ว รูปของมันลบได้',
          );
          expect(h.controller.records, isEmpty);
          expect(h.restart().draft?.id, 'd');
        },
      );
    });
  }

  group('HistoryController normal behaviour stays intact', () {
    test(
      'clear removes everything and deleteAll runs only on full success',
      () async {
        final h = await history(records: [rec('a')], draft: draftRec('d'));
        expect(await h.controller.clear(), isTrue);
        expect(h.repo.durable, isEmpty);
        expect(h.repo.durableDraft, isNull);
        expect(h.images.files, isEmpty);
      },
    );

    test('multi-item undo still works after the rewrite', () async {
      final h = await history(records: [rec('c'), rec('b'), rec('a')]);
      final r1 = h.controller.remove('a');
      final r2 = h.controller.remove('b');
      await Future.wait([r1, r2]);
      await h.controller.finalizeRemoval('a');
      expect(h.images.files, isNot(contains('a.jpg')));
      expect(await h.controller.undoRemoval('b'), isTrue);
      expect(h.controller.records.map((r) => r.id), ['c', 'b']);
      expect(h.images.files, contains('b.jpg'));
      expect(h.repo.durable.map((r) => r.id), ['c', 'b']);
    });

    test('cleanupOrphans keeps images referenced by durable data', () async {
      final h = await history(records: [rec('a')], draft: draftRec('d'));
      h.images.files.add('stray.jpg');
      expect(await h.controller.cleanupOrphans(), 1);
      expect(h.images.files, {'a.jpg', 'd.jpg'});
    });
  });

  for (final fault in [Fault.returnFalse, Fault.throwError]) {
    group('FavoritesController write failure ($fault)', () {
      test(
        'toggle separates the new state from the persistence result',
        () async {
          SharedPreferences.setMockInitialValues({});
          final repo = FaultyFavoritesRepository(
            await SharedPreferences.getInstance(),
          );
          final c = FavoritesController(repo);
          final r = RecipeRepository.byId('EGG-01')!;
          repo.fault = fault;
          final out = await c.toggle(r);
          expect(out.isFavorite, isTrue);
          expect(out.saved, isFalse);
          expect(c.lastSaveFailed, isTrue);
          expect(repo.durable, isEmpty, reason: 'ยังไม่ได้เขียนลงเครื่อง');
          repo.fault = Fault.none;
          expect((await c.toggle(r)).saved, isTrue);
        },
      );

      test('clear failure restores the list', () async {
        SharedPreferences.setMockInitialValues({});
        final r = RecipeRepository.byId('EGG-01')!;
        final repo = FaultyFavoritesRepository(
          await SharedPreferences.getInstance(),
          [r],
        );
        final c = FavoritesController(repo);
        repo.fault = fault;
        expect(await c.clear(), isFalse);
        expect(c.recipes, hasLength(1));
        expect(repo.durable, hasLength(1));
      });
    });

    group('ShoppingController write failure ($fault)', () {
      late FaultyShoppingRepository repo;
      late ShoppingController c;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        repo = FaultyShoppingRepository(await SharedPreferences.getInstance());
        c = ShoppingController(repo);
      });

      test(
        'addName: duplicate and write failure are different outcomes',
        () async {
          expect(await c.addName('ไข่'), AddNameResult.added);
          expect(await c.addName('ไข่ไก่'), AddNameResult.duplicate);
          repo.fault = fault;
          expect(await c.addName('หมู'), AddNameResult.saveFailed);
          expect(repo.durable, hasLength(1));
          expect(c.items, hasLength(1), reason: 'ไม่ค้างรายการที่ไม่ได้บันทึก');
          // ลองชื่อเดิมซ้ำหลังดิสก์กลับมา ต้องบันทึกจริง ไม่ใช่ "ซ้ำ"
          repo.fault = Fault.none;
          expect(await c.addName('หมู'), AddNameResult.added);
          expect(repo.durable, hasLength(2));
          repo.fault = fault;
          // ซ้ำยังเป็นซ้ำแม้ดิสก์เขียนไม่ได้ (ไม่ต้องเขียนอะไร)
          expect(await c.addName('ไข่'), AddNameResult.duplicate);
        },
      );

      test('toggle reports a failed write', () async {
        await c.addName('ไข่');
        final id = c.items.single.id;
        repo.fault = fault;
        expect(await c.toggle(id), isFalse);
        expect(repo.durable.single.checked, isFalse);
        repo.fault = Fault.none;
        expect(await c.toggle(id), isTrue);
      });

      test(
        'remove failure puts the item back; undo failure is reported',
        () async {
          await c.addName('ไข่');
          await c.addName('หมู');
          final id = c.items.last.id;
          repo.fault = fault;
          final saved = c.remove(id);
          expect(c.items, hasLength(1));
          expect(await saved, isFalse);
          expect(c.items, hasLength(2));

          repo.fault = Fault.none;
          await c.remove(id);
          repo.fault = fault;
          expect(await c.undoRemoval(id), isFalse);
          expect(c.items, hasLength(2));
        },
      );

      test('clearChecked / clear failure restore the items', () async {
        await c.addName('ไข่');
        await c.addName('หมู');
        await c.toggle(c.items.first.id);
        repo.fault = fault;
        final r = await c.clearChecked();
        expect(r.saved, isFalse);
        expect(c.items, hasLength(2));
        expect(await c.clear(), isFalse);
        expect(c.items, hasLength(2));
        expect(repo.durable, hasLength(2));
      });

      test('addFromRecipe returns null on failure', () async {
        final r = RecipeRepository.byId('EGG-01')!;
        repo.fault = fault;
        expect(await c.addFromRecipe(r, r.ingredients), isNull);
      });
    });
  }
}
