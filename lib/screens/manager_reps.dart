import 'package:flutter/material.dart';
import '../l10n.dart';

import '../models.dart';
import '../session.dart';
import 'shared.dart';

// ================= قايمة المناديب =================

class ManagerRepsScreen extends StatelessWidget {
  const ManagerRepsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ⚠️ **ListenableBuilder إجبارية** — الشاشة const جوه التابات
    // وفلاتر بيتخطى إعادة بناءها، فالداتا اللي بتوصل بعد الفتح
    // ماكانتش بتبان (نفس باج CustodyScreen الموثّق 2026-08-03).
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) => _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final s = Session.I;

    return Scaffold(
      appBar: AppBar(title: Text(L.t('reps'))),
      body: RefreshIndicator(
        onRefresh: s.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (s.reps.isEmpty)
              Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text(L.t('no_reps'))),
              ),
            ...s.reps.map((r) => RepCard(rep: r)),
          ],
        ),
      ),
    );
  }
}

class RepCard extends StatelessWidget {
  final RepOverview rep;
  const RepCard({super.key, required this.rep});

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel) = rep.status;
    final roleColor =
        rep.isCourier ? const Color(0xFF2563EB) : const Color(0xFF16A34A);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => RepDetailScreen(rep: rep))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: roleColor,
                    child: Icon(
                        rep.isCourier ? Icons.local_shipping : Icons.storefront,
                        color: Colors.white,
                        size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rep.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14.5)),
                        Text('${rep.code} • ${rep.zone ?? '—'}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  Chip2(text: statusLabel, color: statusColor),
                ],
              ),

              if (rep.activeClient != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  // ⚠️ ممنوع تلزيق `L.t(...)` جنب سترنج — التلزيق ده
                  // بيشتغل بين **حروف نصية** بس، ومع دالة بيبقى خطأ
                  // تجميع. لازم استيفاء `${}` صريح.
                  child: Text(
                      L.t('at_client', {'c': '${rep.activeClient}'}) +
                          (rep.activeSince != null
                              ? ' — ${L.t('since_t', {'t': '${fmtTime(rep.activeSince!)}'})}'
                              : ''),
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
              ],

              const SizedBox(height: 10),
              Row(
                children: [
                  _Metric(
                      label: rep.isCourier ? L.t('delivered_value') : L.t('sales'),
                      value: money(rep.isCourier ? rep.posValue : rep.sales)),
                  _Metric(
                      label: rep.isCourier ? L.t('deliveries') : L.t('visits'),
                      value: rep.isCourier
                          ? '${rep.posDone}/${rep.pos}'
                          : '${rep.visitsDone}/${rep.visits}'),
                  _Metric(
                      label: L.t('custody_left'),
                      value: '${rep.custodyRemaining}'),
                ],
              ),

              if (rep.lastAction != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                          '${rep.lastAction}'
                          '${rep.lastSeen != null ? ' • ${fmtTime(rep.lastSeen!)}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 13.5)),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

// ================= تفاصيل المندوب =================

class RepDetailScreen extends StatefulWidget {
  final RepOverview rep;
  const RepDetailScreen({super.key, required this.rep});

  @override
  State<RepDetailScreen> createState() => _RepDetailScreenState();
}

class _RepDetailScreenState extends State<RepDetailScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _data = null;
    });
    try {
      final d = await Session.I.repDetail(widget.rep.id);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final rep = widget.rep;

    return Scaffold(
      appBar: AppBar(title: Text(rep.name)),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: Text(L.t('retry')),
                    ),
                  ],
                ),
              ),
            )
          : _data == null
              ? const Center(child: CircularProgressIndicator())
              : _body(),
    );
  }

  Widget _body() {
    final d = _data!;
    final custody = (d['custody'] as List?) ?? [];
    final invoices = (d['invoices'] as List?) ?? [];
    final pos = (d['pos'] as List?) ?? [];
    final events = (d['events'] as List?) ?? [];
    final rep = widget.rep;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RepCard(rep: rep),

          // ---- العهدة ----
          const SizedBox(height: 8),
          Text('${L.t('custody')} (${L.t('n_items', {'n': '${custody.length}'})})',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (custody.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text(L.t('no_custody'))),
              ),
            ),
          ...custody.map((i) => Card(
                child: ListTile(
                  dense: true,
                  title: Text(i['name'] ?? '',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${L.t('assigned')} ${i['assigned']} • ${L.t('sold')} ${i['sold']}',
                      style: const TextStyle(fontSize: 11)),
                  trailing: Text('${i['remaining']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              )),

          // ---- الفواتير ----
          if (invoices.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(L.t('invoices_today_n', {'n': '${invoices.length}'}),
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...invoices.map((inv) => Card(
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.receipt_long,
                        color: Color(0xFF16A34A), size: 20),
                    title: Text(inv['client'] ?? '',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${inv['number']} • ${inv['payment'] == 'cash' ? L.t('cash') : L.t('credit')}',
                        style: const TextStyle(fontSize: 11)),
                    trailing: Text(money((inv['total'] as num).toDouble()),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                )),
          ],

          // ---- أوامر التوريد ----
          if (pos.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(L.t('pos_n', {'n': '${pos.length}'}),
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...pos.map((p) => Card(
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.local_shipping,
                        color: Color(0xFF2563EB), size: 20),
                    title: Text(p['client'] ?? '',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text('${p['number']} • ${p['status_label']}',
                        style: const TextStyle(fontSize: 11)),
                    trailing: Text(money((p['total'] as num).toDouble()),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                )),
          ],

          // ---- التراكينج ----
          const SizedBox(height: 14),
          Text(L.t('his_activity_n', {'n': '${events.length}'}),
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...events.reversed.map((e) {
            final (icon, color) = switch (e['type']) {
              'start' => (Icons.flag, const Color(0xFF7C3AED)),
              'check_in' => (Icons.login, const Color(0xFF2563EB)),
              'check_out' => (Icons.logout, const Color(0xFFDC2626)),
              'sale' => (Icons.receipt_long, const Color(0xFF16A34A)),
              'deliver' => (Icons.local_shipping, const Color(0xFF0F766E)),
              'request' => (Icons.person_add_alt, const Color(0xFFEA8C1C)),
              _ => (Icons.circle, Colors.grey),
            };
            return Card(
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icon, color: color, size: 17),
                ),
                title: Text(e['title'] ?? '',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
                subtitle: (e['subtitle'] ?? '').toString().isEmpty
                    ? null
                    : Text(e['subtitle'],
                        style: const TextStyle(fontSize: 11)),
                trailing: Text(
                    fmtTime(parseTime(e['time']) ?? DateTime.now()),
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ),
            );
          }),
        ],
      ),
    );
  }
}
