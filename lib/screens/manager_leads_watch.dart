import 'package:flutter/material.dart';

import '../api.dart';
import '../l10n.dart';

/// ═══════════════════════════════════════════════════════════════
/// متابعة ليدات الفريق (٢٨/٨/٢٠٢٦) — «الحركة جمب بحركة» للمدير
/// ═══════════════════════════════════════════════════════════════
///
/// لكل مندوب: أرقام أسبوعه (اتجدوله/راح فعلاً/فايتله/كسبهم — نفس
/// حسبة صفحة متابعة الأسبوع في الـERP) + مجدولين النهارده واحد
/// واحد بعلامة «اتأكد» — وتحت: الأكاونتات اللي اتفتحت من الميدان.
class LeadsWatchScreen extends StatefulWidget {
  const LeadsWatchScreen({super.key});

  @override
  State<LeadsWatchScreen> createState() => _LeadsWatchScreenState();
}

class _LeadsWatchScreenState extends State<LeadsWatchScreen> {
  Map<String, dynamic>? _d;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _err = null);
    try {
      final d = await Api.I.managerLeadsWatch();
      if (!mounted) return;
      setState(() => _d = d);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _err = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _err = L.t('server_down'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reps = ((_d?['reps'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final opened = ((_d?['opened'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(L.t('lw_title'))),
      body: _err != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_err!),
                  TextButton(onPressed: _load, child: Text(L.t('retry'))),
                ],
              ),
            )
          : _d == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      Text(
                          '${L.t('lw_week_of')} ${_d?['week_of'] ?? ''}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      if (reps.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 100),
                          child: Center(child: Text(L.t('lw_none'))),
                        ),
                      ...reps.map(_repCard),

                      if (opened.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(L.t('lw_opened'),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        ...opened.map((o) => Card(
                              child: ListTile(
                                dense: true,
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFE7F6EC),
                                  child: Text('🏪',
                                      style: TextStyle(fontSize: 16)),
                                ),
                                title: Text(
                                    '${o['lead']} → ${o['client_code'] ?? ''}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                    '${o['by'] ?? ''} • ${o['at'] ?? ''}',
                                    style: const TextStyle(fontSize: 11)),
                              ),
                            )),
                      ],
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
    );
  }

  Widget _repCard(Map<String, dynamic> r) {
    final today = ((r['today'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final missed = (r['missed'] as num?)?.toInt() ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundImage: r['avatar_url'] != null
                      ? NetworkImage('${r['avatar_url']}')
                      : null,
                  child: r['avatar_url'] == null
                      ? Text('${r['name']}'.isEmpty ? '؟' : '${r['name']}'[0])
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${r['name']}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                ),
                if (missed > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEC),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('⚠️ $missed ${L.t('lw_missed')}',
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFDC2626))),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _badge(L.t('lw_open'), '${r['open'] ?? 0}',
                    const Color(0xFF2563EB)),
                _badge(L.t('lw_planned'), '${r['planned'] ?? 0}',
                    const Color(0xFF7C3AED)),
                _badge(L.t('lw_visited'), '${r['visited'] ?? 0}',
                    const Color(0xFF16A34A)),
                _badge(L.t('lw_won'), '${r['won'] ?? 0}',
                    const Color(0xFFEA8C1C)),
              ],
            ),
            if (today.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text('📅 ${L.t('lw_today')}',
                  style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [
                  for (final l in today)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: l['confirmed'] == true
                            ? const Color(0xFFE7F6EC)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: l['confirmed'] == true
                                ? const Color(0xFF16A34A)
                                : Colors.grey.shade300),
                      ),
                      child: Text(
                        '${l['confirmed'] == true ? '✓ ' : ''}${l['name']}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: l['confirmed'] == true
                                ? const Color(0xFF15803D)
                                : Colors.grey.shade800),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, String v, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 6),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(v,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.5, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
