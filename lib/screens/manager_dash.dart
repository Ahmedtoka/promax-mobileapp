import 'package:flutter/material.dart';

import '../api.dart';
import '../l10n.dart';
import '../models.dart';
import 'manager_kpi.dart';
import 'manager_leads_watch.dart';
import 'manager_live.dart';
import 'manager_tasks.dart';

/// ═══════════════════════════════════════════════════════════════
/// بورد المعادلة — قلب داشبورد المدير/الأدمن الجديدة (٢٨/٨/٢٠٢٦)
/// ═══════════════════════════════════════════════════════════════
///
/// نفس معادلة داشبورد الـERP بالظبط (عقيدة الأرقام):
///   مبيعات (كاش/آجل/توريدات) − تحصيل (بمصادره) − مرتجعات
///   = صافي حركة المديونية · + المديونية القائمة (سنابشوت)
///
/// سيكشن بيتزرع جوه ListView الداشبورد — بيدير تحميله بنفسه
/// (`Api.I` مباشرة زي بوردات المكتب: مالوش حالة في Session).
/// [isAdmin] بيظهّر فلتر «بعيون مدير».
class ManagerEquationBoard extends StatefulWidget {
  const ManagerEquationBoard({super.key, this.isAdmin = false});

  final bool isAdmin;

  @override
  State<ManagerEquationBoard> createState() => _ManagerEquationBoardState();
}

class _ManagerEquationBoardState extends State<ManagerEquationBoard> {
  Map<String, dynamic>? _d;
  bool _busy = false;
  String? _err;

  /// today | week | month
  String _period = 'month';
  int? _mgrId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  (String, String) _range() {
    final now = DateTime.now();
    String f(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    return switch (_period) {
      'today' => (f(now), f(now)),
      // أسبوع السيستم بيبدأ السبت — زي جدولة المحتملين
      'week' => (f(now.subtract(Duration(days: (now.weekday + 1) % 7))), f(now)),
      _ => (f(DateTime(now.year, now.month, 1)), f(now)),
    };
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _err = null;
    });

    final (from, to) = _range();
    try {
      final d = await Api.I
          .managerDashboard(from: from, to: to, managerId: _mgrId);
      if (!mounted) return;
      setState(() {
        _d = d;
        _busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = L.t('server_down');
      });
    }
  }

  double _n(dynamic v) => (v as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final sales = Map<String, dynamic>.from((d?['sales'] ?? const {}) as Map);
    final coll =
        Map<String, dynamic>.from((d?['collections'] ?? const {}) as Map);
    final rets = Map<String, dynamic>.from((d?['returns'] ?? const {}) as Map);
    final debt = Map<String, dynamic>.from((d?['debt'] ?? const {}) as Map);
    final street = Map<String, dynamic>.from((d?['street'] ?? const {}) as Map);
    final managers = (d?['managers'] as List?) ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ═══ هيدر السيكشن: العنوان + الفترة ═══
        Row(
          children: [
            Expanded(
              child: Text(L.t('eq_title'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            if (_busy)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 19),
              ),
          ],
        ),
        Row(
          children: [
            for (final (k, label) in [
              ('today', L.t('eq_today')),
              ('week', L.t('eq_week')),
              ('month', L.t('eq_month')),
            ]) ...[
              ChoiceChip(
                label: Text(label, style: const TextStyle(fontSize: 12)),
                selected: _period == k,
                visualDensity: VisualDensity.compact,
                onSelected: (_) {
                  setState(() => _period = k);
                  _load();
                },
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),

        // فلتر «بعيون مدير» — للأدمن بس ولما السيرفر يبعت مديرين
        if (widget.isAdmin && managers.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsetsDirectional.only(start: 10, end: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: _mgrId,
                isExpanded: true,
                items: [
                  DropdownMenuItem<int?>(
                      value: null, child: Text(L.t('eq_all_company'))),
                  for (final m in managers.whereType<Map>())
                    DropdownMenuItem<int?>(
                      value: (m['id'] as num).toInt(),
                      child: Text('${m['name']}',
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) {
                  setState(() => _mgrId = v);
                  _load();
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),

        if (_err != null)
          Card(
            color: const Color(0xFFFDECEC),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.wifi_off, color: Color(0xFFDC2626)),
              title: Text(_err!, style: const TextStyle(fontSize: 12.5)),
              trailing: TextButton(onPressed: _load, child: Text(L.t('retry'))),
            ),
          )
        else if (d == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          // ═══ ١) المبيعات ═══
          _EqCard(
            color: const Color(0xFF16A34A),
            icon: Icons.payments_outlined,
            title: L.t('eq_sales'),
            value: money(_n(sales['total'])),
            minis: [
              (L.t('eq_cash'), money(_n(sales['cash']))),
              (L.t('eq_credit'), money(_n(sales['credit']))),
              (L.t('eq_pos'), money(_n(sales['pos']))),
            ],
          ),
          _EqOperator('−'),

          // ═══ ٢) التحصيل بمصادره ═══
          _EqCard(
            color: const Color(0xFF2563EB),
            icon: Icons.account_balance_wallet_outlined,
            title: L.t('eq_coll'),
            value: money(_n(coll['total'])),
            minis: [
              (L.t('eq_coll_inv'), money(_n(coll['invoice']))),
              (L.t('eq_coll_visit'), money(_n(coll['visit']))),
              (L.t('eq_coll_po'), money(_n(coll['po']))),
            ],
          ),
          _EqOperator('−'),

          // ═══ ٣) المرتجعات ═══
          _EqCard(
            color: const Color(0xFFDC2626),
            icon: Icons.assignment_return_outlined,
            title: L.t('eq_returns'),
            value: money(_n(rets['total'])),
            minis: [
              (L.t('eq_docs_n'), '${(rets['n'] as num?)?.toInt() ?? 0}'),
            ],
          ),
          _EqOperator('='),

          // ═══ ٤) صافي حركة المديونية ═══
          _EqCard(
            color: const Color(0xFF7C3AED),
            icon: Icons.swap_vert,
            title: L.t('eq_net'),
            value: money(_n(d['net_move'])),
            highlight: true,
            minis: [
              (L.t('eq_debt'),
                  '${money(_n(debt['total']))} • ${(debt['clients'] as num?)?.toInt() ?? 0}'),
            ],
          ),
          const SizedBox(height: 10),

          // ═══ سطر Billed/Unbilled + العهدة في الشارع ═══
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  title: 'Billed',
                  value: money(_n(sales['billed'])),
                  color: const Color(0xFF0F766E),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  title: 'Unbilled',
                  value: money(_n(sales['unbilled'])),
                  color: const Color(0xFFB86E00),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  title: L.t('eq_street'),
                  value: money(_n(street['value'])),
                  sub:
                      '${(street['vans'] as num?)?.toInt() ?? 0} 🚚 • ${(street['units'] as num?)?.toInt() ?? 0}',
                  color: const Color(0xFFEA8C1C),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// كارت معادلة: القيمة فوق كبيرة، الاسم تحتها، وميني بوكسات تحتيهم —
/// نفس تقسيمة داشبورد الويب (طلب المالك ٢٦/٨)
class _EqCard extends StatelessWidget {
  const _EqCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.value,
    this.minis = const [],
    this.highlight = false,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String value;
  final List<(String, String)> minis;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: highlight ? color.withValues(alpha: 0.07) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icon, color: color, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value,
                          style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: color)),
                      Text(title,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ],
            ),
            if (minis.isNotEmpty) ...[
              const SizedBox(height: 9),
              Row(
                children: [
                  for (final (t, v) in minis) ...[
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Column(
                          children: [
                            Text(v,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800)),
                            Text(t,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ),
                    if (minis.last != (t, v)) const SizedBox(width: 6),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// علامة العملية بين كروت المعادلة — «−» و«=»
class _EqOperator extends StatelessWidget {
  const _EqOperator(this.op);

  final String op;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Text(op,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade500)),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.title,
    required this.value,
    required this.color,
    this.sub,
  });

  final String title;
  final String value;
  final String? sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          Text(title,
              maxLines: 1,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
          if (sub != null)
            Text(sub!,
                maxLines: 1,
                style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

/// ═══ شبكة أدوات الإدارة — مداخل الشاشات الجديدة (كل شاشة ليها
/// مدخل — الدوكترين). بتتزرع تحت المعادلة في بورد المدير والأدمن ═══
class ManagerToolsGrid extends StatelessWidget {
  const ManagerToolsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, Color, String, Widget)>[
      (
        Icons.task_alt,
        const Color(0xFF7C3AED),
        L.t('tools_tasks'),
        const TasksScreen()
      ),
      (
        Icons.flag_outlined,
        const Color(0xFFEA8C1C),
        L.t('tools_leads'),
        const LeadsWatchScreen()
      ),
      (
        Icons.sensors,
        const Color(0xFF16A34A),
        L.t('tools_live'),
        const LiveBoardScreen()
      ),
      (
        Icons.workspace_premium_outlined,
        const Color(0xFF2563EB),
        L.t('tools_kpi'),
        const KpiScreen()
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(L.t('tools_title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (icon, color, label, screen) in items) ...[
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => screen)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Icon(icon, color: color, size: 23),
                        const SizedBox(height: 5),
                        Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: color)),
                      ],
                    ),
                  ),
                ),
              ),
              if (items.last.$3 != label) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}
