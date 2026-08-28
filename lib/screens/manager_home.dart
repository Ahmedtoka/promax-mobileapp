import 'package:flutter/material.dart';
import '../l10n.dart';

import '../models.dart';
import '../nav.dart';
import '../session.dart';
import 'attendance.dart';
import 'account.dart';
import 'shared.dart';
import 'journey.dart';
import 'zones.dart';
import 'supply_orders.dart';
import 'manager_reps.dart';
import 'manager_approvals.dart';
import 'manager_replenishments.dart';

class ManagerHome extends StatefulWidget {
  const ManagerHome({super.key});
  @override
  State<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome> with NavTarget {
  int _index = 0;

  // ═══ وجهة الإشعار (٨/٨/٢٠٢٦ — واتعدّلت مع تابات الميدان ١١/٨) ═══
  // البورد ٠ · خط السير ١ · المناطق ٢ · التوريد ٣ · الموافقات ٤ · الريفيل ٥
  @override
  int? tabForLink(String kind) => switch (kind) {
        'request' => 4,
        'replenishment' => 5,
        'po' => 3,
        'journey' => 1,
        'zone' => 2,
        'home' => 0,
        _ => null,
      };

  @override
  void goToTab(int index) => setState(() => _index = index);

  // ⚠️ «الفريق» و«العهدة» مابقوش تابات (١١/٨) — الوجهات دي بتفتح
  // شاشتها فوق الرئيسية بدل ما تضيع في `AppNav.pending` بلا قارئ.
  // `pick:`/`custody:` بيوصلوا للمدير لما المخزن يجهّز عهدته.
  @override
  void openLink(String link) {
    final Widget? screen = switch (AppNav.kindOf(link)) {
      'rep' => const ManagerRepsScreen(),
      'pick' || 'custody' => const CustodyScreen(),
      'attendance' => const AttendanceScreen(),
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
        final open = Session.I.openRequests.length;
        final rpl = Session.I.pendingReplenishments.length;
        // خطة المدير نفسه — الشارة بتفكّره باللي فاضل زي المندوب
        final pending = Session.I.journeySummary.pending;
        // أوامر التوريد المتسكّنة عليه ولسه ماتسلمتش
        final openPos =
            Session.I.pos.where((p) => p.status != 'delivered').length;

        // ⚠️ **٦ تابات بعد ما المدير بقى ميداني (قرار المالك ١١/٨):**
        // البورد ← خط السير ← المناطق ← التوريد ← الموافقات ← الريفيل.
        // شاشات الميدان هي **نفس شاشات المندوب** — الداتا بتيجي من
        // نفس حقول الجلسة اللي `_refreshManager` بقت بتملاها.
        // «الفريق» و«تحركات الفريق» و«العهدة» ماتشالوش — اتنقلوا
        // مداخل دائمة في البورد (كل شاشة لازم يكون ليها مدخل).
        return Scaffold(
          body: IndexedStack(
            index: _index,
            children: const [
              ManagerDashboard(),
              JourneyScreen(),
              ZonesScreen(),
              SupplyOrdersScreen(),
              ManagerApprovalsScreen(),
              ManagerReplenishmentsScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              NavigationDestination(
                  icon: const Icon(Icons.dashboard_outlined),
                  selectedIcon: const Icon(Icons.dashboard),
                  label: L.t('home')),
              NavigationDestination(
                  icon: Badge(
                    isLabelVisible: pending > 0,
                    label: Text('$pending'),
                    child: const Icon(Icons.alt_route_outlined),
                  ),
                  selectedIcon: const Icon(Icons.alt_route),
                  label: L.t('journey')),
              NavigationDestination(
                  icon: const Icon(Icons.map_outlined),
                  selectedIcon: const Icon(Icons.map),
                  label: L.t('zones')),
              NavigationDestination(
                  icon: Badge(
                    isLabelVisible: openPos > 0,
                    label: Text('$openPos'),
                    child: const Icon(Icons.local_shipping_outlined),
                  ),
                  selectedIcon: const Icon(Icons.local_shipping),
                  label: L.t('supply_tab')),
              NavigationDestination(
                  icon: Badge(
                    isLabelVisible: open > 0,
                    label: Text('$open'),
                    child: const Icon(Icons.fact_check_outlined),
                  ),
                  selectedIcon: const Icon(Icons.fact_check),
                  label: L.t('approvals')),
              NavigationDestination(
                  icon: Badge(
                    isLabelVisible: rpl > 0,
                    label: Text('$rpl'),
                    child: const Icon(Icons.inventory_2_outlined),
                  ),
                  selectedIcon: const Icon(Icons.inventory_2),
                  label: L.t('refill')),
            ],
          ),
        );
      },
    );
  }
}

// ================= داشبورد المدير =================

class ManagerDashboard extends StatelessWidget {
  const ManagerDashboard({super.key});

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
    final st = s.mgrStats;

    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('board')),
        actions: [
          // ⚠️ **المدير ماكانش عنده جرس خالص** — السيرفر بقى بيبعت
          // `notifications` في البوت ستراب (٨/٨/٢٠٢٦) ومفيش مكان
          // يعرضها فيه. باقي التلات رولز عندهم الجرس ده من زمان.
          IconButton(
            onPressed: () => showNotifications(context),
            icon: Badge(
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
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout),
          ),
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
                  child: const Icon(Icons.supervisor_account,
                      color: Colors.white),
                ),
                title: Text(L.t('hello_name', {'n': '${s.user?.name ?? ''}'}),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle:
                    Text('${s.user?.code ?? ''} • ${s.user?.roleLabel ?? ''}'),
              ),
            ),

            // تنبيه الطلبات المستنية
            if (st.openRequests > 0)
              Card(
                color: const Color(0xFFFFF4E0),
                child: ListTile(
                  leading: const Icon(Icons.pending_actions,
                      color: Color(0xFFB86E00)),
                  title: Text(L.t('open_client_requests', {'n': '${st.openRequests}'}),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(L.t('from_field_reps'),
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ManagerApprovalsScreen())),
                ),
              ),

            // تنبيه طلبات الريفيل من البروموتر
            if (s.pendingReplenishments.isNotEmpty)
              Card(
                color: const Color(0xFFEAF2FF),
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined,
                      color: Color(0xFF2563EB)),
                  title: Text(
                      L.t('open_refills', {'n': '${s.pendingReplenishments.length}'}),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(L.t('from_promoter'),
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ManagerReplenishmentsScreen())),
                ),
              ),
            const SizedBox(height: 6),

            Row(
              children: [
                Kpi(
                    title: L.t('sales_today'),
                    value: money(st.sales),
                    icon: Icons.payments_outlined,
                    color: const Color(0xFF16A34A)),
                const SizedBox(width: 10),
                Kpi(
                    title: L.t('deliveries_value'),
                    value: money(st.posValue),
                    icon: Icons.local_shipping_outlined,
                    color: const Color(0xFF2563EB)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Kpi(
                    title: L.t('visits_closed'),
                    value: '${st.visitsDone}/${st.visits}',
                    icon: Icons.storefront_outlined,
                    color: const Color(0xFFEA8C1C)),
                const SizedBox(width: 10),
                Kpi(
                    title: L.t('invoices'),
                    value: '${st.invoices}',
                    icon: Icons.receipt_long_outlined,
                    color: const Color(0xFF7C3AED)),
                const SizedBox(width: 10),
                Kpi(
                    title: L.t('reps_count'),
                    value: '${st.fieldUsers}',
                    icon: Icons.groups_outlined,
                    color: const Color(0xFF0F766E)),
              ],
            ),
            const SizedBox(height: 10),

            // ═══ عهدة المدير الميداني (١١/٨) — مدخل الاستلام ═══
            // ⚠️ العهدة مش تاب في شريط المدير (٦ تابات خلاص) — الكارت
            // ده هو المدخل الدائم: جواه بانر «أمر تجهيز مستنيك» وسطر
            // الخروج من المخزن، زي تاب العهدة عند المندوب بالظبط.
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(L.t('reps_now'),
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ManagerRepsScreen())),
                  child: Text(L.t('all')),
                ),
              ],
            ),
            ...s.reps.take(4).map((r) => RepCard(rep: r)),

            const SizedBox(height: 12),
            // ⚠️ «تحركات الفريق» مابقتش تاب (١١/٨) — «الكل» هنا هو
            // مدخلها الدائم، زي «الفريق» فوق بالظبط.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(L.t('latest_activity'),
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const TeamTimelineScreen())),
                  child: Text(L.t('all')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...s.teamEvents.take(8).map((e) => EventTile(event: e)),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L.t('logout')),
        content: Text(L.t('logout_confirm')),
        actions: [
          OutlinedButton(style: kDialogCancel, onPressed: () => Navigator.pop(ctx), child: Text(L.t('cancel'))),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Session.I.logout();
            },
            child: Text(L.t('logout')),
          ),
        ],
      ),
    );
  }
}

// ================= تايم لاين الفريق =================

class TeamTimelineScreen extends StatelessWidget {
  const TeamTimelineScreen({super.key});

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
    final events = Session.I.teamEvents;

    return Scaffold(
      appBar: AppBar(title: Text(L.t('team_activity'))),
      body: RefreshIndicator(
        onRefresh: Session.I.refresh,
        child: events.isEmpty
            ? ListView(
                children: [
                  SizedBox(height: 200),
                  Center(child: Text(L.t('no_activity'))),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                itemBuilder: (context, i) => EventTile(event: events[i]),
              ),
      ),
    );
  }
}

class EventTile extends StatelessWidget {
  final TeamEvent event;
  const EventTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (event.type) {
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
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(event.title,
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        subtitle: Text(
            '${event.user}${event.subtitle.isEmpty ? '' : ' • ${event.subtitle}'}',
            style: const TextStyle(fontSize: 11.5)),
        trailing: Text(fmtTime(event.time),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ),
    );
  }
}
