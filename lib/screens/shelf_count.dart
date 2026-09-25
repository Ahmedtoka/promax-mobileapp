import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models.dart';
import '../promoter_models.dart';
import '../session.dart';
import 'multi_item_picker.dart';

/// جرد الرف بإيد المنسق (٢١ سبتمبر ٢٠٢٦): لكل صنف الكمية بوحدة القياس
/// وتاريخ الإنتاج والانتهاء. بيتحفظ على الفرع — الزيارة الجاية بتفتح
/// على آخر جرد اتعمل فيه وتقارن بيه.
class ShelfCountScreen extends StatefulWidget {
  final MerchVisit visit;
  const ShelfCountScreen({super.key, required this.visit});

  @override
  State<ShelfCountScreen> createState() => _ShelfCountScreenState();
}

class _ShelfCountScreenState extends State<ShelfCountScreen> {
  /// ترتيب الإضافة محفوظ — المنسق بيمشي على الرف بنفس الترتيب
  final List<CountLine> _lines = [];

  /// ⚠️ كنترولر لكل صنف (درس goods_request ٩/٨): مفتاح متغير على الحقل
  /// بيهدمه مع كل حرف والكيبورد بيقفل
  final Map<int, TextEditingController> _qty = {};
  final Map<int, TextEditingController> _note = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final c in widget.visit.counts) {
      _add(c.copy());
    }
  }

  @override
  void dispose() {
    for (final c in _qty.values) {
      c.dispose();
    }
    for (final c in _note.values) {
      c.dispose();
    }
    super.dispose();
  }

  CatalogProduct? _product(int id) =>
      firstOrNull(Session.I.catalog.where((p) => p.id == id));

  void _add(CountLine l) {
    // وحدة مش معرّفة للصنف (كتالوج اتغيّر بين الزيارتين) → أول وحدة متاحة،
    // وإلا السيرفر هيرفض الحفظ كله
    final units = _product(l.productId)?.countUnits ?? const ['piece'];
    if (!units.contains(l.unit)) l.unit = units.first;

    _lines.add(l);
    _qty[l.productId] = TextEditingController(text: l.qty == 0 ? '' : _fmtQty(l.qty));
    _note[l.productId] = TextEditingController(text: l.note ?? '');
  }

  void _remove(CountLine l) {
    _lines.remove(l);
    _qty.remove(l.productId)?.dispose();
    _note.remove(l.productId)?.dispose();
  }

  static String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  CountLine? _last(int productId) => firstOrNull(
      widget.visit.lastCounts.where((c) => c.productId == productId));

  Future<void> _openPicker() async {
    final entries = <PickEntry>[
      for (final p in Session.I.catalog)
        PickEntry(
            id: p.id, name: p.name, code: p.code, image: p.image, subtitle: p.unit),
    ];

    final res = await showMultiItemPicker(
      context,
      entries: entries,
      preSelected: _lines.map((l) => l.productId).toSet(),
    );
    if (res == null || !mounted) return;

    setState(() {
      for (final l in List<CountLine>.of(_lines)) {
        if (!res.contains(l.productId)) _remove(l);
      }
      for (final p in Session.I.catalog) {
        if (res.contains(p.id) && !_lines.any((l) => l.productId == p.id)) {
          _add(CountLine.blank(p.id, p.name, p.defaultCountUnit));
        }
      }
    });
  }

  /// «ابدأ من آخر جرد»: نفس أصناف الزيارة اللي فاتت ووحداتها — والكميات
  /// والتواريخ فاضية عن قصد، المنسق لازم يعدّ مش ينسخ.
  void _startFromLast() {
    setState(() {
      for (final c in widget.visit.lastCounts) {
        if (_lines.any((l) => l.productId == c.productId)) continue;
        if (_product(c.productId) == null) continue;
        _add(CountLine.blank(c.productId, c.name, c.unit));
      }
    });
  }

  /// الصلاحية سنة من تاريخ الإنتاج (قرار المالك ٢١/٩). المنسق بيكتب
  /// **تاريخ واحد** — اللي مطبوع على العبوة — والتاني بيتحسب: إنتاج + سنة
  /// = انتهاء، أو انتهاء − سنة = إنتاج.
  static DateTime _plusYear(DateTime d, int years) {
    final y = d.year + years;
    final lastDay = DateTime(y, d.month + 1, 0).day;   // 29 فبراير → 28
    return DateTime(y, d.month, d.day > lastDay ? lastDay : d.day);
  }

  /// أنهي تاريخ المنسق بيكتبه للصنف ده — الافتراضي الإنتاج
  final Map<int, bool> _byExpiry = {};

  Future<void> _pickDate(CountLine l) async {
    final byExpiry = _byExpiry[l.productId] ?? false;
    final now = DateTime.now();
    final initial = (byExpiry ? l.expiryDate : l.productionDate) ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null || !mounted) return;
    setState(() {
      if (byExpiry) {
        l.expiryDate = d;
        l.productionDate = _plusYear(d, -1);
      } else {
        l.productionDate = d;
        l.expiryDate = _plusYear(d, 1);
      }
    });
  }

  Future<void> _save() async {
    for (final l in _lines) {
      l.qty = double.tryParse((_qty[l.productId]?.text ?? '').trim()) ?? 0;
      final n = (_note[l.productId]?.text ?? '').trim();
      l.note = n.isEmpty ? null : n;
    }

    // امسك الاتنين قبل الـawait والـpop (درس ٩/٨)
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    final err = await Session.I.saveShelfCount(widget.visit.id, _lines);
    if (!mounted) return;
    setState(() => _busy = false);

    if (err != null) {
      messenger.showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text(L.t('sc_saved'))));
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.visit;
    final hasLast = v.lastCounts.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(L.t('sc_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          if (hasLast)
            Card(
              color: const Color(0xFFEFF6FF),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        L.t('sc_last_title', {
                          'd': v.lastCountAt == null ? '' : fmtDate(v.lastCountAt!)
                        }),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(L.t('sc_last_hint', {'n': '${v.lastCounts.length}'}),
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.history, size: 18),
                      label: Text(L.t('sc_start_from_last')),
                      onPressed: _busy ? null : _startFromLast,
                    ),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46)),
            icon: const Icon(Icons.playlist_add, size: 20),
            label: Text(L.t('sc_pick_items')),
            onPressed: _busy ? null : _openPicker,
          ),
          const SizedBox(height: 10),
          if (_lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(L.t('sc_empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600)),
            )
          else
            ..._lines.map(_row),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy) const LinearProgressIndicator(),
              const SizedBox(height: 6),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                icon: const Icon(Icons.save_outlined),
                label: Text(L.t('sc_save', {'n': '${_lines.length}'})),
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(CountLine l) {
    final p = _product(l.productId);
    final units = p?.countUnits ?? const ['piece'];
    final last = _last(l.productId);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13.5)),
                ),
                IconButton(
                  tooltip: L.t('sc_remove'),
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _busy ? null : () => setState(() => _remove(l)),
                ),
              ],
            ),
            if (last != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                    L.t('sc_last_line', {
                      'q': _fmtQty(last.qty),
                      'u': L.t('unit_${last.unit}'),
                      'e': last.expiryDate == null
                          ? '—'
                          : fmtDate(last.expiryDate!),
                    }),
                    style: TextStyle(
                        fontSize: 11.5, color: Colors.blueGrey.shade600)),
              ),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _qty[l.productId],
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: L.t('sc_qty'), isDense: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('unit-${l.productId}'),
                    initialValue: units.contains(l.unit) ? l.unit : units.first,
                    isDense: true,
                    decoration: InputDecoration(
                        labelText: L.t('sc_unit'), isDense: true),
                    items: [
                      for (final u in units)
                        DropdownMenuItem(
                          value: u,
                          child: Text(
                              u == 'piece'
                                  ? L.t('unit_piece')
                                  : '${L.t('unit_$u')} × ${p?.unitFactors[u] ?? 1}',
                              style: const TextStyle(fontSize: 13)),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (u) => setState(() => l.unit = u ?? 'piece'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _dateRow(l),
            const SizedBox(height: 8),
            TextField(
              controller: _note[l.productId],
              maxLength: 190,
              decoration: InputDecoration(
                  labelText: L.t('note_optional'),
                  isDense: true,
                  counterText: ''),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateRow(CountLine l) {
    final byExpiry = _byExpiry[l.productId] ?? false;
    final typed = byExpiry ? l.expiryDate : l.productionDate;
    final exp = l.expiryDate;
    final warn = exp != null &&
        exp.isBefore(DateTime.now().add(const Duration(days: 30)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _busy ? null : () => _pickDate(l),
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText:
                        byExpiry ? L.t('sc_expiry') : L.t('sc_production'),
                    isDense: true,
                    suffixIcon: typed == null
                        ? const Icon(Icons.event, size: 18)
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                      l.productionDate = null;
                                      l.expiryDate = null;
                                    })),
                  ),
                  child: Text(
                      typed == null ? L.t('sc_no_date') : fmtDate(typed),
                      style: TextStyle(
                          fontSize: 13,
                          color: typed == null ? Colors.grey : Colors.black87)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // اللي مكتوب على العبوة إنتاج ولا انتهاء؟
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(
                      () => _byExpiry[l.productId] = !byExpiry),
              child: Text(
                  byExpiry ? L.t('sc_switch_to_prod') : L.t('sc_switch_to_exp'),
                  style: const TextStyle(fontSize: 11.5)),
            ),
          ],
        ),
        if (exp != null && l.productionDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                byExpiry
                    ? L.t('sc_calc_prod', {'d': fmtDate(l.productionDate!)})
                    : L.t('sc_calc_exp', {'d': fmtDate(exp)}),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: warn ? FontWeight.bold : FontWeight.normal,
                    color: warn
                        ? const Color(0xFFB00020)
                        : Colors.blueGrey.shade700)),
          ),
      ],
    );
  }
}
