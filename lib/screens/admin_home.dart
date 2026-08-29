import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models.dart';
import '../nav.dart';
import '../session.dart';
import 'account.dart';
import 'attendance.dart';
import 'manager_approvals.dart';
import 'manager_dash.dart';
import 'manager_home.dart' show EventTile, TeamTimelineScreen;
import 'manager_replenishments.dart';
import 'manager_reps.dart';
import 'shared.dart';
import 'supply_orders.dart';

/// ═══════════════════════════════════════════════════════════════
/// شاشة الأدمن المستقلة (٢٨/٨/٢٠٢٦ — قرار المالك)
/// ═══════════════════════════════════════════════════════════════
///
/// الأدمن كان بيدخل على شاشة المدير بالظبط — بتوابع ميدانية مالهاش
/// لازمة ليه (خط سير، مناطق، عهدة). دي شاشته: ٤ تابات —
/// البورد (معادلة الشركة كلها + فلتر «بعيون مدير») · التوريد ·
/// الموافقات · الريفيل. الداتا من نفس بوت ستراب المدير
/// (`todayTotals` أصلاً على مستوى الشركة، والـAPI بيسمح للأدمن).
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> with NavTarget {
  int _index = 0;

  // وجهات الإشعارات — نفس أنواع المدير بترتيب تاباتنا
  @override
  int? tabForLink(String kind) => switch (kind) {
        'po' => 1,
        'request' => 2,
        'replenishment' => 3,
        'home' => 0,
        _ => null,
      };

  @override
  void goToTab(int index) => setState(() => _index = index);

  @override
  void openLink(String link) {
    final Widget? screen = switch (AppNav.kindOf(link)) {
      'rep' => const ManagerRepsScreen(),
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
        final s = Session.I;
        final open = s.openRequests.length;
        final rpl = s.pendingReplenishments.length;
        final openPos = s.pos.where((p) => p.status != 'delivered').length;

        return Scaffold(
          body: IndexedStack(
            index: _index,
            children: const [
              AdminDashboard(),
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

/// بورد الأدمن — أرقام الشركة كلها + «بعيون مدير» + كل المداخل
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // ⚠️ ListenableBuilder إجبارية — الشاشة const جوه IndexedStack
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
        title: Text(L.t('adm_title')),
        actions: [
          IconButton(
            onPressed: () => showNotifications(context),
            icon: Badge(
              isLabelVisible: s.unreadCount > 0,
              label: Text('${s.unreadCount}'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountScreen())),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: s.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child:
                      const Icon(Icons.workspace_premium, color: Colors.white),
                ),
                title: Text(L.t('hello_name', {'n': '${s.user?.name ?? ''}'}),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(L.t('adm_sub')),
              ),
            ),

            // ═══ لمحة النهارده — الشركة كلها ═══
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
            const SizedBox(height: 14),

            // ═══ معادلة الشركة + «بعيون مدير» ═══
            const ManagerEquationBoard(isAdmin: true),
            const SizedBox(height: 14),

            // ═══ أدوات الإدارة: المهام · المحتملين · اللايف · KPI ═══
            const ManagerToolsGrid(),
            const SizedBox(height: 12),

            // ═══ الفريق وآخر الحركة ═══
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(L.t('reps_now'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ManagerRepsScreen())),
                  child: Text(L.t('all')),
                ),
              ],
            ),
            ...s.reps.take(4).map((r) => RepCard(rep: r)),

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(L.t('latest_activity'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const TeamTimelineScreen())),
                  child: Text(L.t('all')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...s.teamEvents.take(8).map((e) => EventTile(event: e)),

            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => confirmLogout(context),
                icon: const Icon(Icons.logout, size: 17),
                label: Text(L.t('logout')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
