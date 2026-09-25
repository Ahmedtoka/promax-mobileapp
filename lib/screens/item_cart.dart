import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../brand.dart';
import '../l10n.dart';
import '../models.dart';
import 'multi_item_picker.dart';

/// ═══════════════════════════════════════════════════════════════
/// اختيار الأصناف — مشترك بين البيع والمرتجع
/// ═══════════════════════════════════════════════════════════════
///
/// الفلو اللي المالك طلبه (2026-08-12) — بدل البحث صنف بصنف:
///   1. دوسة على خانة البحث بتفتح **كل** الأصناف بتشيك بوكس
///   2. يعلّم على اللي عايزه ويدوس «إضافة (X)» — كلهم ينزلوا سطور
///   3. كل سطر: كمية (كتابة أو +/-) + وحدة + سعر محسوب + حذف
///
/// نفس الودجت للبيع (بحد المتبقي) والمرتجع (من غير حد).
class ItemCart extends StatefulWidget {
  /// كتالوج الأصناف (مدموج بالصنف — `Custody.byProduct`)
  final List<CustodyItem> catalog;

  /// الكميات المختارة — ملك الشاشة الأم عشان تحسب الإجماليات.
  /// ⚠️ الكمية **بوحدة السطر** (2 كرتونة = 2) — مش بالقطع.
  final Map<int, int> qty;

  /// وحدة كل سطر (piece/box/case) — ملك الشاشة الأم عشان تبعتها للسيرفر
  final Map<int, String> units;
  final VoidCallback onChanged;

  /// البيع بيقف عند المتبقي؛ المرتجع مفتوح
  final bool limitToRemaining;
  final Color accent;

  /// أسعار قايمة العميل — productId ← سعر.
  ///
  /// ⚠️ **الودجت دي مشتركة بين البيع والمرتجع**، والاتنين بيعرضوا
  /// سعر للمندوب وهو واقف قدام العميل. سعر `CustodyItem.price`
  /// استرشادي (قايمة مشتقة من رول المندوب) — لو الشاشة الأم عندها
  /// أسعار العميل بتبعتها هنا عشان الرقم المعروض = رقم الفاتورة.
  final Map<int, double> priceOverride;

  const ItemCart({
    super.key,
    required this.catalog,
    required this.qty,
    required this.units,
    required this.onChanged,
    required this.limitToRemaining,
    required this.accent,
    this.priceOverride = const {},
  });

  double priceOf(CustodyItem i) => priceOverride[i.productId] ?? i.price;

  @override
  State<ItemCart> createState() => _ItemCartState();
}

class _ItemCartState extends State<ItemCart> {
  final Map<int, TextEditingController> _qtyCtrl = {};

  /// ترتيب اللاينات زي ما اتضافت — مش بترتيب الكتالوج
  final List<int> _order = [];

  @override
  void dispose() {
    for (final c in _qtyCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ⚠️ الديفولت الموحّد (٩ أغسطس): علبة لو موجودة وإلا قطعة
  String _unitOf(CustodyItem i) => widget.units[i.productId] ?? i.defaultUnit;

  /// مضاعِف وحدة السطر بالقطع — العرض والحدود بس، الضرب الحقيقي في السيرفر
  int _factor(CustodyItem i) => i.factorOf(_unitOf(i));

  /// الحد الأقصى **بوحدة السطر**: متبقي 100 قطعة ووحدة كرتونة (12) → 8
  int _maxFor(CustodyItem i) =>
      widget.limitToRemaining ? i.remaining ~/ _factor(i) : 9999;

  void _setUnit(CustodyItem i, String unit) {
    final prev = _unitOf(i);
    widget.units[i.productId] = unit;

    // ⚠️ المتبقي أقل من الوحدة الجديدة؟ نرجع للوحدة القديمة بدل ما
    // الكمية تتصفّر واللاين يختفي والمندوب مايعرفش السبب.
    if (widget.limitToRemaining && _maxFor(i) == 0) {
      widget.units[i.productId] = prev;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.t('unit_no_stock'))));
      return;
    }

    // الكمية المكتوبة بوحدة قديمة ممكن تبقى أكبر من حد الوحدة الجديدة
    final q = widget.qty[i.productId] ?? 0;
    final max = _maxFor(i);

    if (q > max) {
      _setQty(i, max); // بيعمل setState + onChanged جواه
    } else {
      setState(() {});
      widget.onChanged();
    }
  }

  TextEditingController _ctrlFor(CustodyItem i) =>
      _qtyCtrl.putIfAbsent(i.productId,
          () => TextEditingController(text: '${widget.qty[i.productId] ?? 0}'));

  void _setQty(CustodyItem i, int v) {
    final clamped = v.clamp(0, _maxFor(i));
    setState(() {
      widget.qty[i.productId] = clamped;
      // ⚠️ **الديفولت بيتكتب في الخريطة مش بيتساب فولباك** — الشاشة
      // بتحسب بـ`defaultUnit` والإرسال في `Session` فولباكه `piece`؛
      // لو الخريطة فضلت فاضية والمندوب ماغيّرش الوحدة، الشاشة تقول
      // «٢ علبة» والسيرفر يسجّل «٢ قطعة». الكتابة هنا بتوحّدهم.
      widget.units.putIfAbsent(i.productId, () => i.defaultUnit);
      if (clamped > 0 && !_order.contains(i.productId)) {
        _order.add(i.productId);
      }
      if (clamped == 0) _order.remove(i.productId);

      final c = _ctrlFor(i);
      if (c.text != '$clamped') {
        c.text = '$clamped';
        c.selection = TextSelection.collapsed(offset: c.text.length);
      }
    });
    widget.onChanged();
  }

  /// المنتقي المتعدد — دوسة على خانة البحث بتفتح كل الأصناف
  /// بتشيك بوكس، والنتيجة بتترجم لسطور: الجديد بينزل بكمية ١
  /// ووحدته الديفولت، واللي اتشالت علامته سطره بيتشال.
  Future<void> _openPicker() async {
    // ⚠️ **الصنف اللي متاحه صفر مابيظهرش خالص** (قرار المالك 2026-08-08)
    // — بيتطبق بس لما الشاشة محدودة (`limitToRemaining`): البيع محدود
    // بالمتبقي في العربية، والمرتجع محدود باللي العميل اشتراه فعلاً
    // (returnable بيحط المتاح للرد في assigned).
    final items = widget.catalog
        .where((i) => !widget.limitToRemaining || i.remaining > 0)
        .toList();

    final entries = <PickEntry>[
      for (final i in items)
        PickEntry(
          id: i.productId,
          name: i.name,
          code: i.code,
          image: i.image,
          // ⚠️ السعر بس من غير الوحدة/الوزن (طلب المالك ٢٠/٨) —
          // الوزن أصلاً جوه اسم الصنف، وتكراره كان زحمة
          subtitle: money(widget.priceOf(i)),
          badge: widget.limitToRemaining
              ? L.t('available_n', {'n': '${i.remaining}'})
              : null,
          badgeBg: switch (i.remaining) {
            <= 0 => const Color(0xFFFDECEC),
            < 5 => const Color(0xFFFFF3E0),
            _ => const Color(0xFFE8F5EC),
          },
          badgeFg: switch (i.remaining) {
            <= 0 => Brand.red,
            < 5 => Brand.orange,
            _ => Brand.green,
          },
          searchText: '${i.nameAr} ${i.nameEn}',
        ),
    ];

    // اللي ليه سطر خلاص بيفتح متعلّم عليه — رحلة ذهاب وعودة
    final pre = <int>{
      for (final i in items)
        if ((widget.qty[i.productId] ?? 0) > 0) i.productId,
    };

    final res = await showMultiItemPicker(
      context,
      entries: entries,
      preSelected: pre,
      accent: widget.accent,
    );
    if (res == null || !mounted) return;

    for (final i in items) {
      final had = (widget.qty[i.productId] ?? 0) > 0;
      final want = res.contains(i.productId);

      if (want && !had) {
        // حزام أمان: وحدة قديمة أكبر من المتبقي كانت بتخلّي الإضافة
        // تتقفّل بصفر — نرجّعها قطعة قبل ما نضيف
        if (_maxFor(i) == 0 && _unitOf(i) != 'piece') {
          widget.units[i.productId] = 'piece';
        }
        _setQty(i, 1);
      } else if (!want && had) {
        _setQty(i, 0);
      }
    }
  }

  List<CustodyItem> get _lines => [
        for (final id in _order)
          for (final i in widget.catalog)
            if (i.productId == id && (widget.qty[id] ?? 0) > 0) i,
      ];

  /// صورة المنتج — أو أيقونة لو مفيش/فشل التحميل
  /// شارة «المتاح» — أكبر وملوّنة عشان تتقري من بعيد.
  ///
  /// ⚠️ **الرقم ده هو اللي بيمنع المندوب يبيع حاجة مش معاه.** كان
  /// مكتوب بنفس حجم ولون السعر في سطر رمادي واحد، فالمندوب بيدوّر
  /// عليه بعينه في كل صنف وبيكتب كمية أكبر من المتاح ويتفاجئ بالرفض.
  ///
  /// ⚠️ **تلات ألوان مش لونين**: الأحمر «خلاص» (صفر أو أقل)، البرتقالي
  /// «باقي قليل» (تحت 5)، الأخضر «مرتاح». التدرّج ده بيخلّي المندوب
  /// ياخد باله قبل ما يخلص مش بعد ما يخلص.
  Widget _avail(int left) {
    final (bg, fg) = switch (left) {
      <= 0 => (const Color(0xFFFDECEC), Brand.red),
      < 5 => (const Color(0xFFFFF3E0), Brand.orange),
      _ => (const Color(0xFFE8F5EC), Brand.green),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        L.t('available_n', {'n': '${left < 0 ? 0 : left}'}),
        // ⚠️ الرقم عربي والليبل عربي — من غير `textDirection` الرقم
        // بيتزحلق لآخر السطر في الواجهة العربية
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }

  Widget _thumb(CustodyItem i, {double size = 58}) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: size,
          height: size,
          child: i.image == null
              ? _thumbFallback(size)
              : Image.network(i.image!, cacheWidth: 800,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _thumbFallback(size),
                ),
        ),
      );

  Widget _thumbFallback(double size) => Container(
        color: const Color(0xFFF0EEE8),
        child: Icon(Icons.inventory_2_outlined,
            size: size * .5, color: Brand.muted),
      );

  @override
  Widget build(BuildContext context) {
    final lines = _lines;

    return Column(
      children: [
        // ═══ فتح المنتقي المتعدد — «دوس واختار كله مرة واحدة» ═══
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: PickerBox(onTap: _openPicker, accent: widget.accent),
        ),

        Expanded(
          // ═══ اللاينات المختارة ═══
          child: (lines.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.checklist_rounded,
                              size: 46, color: Brand.muted),
                          const SizedBox(height: 10),
                          Text(L.t('pick_then_qty_hint'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13, color: Brand.muted)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: lines.length,
                      itemBuilder: (context, idx) {
                        final i = lines[idx];
                        final q = widget.qty[i.productId] ?? 0;

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    _thumb(i, size: 58),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(i.name,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w800,
                                                  fontSize: 13)),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(
                                                  '${money(widget.priceOf(i))} / ${i.unit}',
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Brand.muted)),
                                              if (widget.limitToRemaining) ...[
                                                const SizedBox(width: 6),
                                                _avail(i.remaining -
                                                    q * _factor(i)),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: L.t('remove_line'),
                                      onPressed: () => _setQty(i, 0),
                                      icon: const Icon(
                                          Icons.delete_outline,
                                          size: 19,
                                          color: Color(0xFFB00020)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: q > 0
                                          ? () => _setQty(i, q - 1)
                                          : null,
                                      icon: const Icon(
                                          Icons.remove_circle_outline),
                                    ),
                                    SizedBox(
                                      width: 52,
                                      child: TextField(
                                        controller: _ctrlFor(i),
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(4),
                                        ],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                              EdgeInsets.symmetric(
                                                  vertical: 6),
                                          border: UnderlineInputBorder(),
                                        ),
                                        onChanged: (v) => _setQty(
                                            i, int.tryParse(v) ?? 0),
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: q < _maxFor(i)
                                          ? () => _setQty(i, q + 1)
                                          : null,
                                      icon: Icon(Icons.add_circle,
                                          color: widget.accent),
                                    ),
                                    // الوحدة: قطعة/علبة/كرتونة — بتظهر
                                    // بس للأصناف اللي ليها تدريج
                                    if (i.unitFactors.length > 1) ...[
                                      const SizedBox(width: 4),
                                      DropdownButton<String>(
                                        value: _unitOf(i),
                                        isDense: true,
                                        underline: const SizedBox.shrink(),
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: widget.accent),
                                        items: [
                                          for (final u
                                              in i.unitFactors.keys)
                                            DropdownMenuItem(
                                              value: u,
                                              child: Text(
                                                  CustodyItem.unitName(u) +
                                                      (i.factorOf(u) > 1
                                                          ? ' (${i.factorOf(u)})'
                                                          : '')),
                                            ),
                                        ],
                                        onChanged: (u) {
                                          if (u != null) _setUnit(i, u);
                                        },
                                      ),
                                    ],
                                    const Spacer(),
                                    // السعر = سعر القطعة × قطع الوحدة × الكمية
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                            money(q *
                                                _factor(i) *
                                                widget.priceOf(i)),
                                            style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight:
                                                    FontWeight.w900,
                                                color: widget.accent)),
                                        if (_factor(i) > 1 && q > 0)
                                          Text(
                                              L.t('eq_pieces', {
                                                'n': '${q * _factor(i)}'
                                              }),
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Brand.muted)),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )),
        ),
      ],
    );
  }
}
