import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../brand.dart';
import '../l10n.dart';
import '../locator.dart';
import '../models.dart';
import 'shared.dart';

/// ═══════════════════════════════════════════════════════════════
/// شاشة التشجيع «حوافزي» — الأبديت الكبير (2026-08-06)
/// ═══════════════════════════════════════════════════════════════
///
/// المندوب بيشوف: تارجتاته الأربعة ببارات التحقيق، نقاطه وقيمتها
/// بالفلوس، عمولته المتوقعة بالنسبة، رصيد تصفيته (عليه/ليه)،
/// وإحصاء الليدز بتاعته — كله من `/my-incentives`.
class IncentivesScreen extends StatefulWidget {
  const IncentivesScreen({super.key});

  @override
  State<IncentivesScreen> createState() => _IncentivesScreenState();
}

class _IncentivesScreenState extends State<IncentivesScreen> {
  Map<String, dynamic>? data;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.I.myIncentives();
      if (mounted) setState(() { data = d; error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.t('my_incentives'))),
      body: error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: _load, child: Text(L.t('retry'))),
                ],
              ),
            )
          : data == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _body(data!),
                ),
    );
  }

  Widget _body(Map<String, dynamic> d) {
    final targets = (d['targets'] ?? {}) as Map<String, dynamic>;
    final points = (d['points'] ?? {}) as Map<String, dynamic>;
    final commission = (d['commission'] ?? {}) as Map<String, dynamic>;
    final settlement = d['settlement'] as Map<String, dynamic>?;
    final leads = (d['leads'] ?? {}) as Map<String, dynamic>;

    return ListView(
      // viewPadding صريح (مسح ٢١/٨)
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
      children: [
        // ═══ العمولة — الرقم الكبير المشجع فوق ═══
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: Brand.gradient,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Text(L.t('commission_expected'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              const SizedBox(height: 6),
              Text(money(_d(commission['amount'])),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
              Text('${commission['rate_pct'] ?? 0}% • ${d['month'] ?? ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ═══ التارجتات الأربعة ببارات التحقيق ═══
        Text(L.t('my_targets'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _targetCard('💰', L.t('target_money'), targets['money'], isMoney: true),
        _targetCard('📍', L.t('target_visits'), targets['visits']),
        _targetCard('🏪', L.t('target_clients'), targets['new_clients']),
        _targetCard('📦', L.t('target_pieces'), targets['pieces']),
        const SizedBox(height: 14),

        // ═══ النقاط ═══
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(L.t('my_points'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                    const Spacer(),
                    Text('${points['total'] ?? 0}',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Brand.royalBlue)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${L.t('points_auto')}: ${points['auto'] ?? 0} • '
                  '${L.t('points_manual')}: ${points['manual'] ?? 0}',
                  style: TextStyle(fontSize: 11.5, color: Brand.muted),
                ),
                const SizedBox(height: 4),
                Text(L.t('points_worth', {'m': money(_d(points['money']))}),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
              ],
            ),
          ),
        ),

        // ═══ رصيد التصفية — عليه/ليه ═══
        if (settlement != null)
          Card(
            child: ListTile(
              leading: const Text('🤝', style: TextStyle(fontSize: 20)),
              title: Text(L.t('settlement_balance'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              subtitle: Text('${settlement['number']} • ${settlement['date']}',
                  style: const TextStyle(fontSize: 11)),
              trailing: _balanceChip(_d(settlement['balance'])),
            ),
          ),

        // ═══ إحصاء الليدز ═══
        Card(
          child: ListTile(
            leading: const Text('✨', style: TextStyle(fontSize: 20)),
            title: Text(L.t('my_leads'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            subtitle: Text(
                L.t('lead_stats', {
                  's': '${leads['shown'] ?? 0}',
                  'a': '${leads['accepted'] ?? 0}',
                  'r': '${leads['rejected'] ?? 0}',
                }),
                style: const TextStyle(fontSize: 11.5)),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  double _d(Object? v) => v is num ? v.toDouble() : 0;

  Widget _balanceChip(double balance) {
    if (balance > 0) {
      return Chip(
        label: Text('${L.t('you_owe')} ${money(balance)}',
            style: const TextStyle(color: Colors.white, fontSize: 11.5)),
        backgroundColor: const Color(0xFFB00020),
      );
    }
    if (balance < 0) {
      return Chip(
        label: Text('${L.t('you_have')} ${money(-balance)}',
            style: const TextStyle(color: Colors.white, fontSize: 11.5)),
        backgroundColor: const Color(0xFF16A34A),
      );
    }
    return Chip(label: Text(L.t('settled_ok'), style: const TextStyle(fontSize: 11.5)));
  }

  Widget _targetCard(String icon, String title, Object? raw, {bool isMoney = false}) {
    final t = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    final target = _d(t['target']);
    final done = _d(t['done']);
    final pct = _d(t['pct']);
    final color = pct >= 100
        ? const Color(0xFF16A34A)
        : (pct >= 70 ? const Color(0xFFB86E00) : const Color(0xFFB00020));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const Spacer(),
                Text(
                  target > 0
                      ? '${isMoney ? money(done) : done.toInt()} / ${isMoney ? money(target) : target.toInt()}'
                      : (isMoney ? money(done) : '${done.toInt()}'),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                ),
              ],
            ),
            if (target > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (pct / 100).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: const Color(0xFFEDEFF5),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${pct.toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(L.t('no_target_set'),
                  style: TextStyle(fontSize: 10.5, color: Brand.muted)),
            ],
          ],
        ),
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// مراقب الليدز — أليرت نمط أوبر (2026-08-06)
/// ═══════════════════════════════════════════════════════════════
///
/// كل 3 دقايق: موقع المندوب ← `/leads/nearby` ← لو فيه ليد جديد
/// في النطاق بيطلع بوتوم شيت بأيقونة نابضة: «عميل محتمل جمبك!»
/// قبول ← بيتسكّن عليه وبتفتح ملاحة جوجل ماب · رفض ← مش بينوّر تاني.
class LeadWatcher {
  LeadWatcher._();

  static Timer? _timer;
  static final Set<int> _alerted = {};   // اتعرض في الجلسة دي — مايتكررش
  static bool _showing = false;

  /// ليد اتنبّه عليه إشعاراً والأبلكيشن في الخلفية — الشيت بيطلع
  /// أول ما المندوب يرجع (فلو الليد المطور ٢٦/٨)
  static Map<String, dynamic>? _pending;

  static void start(BuildContext context) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 3), (_) => _check(context));
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// بيتنده من الـHome عند العودة للمقدمة — لو فيه ليد مستني من
  /// إشعار الخلفية، الشيت بيطلع فوراً زي ما كان هيطلع ساعتها
  static void onResumed(BuildContext context) {
    final p = _pending;
    if (p == null || _showing || !context.mounted) return;
    _pending = null;
    _show(context, p);
  }

  static Future<void> _check(BuildContext context) async {
    if (_showing || !context.mounted) return;

    final pos = await Locator.get();
    if (pos == null) return;

    // الأبلكيشن في الخلفية؟ — الشيت مش هيبان، فالنداء إشعار بصوت
    final inBackground =
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;

    try {
      // ⚠️ اللي اتنبّه عليه في الخلفية ومردش بيفضل «مستني» —
      // وبنكرر الإشعار كل دورة (زي أوبر: ترن ترن لحد ما يرد)
      if (inBackground && _pending != null) {
        final name = '${_pending!['name'] ?? ''}';
        await Locator.notify(L.t('lead_nearby'), name);

        return;
      }

      final res = await Api.I.nearbyLeads(pos.$1, pos.$2);
      final leads = (res['leads'] as List?) ?? [];
      final fresh = leads
          .whereType<Map<String, dynamic>>()
          .where((l) => !_alerted.contains(l['id']))
          .toList();

      if (fresh.isEmpty || !context.mounted) return;

      final lead = fresh.first;
      _alerted.add(lead['id'] as int);

      if (inBackground) {
        // إشعار heads-up بصوت — والشيت بيطلع لما يفتح (onResumed)
        _pending = lead;
        await Locator.notify(L.t('lead_nearby'), '${lead['name'] ?? ''}');

        return;
      }

      _show(context, lead);
    } catch (_) {
      // نت واقع — المحاولة الجاية بعد 3 دقايق
    }
  }

  static Future<void> _show(BuildContext context, Map<String, dynamic> lead) async {
    _showing = true;

    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => _LeadSheet(lead: lead),
    );

    _showing = false;
  }
}

class _LeadSheet extends StatefulWidget {
  const _LeadSheet({required this.lead});

  final Map<String, dynamic> lead;

  @override
  State<_LeadSheet> createState() => _LeadSheetState();
}

class _LeadSheetState extends State<_LeadSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // النبضة — بتنور وتطفي زي أوبر
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _decide(String action) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await Api.I.leadAction(widget.lead['id'] as int, action);

      if (action == 'accepted') {
        // ملاحة جوجل ماب للعميل المحتمل — نفس تجربة أوبر
        final lat = widget.lead['lat'];
        final lng = widget.lead['lng'];
        await Locator.openUrl(
            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
      }

      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    final dist = lead['distance_m'] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // الأيقونة النابضة
          FadeTransition(
            opacity: Tween(begin: 0.35, end: 1.0).animate(_pulse),
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Brand.purpleHeart.withValues(alpha: .14),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('✨', style: TextStyle(fontSize: 30))),
            ),
          ),
          const SizedBox(height: 10),
          Text(L.t('lead_nearby'),
              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${lead['name']}',
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          Text(
            '${L.t('lead_distance', {'m': '$dist'})}'
            '${(lead['address'] ?? '').toString().isNotEmpty ? ' • ${lead['address']}' : ''}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Brand.muted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _decide('rejected'),
                  child: Text(L.t('lead_reject')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _decide('accepted'),
                  icon: const Icon(Icons.navigation_outlined, size: 18),
                  label: Text(L.t('lead_accept')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
