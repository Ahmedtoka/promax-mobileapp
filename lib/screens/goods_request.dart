import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models.dart';
import '../session.dart';
import 'multi_item_picker.dart';
import 'shared.dart';

/// ═══════════════════════════════════════════════════════════════
/// طلب بضاعة للعميل — من عند العميل (2026-08-09)
/// ═══════════════════════════════════════════════════════════════
///
/// المندوب واقف عند العميل وعامل تشيك إن، بيختار من **الكتالوج
/// الكامل** (مش عهدته — البضاعة جاية من المخزن) زي ما بيبيع:
/// الصنف ده كرتونة، والصنف ده قطعة. الطلب بينزل للمدير يوافق،
/// يتحول أمر توريد، يتجهّز، والمندوب يوصله إشعار «تعالى استلم».
///
/// ⚠️ الوحدة بتتبعت اسم والسيرفر هو اللي بيضرب — نفس دوكترين
/// الفاتورة بالظبط (`itemsToPieces`).
class GoodsRequestScreen extends StatefulWidget {
  final Client client;

  const GoodsRequestScreen({super.key, required this.client});

  @override
  State<GoodsRequestScreen> createState() => _GoodsRequestScreenState();
}

class _CatalogItem {
  final int productId;
  final String name;
  final String barcode;

  /// ⚠️ **نَل مسموح** — الصنف اللي مالوش صورة مرفوعة بيرجع `null`
  /// والمنتقي بيوري أيقونة بديلة. الخطأ كان إن الحقل نفسه مش
  /// موجود، فحتى الصنف اللي ليه صورة كان بيظهر بالأيقونة.
  final String? image;
  final double price;
  final int unitsPerCase;
  final int boxUnits;

  _CatalogItem.fromJson(Map<String, dynamic> j)
      : productId = j['product_id'],
        name = j['name'] ?? '',
        image = j['image'] as String?,
        barcode = j['barcode']?.toString() ?? '',
        price = (j['price'] as num?)?.toDouble() ?? 0,
        unitsPerCase = (j['units_per_case'] as num?)?.toInt() ?? 0,
        boxUnits = (j['box_units'] as num?)?.toInt() ?? 0;

  /// الوحدات المتاحة للصنف — قطعة دايماً، وعلبة/كرتونة لو معرّفين
  List<String> get units => [
        'piece',
        if (boxUnits > 1) 'box',
        if (unitsPerCase > 1) 'case',
      ];

  int factorOf(String unit) => switch (unit) {
        'case' => unitsPerCase > 1 ? unitsPerCase : 1,
        'box' => boxUnits > 1 ? boxUnits : 1,
        _ => 1,
      };

  /// ⚠️ الديفولت الموحّد (قرار المالك ٩ أغسطس): علبة لو موجودة وإلا قطعة
  String get defaultUnit => boxUnits > 1 ? 'box' : 'piece';
}

class _GoodsRequestScreenState extends State<GoodsRequestScreen> {
  final Map<int, int> _qty = {};
  final Map<int, String> _unit = {};

  // ⚠️ **كنترولر لكل صنف مش ValueKey فيها الكمية** (تدقيق ٩/٨).
  // المفتاح اللي بيتغير مع كل حرف كان بيهدم الحقل ويعيد بناءه
  // بفوكس جديد — فكتابة «12» كانت مستحيلة: الكيبورد بيقفل بعد
  // أول رقم. الكنترولر الثابت بيخلّي أزرار +/− والكتابة يتشاركوا
  // نفس الحقل من غير ما يفقد الفوكس.
  final Map<int, TextEditingController> _qtyCtrl = {};
  final _note = TextEditingController();

  /// السطور المختارة بترتيب الإضافة — الشاشة بقت بتعرض المختار بس،
  /// والاختيار نفسه بيحصل في المنتقي المتعدد (طلب المالك ١٢/٨)
  final List<int> _order = [];

  List<_CatalogItem> _items = [];
  bool _loading = true;
  bool _busy = false;
  String? _loadError;

  TextEditingController _ctrlOf(int productId) =>
      _qtyCtrl.putIfAbsent(productId, () => TextEditingController());

  /// تغيير الكمية من الزراير — بيحدّث الحقل والخريطة مع بعض.
  /// ⚠️ والوحدة الديفولت **بتتكتب** مش بتتساب فولباك — عشان العرض
  /// والإرسال يفضلوا نفس القيمة.
  void _setQty(int productId, int value) {
    final v = value < 0 ? 0 : value;
    setState(() {
      _qty[productId] = v;
      final it = firstOrNull(_items.where((x) => x.productId == productId));
      if (it != null) _unit.putIfAbsent(productId, () => it.defaultUnit);
      _ctrlOf(productId).text = v > 0 ? '$v' : '';
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _qtyCtrl.values) {
      c.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  /// المنتقي المتعدد: الجديد بينزل سطر بكمية ١ ووحدته الديفولت،
  /// واللي علامته اتشالت سطره بيتشال.
  Future<void> _openPicker() async {
    final entries = <PickEntry>[
      for (final it in _items)
        PickEntry(
          id: it.productId,
          name: it.name,
          code: it.barcode,
          image: it.image,
          subtitle: '${money(it.price)} / ${L.t('unit_piece')}',
        ),
    ];

    final res = await showMultiItemPicker(
      context,
      entries: entries,
      preSelected: _order.toSet(),
    );
    if (res == null || !mounted) return;

    setState(() {
      for (final it in _items) {
        final had = _order.contains(it.productId);
        final want = res.contains(it.productId);

        if (want && !had) {
          _order.add(it.productId);
          _qty[it.productId] = 1;
          // الديفولت الموحّد بيتكتب في الخريطة — نفس دوكترين _setQty
          _unit.putIfAbsent(it.productId, () => it.defaultUnit);
          _ctrlOf(it.productId).text = '1';
        } else if (!want && had) {
          _removeLine(it.productId);
        }
      }
    });
  }

  /// شيل سطر — من المنتقي (شيل العلامة) أو من زرار الحذف في السطر.
  /// الوحدة بتتشال كمان — لو رجع تاني ياخد الديفولت مش وحدة قديمة.
  void _removeLine(int productId) {
    _order.remove(productId);
    _qty.remove(productId);
    _unit.remove(productId);
    _ctrlOf(productId).text = '';
  }

  Future<void> _load() async {
    try {
      final res = await Session.I.clientCatalog(widget.client);
      if (!mounted) return;
      setState(() {
        _items = ((res['items'] ?? []) as List)
            .map((e) => _CatalogItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '$e';
      });
    }
  }

  /// إجمالي تقديري بالقطع — بسعر العميل، للعرض بس (السيرفر بيسعّر)
  double get _estimate {
    var total = 0.0;
    for (final it in _items) {
      final q = _qty[it.productId] ?? 0;
      if (q > 0) {
        total += q * it.factorOf(_unit[it.productId] ?? it.defaultUnit) * it.price;
      }
    }

    return total;
  }

  int get _linesCount => _qty.values.where((q) => q > 0).length;

  Future<void> _submit() async {
    final items = <Map<String, dynamic>>[];
    for (final e in _qty.entries) {
      if (e.value > 0) {
        final it = firstOrNull(_items.where((x) => x.productId == e.key));
        items.add({
          'product_id': e.key,
          'qty': e.value,
          'unit': _unit[e.key] ?? it?.defaultUnit ?? 'piece',
        });
      }
    }

    if (items.isEmpty) {
      snack(context, L.t('goods_pick_something'), bad: true);
      return;
    }

    setState(() => _busy = true);

    final (err, number) = await Session.I
        .createGoodsRequest(widget.client, items, _note.text.trim());

    if (!mounted) return;
    setState(() => _busy = false);

    if (err != null) {
      snack(context, err, bad: true);
      return;
    }

    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(SnackBar(
        content: Text(L.t('goods_request_sent', {'n': number ?? ''}))));
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    // السطور المختارة بترتيب إضافتها — الكتالوج كله جوه المنتقي
    final lines = <_CatalogItem>[];
    for (final id in _order) {
      final it = firstOrNull(_items.where((x) => x.productId == id));
      if (it != null) lines.add(it);
    }

    return Scaffold(
      appBar: AppBar(title: Text(L.t('goods_request_title'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: PickerBox(
                onTap: (_loading || _loadError != null || _items.isEmpty)
                    ? () {}
                    : _openPicker),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                              L.t('error_with', {'e': '$_loadError'}),
                              textAlign: TextAlign.center),
                        ),
                      )
                    : _items.isEmpty
                        ? Center(
                            child: Text(L.t('no_products'),
                                style:
                                    TextStyle(color: Colors.grey.shade600)))
                        : lines.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.checklist_rounded,
                                        size: 46, color: Colors.grey.shade500),
                                    const SizedBox(height: 10),
                                    Text(L.t('pick_then_qty_hint'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                itemCount: lines.length,
                                itemBuilder: (_, i) => _row(lines[i]),
                              ),
          ),

          // ═══ الشريط السفلي: الملخص + الإرسال ═══
          SafeArea(
            top: false,
            bottom: false,
            child: Container(
              // viewPadding صريح (مسح ٢١/٨)
              padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.viewPaddingOf(context).bottom),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: .08),
                      blurRadius: 12,
                      offset: const Offset(0, -3)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _note,
                    decoration: InputDecoration(
                        labelText: L.t('note_optional'), isDense: true),
                  ),
                  const SizedBox(height: 10),
                  if (_busy) const LinearProgressIndicator(),
                  const SizedBox(height: 4),
                  FilledButton.icon(
                    icon: const Icon(Icons.send_outlined),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50)),
                    label: Text(
                      _linesCount == 0
                          ? L.t('goods_request_send')
                          : '${L.t('goods_request_send')} · $_linesCount ${L.t('goods_lines')} · ${money(_estimate)}',
                      style: const TextStyle(fontSize: 14.5),
                    ),
                    onPressed: _busy || _linesCount == 0 ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(_CatalogItem it) {
    final qty = _qty[it.productId] ?? 0;
    final unit = _unit[it.productId] ?? it.defaultUnit;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text('${money(it.price)} / ${L.t('unit_piece')}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                if (qty > 0)
                  Chip2(
                      text:
                          '${qty * it.factorOf(unit)} ${L.t('unit_piece')}',
                      color: const Color(0xFF16A34A)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: L.t('remove_line'),
                  onPressed: () =>
                      setState(() => _removeLine(it.productId)),
                  icon: const Icon(Icons.delete_outline,
                      size: 19, color: Color(0xFFB00020)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // الوحدة — قطعة/علبة/كرتونة حسب تعريف الصنف
                if (it.units.length > 1)
                  DropdownButton<String>(
                    value: unit,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final u in it.units)
                        DropdownMenuItem(
                          value: u,
                          child: Text(
                            it.factorOf(u) > 1
                                ? '${L.t('unit_$u')} (${it.factorOf(u)})'
                                : L.t('unit_$u'),
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(
                        () => _unit[it.productId] = v ?? it.defaultUnit),
                  )
                else
                  Text(L.t('unit_piece'),
                      style: const TextStyle(fontSize: 12.5)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed:
                      qty > 0 ? () => _setQty(it.productId, qty - 1) : null,
                ),
                SizedBox(
                  width: 52,
                  child: TextField(
                    controller: _ctrlOf(it.productId),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15),
                    decoration:
                        const InputDecoration(isDense: true, hintText: '0'),
                    // الكتابة بتحدّث الخريطة بس — الكنترولر معاه
                    // النص أصلاً، فمفيش إعادة بناء تفقد الفوكس
                    onChanged: (v) => setState(
                        () => _qty[it.productId] = int.tryParse(v) ?? 0),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _setQty(it.productId, qty + 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
