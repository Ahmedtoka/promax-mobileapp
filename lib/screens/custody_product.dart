import 'package:flutter/material.dart';

import '../api.dart';
import '../brand.dart';
import '../l10n.dart';
import '../models.dart';
import 'shared.dart';

/// ═══════════════════════════════════════════════════════════════
/// تفاصيل صنف في العهدة (طلب المالك ٢٠/٨)
/// ═══════════════════════════════════════════════════════════════
///
/// الصورة كبيرة فوق، الاسم بتفاصيله (SKU · كرتونة · باتش · انتهاء)،
/// كارت «لسه في العربية» بالتدرج، «أرقام الصنف النهاردة»، تقسيمة
/// الباتشات لو أكتر من واحد، وآخر حاجة «حركة الصنف» بفلتر تاريخ
/// من/إلى — عشان المندوب يجيب كل تحركات الصنف عنده مش النهاردة بس.
class CustodyProductScreen extends StatefulWidget {
  /// الصنف المدموج (byProduct) — أرقامه هي أرقام الداشبورد
  final CustodyItem item;

  /// الصفوف الخام — كل صف = باتش، لتقسيمة الباتشات
  final List<CustodyItem> rows;

  const CustodyProductScreen(
      {super.key, required this.item, required this.rows});

  @override
  State<CustodyProductScreen> createState() => _CustodyProductScreenState();
}

class _CustodyProductScreenState extends State<CustodyProductScreen> {
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  bool _mvBusy = true;
  String? _mvError;
  List<Map<String, dynamic>> _moves = const [];

  @override
  void initState() {
    super.initState();
    _loadMoves();
  }

  String _d(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadMoves() async {
    setState(() {
      _mvBusy = true;
      _mvError = null;
    });

    try {
      final res = await Api.I.custodyProductMovements(
        widget.item.productId,
        from: _d(_from),
        to: _d(_to),
      );
      if (!mounted) return;

      setState(() {
        _mvBusy = false;
        _moves = ((res['events'] ?? []) as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _mvBusy = false;
        _mvError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mvBusy = false;
        _mvError = L.t('connection_error', {'e': ''});
      });
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final cur = isFrom ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;

    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_from.isAfter(_to)) _from = _to;
      }
    });
    _loadMoves();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.item;
    final color = Theme.of(context).colorScheme.primary;

    final ret = p.returnedIn + p.damagedIn;
    final spentPct =
        p.assigned == 0 ? 0 : ((p.assigned - p.remaining) / p.assigned * 100);

    return Scaffold(
      // الاسم أصغر شويتين في الهيدر (طلب المالك ٢٠/٨) — الأسماء
      // الطويلة كانت بتتقص من غير داعي
      appBar: AppBar(
          title: Text(p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w800))),
      // ⚠️ SafeArea — المحتوى كان بيدخل تحت بار النظام (بلاغ ٢١/٨)
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        children: [
          // ═══ الصورة الكبيرة + شارة السعر ═══
          Stack(children: [
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE7E3DA)),
              ),
              clipBehavior: Clip.antiAlias,
              padding: const EdgeInsets.all(14),
              child: p.image == null
                  ? Icon(Icons.inventory_2_outlined,
                      size: 60, color: Brand.muted)
                  : Image.network(p.image!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.inventory_2_outlined,
                          size: 60,
                          color: Brand.muted)),
            ),
            PositionedDirectional(
              top: 10,
              start: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('${money(p.price)} / ${p.unit}',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // ═══ التفاصيل — الاسم اتشال من هنا، مكتوب فوق في الهيدر
          // (طلب المالك ٢٠/٨) ═══
          if (p.familyLabel.isNotEmpty) ...[
            Text(p.familyLabel,
                style: TextStyle(fontSize: 11.5, color: Brand.muted)),
            const SizedBox(height: 6),
          ],
          Wrap(spacing: 6, runSpacing: 6, children: [
            _chip('SKU ${p.code}'),
            if (p.caseUnits > 0)
              _chip(L.t('case_eq', {'n': '${p.caseUnits}'})),
            ..._batchChips(),
          ]),
          const SizedBox(height: 14),

          // ═══ لسه في العربية — بالتدرج ═══
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: Brand.gradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${p.remaining}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 26)),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${p.unit} · ${L.t('left_in_van')}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11.5)),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(money(p.remaining * p.price),
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15)),
                        Text(L.t('worth'),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: p.assigned == 0
                        ? 0
                        : (p.assigned - p.remaining) / p.assigned,
                    minHeight: 9,
                    backgroundColor: Colors.white24,
                    color: const Color(0xFFFFF927),
                  ),
                ),
                const SizedBox(height: 7),
                Row(children: [
                  Text(L.t('spent_pct', {'p': spentPct.round().toString()}),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (p.packBd(p.remaining) != null)
                    Text(p.packBd(p.remaining)!,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 10.5)),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ═══ أرقام الصنف النهاردة ═══
          Text(L.t('today_numbers'),
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Row(children: [
            _stat(L.t('loaded_from_wh'), p.assigned, const Color(0xFFF0F4FF),
                color),
            const SizedBox(width: 8),
            _stat(L.t('sold_to_clients'), p.sold, const Color(0xFFF0F4FF),
                const Color(0xFF1565C0)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _stat(L.t('returned_from_clients'), ret,
                const Color(0xFFFFF4E5), const Color(0xFFB45309)),
            const SizedBox(width: 8),
            _stat(L.t('gifts_samples'), p.gifted, const Color(0xFFE9F9F0),
                Brand.green),
          ]),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(children: [
                _moneyRow(L.t('sales_value'), p.sold * p.price, null),
                _moneyRow(L.t('returns_value'), ret * p.price,
                    ret > 0 ? const Color(0xFFB45309) : null),
                const Divider(height: 14),
                _moneyRow(L.t('item_net'), (p.sold - ret) * p.price, color,
                    bold: true),
              ]),
            ),
          ),

          // ═══ الباتشات — لو الصنف متوزع على أكتر من باتش ═══
          if (widget.rows.length > 1) ...[
            const SizedBox(height: 14),
            Text(L.t('custody_batches_title'),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Column(children: [
                for (final r in (widget.rows.toList()
                  ..sort((a, b) =>
                      (a.expires ?? '9999').compareTo(b.expires ?? '9999'))))
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                            r.batch.isEmpty ? L.t('no_batch') : r.batch,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                      if (r.daysLeft != null)
                        Chip2(
                          text: L.t('days_left_n', {'n': '${r.daysLeft}'}),
                          color: r.daysLeft! <= 60
                              ? Brand.red
                              : r.daysLeft! <= 120
                                  ? const Color(0xFFB45309)
                                  : Brand.green,
                        ),
                      const SizedBox(width: 8),
                      Text('${r.remaining}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: color)),
                    ]),
                  ),
              ]),
            ),
          ],

          // ═══ حركة الصنف — بفلتر من/إلى ═══
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: Text(L.t('item_moves'),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900)),
            ),
            _dateBtn(true),
            const SizedBox(width: 6),
            _dateBtn(false),
          ]),
          const SizedBox(height: 8),

          if (_mvBusy) const LinearProgressIndicator(),
          if (_mvError != null)
            Card(
              color: const Color(0xFFFDECEC),
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_mvError!,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFB00020))),
              ),
            ),
          if (!_mvBusy && _mvError == null && _moves.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Center(
                child: Text(L.t('no_moves'),
                    style: TextStyle(fontSize: 12, color: Brand.muted)),
              ),
            ),
          if (_moves.isNotEmpty)
            Card(
              margin: EdgeInsets.zero,
              child: Column(children: [
                for (final m in _moves) _moveRow(m, color),
              ]),
            ),
        ],
        ),
      ),
    );
  }

  // ═══════════ ودجتس مساعدة ═══════════

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE0DDD4)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700)),
      );

  List<Widget> _batchChips() {
    // باتش واحد = شارته + انتهاؤه · أكتر = عددهم (والتفصيل تحت)
    final withBatch =
        widget.rows.where((r) => r.batch.isNotEmpty).toList()
          ..sort((a, b) =>
              (a.expires ?? '9999').compareTo(b.expires ?? '9999'));

    if (withBatch.isEmpty) return const [];

    if (withBatch.length == 1) {
      final r = withBatch.first;
      return [
        _chip(r.batch),
        if (r.expires != null)
          _chip(L.t('expires_d', {'d': r.expires!})),
      ];
    }

    return [_chip(L.t('batches_n', {'n': '${withBatch.length}'}))];
  }

  Widget _stat(String label, int value, Color bg, Color fg) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value ${widget.item.unit}',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900, color: fg)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(fontSize: 10.5, color: Brand.muted)),
            ],
          ),
        ),
      );

  Widget _moneyRow(String label, double value, Color? c, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: bold ? FontWeight.w900 : FontWeight.w600)),
          ),
          Text(money(value),
              textDirection: TextDirection.ltr,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                  color: c)),
        ]),
      );

  Widget _dateBtn(bool isFrom) {
    final d = isFrom ? _from : _to;

    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () => _pickDate(isFrom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE0DDD4)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today_outlined,
              size: 12, color: Brand.muted),
          const SizedBox(width: 4),
          Text(
              '${isFrom ? L.t('from_date') : L.t('to_date')} ${d.month}/${d.day}',
              style: const TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  Widget _moveRow(Map<String, dynamic> m, Color color) {
    final kind = m['kind']?.toString() ?? '';
    final qty = (m['qty'] as num?)?.toInt() ?? 0;
    final at = DateTime.tryParse(m['at']?.toString() ?? '')?.toLocal();
    final label = m['label']?.toString() ?? '';
    final ref = m['ref']?.toString() ?? '';

    final (icon, c) = switch (kind) {
      'load' => (Icons.arrow_upward, Brand.green),
      'sale' => (Icons.arrow_downward, const Color(0xFF1565C0)),
      'return' => (Icons.u_turn_left, const Color(0xFFB45309)),
      'gift' => (Icons.card_giftcard_outlined, const Color(0xFF7D40D6)),
      _ => (Icons.circle_outlined, Brand.muted),
    };

    final when = at == null
        ? ''
        : '${at.month}/${at.day} · ${at.hour % 12 == 0 ? 12 : at.hour % 12}:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? L.t('am') : L.t('pm')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: c.withValues(alpha: .10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15, color: c),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.isEmpty ? ref : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800)),
              Text([if (ref.isNotEmpty && label.isNotEmpty) ref, when]
                      .join(' · '),
                  style: TextStyle(fontSize: 10.5, color: Brand.muted)),
            ],
          ),
        ),
        Text('${qty > 0 ? '+' : ''}$qty',
            textDirection: TextDirection.ltr,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w900, color: c)),
      ]),
    );
  }
}
