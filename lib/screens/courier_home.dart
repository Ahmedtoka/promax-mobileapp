import 'package:flutter/material.dart';
import '../l10n.dart';

import '../models.dart';
import '../nav.dart';
import '../session.dart';
import 'attendance.dart';
import 'account.dart';
import 'shared.dart';
import 'pick_orders.dart';

class CourierHome extends StatefulWidget {
  const CourierHome({super.key});
  @override
  State<CourierHome> createState() => _CourierHomeState();
}

class _CourierHomeState extends State<CourierHome> with NavTarget {
  int _index = 0;

  // ═══ وجهة الإشعار (٨/٨/٢٠٢٦) ═══
  // ⚠️ **السواق هو أكتر واحد بياخد إشعارات أوامر توريد** — وكان
  // الوحيد اللي مابيستقبلش الوجهة، فالإشعار بيفتح الرئيسية.
  // الرئيسية ٠ · الأوامر ١ · التجهيز ٢ · العهدة ٣ · التتبع ٤
  @override
  int? tabForLink(String kind) => switch (kind) {
        'po' => 1,
        'pick' => 2,
        'custody' => 3,
        'home' => 0,
        _ => null,
      };

  @override
  void goToTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final ready = Session.I.readyPicks;

        return Scaffold(
          body: IndexedStack(
            index: _index,
            children: const [
              CourierDashboard(),
              PosScreen(),
              PickOrdersScreen(),
              CustodyScreen(),
              TrackingScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: L.t('home')),
              NavigationDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment),
                  label: L.t('requests')),
              NavigationDestination(
                  icon: Badge(
                    isLabelVisible: ready > 0,
                    label: Text('$ready'),
                    child: const Icon(Icons.move_to_inbox_outlined),
                  ),
                  selectedIcon: const Icon(Icons.move_to_inbox),
                  label: L.t('warehouse')),
              NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: L.t('custody')),
              NavigationDestination(
                  icon: Icon(Icons.route_outlined),
                  selectedIcon: Icon(Icons.route),
                  label: L.t('tracking')),
            ],
          ),
        );
      },
    );
  }
}

class CourierDashboard extends StatelessWidget {
  const CourierDashboard({super.key});

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
    final active = s.activePo;

    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('home')),
        actions: [
          IconButton(
            onPressed: () => showNotifications(context),
            icon: Badge(
              // الشارة = المش مقروء بس (إصلاح 2026-08-07)
              isLabelVisible: s.unreadCount > 0,
              label: Text('${s.unreadCount}'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          // ⚠️ **«حسابي» كانت للمندوب بس** (تدقيق ٨/٨/٢٠٢٦) — وجواها
          // **مبدّل اللغة**. يعني السواق والبروموتر والمدير ماكانوش
          // يقدروا يغيّروا لغة الأبلكيشن من جوّاه خالص: الطريقة
          // الوحيدة إنه يخرج ويغيّرها من شاشة الدخول ويدخل تاني.
          IconButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountScreen())),
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
              onPressed: () => confirmLogout(context),
              icon: const Icon(Icons.logout)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: s.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ═══ الحضور — **فوق كل حاجة** (تدقيق ٨/٨/٢٠٢٦) ═══
            // ⚠️ **الرول ده ماكانش عنده أي مدخل للحضور خالص** — يعني
            // مايقدرش ياخد بريك ولا ينصرف. الكارت كان في شاشة المندوب
            // بس، والسواق والبروموتر والمدير بيسجّلوا حضور ومايعرفوش
            // يقفلوه، فاليومية بتتقفل أوتوماتيك آخر الليل بساعات غلط.
            const AttendanceCard(),

            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.local_shipping, color: Colors.white),
                ),
                title: Text(L.t('hello_name', {'n': '${s.user?.name ?? ''}'}),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${s.user?.code ?? ''} • ${L.t('role_driver')}'),
              ),
            ),

            if (active != null)
              Card(
                color: const Color(0xFFFFF4E0),
                child: ListTile(
                  leading: const Icon(Icons.local_shipping,
                      color: Color(0xFFB86E00)),
                  title: Text(L.t('delivering_to', {'c': '${active.client}'}),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: active.arrivedAt != null
                      ? Text(L.t('arrived_at_t', {'t': '${fmtTime(active.arrivedAt!)}'}))
                      : null,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PoScreen(po: active))),
                ),
              ),
            const SizedBox(height: 6),

            Row(
              children: [
                Kpi(
                    title: L.t('deliveries_today'),
                    value: '${s.today.posDelivered}/${s.pos.length}',
                    icon: Icons.assignment_turned_in_outlined,
                    color: const Color(0xFF2563EB)),
                const SizedBox(width: 10),
                Kpi(
                    title: L.t('delivered_value'),
                    value: money(s.today.posValue),
                    icon: Icons.payments_outlined,
                    color: const Color(0xFF16A34A)),
                const SizedBox(width: 10),
                Kpi(
                    title: L.t('custody_left'),
                    value: '${s.custody.remainingUnits}',
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xFFEA8C1C)),
              ],
            ),
            const SizedBox(height: 16),

            Text(L.t('requests_today'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (s.pos.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                      child: Text(L.t('no_pos'),
                          style: TextStyle(color: Colors.grey.shade600))),
                ),
              ),
            ...s.pos.map((po) => PoCard(po: po)),
          ],
        ),
      ),
    );
  }
}

// ================= قايمة الريكوستات =================

class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

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
    final done = s.pos.where((p) => p.status == 'delivered').length;

    return Scaffold(
      appBar: AppBar(title: Text(L.t('requests'))),
      body: RefreshIndicator(
        onRefresh: s.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(L.t('delivered_of', {'a': '$done', 'b': '${s.pos.length}'}),
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 10),
            ...s.pos.map((po) => PoCard(po: po)),
          ],
        ),
      ),
    );
  }
}

class PoCard extends StatelessWidget {
  final PurchaseOrder po;
  const PoCard({super.key, required this.po});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (po.status) {
      'delivered' => (const Color(0xFF16A34A), L.t('delivered')),
      'arrived' => (const Color(0xFFB86E00), L.t('delivering_now')),
      _ => (Colors.grey, L.t('waiting')),
    };
    // ⚠️ من العلم الثابت — المقارنة القديمة كانت نص حر × نص مترجم،
    // فاللون كان غلط في لغة من الاتنين دايماً (تدقيق ٩/٨)
    final srcColor = po.isReplenishment
        ? const Color(0xFFEA8C1C)
        : const Color(0xFF7C3AED);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => PoScreen(po: po))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip2(text: po.source, color: srcColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(po.client,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14.5)),
                  ),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ],
              ),
              const SizedBox(height: 8),
              Text('${po.number} • ${L.t('n_units', {'n': '${po.qtyTotal}'})} • ${money(po.total)}',
                  style:
                      TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.place_outlined,
                      size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(po.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= تفاصيل الـ PO =================

class PoScreen extends StatefulWidget {
  final PurchaseOrder po;
  const PoScreen({super.key, required this.po});

  @override
  State<PoScreen> createState() => _PoScreenState();
}

class _PoScreenState extends State<PoScreen> {
  bool _busy = false;

  Future<void> _run(Future<String?> Function() action, String okMsg) async {
    setState(() => _busy = true);
    final err = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(err ?? okMsg)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final po =
            firstOrNull(Session.I.pos.where((p) => p.id == widget.po.id)) ??
                widget.po;

        return Scaffold(
          appBar: AppBar(title: Text(po.number)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(po.client,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      InfoRow(icon: Icons.place_outlined, text: po.address),
                      InfoRow(
                          icon: Icons.store_outlined,
                          text: L.t('source_is', {'s': '${po.source}'})),
                      if (po.arrivedAt != null)
                        InfoRow(
                            icon: Icons.login,
                            text: '${L.t('arrive')}: ${fmtTime(po.arrivedAt!)}'),
                      if (po.deliveredAt != null)
                        InfoRow(
                            icon: Icons.done_all,
                            text: '${L.t('deliver')}: ${fmtTime(po.deliveredAt!)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Text(L.t('order_lines'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ...po.items.map((i) => ListTile(
                          dense: true,
                          title: Text(i.name,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(i.unit,
                              style: const TextStyle(fontSize: 11)),
                          trailing: Text(
                              '${i.qty} × ${money(i.price)} = ${money(i.total)}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        )),
                    const Divider(height: 1),
                    ListTile(
                      title: Text(L.t('total'),
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text(money(po.total),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (_busy) const LinearProgressIndicator(),

              if (po.status == 'pending')
                FilledButton.icon(
                  icon: const Icon(Icons.location_on_outlined),
                  label: Text(L.t('arrived_at_place'),
                      style: TextStyle(fontSize: 16)),
                  onPressed: _busy
                      ? null
                      : () => _run(() => Session.I.arrivePo(po),
                          L.t('arrival_logged')),
                ),

              if (po.status == 'arrived')
                FilledButton.icon(
                  icon: const Icon(Icons.done_all),
                  label: Text(L.t('delivered_deducted'),
                      style: TextStyle(fontSize: 16)),
                  onPressed: _busy
                      ? null
                      // السواق بيسلم كامل زي ما هو — الرد الجديد (خطأ، سامري)
                      : () => _run(() async {
                          final (err, _) = await Session.I.deliverPo(po);
                          return err;
                        }, L.t('delivered_deducted_n', {'n': '${po.qtyTotal}'})),
                ),

              if (po.status == 'delivered')
                Card(
                  color: const Color(0xFFE7F7EE),
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF16A34A)),
                        SizedBox(width: 10),
                        Text(L.t('order_delivered'),
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
