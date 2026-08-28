import 'package:flutter/material.dart';

import '../api.dart';
import '../brand.dart';
import '../l10n.dart';
import '../models.dart';
import '../pick_models.dart';

/// ═══════════════════════════════════════════════════════════════
/// استلامات العهدة — كل اللي المندوب استلمه بتواريخه وبنوده
/// ═══════════════════════════════════════════════════════════════
///
/// «استلمت إيه وإمتى» — كل أمر تجهيز اتسلّم بيبان هنا للأبد:
/// الرقم، التاريخ، المخزن، الكميات، والبنود بالتفصيل لما يتفتح.
class PickHistoryScreen extends StatefulWidget {
  const PickHistoryScreen({super.key});

  @override
  State<PickHistoryScreen> createState() => _PickHistoryScreenState();
}

class _PickHistoryScreenState extends State<PickHistoryScreen> {
  List<PickOrder>? _orders;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _orders = null;
      _error = null;
    });

    try {
      final d = await Api.I.picksHistory();
      if (!mounted) return;
      setState(() {
        _orders = ((d['picks'] ?? []) as List)
            .map((e) => PickOrder.fromJson(e))
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
    final color = Theme.of(context).colorScheme.primary;
    final orders = _orders;

    return Scaffold(
      appBar: AppBar(title: Text(L.t('custody_history'))),
      body: _error != null
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
          : orders == null
              ? const Center(child: CircularProgressIndicator())
              // ⚠️ الفاضي جوه الـRefreshIndicator — عشان السحب يفضل شغال
              : orders.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        children: [
                          const SizedBox(height: 130),
                          Icon(Icons.history, size: 52, color: Brand.muted),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(L.t('no_custody_history'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: orders.length,
                        itemBuilder: (context, idx) =>
                            _orderCard(orders[idx], color),
                      ),
                    ),
    );
  }

  Widget _orderCard(PickOrder o, Color color) {
    final when = o.handedAt ?? o.time;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: CircleAvatar(
          radius: 19,
          backgroundColor: color.withValues(alpha: .1),
          child: Icon(Icons.inventory_2_outlined, size: 19, color: color),
        ),
        title: Text(o.number,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            '${fmtDate(when)} • ${o.warehouse}',
            style: TextStyle(fontSize: 11.5, color: Brand.muted),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(L.t('total_units', {'n': '${o.qtyReceived}'}),
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w900, color: color)),
            if (o.giftTotal > 0)
              Text('🎁 ${o.giftTotal}',
                  style: const TextStyle(fontSize: 11)),
          ],
        ),
        children: [
          const Divider(height: 1),
          for (final i in o.items)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.name,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700)),
                        if (i.batchNo != '—')
                          Text(
                              '${L.t('batch')}: ${i.batchNo}${i.expiresOn != null ? ' • ${i.expiresOn}' : ''}',
                              style: TextStyle(
                                  fontSize: 10.5, color: Brand.muted)),
                      ],
                    ),
                  ),
                  if (i.giftQty > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('🎁 ${i.giftQty}',
                          style: const TextStyle(fontSize: 11)),
                    ),
                  Text('× ${i.qtyReceived ?? i.qtyPicked}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: color)),
                ],
              ),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
