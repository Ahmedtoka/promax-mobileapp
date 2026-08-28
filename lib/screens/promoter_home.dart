import 'package:flutter/material.dart';
import '../l10n.dart';

import '../models.dart';
import '../promoter_models.dart';
import '../nav.dart';
import '../session.dart';
import 'attendance.dart';
import 'account.dart';
import 'shared.dart';
import 'promoter_visit.dart';
import 'supply_orders.dart';

class PromoterHome extends StatefulWidget {
  const PromoterHome({super.key});
  @override
  State<PromoterHome> createState() => _PromoterHomeState();
}

class _PromoterHomeState extends State<PromoterHome> with NavTarget {
  int _index = 0;

  // ═══ وجهة الإشعار (٨/٨/٢٠٢٦ — واتوسعت ١١/٨ مساءً) ═══
  // البروموتر بياخد قرارات طلبات الريفيل بتاعته، وبقى يستلم
  // ويسلّم أوامر توريد («نفس المندوب اللي طلبه» — قرار المالك).
  // الرئيسية ٠ · الفروع ١ · الريفيل ٢ · العهدة ٣ · التوريد ٤ · التتبع ٥
  @override
  int? tabForLink(String kind) => switch (kind) {
        'replenishment' => 2,
        'client' => 1,
        'pick' || 'custody' => 3,
        'po' => 4,
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
        // شارات زي تابات المندوب: أوامر تجهيز مستنية استلامه،
        // وأوامر توريد لسه ماتسلمتش
        final ready = Session.I.readyPicks;
        final openPos =
            Session.I.pos.where((p) => p.status != 'delivered').length;

        return Scaffold(
          body: IndexedStack(
            index: _index,
            children: const [
              PromoterDashboard(),
              BranchesScreen(),
              ReplenishmentsScreen(),
              CustodyScreen(),
              SupplyOrdersScreen(),
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
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront),
                  label: L.t('branches')),
              NavigationDestination(
                  icon: Icon(Icons.inventory_outlined),
                  selectedIcon: Icon(Icons.inventory),
                  label: L.t('refill_requests')),
              NavigationDestination(
                  icon: Badge(
                    isLabelVisible: ready > 0,
                    label: Text('$ready'),
                    child: const Icon(Icons.inventory_2_outlined),
                  ),
                  selectedIcon: const Icon(Icons.inventory_2),
                  label: L.t('custody')),
              NavigationDestination(
                  icon: Badge(
                    isLabelVisible: openPos > 0,
                    label: Text('$openPos'),
                    child: const Icon(Icons.local_shipping_outlined),
                  ),
                  selectedIcon: const Icon(Icons.local_shipping),
                  label: L.t('supply_tab')),
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

// ================= داشبورد البروموتر =================

class PromoterDashboard extends StatelessWidget {
  const PromoterDashboard({super.key});

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
    final st = s.promoStats;
    final open = s.openMerchVisit;

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
            // ⚠️ **البروموتر ماكانش عنده أي مدخل للحضور خالص** — يعني
            // مايقدرش ياخد بريك ولا ينصرف، واليومية بتتقفل أوتوماتيك
            // آخر الليل بساعات غلط بتروح للمرتبات.
            const AttendanceCard(),

            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.shelves, color: Colors.white),
                ),
                title: Text(L.t('hello_name', {'n': '${s.user?.name ?? ''}'}),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${s.user?.code ?? ''} • ${L.t('role_promoter')}${s.user?.zone != null ? ' — ${s.user!.zone}' : ''}'),
              ),
            ),

            if (open != null)
              Card(
                color: const Color(0xFFFFF4E0),
                child: ListTile(
                  leading:
                      const Icon(Icons.timelapse, color: Color(0xFFB86E00)),
                  title: Text(L.t('visit_open_with', {'c': '${open.client}'}),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(open.checkedInAt != null
                      ? L.t('since_t', {'t': '${fmtTime(open.checkedInAt!)}'})
                      : ''),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => VisitScreen(visit: open))),
                ),
              ),
            const SizedBox(height: 6),

            Row(
              children: [
                Kpi(
                    title: L.t('visits_today'),
                    value: '${st.visitsDone}/${st.branches}',
                    icon: Icons.storefront_outlined,
                    color: const Color(0xFF7C3AED)),
                const SizedBox(width: 10),
                Kpi(
                    title: L.t('moved_to_shelf'),
                    value: '${st.moved}',
                    icon: Icons.move_up,
                    color: const Color(0xFF16A34A)),
                const SizedBox(width: 10),
                Kpi(
                    title: L.t('refills'),
                    value: '${st.requests}',
                    icon: Icons.inventory_outlined,
                    color: const Color(0xFFEA8C1C)),
              ],
            ),
            const SizedBox(height: 16),

            Text(L.t('branches_today'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (s.branches.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                      child: Text(L.t('no_branches_assigned'),
                          style: TextStyle(color: Colors.grey.shade600))),
                ),
              ),
            ...s.branches.take(6).map((b) => BranchTile(branch: b)),
          ],
        ),
      ),
    );
  }
}

// ================= قايمة الفروع =================

class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});
  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  final _q = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final s = _q.text.trim().toLowerCase();
        var list = Session.I.branches.where((b) {
          if (s.isEmpty) return true;
          return b.name.toLowerCase().contains(s) ||
              b.address.toLowerCase().contains(s);
        }).toList();

        if (_filter == 'pending') {
          list = list.where((b) => b.status != BranchVisitStatus.done).toList();
        } else if (_filter == 'done') {
          list = list.where((b) => b.status == BranchVisitStatus.done).toList();
        }

        return Scaffold(
          appBar: AppBar(title: Text(L.t('ka_branches'))),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _q,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: L.t('search_branch'),
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE7E3DA)),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<String>(
                  style:
                      const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: [
                    ButtonSegment(value: 'all', label: Text(L.t('all'))),
                    ButtonSegment(value: 'pending', label: Text(L.t('pending'))),
                    ButtonSegment(value: 'done', label: Text(L.t('visited'))),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (v) => setState(() => _filter = v.first),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: Session.I.refresh,
                  child: list.isEmpty
                      ? ListView(children: [
                          SizedBox(height: 140),
                          Center(child: Text(L.t('no_branches'))),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: list.length,
                          itemBuilder: (context, i) =>
                              BranchTile(branch: list[i]),
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

class BranchTile extends StatelessWidget {
  final Branch branch;
  const BranchTile({super.key, required this.branch});

  Future<void> _open(BuildContext context) async {
    final s = Session.I;

    // زيارة مفتوحة على نفس الفرع؟ افتحها
    if (s.openMerchVisit != null && s.openMerchVisit!.clientId == branch.id) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => VisitScreen(visit: s.openMerchVisit!)));
      return;
    }

    if (branch.status == BranchVisitStatus.done) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.t('branch_visited'))));
      return;
    }

    final err = await s.startMerchVisit(branch);
    if (!context.mounted) return;

    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (s.openMerchVisit != null) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => VisitScreen(visit: s.openMerchVisit!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = branch;
    final (color, label, icon) = b.info;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(b.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.place_outlined,
                      size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(b.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade600)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (b.subChannel != null)
                    Chip2(text: b.subChannel!, color: const Color(0xFF7C3AED)),
                  if (b.movedToday > 0)
                    Chip2(
                        text: L.t('n_moved', {'n': '${b.movedToday}'}),
                        color: const Color(0xFF16A34A)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= طلبات الريفيل =================

class ReplenishmentsScreen extends StatelessWidget {
  const ReplenishmentsScreen({super.key});

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
    final list = Session.I.replenishments;

    return Scaffold(
      appBar: AppBar(title: Text(L.t('refill_requests'))),
      body: RefreshIndicator(
        onRefresh: Session.I.refresh,
        child: list.isEmpty
            ? ListView(children: [
                SizedBox(height: 160),
                Center(child: Text(L.t('no_refill_requests'))),
              ])
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final r = list[i];
                  final (color, label) = r.info;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.12),
                        child:
                            Icon(Icons.inventory, color: color, size: 19),
                      ),
                      title: Text(r.client,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13.5)),
                      subtitle: Text(
                          '${r.number} • ${L.t('n_units', {'n': '${r.qtyTotal}'})} • ${fmtTime(r.time)}',
                          style: const TextStyle(fontSize: 11.5)),
                      trailing: Text(label,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
