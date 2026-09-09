import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../movements/movements_screen.dart';
import '../finance/finance_screen.dart';
import '../products/product_detail_screen.dart';
import '../products/product_form_screen.dart';
import '../products/products_screen.dart';
import '../scanner/scanner_screen.dart';
import '../stock_count/stock_count_screen.dart';
import '../warehouses/transfer_screen.dart';
import '../warehouses/warehouses_screen.dart';
import '../workspace/workspace_settings_screen.dart';

class MobileShell extends ConsumerStatefulWidget {
  const MobileShell({super.key});

  @override
  ConsumerState<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<MobileShell> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final canViewFinance = ref
            .watch(currentMembershipProvider)
            .whenOrNull(data: (m) => m?.canViewFinancials) ??
        false;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1017),
        elevation: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              width: 26,
              height: 26,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.bolt_rounded,
                color: Color(0xFFF58220),
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'BITRONIX',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          if (canViewFinance)
            IconButton(
              tooltip: 'Finans',
              icon: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Color(0xFFF58220),
                size: 20,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FinanceScreen()),
              ),
            ),
          IconButton(
            tooltip: 'Barkod / QR Tara',
            icon: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Color(0xFFF58220),
              size: 20,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const _CameraScanModal()),
              );
            },
          ),
          IconButton(
            tooltip: 'Çalışma Alanı',
            icon: const Icon(
              Icons.settings_outlined,
              color: Color(0xFF64748B),
              size: 20,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const WorkspaceSettingsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Çıkış Yap',
            icon: const Icon(
              Icons.logout_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          _MobileHomeScreen(),
          ProductsScreen(),
          MovementsScreen(),
          WarehousesScreen(),
          StockCountScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1017),
          border: Border(top: BorderSide(color: Color(0xFF1A1E2A))),
        ),
        child: BottomNavigationBar(
          currentIndex: _tabIndex,
          onTap: (i) => setState(() => _tabIndex = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFFF58220),
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Ana Ekran',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.widgets_outlined),
              activeIcon: Icon(Icons.widgets_rounded),
              label: 'Ürünler',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history_rounded),
              label: 'Hareketler',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.warehouse_outlined),
              activeIcon: Icon(Icons.warehouse_rounded),
              label: 'Depolar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fact_check_outlined),
              activeIcon: Icon(Icons.fact_check_rounded),
              label: 'Sayım',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mobile Home Screen (Operation-Focused) ───────────────────────────────────

class _MobileHomeScreen extends ConsumerWidget {
  const _MobileHomeScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final movementsAsync = ref.watch(recentMovementsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── BIG "BARKOD TARA" BUTTON ────────────────────────────────────────
          _BigScanButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const _CameraScanModal()),
              );
            },
          ),
          const SizedBox(height: 16),

          // ── QUICK ACTIONS GRID ──────────────────────────────────────────────
          const Text(
            'Hızlı İşlemler',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Stok Girişi',
                  color: const Color(0xFF10B981),
                  onTap: () =>
                      _openQuickStockDialog(context, ref, isStockIn: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.remove_circle_outline_rounded,
                  label: 'Stok Çıkışı',
                  color: const Color(0xFFEF4444),
                  onTap: () =>
                      _openQuickStockDialog(context, ref, isStockIn: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Transfer',
                  color: const Color(0xFF3B82F6),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TransferScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.add_box_outlined,
                  label: 'Ürün Ekle',
                  color: const Color(0xFFF58220),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProductFormScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.fact_check_outlined,
                  label: 'Depo Sayımı',
                  color: const Color(0xFF8B5CF6),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StockCountScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.qr_code_2_rounded,
                  label: 'Barkod Okuyucu',
                  color: const Color(0xFF06B6D4),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScannerScreen()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── KRİTİK STOK UYARILARI ───────────────────────────────────────────
          productsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
            data: (products) {
              final criticals = products
                  .where((p) => p.isCritical || p.isLow)
                  .toList();
              if (criticals.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFEF4444),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Kritik Stok Uyarısı (${criticals.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: criticals.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 10),
                      itemBuilder: (ctx, i) {
                        final p = criticals[i];
                        final isOut = p.isOutOfStock;
                        final color = isOut
                            ? const Color(0xFF64748B)
                            : p.isCritical
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFF59E0B);
                        return InkWell(
                          onTap: () => Navigator.push(
                            ctx,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(product: p),
                            ),
                          ),
                          child: Container(
                            width: 160,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: color.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${p.stock} ${p.unit}',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),

          // ── SON STOK HAREKETLERİ ────────────────────────────────────────────
          const Text(
            'Son Stok Hareketleri',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          movementsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Color(0xFFF58220)),
              ),
            ),
            error: (e, _) =>
                Text('$e', style: const TextStyle(color: Colors.redAccent)),
            data: (movements) {
              if (movements.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF12151E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E2333)),
                  ),
                  child: const Text(
                    'Henüz hareket kaydedilmedi.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                );
              }
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF12151E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E2333)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: movements.take(6).length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: Color(0xFF1E2333), height: 1),
                  itemBuilder: (ctx, i) {
                    final m = movements[i];
                    final isPos = m.quantity > 0;
                    final color = isPos
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444);
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Icon(
                          isPos
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          color: color,
                          size: 14,
                        ),
                      ),
                      title: Text(
                        m.productName.isNotEmpty ? m.productName : m.productId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      subtitle: Text(
                        m.type.displayLabel,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                      trailing: Text(
                        '${isPos ? '+' : ''}${m.quantity}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openQuickStockDialog(
    BuildContext context,
    WidgetRef ref, {
    required bool isStockIn,
  }) {
    final codeCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161922),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF262C3D)),
        ),
        title: Row(
          children: [
            Icon(
              isStockIn
                  ? Icons.add_circle_outline_rounded
                  : Icons.remove_circle_outline_rounded,
              color: isStockIn
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
            ),
            const SizedBox(width: 8),
            Text(
              isStockIn ? 'Hızlı Stok Girişi' : 'Hızlı Stok Çıkışı',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Barkod veya SKU',
                labelStyle: TextStyle(color: Color(0xFF64748B)),
                filled: true,
                fillColor: Color(0xFF0B0D12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Miktar',
                labelStyle: TextStyle(color: Color(0xFF64748B)),
                filled: true,
                fillColor: Color(0xFF0B0D12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'İptal',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isStockIn
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(ctx);
              final code = codeCtrl.text.trim();
              final qty = num.tryParse(qtyCtrl.text) ?? 0;
              if (code.isEmpty || qty <= 0) return;

              final repo = ref.read(stockRepositoryProvider)!;
              final product = await repo.findByCode(code);
              if (product == null) {
                messenger.showSnackBar(
                  SnackBar(content: Text('"$code" kodlu ürün bulunamadı.')),
                );
                return;
              }

              final user = FirebaseAuth.instance.currentUser;
              final delta = isStockIn ? qty : -qty;

              await repo.adjustStock(
                product: product,
                quantity: delta,
                type: isStockIn ? MovementType.stockIn : MovementType.stockOut,
                userId: user?.uid ?? 'unknown',
                userName: user?.email,
                reason: 'Mobil Hızlı İşlem',
              );

              nav.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    '${product.name}: ${isStockIn ? '+' : ''}$delta adet işlendi.',
                  ),
                ),
              );
            },
            child: const Text('Uygula'),
          ),
        ],
      ),
    );
  }
}

// ─── Camera Scan Modal ────────────────────────────────────────────────────────

class _CameraScanModal extends ConsumerStatefulWidget {
  const _CameraScanModal();

  @override
  ConsumerState<_CameraScanModal> createState() => _CameraScanModalState();
}

class _CameraScanModalState extends ConsumerState<_CameraScanModal> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Barkod / QR Kamera'),
      ),
      body: MobileScanner(
        onDetect: (capture) async {
          if (_handled) return;
          final barcodes = capture.barcodes;
          if (barcodes.isEmpty) return;
          final code = barcodes.first.rawValue;
          if (code == null || code.trim().isEmpty) return;

          final nav = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);

          setState(() => _handled = true);
          final repo = ref.read(stockRepositoryProvider)!;
          final product = await repo.findByCode(code.trim());

          if (!mounted) return;
          nav.pop();

          if (product == null) {
            messenger.showSnackBar(
              SnackBar(content: Text('"$code" barkodlu ürün bulunamadı.')),
            );
          } else {
            nav.push(
              MaterialPageRoute(
                builder: (ctx) => ProductDetailScreen(product: product),
              ),
            );
          }
        },
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _BigScanButton extends StatelessWidget {
  const _BigScanButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 70,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 28),
        label: const Text(
          'BARKOD TARA',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF58220),
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: const Color(0xFFF58220).withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF12151E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E2333)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
