import 'package:flutter/material.dart';

import '../api.dart';
import '../brand.dart';
import '../l10n.dart';
import '../models.dart';

/// ═══════════════════════════════════════════════════════════════
/// مبيعاتي ومرتجعاتي — آخر ٧ أيام
/// ═══════════════════════════════════════════════════════════════
///
/// المندوب بيراجع «بعت إيه ورجّعت إيه» بنفسه — من غير ما يسأل حد
/// في المكتب. الفواتير بإجماليها المتحصّل (شامل الضريبة) والمرتجعات
/// بقيمتها اللي اتقيدت لصالح العميل.
class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

/// فترات الفلتر — زي ما المالك طلب بالظبط
enum SalesRange { today, yesterday, thisMonth, custom, week }

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  List<InvoiceRow>? _invoices;
  List<ReturnRow>? _returns;
  String? _error;

  SalesRange _range = SalesRange.week;
  DateTimeRange? _custom;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _d(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  (String?, String?) get _fromTo {
    final now = DateTime.now();

    return switch (_range) {
      SalesRange.today => (_d(now), _d(now)),
      SalesRange.yesterday => (
          _d(now.subtract(const Duration(days: 1))),
          _d(now.subtract(const Duration(days: 1)))
        ),
      SalesRange.thisMonth => (_d(DateTime(now.year, now.month, 1)), _d(now)),
      SalesRange.custom when _custom != null => (
          _d(_custom!.start),
          _d(_custom!.end)
        ),
      _ => (null, null), // الافتراضي: آخر ٧ أيام من السيرفر
    };
  }

  Future<void> _pickCustom() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2026),
      lastDate: DateTime.now(),
      initialDateRange: _custom,
    );

    if (picked != null) {
      setState(() {
        _custom = picked;
        _range = SalesRange.custom;
      });
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _invoices = null;
      _returns = null;
      _error = null;
    });

    try {
      final (from, to) = _fromTo;
      final d = await Api.I.mySales(from: from, to: to);
      if (!mounted) return;
      setState(() {
        _invoices = ((d['invoices'] ?? []) as List)
            .map((e) => InvoiceRow.fromJson(e))
            .toList();
        _returns = ((d['returns'] ?? []) as List)
            .map((e) => ReturnRow.fromJson(e))
            .toList();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = L.t('error_with', {'e': '$e'}));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(L.t('my_sales')),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: L.t('sales_tab')),
              Tab(text: L.t('returns_tab')),
            ],
          ),
        ),
        body: Column(
          children: [
            // ═══ فلتر التاريخ ═══
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                children: [
                  _chip(L.t('filter_week'), SalesRange.week),
                  _chip(L.t('filter_today'), SalesRange.today),
                  _chip(L.t('filter_yesterday'), SalesRange.yesterday),
                  _chip(L.t('filter_this_month'), SalesRange.thisMonth),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text(
                        _range == SalesRange.custom && _custom != null
                            ? '${_d(_custom!.start)} ← ${_d(_custom!.end)}'
                            : L.t('filter_custom'),
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      selected: _range == SalesRange.custom,
                      onSelected: (_) => _pickCustom(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _content()),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, SalesRange r) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 11.5)),
          selected: _range == r,
          onSelected: (_) {
            setState(() => _range = r);
            _load();
          },
        ),
      );

  Widget _content() {
    return _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: Text(L.t('retry')),
                      ),
                    ],
                  ),
                ),
              )
            : (_invoices == null || _returns == null)
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      _invoicesTab(),
                      _returnsTab(),
                    ],
                  );
  }

  Widget _empty(String text) => ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.receipt_long_outlined, size: 52, color: Brand.muted),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      );

  Widget _invoicesTab() {
    final rows = _invoices!;
    final total = rows.fold<double>(0, (t, r) => t + r.grandTotal);

    return RefreshIndicator(
      onRefresh: _load,
      child: rows.isEmpty
          ? _empty(L.t('no_sales_yet'))
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _totalCard(L.t('sales_period_total'), total,
                    const Color(0xFF16A34A), Icons.payments_outlined),
                for (final r in rows)
                  Card(
                    child: ListTile(
                      dense: true,
                      // فتح الفاتورة بالبنود والصور — ضد أخطاء «باعت إيه؟»
                      onTap: r.lines.isEmpty ? null : () => _openInvoice(r),
                      leading: CircleAvatar(
                        radius: 17,
                        backgroundColor: const Color(0xFF16A34A)
                            .withValues(alpha: .1),
                        child: const Icon(Icons.receipt_long,
                            size: 17, color: Color(0xFF16A34A)),
                      ),
                      title: Text(r.client,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800)),
                      subtitle: Text(
                          '${r.number} • ${r.paymentLabel} • ${fmtDate(r.time)}',
                          style: TextStyle(
                              fontSize: 11, color: Brand.muted)),
                      trailing: Text(money(r.grandTotal),
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _returnsTab() {
    final rows = _returns!;
    final total = rows.fold<double>(0, (t, r) => t + r.total);

    return RefreshIndicator(
      onRefresh: _load,
      child: rows.isEmpty
          ? _empty(L.t('no_returns_yet'))
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _totalCard(L.t('returns_period_total'), total,
                    const Color(0xFFB45309), Icons.u_turn_left),
                for (final r in rows)
                  Card(
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 17,
                        backgroundColor:
                            const Color(0xFFB45309).withValues(alpha: .1),
                        child: const Icon(Icons.u_turn_left,
                            size: 17, color: Color(0xFFB45309)),
                      ),
                      title: Text(r.client,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800)),
                      subtitle: Text('${r.number} • ${fmtDate(r.time)}',
                          style: TextStyle(
                              fontSize: 11, color: Brand.muted)),
                      trailing: Text('- ${money(r.total)}',
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFB45309))),
                    ),
                  ),
              ],
            ),
    );
  }

  /// تفاصيل الفاتورة — البنود بالصور في بوتوم شيت
  void _openInvoice(InvoiceRow r) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('${r.number} • ${r.client}',
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w900)),
            Text('${r.paymentLabel} • ${fmtDate(r.time)}',
                style: TextStyle(fontSize: 11.5, color: Brand.muted)),
            const SizedBox(height: 10),
            for (final l in r.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: const Color(0xFFE7E3DA)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: l.image == null
                          ? Icon(Icons.inventory_2_outlined,
                              size: 24, color: Brand.muted)
                          : Image.network(l.image!, cacheWidth: 800,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                  Icons.inventory_2_outlined,
                                  size: 24,
                                  color: Brand.muted)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.name,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                          Text('${money(l.price)} × ${l.qty}',
                              style: TextStyle(
                                  fontSize: 11.5, color: Brand.muted)),
                        ],
                      ),
                    ),
                    Text(money(l.total),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                    child: Text(L.t('total_due'),
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w800))),
                Text(money(r.grandTotal),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalCard(String label, double value, Color color, IconData icon) =>
      Card(
        color: color.withValues(alpha: .07),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Text(money(value),
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
        ),
      );
}
