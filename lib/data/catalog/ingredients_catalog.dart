import '../../models/ingredient.dart';

typedef _C = IngredientCategory;

/// ฐานข้อมูลวัตถุดิบของแอป
/// - id ภาษาอังกฤษตัวเล็ก ใช้ร่วมกับ AI (prompt ส่งรายการ id นี้ไปให้)
/// - synonyms ใช้จับคู่ชื่อแบบตรงทั้งคำ (ไม่ใช้ substring เพื่อกัน "ไข่" ไปตรงกับ "ไข่เค็ม")
class IngredientCatalog {
  IngredientCatalog._();

  static const List<Ingredient> all = [
    // ---------- โปรตีน ----------
    Ingredient(
      id: 'egg',
      nameTh: 'ไข่ไก่',
      nameEn: 'egg',
      emoji: '🥚',
      category: _C.dairy,
      synonyms: ['ไข่', 'ไข่ไก่สด'],
    ),
    Ingredient(
      id: 'pork',
      nameTh: 'หมู',
      nameEn: 'pork',
      emoji: '🥩',
      category: _C.protein,
      synonyms: [
        'หมูสับ',
        'เนื้อหมู',
        'หมูบด',
        'หมูสามชั้น',
        'หมูชิ้น',
        'สันในหมู',
        'สันคอหมู',
        'หมูหมัก',
      ],
    ),
    Ingredient(
      id: 'chicken',
      nameTh: 'ไก่',
      nameEn: 'chicken',
      emoji: '🍗',
      category: _C.protein,
      synonyms: [
        'เนื้อไก่',
        'อกไก่',
        'สะโพกไก่',
        'น่องไก่',
        'ไก่สับ',
        'ปีกไก่',
        'ไก่บด',
      ],
    ),
    Ingredient(
      id: 'beef',
      nameTh: 'เนื้อวัว',
      nameEn: 'beef',
      emoji: '🥩',
      category: _C.protein,
      synonyms: ['เนื้อ', 'เนื้อสันใน', 'เนื้อบด'],
    ),
    Ingredient(
      id: 'shrimp',
      nameTh: 'กุ้ง',
      nameEn: 'shrimp',
      emoji: '🦐',
      category: _C.protein,
      synonyms: ['กุ้งสด', 'กุ้งแม่น้ำ', 'กุ้งขาว', 'prawn'],
    ),
    Ingredient(
      id: 'fish',
      nameTh: 'ปลา',
      nameEn: 'fish',
      emoji: '🐟',
      category: _C.protein,
      synonyms: ['เนื้อปลา', 'ปลานิล', 'ปลากะพง', 'ปลาดอรี่', 'ปลาทับทิม'],
    ),
    Ingredient(
      id: 'squid',
      nameTh: 'ปลาหมึก',
      nameEn: 'squid',
      emoji: '🦑',
      category: _C.protein,
      synonyms: ['หมึก', 'หมึกกล้วย'],
    ),
    Ingredient(
      id: 'tuna',
      nameTh: 'ทูน่ากระป๋อง',
      nameEn: 'canned tuna',
      emoji: '🥫',
      category: _C.protein,
      synonyms: ['ทูน่า', 'ปลาทูน่า'],
    ),
    Ingredient(
      id: 'sausage',
      nameTh: 'ไส้กรอก',
      nameEn: 'sausage',
      emoji: '🌭',
      category: _C.protein,
      synonyms: ['ไส้กรอกหมู', 'ไส้กรอกไก่'],
    ),
    Ingredient(
      id: 'tofu',
      nameTh: 'เต้าหู้',
      nameEn: 'tofu',
      emoji: '🧊',
      category: _C.protein,
      synonyms: ['เต้าหู้ไข่', 'เต้าหู้แข็ง', 'เต้าหู้ขาว', 'เต้าหู้อ่อน'],
    ),

    // ---------- ข้าว เส้น แป้ง ----------
    Ingredient(
      id: 'rice',
      nameTh: 'ข้าวสวย',
      nameEn: 'rice',
      emoji: '🍚',
      category: _C.staple,
      synonyms: ['ข้าว', 'ข้าวสาร', 'ข้าวหอมมะลิ', 'ข้าวสุก'],
    ),
    Ingredient(
      id: 'sticky_rice',
      nameTh: 'ข้าวเหนียว',
      nameEn: 'sticky rice',
      emoji: '🍙',
      category: _C.staple,
      synonyms: ['ข้าวเหนียวนึ่ง', 'ข้าวเหนียวมูน'],
    ),
    Ingredient(
      id: 'rice_noodle',
      nameTh: 'เส้นก๋วยเตี๋ยว',
      nameEn: 'rice noodle',
      emoji: '🍜',
      category: _C.staple,
      synonyms: ['เส้นเล็ก', 'เส้นใหญ่', 'เส้นหมี่', 'เส้นจันท์', 'ก๋วยเตี๋ยว'],
    ),
    Ingredient(
      id: 'egg_noodle',
      nameTh: 'บะหมี่',
      nameEn: 'egg noodle',
      emoji: '🍜',
      category: _C.staple,
      synonyms: ['เส้นบะหมี่', 'บะหมี่เหลือง', 'เส้นข้าวซอย'],
    ),
    Ingredient(
      id: 'instant_noodle',
      nameTh: 'บะหมี่กึ่งสำเร็จรูป',
      nameEn: 'instant noodle',
      emoji: '🍜',
      category: _C.staple,
      synonyms: ['มาม่า', 'ไวไว', 'ยำยำ'],
    ),
    Ingredient(
      id: 'glass_noodle',
      nameTh: 'วุ้นเส้น',
      nameEn: 'glass noodle',
      emoji: '🍜',
      category: _C.staple,
    ),
    Ingredient(
      id: 'bread',
      nameTh: 'ขนมปัง',
      nameEn: 'bread',
      emoji: '🍞',
      category: _C.staple,
      synonyms: ['ขนมปังแผ่น', 'ขนมปังโฮลวีต'],
    ),
    Ingredient(
      id: 'flour',
      nameTh: 'แป้งสาลี',
      nameEn: 'flour',
      emoji: '🌾',
      category: _C.staple,
      synonyms: ['แป้ง', 'แป้งอเนกประสงค์'],
    ),

    // ---------- ผัก ----------
    Ingredient(
      id: 'tomato',
      nameTh: 'มะเขือเทศ',
      nameEn: 'tomato',
      emoji: '🍅',
      category: _C.vegetable,
      synonyms: ['มะเขือเทศสีดา', 'มะเขือเทศราชินี'],
    ),
    Ingredient(
      id: 'potato',
      nameTh: 'มันฝรั่ง',
      nameEn: 'potato',
      emoji: '🥔',
      category: _C.vegetable,
    ),
    Ingredient(
      id: 'carrot',
      nameTh: 'แครอท',
      nameEn: 'carrot',
      emoji: '🥕',
      category: _C.vegetable,
      synonyms: ['แคร์รอต'],
    ),
    Ingredient(
      id: 'onion',
      nameTh: 'หอมใหญ่',
      nameEn: 'onion',
      emoji: '🧅',
      category: _C.vegetable,
      synonyms: ['หัวหอมใหญ่', 'หัวหอม'],
    ),
    Ingredient(
      id: 'shallot',
      nameTh: 'หอมแดง',
      nameEn: 'shallot',
      emoji: '🧅',
      category: _C.herb,
      synonyms: ['หัวหอมแดง'],
    ),
    Ingredient(
      id: 'garlic',
      nameTh: 'กระเทียม',
      nameEn: 'garlic',
      emoji: '🧄',
      category: _C.herb,
      synonyms: ['กระเทียมไทย', 'กระเทียมสับ'],
      pantry: true,
    ),
    Ingredient(
      id: 'chili',
      nameTh: 'พริก',
      nameEn: 'chili',
      emoji: '🌶️',
      category: _C.herb,
      synonyms: ['พริกขี้หนู', 'พริกชี้ฟ้า', 'พริกสด', 'พริกแห้ง'],
    ),
    Ingredient(
      id: 'morning_glory',
      nameTh: 'ผักบุ้ง',
      nameEn: 'morning glory',
      emoji: '🥬',
      category: _C.vegetable,
      synonyms: ['ผักบุ้งจีน', 'ผักบุ้งไทย'],
    ),
    Ingredient(
      id: 'kale',
      nameTh: 'คะน้า',
      nameEn: 'chinese kale',
      emoji: '🥬',
      category: _C.vegetable,
      synonyms: ['ผักคะน้า'],
    ),
    Ingredient(
      id: 'cabbage',
      nameTh: 'กะหล่ำปลี',
      nameEn: 'cabbage',
      emoji: '🥬',
      category: _C.vegetable,
      synonyms: ['กะหล่ำ'],
    ),
    Ingredient(
      id: 'napa_cabbage',
      nameTh: 'ผักกาดขาว',
      nameEn: 'napa cabbage',
      emoji: '🥬',
      category: _C.vegetable,
      synonyms: ['ผักกาดขาวปลี'],
    ),
    Ingredient(
      id: 'broccoli',
      nameTh: 'บรอกโคลี',
      nameEn: 'broccoli',
      emoji: '🥦',
      category: _C.vegetable,
      synonyms: ['บร็อคโคลี่', 'บรอคโคลี'],
    ),
    Ingredient(
      id: 'cucumber',
      nameTh: 'แตงกวา',
      nameEn: 'cucumber',
      emoji: '🥒',
      category: _C.vegetable,
    ),
    Ingredient(
      id: 'long_bean',
      nameTh: 'ถั่วฝักยาว',
      nameEn: 'long bean',
      emoji: '🫛',
      category: _C.vegetable,
    ),
    Ingredient(
      id: 'bean_sprout',
      nameTh: 'ถั่วงอก',
      nameEn: 'bean sprout',
      emoji: '🌱',
      category: _C.vegetable,
    ),
    Ingredient(
      id: 'eggplant',
      nameTh: 'มะเขือยาว',
      nameEn: 'eggplant',
      emoji: '🍆',
      category: _C.vegetable,
      synonyms: ['มะเขือ', 'มะเขือม่วง'],
    ),
    Ingredient(
      id: 'pumpkin',
      nameTh: 'ฟักทอง',
      nameEn: 'pumpkin',
      emoji: '🎃',
      category: _C.vegetable,
    ),
    Ingredient(
      id: 'corn',
      nameTh: 'ข้าวโพด',
      nameEn: 'corn',
      emoji: '🌽',
      category: _C.vegetable,
      synonyms: ['ข้าวโพดหวาน', 'ข้าวโพดอ่อน', 'ข้าวโพดกระป๋อง'],
    ),
    Ingredient(
      id: 'mushroom',
      nameTh: 'เห็ด',
      nameEn: 'mushroom',
      emoji: '🍄',
      category: _C.vegetable,
      synonyms: [
        'เห็ดฟาง',
        'เห็ดหอม',
        'เห็ดนางฟ้า',
        'เห็ดเข็มทอง',
        'เห็ดออรินจิ',
        'เห็ดรวม',
      ],
    ),
    Ingredient(
      id: 'bell_pepper',
      nameTh: 'พริกหวาน',
      nameEn: 'bell pepper',
      emoji: '🫑',
      category: _C.vegetable,
      synonyms: ['พริกหยวก'],
    ),
    Ingredient(
      id: 'lettuce',
      nameTh: 'ผักสลัด',
      nameEn: 'lettuce',
      emoji: '🥗',
      category: _C.vegetable,
      synonyms: ['ผักกาดหอม', 'กรีนโอ๊ค', 'เรดโอ๊ค'],
    ),
    Ingredient(
      id: 'papaya',
      nameTh: 'มะละกอดิบ',
      nameEn: 'green papaya',
      emoji: '🥗',
      category: _C.vegetable,
      synonyms: ['มะละกอ', 'มะละกอสับ'],
    ),
    Ingredient(
      id: 'spring_onion',
      nameTh: 'ต้นหอม',
      nameEn: 'spring onion',
      emoji: '🌱',
      category: _C.herb,
      synonyms: ['หอมซอย'],
    ),
    Ingredient(
      id: 'coriander',
      nameTh: 'ผักชี',
      nameEn: 'coriander',
      emoji: '🌿',
      category: _C.herb,
      synonyms: ['ผักชีไทย', 'รากผักชี'],
    ),
    Ingredient(
      id: 'holy_basil',
      nameTh: 'ใบกะเพรา',
      nameEn: 'holy basil',
      emoji: '🌿',
      category: _C.herb,
      synonyms: ['กะเพรา'],
    ),
    Ingredient(
      id: 'thai_basil',
      nameTh: 'ใบโหระพา',
      nameEn: 'thai basil',
      emoji: '🌿',
      category: _C.herb,
      synonyms: ['โหระพา'],
    ),
    Ingredient(
      id: 'lemongrass',
      nameTh: 'ตะไคร้',
      nameEn: 'lemongrass',
      emoji: '🌾',
      category: _C.herb,
    ),
    Ingredient(
      id: 'galangal',
      nameTh: 'ข่า',
      nameEn: 'galangal',
      emoji: '🫚',
      category: _C.herb,
    ),
    Ingredient(
      id: 'ginger',
      nameTh: 'ขิง',
      nameEn: 'ginger',
      emoji: '🫚',
      category: _C.herb,
      synonyms: ['ขิงอ่อน'],
    ),
    Ingredient(
      id: 'kaffir_lime_leaf',
      nameTh: 'ใบมะกรูด',
      nameEn: 'kaffir lime leaf',
      emoji: '🍃',
      category: _C.herb,
    ),
    Ingredient(
      id: 'lime',
      nameTh: 'มะนาว',
      nameEn: 'lime',
      emoji: '🍋',
      category: _C.fruit,
      synonyms: ['น้ำมะนาว'],
    ),

    // ---------- ผลไม้ ----------
    Ingredient(
      id: 'banana',
      nameTh: 'กล้วย',
      nameEn: 'banana',
      emoji: '🍌',
      category: _C.fruit,
      synonyms: ['กล้วยหอม', 'กล้วยน้ำว้า', 'กล้วยไข่'],
    ),
    Ingredient(
      id: 'mango',
      nameTh: 'มะม่วง',
      nameEn: 'mango',
      emoji: '🥭',
      category: _C.fruit,
      synonyms: ['มะม่วงสุก', 'มะม่วงน้ำดอกไม้'],
    ),
    Ingredient(
      id: 'pineapple',
      nameTh: 'สับปะรด',
      nameEn: 'pineapple',
      emoji: '🍍',
      category: _C.fruit,
    ),
    Ingredient(
      id: 'apple',
      nameTh: 'แอปเปิล',
      nameEn: 'apple',
      emoji: '🍎',
      category: _C.fruit,
      synonyms: ['แอปเปิ้ล'],
    ),

    // ---------- นม กะทิ ----------
    Ingredient(
      id: 'milk',
      nameTh: 'นมสด',
      nameEn: 'milk',
      emoji: '🥛',
      category: _C.dairy,
      synonyms: ['นม', 'นมจืด', 'นมวัว'],
    ),
    Ingredient(
      id: 'butter',
      nameTh: 'เนย',
      nameEn: 'butter',
      emoji: '🧈',
      category: _C.dairy,
      synonyms: ['เนยจืด', 'เนยเค็ม'],
    ),
    Ingredient(
      id: 'cheese',
      nameTh: 'ชีส',
      nameEn: 'cheese',
      emoji: '🧀',
      category: _C.dairy,
      synonyms: ['เชดดาร์ชีส', 'มอสซาเรลลาชีส'],
    ),
    Ingredient(
      id: 'coconut_milk',
      nameTh: 'กะทิ',
      nameEn: 'coconut milk',
      emoji: '🥥',
      category: _C.dairy,
      synonyms: ['หัวกะทิ', 'กะทิกล่อง', 'น้ำกะทิ'],
    ),

    // ---------- เครื่องปรุงที่ต้องซื้อเฉพาะ ----------
    Ingredient(
      id: 'curry_paste',
      nameTh: 'พริกแกง',
      nameEn: 'curry paste',
      emoji: '🥘',
      category: _C.seasoning,
      synonyms: ['พริกแกงเผ็ด', 'พริกแกงเขียวหวาน', 'พริกแกงแดง'],
    ),
    Ingredient(
      id: 'chili_paste',
      nameTh: 'น้ำพริกเผา',
      nameEn: 'chili paste',
      emoji: '🫙',
      category: _C.seasoning,
    ),
    Ingredient(
      id: 'tamarind',
      nameTh: 'มะขามเปียก',
      nameEn: 'tamarind',
      emoji: '🫙',
      category: _C.seasoning,
      synonyms: ['น้ำมะขามเปียก', 'น้ำมะขาม'],
    ),

    // ---------- เครื่องปรุงพื้นฐาน (ถือว่ามีในครัว) ----------
    Ingredient(
      id: 'fish_sauce',
      nameTh: 'น้ำปลา',
      nameEn: 'fish sauce',
      emoji: '🫙',
      category: _C.seasoning,
      pantry: true,
    ),
    Ingredient(
      id: 'soy_sauce',
      nameTh: 'ซีอิ๊วขาว',
      nameEn: 'soy sauce',
      emoji: '🫙',
      category: _C.seasoning,
      synonyms: ['ซีอิ๊ว', 'ซีอิ๊วดำ', 'ซอสถั่วเหลือง'],
      pantry: true,
    ),
    Ingredient(
      id: 'oyster_sauce',
      nameTh: 'ซอสหอยนางรม',
      nameEn: 'oyster sauce',
      emoji: '🫙',
      category: _C.seasoning,
      synonyms: ['น้ำมันหอย'],
      pantry: true,
    ),
    Ingredient(
      id: 'seasoning_sauce',
      nameTh: 'ซอสปรุงรส',
      nameEn: 'seasoning sauce',
      emoji: '🫙',
      category: _C.seasoning,
      synonyms: ['แม็กกี้'],
      pantry: true,
    ),
    Ingredient(
      id: 'sugar',
      nameTh: 'น้ำตาล',
      nameEn: 'sugar',
      emoji: '🍬',
      category: _C.seasoning,
      synonyms: ['น้ำตาลทราย', 'น้ำตาลปี๊บ', 'น้ำตาลมะพร้าว', 'น้ำตาลเล็กน้อย'],
      pantry: true,
    ),
    Ingredient(
      id: 'salt',
      nameTh: 'เกลือ',
      nameEn: 'salt',
      emoji: '🧂',
      category: _C.seasoning,
      synonyms: ['เกลือป่น'],
      pantry: true,
    ),
    Ingredient(
      id: 'pepper',
      nameTh: 'พริกไทย',
      nameEn: 'pepper',
      emoji: '🧂',
      category: _C.seasoning,
      synonyms: ['พริกไทยป่น', 'พริกไทยดำ'],
      pantry: true,
    ),
    Ingredient(
      id: 'oil',
      nameTh: 'น้ำมันพืช',
      nameEn: 'cooking oil',
      emoji: '🫗',
      category: _C.seasoning,
      synonyms: ['น้ำมัน', 'น้ำมันรำข้าว', 'น้ำมันถั่วเหลือง'],
      pantry: true,
    ),
    Ingredient(
      id: 'water',
      nameTh: 'น้ำเปล่า',
      nameEn: 'water',
      emoji: '💧',
      category: _C.seasoning,
      synonyms: ['น้ำ'],
      pantry: true,
    ),
    Ingredient(
      id: 'stock',
      nameTh: 'น้ำซุป',
      nameEn: 'stock',
      emoji: '🍲',
      category: _C.seasoning,
      synonyms: ['น้ำสต็อก', 'ซุปก้อน', 'น้ำเปล่าหรือน้ำซุป'],
      pantry: true,
    ),
  ];

  static final Map<String, Ingredient> _byId = {for (final i in all) i.id: i};

  static final Map<String, Ingredient> _byName = {
    for (final i in all)
      for (final n in [...i.allNames, i.nameEn, i.id]) normalize(n): i,
  };

  static Ingredient? byId(String id) => _byId[id.trim().toLowerCase()];

  /// จับคู่ชื่อ (ไทย/อังกฤษ/id) กับวัตถุดิบในฐานข้อมูล แบบตรงทั้งคำหลังตัดช่องว่าง
  static Ingredient? resolve(String? name) {
    if (name == null) return null;
    final key = normalize(name);
    if (key.isEmpty) return null;
    return _byName[key];
  }

  /// ทำให้ชื่อเทียบกันได้: ตัวเล็ก ไม่มีช่องว่าง/อักขระควบคุม/zero-width, "_" = ช่องว่าง
  static String normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s_​‌‍﻿\u0000-\u001f]'), '');

  /// วัตถุดิบที่ผู้ใช้เลือกได้ (ไม่รวมเครื่องปรุงพื้นฐาน)
  static List<Ingredient> get selectable => [
    for (final i in all)
      if (!i.pantry) i,
  ];

  /// ค้นหาวัตถุดิบจากคำบางส่วน (ใช้กับ autocomplete — ไม่ใช่การจับคู่สูตร)
  static List<Ingredient> search(String query, {bool includePantry = false}) {
    final q = normalize(query);
    if (q.isEmpty) return const [];
    final starts = <Ingredient>[];
    final contains = <Ingredient>[];
    for (final i in all) {
      if (i.pantry && !includePantry) continue;
      final names = [...i.allNames, i.nameEn].map(normalize);
      if (names.any((n) => n.startsWith(q))) {
        starts.add(i);
      } else if (names.any((n) => n.contains(q))) {
        contains.add(i);
      }
    }
    return [...starts, ...contains];
  }
}
