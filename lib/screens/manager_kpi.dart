import 'package:flutter/material.dart';

import '../api.dart';
import '../l10n.dart';
import '../models.dart';

/// ═══════════════════════════════════════════════════════════════
/// العمولات والـKPI — قراءة بس (٢٨/٨/٢٠٢٦، قرار المالك)
/// ═══════════════════════════════════════════════════════════════
///
/// نفس أرقام حاسبة `/erp/kpi` بالظبط (المحرك واحد — `Kpi::calculate`):
/// المدير بيشوف قنواته بس والأدمن الكل. التعديل من الداشبورد.
/// لكل مندوب: التحصيل · التحقيق٪ · الدرجة · الحافز النهائي.
class KpiScreen extends StatefulWidget {
  const KpiScreen({super.key});

  @override
  State<KpiScreen> createState() => _KpiScreenState();
}

class _KpiScreenState extends State<KpiScreen> {
  Map<String, dynamic>? _d;
  String? _err;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  String get _period =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _d = null;
      _err = null;
    });
    try {
      final d = await Api.I.managerKpi(_period);
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

  void _shift(int months) {
    setState(() =>
        _month = DateTime(_month.year, _month.month + months));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final channels = ((_d?['channels'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final now = DateTime.now();
    final atCurrent =
        _month.year == now.year && _month.month == now.month;

    return Scaffold(
      appBar: AppBar(title: Text(L.t('kp_title'))),
      body: Column(
        children: [
          // ═══ منتقي الشهر ═══
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                IconButton(
                    onPressed: () => _shift(-1),
                    icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Center(
                    child: Text(_period,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
                IconButton(
                    onPressed: atCurrent ? null : () => _shift(1),
                    icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
          Expanded(
            child: _err != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_err!),
                        TextButton(
                            onPressed: _load, child: Text(L.t('retry'))),
                      ],
                    ),
                  )
                : _d == null
                    ? const Center(child: CircularProgressIndicator())
                    : channels.isEmpty
                        ? Center(child: Text(L.t('kp_none')))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              padding: const EdgeInsets.all(12),
                              children: [
                                Text(L.t('kp_hint'),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600)),
                                const SizedBox(height: 6),
                                ...channels.map(_channelCard),
                                const SizedBox(height: 30),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _channelCard(Map<String, dynamic> ch) {
    final reps = ((ch['reps'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final mgr = ch['manager'] is Map
        ? Map<String, dynamic>.from(ch['manager'] as Map)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📣 ${ch['name']}',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (reps.isEmpty)
              Text(L.t('kp_no_reps'),
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ...reps.map(_repRow),
            if (mgr != null) ...[
              const Divider(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text('👔 ${L.t('kp_manager_row')}',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w800)),
                  ),
                  Text(money((mgr['final'] as num?)?.toDouble() ?? 0),
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF7C3AED))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _repRow(Map<String, dynamic> r) {
    final cleared = r['cleared'] == true;
    final ach = (r['achievement'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundImage: r['avatar_url'] != null
                    ? NetworkImage('${r['avatar_url']}')
                    : null,
                child: r['avatar_url'] == null
                    ? Text('${r['name']}'.isEmpty ? '؟' : '${r['name']}'[0],
                        style: const TextStyle(fontSize: 10))
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${r['name']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              Text(money((r['final'] as num?)?.toDouble() ?? 0),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: cleared
                          ? const Color(0xFF16A34A)
                          : Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              // بار التحقيق — البوابة بتبان بلونها
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (ach / 100).clamp(0.0, 1.0).toDouble(),
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    color: cleared
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFB86E00),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${ach.toStringAsFixed(0)}% • '
                '${L.t('kp_coll')} ${money((r['collections'] as num?)?.toDouble() ?? 0)} • '
                '${L.t('kp_score')} ${r['score'] ?? 0}',
                style:
                    TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
