import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../favorites/favorites_screen.dart';
import '../history/history_screen.dart';
import '../scan/scan_screen.dart';
import '../shopping/shopping_screen.dart';

/// ลำดับแท็บของแถบนำทางล่าง
abstract final class ShellTab {
  static const scan = 0;
  static const history = 1;
  static const favorites = 2;
  static const shopping = 3;
}

/// แท็บที่เปิดอยู่ — หน้าที่ push ซ้อนอยู่ใช้สลับแท็บได้ (เช่น "ดูรายการซื้อของ")
final ValueNotifier<int> shellTab = ValueNotifier(ShellTab.scan);

/// ปิดหน้าที่ซ้อนอยู่ทั้งหมดแล้วไปยังแท็บ [tab]
void goToShellTab(BuildContext context, int tab) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  shellTab.value = tab;
}

/// โครงหลักของแอป: แถบนำทางล่าง 4 แท็บ (สแกน · ประวัติ · เมนูโปรด · ซื้อของ)
/// - IndexedStack เก็บสถานะของแต่ละแท็บไว้ (รูปที่เลือก, ตำแหน่งเลื่อน)
/// - ปุ่มย้อนกลับของระบบ: จากแท็บอื่นกลับไปแท็บสแกนก่อน แล้วค่อยออกจากแอป
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    shellTab.value = ShellTab.scan;
    shellTab.addListener(_onTab);
  }

  @override
  void dispose() {
    shellTab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() => setState(() {});

  void _go(int i) {
    if (i == shellTab.value) return;
    AppScope.read(context).settings.selection();
    shellTab.value = i;
  }

  @override
  Widget build(BuildContext context) {
    final index = shellTab.value;
    final toBuy = AppScope.of(context).shopping.remaining;
    return PopScope(
      canPop: index == ShellTab.scan,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(ShellTab.scan);
      },
      child: Scaffold(
        body: IndexedStack(
          index: index,
          children: [
            ScanScreen(onOpenTab: _go),
            HistoryScreen(onStartScan: () => _go(ShellTab.scan)),
            const FavoritesScreen(),
            const ShoppingScreen(),
          ],
        ),
        bottomNavigationBar: MediaQuery.withClampedTextScaling(
          // แถบล่างสูงคงที่ จำกัดการขยายตัวอักษรของป้ายกำกับ
          maxScaleFactor: 1.2,
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: _go,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.photo_camera_outlined),
                selectedIcon: Icon(Icons.photo_camera),
                label: 'สแกน',
              ),
              const NavigationDestination(
                icon: Icon(Icons.history),
                selectedIcon: Icon(Icons.history),
                label: 'ประวัติ',
              ),
              const NavigationDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite),
                label: 'เมนูโปรด',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: toBuy > 0,
                  label: Text('$toBuy'),
                  child: const Icon(Icons.shopping_basket_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: toBuy > 0,
                  label: Text('$toBuy'),
                  child: const Icon(Icons.shopping_basket),
                ),
                label: 'ซื้อของ',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
