import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../barcodes/barcodes_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../movements/movements_screen.dart';
import '../products/product_form_screen.dart';
import '../products/products_screen.dart';
import '../scanner/scanner_screen.dart';
import '../stock_count/stock_count_screen.dart';
import '../users/users_screen.dart';
import '../warehouses/transfer_screen.dart';
import '../warehouses/warehouses_screen.dart';

class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  int _selectedIndex = 0;
  bool _sidebarCollapsed = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard', activeIcon: Icons.dashboard_rounded),
    _NavItem(icon: Icons.widgets_outlined, label: 'Ürünler', activeIcon: Icons.widgets_rounded),
    _NavItem(icon: Icons.qr_code_2_outlined, label: 'Barkodlar', activeIcon: Icons.qr_code_2_rounded),
    _NavItem(icon: Icons.warehouse_outlined, label: 'Depolar', activeIcon: Icons.warehouse_rounded),
    _NavItem(icon: Icons.swap_horiz_outlined, label: 'Transfer', activeIcon: Icons.swap_horiz_rounded),
    _NavItem(icon: Icons.history_outlined, label: 'Stok Hareketleri', activeIcon: Icons.history_rounded),
    _NavItem(icon: Icons.fact_check_outlined, label: 'Sayım', activeIcon: Icons.fact_check_rounded),
    _NavItem(icon: Icons.qr_code_scanner_outlined, label: 'Barkod Okuyucu', activeIcon: Icons.qr_code_scanner_rounded),
    _NavItem(icon: Icons.local_shipping_outlined, label: 'Tedarikçiler', activeIcon: Icons.local_shipping_rounded, isComingSoon: true),
    _NavItem(icon: Icons.shopping_cart_outlined, label: 'Satın Alma', activeIcon: Icons.shopping_cart_rounded, isComingSoon: true),
    _NavItem(icon: Icons.precision_manufacturing_outlined, label: 'Üretim', activeIcon: Icons.precision_manufacturing_rounded, isComingSoon: true),
    _NavItem(icon: Icons.bar_chart_outlined, label: 'Raporlar', activeIcon: Icons.bar_chart_rounded, isComingSoon: true),
    _NavItem(icon: Icons.group_outlined, label: 'Kullanıcılar', activeIcon: Icons.group_rounded),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Widget _buildScreen(int index) {
    return switch (index) {
      0 => const DashboardScreen(),
      1 => ProductsScreen(searchQuery: _searchQuery),
      2 => const BarcodesScreen(),
      3 => const WarehousesScreen(),
      4 => const TransferScreen(),
      5 => const MovementsScreen(),
      6 => const StockCountScreen(),
      7 => const ScannerScreen(),
      8 || 9 || 10 || 11 => const _ComingSoonScreen(),
      12 => const UsersScreen(),
      _ => const DashboardScreen(),
    };
  }

  void _navigate(int idx) {
    if (_navItems[idx].isComingSoon) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_navItems[idx].label} modülü yakında eklenecek.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E2333),
        ),
      );
      return;
    }
    setState(() => _selectedIndex = idx);
  }

  void _handleGlobalSearch() {
    if (_selectedIndex != 1) setState(() => _selectedIndex = 1);
    _searchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.f2): const _NavIntent(7),
        LogicalKeySet(LogicalKeyboardKey.f3): const _StockInIntent(),
        LogicalKeySet(LogicalKeyboardKey.f4): const _StockOutIntent(),
        LogicalKeySet(LogicalKeyboardKey.f5): const _NavIntent(4),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
            const _SearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN):
            const _NewProductIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const _EscapeIntent(),
      },
      child: Actions(
        actions: {
          _NavIntent: CallbackAction<_NavIntent>(
            onInvoke: (i) {
              _navigate(i.index);
              return null;
            },
          ),
          _SearchIntent: CallbackAction<_SearchIntent>(
            onInvoke: (_) {
              _handleGlobalSearch();
              return null;
            },
          ),
          _NewProductIntent: CallbackAction<_NewProductIntent>(
            onInvoke: (_) {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ProductFormScreen()),
              );
              return null;
            },
          ),
          _StockInIntent: CallbackAction<_StockInIntent>(
            onInvoke: (_) {
              _navigate(7); // scanner for quick stock in
              return null;
            },
          ),
          _StockOutIntent: CallbackAction<_StockOutIntent>(
            onInvoke: (_) {
              _navigate(7); // scanner for quick stock out
              return null;
            },
          ),
          _EscapeIntent: CallbackAction<_EscapeIntent>(
            onInvoke: (_) {
              if (Navigator.canPop(context)) Navigator.pop(context);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: const Color(0xFF0B0D12),
            body: Row(
              children: [
                // ── SIDEBAR ────────────────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  width: _sidebarCollapsed ? 60 : 220,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D1017),
                    border: Border(
                      right: BorderSide(color: Color(0xFF1A1E2A), width: 1),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Logo / Header
                      Container(
                        height: 60,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/logo.png',
                              width: 32,
                              height: 32,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.bolt_rounded,
                                  color: Color(0xFFF58220),
                                  size: 28),
                            ),
                            if (!_sidebarCollapsed) ...[
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'BITRONIX',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Divider(
                          height: 1, color: Color(0xFF1A1E2A)),
                      const SizedBox(height: 8),

                      // Nav items
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          itemCount: _navItems.length,
                          itemBuilder: (context, index) {
                            // Section divider before Tedarikçiler
                            if (index == 8) {
                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                    child: Divider(
                                        height: 1,
                                        color: const Color(0xFF1A1E2A)),
                                  ),
                                  _SidebarItem(
                                    item: _navItems[index],
                                    isSelected: _selectedIndex == index,
                                    collapsed: _sidebarCollapsed,
                                    onTap: () => _navigate(index),
                                  ),
                                ],
                              );
                            }
                            return _SidebarItem(
                              item: _navItems[index],
                              isSelected: _selectedIndex == index,
                              collapsed: _sidebarCollapsed,
                              onTap: () => _navigate(index),
                            );
                          },
                        ),
                      ),

                      const Divider(height: 1, color: Color(0xFF1A1E2A)),

                      // User profile section
                      if (!_sidebarCollapsed) ...[
                        const SizedBox(height: 8),
                        _UserProfileTile(),
                        const SizedBox(height: 4),
                      ],

                      // Collapse toggle
                      InkWell(
                        onTap: () => setState(
                            () => _sidebarCollapsed = !_sidebarCollapsed),
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            _sidebarCollapsed
                                ? Icons.chevron_right_rounded
                                : Icons.chevron_left_rounded,
                            color: const Color(0xFF64748B),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                // ── MAIN CONTENT ───────────────────────────────────────
                Expanded(
                  child: Column(
                    children: [
                      // Top Header
                      Container(
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0D1017),
                          border: Border(
                            bottom: BorderSide(
                                color: Color(0xFF1A1E2A), width: 1),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            // Breadcrumb title
                            Text(
                              _navItems[_selectedIndex].label,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                            const Spacer(),

                            // Global search (Ctrl+K)
                            SizedBox(
                              width: 280,
                              height: 36,
                              child: TextField(
                                controller: _searchCtrl,
                                focusNode: _searchFocus,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                                onChanged: (v) =>
                                    setState(() => _searchQuery = v),
                                onTap: _handleGlobalSearch,
                                decoration: InputDecoration(
                                  hintText: 'Ara...  Ctrl+K',
                                  hintStyle: const TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 12),
                                  prefixIcon: const Icon(Icons.search_rounded,
                                      color: Color(0xFF475569), size: 18),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded,
                                              size: 16,
                                              color: Color(0xFF64748B)),
                                          onPressed: () => setState(() {
                                            _searchCtrl.clear();
                                            _searchQuery = '';
                                          }),
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: const Color(0xFF12151E),
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 0),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF1A1E2A)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF1A1E2A)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFF58220), width: 1.5),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Keyboard shortcuts tooltip
                            Tooltip(
                              message:
                                  'F2: Barkod Okuyucu\nF3: Stok Giriş\nF4: Stok Çıkış\nF5: Transfer\nCtrl+K: Arama\nCtrl+N: Yeni Ürün\nEsc: Kapat',
                              textStyle: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF12151E),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFF262C3D)),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF12151E),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFF1A1E2A)),
                                ),
                                child: const Icon(Icons.keyboard_rounded,
                                    color: Color(0xFF64748B), size: 18),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Logout button
                            IconButton(
                              tooltip: 'Çıkış Yap',
                              icon: const Icon(Icons.logout_rounded,
                                  color: Color(0xFF64748B), size: 20),
                              onPressed: () async {
                                await FirebaseAuth.instance.signOut();
                              },
                            ),
                          ],
                        ),
                      ),

                      // Page content
                      Expanded(
                        child: IndexedStack(
                          index: _selectedIndex,
                          children:
                              List.generate(_navItems.length, _buildScreen),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sidebar Item ─────────────────────────────────────────────────────────────

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.isSelected,
    required this.collapsed,
    required this.onTap,
  });

  final _NavItem item;
  final bool isSelected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: collapsed ? item.label : '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : 12, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFF58220).withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFF58220).withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: collapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                isSelected ? item.activeIcon : item.icon,
                size: 19,
                color: isSelected
                    ? const Color(0xFFF58220)
                    : item.isComingSoon
                        ? const Color(0xFF374151)
                        : const Color(0xFF94A3B8),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : item.isComingSoon
                              ? const Color(0xFF374151)
                              : const Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (item.isComingSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1E2A),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Yakında',
                        style: TextStyle(
                            color: Color(0xFF374151),
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── User Profile Tile ────────────────────────────────────────────────────────

class _UserProfileTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final user = FirebaseAuth.instance.currentUser;

    final name = profileAsync.whenOrNull(
          data: (p) => p?.name,
        ) ??
        user?.email?.split('@').first ??
        'Kullanıcı';

    final role = profileAsync.whenOrNull(
          data: (p) => p?.role.label,
        ) ??
        '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF12151E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor:
                  const Color(0xFFF58220).withValues(alpha: 0.2),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Color(0xFFF58220),
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  if (role.isNotEmpty)
                    Text(role,
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 10),
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Coming Soon ─────────────────────────────────────────────────────────────

class _ComingSoonScreen extends StatelessWidget {
  const _ComingSoonScreen();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_rounded,
                size: 64,
                color: const Color(0xFF262C3D)),
            const SizedBox(height: 16),
            const Text('Bu modül yakında geliyor.',
                style: TextStyle(
                    color: Color(0xFF64748B), fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
              'BOM, Satın Alma, Tedarikçi ve Üretim modülleri\n bir sonraki geliştirme fazında eklenecek.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF374151), fontSize: 13),
            ),
          ],
        ),
      );
}

// ─── Data ─────────────────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.activeIcon,
    this.isComingSoon = false,
  });

  final IconData icon, activeIcon;
  final String label;
  final bool isComingSoon;
}

// ─── Intents & Actions (Keyboard Shortcuts) ───────────────────────────────────

class _NavIntent extends Intent {
  const _NavIntent(this.index);
  final int index;
}

class _SearchIntent extends Intent {
  const _SearchIntent();
}

class _NewProductIntent extends Intent {
  const _NewProductIntent();
}

class _StockInIntent extends Intent {
  const _StockInIntent();
}

class _StockOutIntent extends Intent {
  const _StockOutIntent();
}

class _EscapeIntent extends Intent {
  const _EscapeIntent();
}
