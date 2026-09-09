import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isSearching = false;
  Product? _scannedProduct;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Auto focus the input field so USB Barcode Scanners work immediately upon opening screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _processBarcode(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty || _isSearching) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _scannedProduct = null;
    });

    try {
      final p =
          await ref.read(stockRepositoryProvider)!.findByCode(cleanCode);
      if (!mounted) return;

      if (p == null) {
        setState(() {
          _errorMessage = 'Barkod veya SKU "$cleanCode" ile eşleşen ürün bulunamadı.';
          _isSearching = false;
        });
      } else {
        setState(() {
          _scannedProduct = p;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Arama hatası: $e';
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF12151E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E2333)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF58220).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Color(0xFFF58220),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'USB Barkod Okuyucu & Hızlı Arama',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'USB El terminali veya klavye ile barkod Okutun/yazın ve Enter’a basın',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Barcode Input Field
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            focusNode: _focusNode,
                            autofocus: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                            onSubmitted: _processBarcode,
                            decoration: InputDecoration(
                              hintText: 'Barkod veya SKU girin / okutun...',
                              hintStyle: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 14,
                                fontFamily: 'sans-serif',
                                fontWeight: FontWeight.normal,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF0B0D12),
                              prefixIcon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFFF58220)),
                              suffixIcon: _codeController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, color: Color(0xFF64748B)),
                                      onPressed: () {
                                        _codeController.clear();
                                        setState(() {
                                          _scannedProduct = null;
                                          _errorMessage = null;
                                        });
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF262C3D)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF262C3D)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFF58220), width: 2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isSearching
                              ? null
                              : () => _processBarcode(_codeController.text),
                          icon: _isSearching
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.search, size: 18),
                          label: const Text('Ürün Bul'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF58220),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Error State
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // Product Result Card & Instant Stock Actions
              if (_scannedProduct != null)
                _ScannedProductCard(
                  product: _scannedProduct!,
                  onStockUpdated: () {
                    // Refetch product
                    _processBarcode(_scannedProduct!.barcode ?? _scannedProduct!.sku);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannedProductCard extends ConsumerStatefulWidget {
  const _ScannedProductCard({
    required this.product,
    required this.onStockUpdated,
  });

  final Product product;
  final VoidCallback onStockUpdated;

  @override
  ConsumerState<_ScannedProductCard> createState() =>
      _ScannedProductCardState();
}

class _ScannedProductCardState extends ConsumerState<_ScannedProductCard> {
  bool _isBusy = false;

  Future<void> _adjust(num delta) async {
    setState(() => _isBusy = true);
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'desktop_user';

    try {
      await ref.read(stockRepositoryProvider)!.adjustStock(
        product: widget.product,
        quantity: delta,
        type: delta > 0 ? MovementType.stockIn : MovementType.stockOut,
        userId: userId,
        reason: 'Hızlı Masaüstü Barkod İşlemi',
      );
      widget.onStockUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SKU: ${p.sku} | Barkod: ${p.barcode ?? '-'}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Mevcut Stok',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                  Text(
                    '${p.stock} ${p.unit}',
                    style: TextStyle(
                      color: p.isCritical ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFF1E2333), height: 1),
          const SizedBox(height: 20),

          const Text(
            'Hızlı Stok Değişimi',
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionButton(
                label: '+1 Ekle',
                color: const Color(0xFF10B981),
                isBusy: _isBusy,
                onPressed: () => _adjust(1),
              ),
              _ActionButton(
                label: '+5 Ekle',
                color: const Color(0xFF10B981),
                isBusy: _isBusy,
                onPressed: () => _adjust(5),
              ),
              _ActionButton(
                label: '+10 Ekle',
                color: const Color(0xFF10B981),
                isBusy: _isBusy,
                onPressed: () => _adjust(10),
              ),
              _ActionButton(
                label: '-1 Çıkar',
                color: const Color(0xFFEF4444),
                isBusy: _isBusy,
                onPressed: () => _adjust(-1),
              ),
              _ActionButton(
                label: '-5 Çıkar',
                color: const Color(0xFFEF4444),
                isBusy: _isBusy,
                onPressed: () => _adjust(-5),
              ),
              _ActionButton(
                label: '-10 Çıkar',
                color: const Color(0xFFEF4444),
                isBusy: _isBusy,
                onPressed: () => _adjust(-10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.isBusy,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isBusy ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }
}
