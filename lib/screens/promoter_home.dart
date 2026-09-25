import 'package:flutter/material.dart';
import '../l10n.dart';

import '../models.dart';
import '../promoter_models.dart';
import '../nav.dart';
import '../session.dart';
import 'attendance.dart';
import 'account.dart';
import 'shared.dart';
import 'journey.dart';
import 'promoter_visit.dart';
import 'supply_orders.dart';
import 'zones.dart' show ZonesScreen;

class PromoterHome extends StatefulWidget {
  const PromoterHome({super.key});
  @override
  State<PromoterHome> createState() => _PromoterHomeState();
}

class _PromoterHomeState extends State<PromoterHome> with NavTarget {
  int _index = 0;

  // ═══ إعادة بناء شاشة المنسق (٢٨/٨ — قرار المالك بالحرف) ═══
  //
  // «هو يبقى عنده الرئيسية والمناطق وخط السير وصفحة الشخصية —
  // وشيل أي حاجة ملهاش لازمة». ٤ تابات بس:
  //   الرئيسية ٠ · المناطق ١ (بالتسكين الحقيقي) · خط السير ٢ · حسابي ٣
  //
  // الفروع والريفيل والتوريد والتتبع والعهدة **مش تابات** — الريفيل
  // والتوريد والعهدة بقوا كروت مداخل في الرئيسية (دوكترين «كل شاشة
  // ليها مدخل»)، والتتبع اتشال خالص.
  @override
  int? tabForLink(String kind) => switch (kind) {
        'client' || 'zone' => 1,
        'journey' => 2,
        'home' => 0,
        _ => null,
      };

  @override
  void goToTab(int index) => setState(() => _index = index);

  // اللينكات اللي مابقتش تابات — بتفتح شاشتها فوق الرئيسية بدل ما
  // تضيع في `AppNav.pending` بلا قارئ (نفس نمط المدير ١١/٨)
  @override
  void openLink(String link) {
    final Widget? screen = switch (AppNav.kindOf(link)) {
      'replenishment' => const ReplenishmentsScreen(),
      'po' => const SupplyOrdersScreen(),
      'pick' || 'custody' => const CustodyScreen(),
      _ => null,
    };

    if (screen != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        // شارة خط السير: محطات خطة النهارده الفاضلة
        final pending = Session.I.journeySummary.pending;

        return Scaffold(
          body: IndexedStack(
            index: _index,
            children: const [
              PromoterDashboard(),
              // المناطق — نفس شاشة المندوب، بالعملاء المتسكنين فعلاً
              ZonesScreen(),
              JourneyScreen(),
              AccountScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: L.t('home')),
              NavigationDestination(
                  icon: const Icon(Icons.map_outlined),
                  selectedIcon: const Icon(Icons.map),
                  label: L.t('zones')),
              NavigationDestination(
                  icon: Badge(
                    isLabelVisible: pending > 0,
                    label: Text('$pending'),
                    child: const Icon(Icons.alt_route_outlined),
                  ),
                  selectedIcon: const Icon(Icons.alt_route),
                  label: L.t('journey')),
              NavigationDestination(
                  icon: const Icon(Icons.person_outline),
                  selectedIcon: const Icon(Icons.person),
                  label: L.t('account')),
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

            // ═══ مداخل الشاشات اللي مابقتش تابات (٢٨/٨) ═══
            // طلبات الريفيل — شغل المنسق الأساسي، دايماً ظاهر
            Card(
              child: ListTile(
                leading: Badge(
                  isLabelVisible: s.replenishments.isNotEmpty,
                  label: Text('${s.replenishments.length}'),
                  child: const Icon(Icons.inventory_outlined,
                      color: Color(0xFFEA8C1C)),
                ),
                title: Text(L.t('refill_requests'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ReplenishmentsScreen())),
              ),
            ),

            // التوريد — بيظهر بس لو فيه أوامر عليه فعلاً
            if (s.pos.any((p) => p.status != 'delivered'))
              Card(
                child: ListTile(
                  leading: Badge(
                    label: Text(
                        '${s.pos.where((p) => p.status != 'delivered').length}'),
                    child: const Icon(Icons.local_shipping_outlined,
                        color: Color(0xFF2563EB)),
                  ),
                  title: Text(L.t('supply_tab'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SupplyOrdersScreen())),
                ),
              ),

            // ═══ العهدة — كارت شرطي بدل التاب (٢٨/٨) ═══
            // البروموتر عادةً مايشيلش عهدة، فالتاب اتشال وخط السير
            // خد مكانه. الكارت ده بيظهر **بس** لو فيه فعلاً بضاعة
            // عليه أو أمر تجهيز مستنيه — دوكترين «كل شاشة ليها مدخل»
            // من غير ما تاب فاضي ياخد مكان في الشريط.
            if (s.custody.remainingUnits > 0 || s.readyPicks > 0) ...[
              Card(
                child: ListTile(
                  leading: Badge(
                    isLabelVisible: s.readyPicks > 0,
                    label: Text('${s.readyPicks}'),
                    child: const Icon(Icons.inventory_2_outlined,
                        color: Color(0xFFEA8C1C)),
                  ),
                  title: Text(L.t('custody'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(
                      '${L.t('custody_left')}: ${s.custody.remainingUnits}',
                      style: const TextStyle(fontSize: 11.5)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const CustodyScreen())),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // ═══ «فروع النهارده» (اتوضحت ٢٨/٨ — بلاغ «جايب العملاء
            // منين؟») ═══
            // لو المالك جدوله خط سير، القايمة هي **محطات الخطة**
            // بترتيبها. لو مفيش خطة، فولباك فروع منطقته زي زمان —
            // بعنوان مختلف عشان الشاشة تقول مصدرها.
            if (s.journey.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(L.t('journey_today'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                      '${s.journeySummary.done}/${s.journeySummary.planned}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 8),
              // المحطة بتترسم بكارت الفرع بتاعها (فيه زرار الزيارة
              // وحالتها) — ولو المحطة عميل مش في فروع زونه (المدير
              // حاطه في الخطة) بنرسم كارت مبسط بدل ما نسقطه في صمت
              ...s.journey.take(6).map((stop) {
                final branch =
                    firstOrNull(s.branches.where((b) => b.id == stop.clientId));

                return branch != null
                    ? BranchTile(branch: branch)
                    : Card(
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.storefront_outlined),
                          title: Text(stop.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          subtitle: Text(stop.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11)),
                        ),
                      );
              }),
            ] else ...[
              // ⚠️ مفيش خطة النهارده — مدخل للمناطق بدل قايمة الزون
              // القديمة (heuristic كانت بتوري عملاء مش متسكنين عليه)
              Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.map_outlined, color: Color(0xFF0F766E)),
                  title: Text(L.t('no_plan_go_zones'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13.5)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ZonesScreen())),
                ),
              ),
            ],
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

  Future<void> _open(BuildContext context) => openMerchBranch(context, branch);

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
