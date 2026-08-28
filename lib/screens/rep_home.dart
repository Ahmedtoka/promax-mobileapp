import 'dart:math';

import 'package:flutter/material.dart';
// ⚠️ لتثبيت ستايل شريط الحالة (بلاغ ٢١/٨) — أيقونات الساعة والشبكة
// كانت بتتغيّر من تاب لتاب وبتضيع لما نرجع من شاشة هيدرها غامق.
import 'package:flutter/services.dart';

import '../api.dart';

import '../brand.dart';
import '../l10n.dart';
import '../models.dart';
import '../nav.dart';
import '../locator.dart';
import '../session.dart';
import 'journey.dart';
import 'leads.dart';
import 'shared.dart';
import 'zones.dart';
import 'new_client.dart';
import 'client_requests.dart';
import 'account.dart';
import 'incentives.dart';
import 'sales_history.dart';
import 'supply_orders.dart';
import 'attendance.dart';

class RepHome extends StatefulWidget {
  const RepHome({super.key});
  @override
  State<RepHome> createState() => _RepHomeState();
}

class _RepHomeState extends State<RepHome>
    with NavTarget, WidgetsBindingObserver {
  /// عودة من الخلفية (فلو الليد ٢٦/٨): لو فيه «عميل محتمل جمبك»
  /// اتنبّه عليه بإشعار وهو قافل — الشيت بيطلع فوراً هنا
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      LeadWatcher.onResumed(context);
    }
  }

  int _index = 0;

  // ═══ وجهة الإشعار — المِكسِن بيعمل الاستماع والتصفير ═══
  // الرئيسية ٠ · خط السير ١ · المناطق ٢ · العهدة ٣ · التوريد ٤ · حسابي ٥
  @override
  int? tabForLink(String kind) => switch (kind) {
        'po' => 4,
        // ⚠️ «طلب عميلك اتوافق عليه» كان بيقع على «مفتاح مش معروف
        // = الرئيسية» — تاب حسابي هو اللي فيه كارت طلبات العملاء
        'request' => 5,
        'pick' || 'custody' => 3,
        'journey' => 1,
        'zone' => 2,
        'home' => 0,
        _ => null,
      };

  @override
  void goToTab(int index) => setState(() => _index = index);

  @override
  void openLink(String link) {
    if (AppNav.kindOf(link) == 'attendance') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const AttendanceScreen(),
      ));
    }
  }

  @override
  void initState() {
    super.initState();   // ← المِكسِن بيسجّل المستمع هنا
    WidgetsBinding.instance.addObserver(this);   // مراقب الخلفية/العودة
    // مراقب الليدز — أليرت نمط أوبر لما يعدي جمب عميل محتمل (2026-08-06)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) LeadWatcher.start(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LeadWatcher.stop();
    super.dispose();     // ← والمِكسِن بيشيله هنا
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final ready = Session.I.readyPicks;
        final pending = Session.I.journeySummary.pending;
        // أوامر توريد الكي أكاونت اللي لسه ماتسلمتش — شارة تاب التوريد
        final openPos =
            Session.I.pos.where((p) => p.status != 'delivered').length;

        // ⚠️ **ستايل شريط الحالة مثبّت هنا للتابات الستة** (بلاغ ٢١/٨):
        // كل التابات خلفيتها فاتحة وهيدرها كارت متدرج، فالأيقونات
        // **غامقة دايماً**. من غير التثبيت ده، الرجوع من شاشة بهيدر
        // مليان (زي شاشة العميل) كان بيسيب الأيقونات بيضا على أبيض.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: Scaffold(
          // ⚠️ **5 تابات بترتيب يوم المندوب** (قرار المالك 2026-08-02):
          // الرئيسية ← خط السير ← المناطق ← العهدة ← حسابي.
          // أوامر التجهيز بقت جوه العهدة (بانر استلام فوقها)، والتتبع
          // واللغة والخروج اتنقلوا لـ«حسابي».
          // ⚠️ 6 تابات بعد إضافة «التوريد» (قرار المالك 2026-08-04):
          // الرئيسية ← خط السير ← المناطق ← العهدة ← التوريد ← حسابي
          // ⚠️ 7 تابات بعد إضافة «المحتملين» (بايبلاين ٢٦/٨):
          // الرئيسية ← خط السير ← المناطق ← المحتملين ← العهدة
          // ← التوريد ← حسابي
          body: IndexedStack(
            index: _index,
            children: const [
              RepDashboard(),
              JourneyScreen(),
              ZonesScreen(),
              LeadsScreen(),
              CustodyScreen(),
              SupplyOrdersScreen(),
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
                  icon: Badge(
                    // العدد اللي لسه في خطة اليوم — بيفكّر المندوب
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
              // العملاء المحتملين (بايبلاين ٢٦/٨) — بالمناطق زي العملاء
              NavigationDestination(
                  icon: const Icon(Icons.flag_outlined),
                  selectedIcon: const Icon(Icons.flag),
                  label: L.t('leads_tab')),
              NavigationDestination(
                  // ⚠️ الشارة = أوامر تجهيز مستنية استلامه — العهدة
                  // الجديدة جواها دلوقتي
                  icon: Badge(
                    isLabelVisible: ready > 0,
                    label: Text('$ready'),
                    child: const Icon(Icons.inventory_2_outlined),
                  ),
                  selectedIcon: const Icon(Icons.inventory_2),
                  label: L.t('custody')),
              NavigationDestination(
                  // ⚠️ الشارة = أوامر توريد لسه ماتسلمتش للفروع
                  icon: Badge(
                    isLabelVisible: openPos > 0,
                    label: Text('$openPos'),
                    child: const Icon(Icons.local_shipping_outlined),
                  ),
                  selectedIcon: const Icon(Icons.local_shipping),
                  label: L.t('supply_tab')),
              NavigationDestination(
                  icon: const Icon(Icons.person_outline),
                  selectedIcon: const Icon(Icons.person),
                  label: L.t('account')),
            ],
          ),
          ),
        );
      },
    );
  }
}

class RepDashboard extends StatefulWidget {
  const RepDashboard({super.key});

  @override
  State<RepDashboard> createState() => _RepDashboardState();
}

/// ⚠️ Stateful (٢٠/٨): بنجيب نقطة GPS مرة واحدة لحساب مسافة
/// الزيارة الجاية، ونسبة تارجت الشهر لكارت حوافزي — الاتنين
/// تجميل، فشلهم مش بيعطل الهوم.
class _RepDashboardState extends State<RepDashboard> {
  (double, double)? _pos;
  double? _incPct;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final p = await Locator.get();
    if (mounted && p != null) setState(() => _pos = p);

    try {
      final d = await Api.I.myIncentives();
      final t = (d['targets'] ?? {}) as Map<String, dynamic>;
      final m = t['money'];
      final pct = m is Map ? (m['pct'] as num?)?.toDouble() : null;
      if (mounted && pct != null) setState(() => _incPct = pct);
    } catch (_) {
      // مفيش تارجتات متظبطة؟ — الكارت بيشتغل من غير النسبة
    }
  }

  String _clock(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? L.t('am') : L.t('pm')}';
  }

  /// مسافة تقريبية للعميل — من آخر نقطة GPS، بسرعة مدينة ~18كم/س
  String? _distanceLabel(Client c) {
    final p = _pos;
    if (p == null || c.lat == null || c.lng == null) return null;

    double rad(double d) => d * pi / 180;
    final dLat = rad(c.lat! - p.$1);
    final dLng = rad(c.lng! - p.$2);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(rad(p.$1)) * cos(rad(c.lat!)) * sin(dLng / 2) * sin(dLng / 2);
    final km = 2 * 6371.0 * atan2(sqrt(a), sqrt(1 - a));

    if (km > 200) return null; // نقطة زايغة — نسكت أحسن من رقم مضحك

    final mins = (km / 0.3).ceil().clamp(1, 999);

    return L.t('dist_km_min', {'k': km.toStringAsFixed(1), 'm': '$mins'});
  }

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
    final zone = s.todayZone;
    final active = s.activeClient;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: s.refresh,
          child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            // ═══ الهيدر بالتدرج (إعادة تصميم ٢٠/٨) ═══
            // الترحيب والجرس واللغة في كارت واحد — مفيش آب بار خالص،
            // زي الموك أب بالظبط. الدوسة على الاسم بتفتح «حسابي».
            _header(context, s, zone),
            const SizedBox(height: 10),

            if (active != null)
              Card(
                color: const Color(0xFFFFF4E0),
                child: ListTile(
                  leading:
                      const Icon(Icons.storefront, color: Color(0xFFB86E00)),
                  title: Text(L.t('visit_open_with', {'c': '${active.name}'}),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: active.checkInAt != null
                      ? Text('${L.t('check_in')} ${fmtTime(active.checkInAt!)}')
                      : null,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ClientScreen(client: active))),
                ),
              ),

            // ═══ الزيارة الجاية — كارت البطل (٢٠/٨) ═══
            _nextVisitCard(context, s),

            // ═══ أرقام النهاردة ═══
            Row(
              children: [
                Kpi(
                    title: L.t('sales_today'),
                    value: money(s.today.sales),
                    icon: Icons.payments_outlined,
                    color: const Color(0xFF16A34A),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const SalesHistoryScreen()))),
                const SizedBox(width: 10),
                Kpi(
                    title: L.t('custody_left'),
                    value: '${s.custody.remainingUnits}',
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xFFEA8C1C),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const CustodyScreen()))),
                const SizedBox(width: 10),
                Kpi(
                    title: L.t('visits'),
                    value: '${s.today.visitsDone}/${zone?.clients.length ?? 0}',
                    icon: Icons.storefront_outlined,
                    color: const Color(0xFF2563EB),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const JourneyScreen()))),
              ],
            ),
            const SizedBox(height: 14),

            // ═══ «محتاج منك» — الأكشنات اللي مستنياه (٢٠/٨) ═══
            ..._needYou(context, s),

            // بحث سريع في الزون
            if (zone != null)
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ZoneScreen(zone: zone))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.grey.shade600),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              L.t('search_in_zone', {'z': '${zone.name}', 'n': '${zone.clients.length}'}),
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade600)),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 6),

            // طلبات العملاء الجدد
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(L.t('new_client_requests'),
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // الرئيسية بتعرض آخر ٥ بس — «الكل» بيفتح الليستة
                    if (s.requests.length > 5)
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    const ClientRequestsScreen())),
                        child: Text(L.t('view_all'),
                            style: const TextStyle(fontSize: 12.5)),
                      ),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const NewClientScreen())),
                      icon: const Icon(Icons.person_add_alt, size: 17),
                      label: Text(L.t('new_client')),
                    ),
                  ],
                ),
              ],
            ),
            if (s.requests.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(L.t('new_client_hint'),
                        style: TextStyle(
                            fontSize: 12.5, color: Colors.grey.shade600)),
                  ),
                ),
              ),
            // ⚠️ **آخر ٥ بس** (طلب المالك ٢٠/٨) — الرئيسية لمحة سريعة
            // مش أرشيف. الليستة الكاملة في شاشة «طلبات العملاء الجدد».
            ...s.requests.take(5).map((r) {
              final (color, label) = r.info;
              // ═══ المعتمد كليك أبل من الرئيسية كمان (١٩/٨) ═══
              final sellable = r.status == 'approved';

              return Card(
                child: ListTile(
                  onTap: !sellable
                      ? null
                      : () {
                          final c = r.clientId == null
                              ? null
                              : Session.I.clientById(r.clientId!);

                          if (c == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        L.t('request_client_syncing'))));
                            Session.I.refresh();
                            return;
                          }

                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ClientScreen(client: c)));
                        },
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Icon(Icons.storefront, color: color, size: 19),
                  ),
                  title: Text(r.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text('${r.number} • ${fmtTime(r.time)}',
                      style: const TextStyle(fontSize: 11.5)),
                  // ⚠️ الجملة الخضرا اتشالت (طلب المالك ٢٠/٨) —
                  // الحالة + سهم دخول للمتوافق عليه وبس
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: color)),
                      if (sellable)
                        Icon(Icons.chevron_left, size: 18, color: color),
                    ],
                  ),
                ),
              );
            }),
          ],
          ),
        ),
      ),
    );
  }

  // ═══════════ الهيدر بالتدرج ═══════════

  Widget _header(BuildContext context, Session s, Zone? zone) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        gradient: Brand.gradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: [
        Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AccountScreen())),
              child: Row(children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: Colors.white.withValues(alpha: .18),
                  child: Text(
                    (s.user?.name ?? L.t('initial_unknown'))
                        .characters
                        .first,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(L.t('hello_name', {'n': '${s.user?.name ?? ''}'}),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(
                          '${s.user?.code ?? ''} · ${L.t('today_zone')}: ${zone?.name ?? '—'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          IconButton(
            onPressed: () => showNotifications(context),
            icon: Badge(
              isLabelVisible: s.unreadCount > 0,
              label: Text('${s.unreadCount}'),
              child: const Icon(Icons.notifications_outlined,
                  color: Colors.white),
            ),
          ),
          // ⚠️ زرار لغة مختصر — الزرارين الكبار كانوا بياكلوا عرض
          // الهيدر والاسم بيتقص «اسلام ط...» (بلاغ ٢٠/٨)
          _langBtn(context),
        ],
        ),
        const SizedBox(height: 11),
        _attStrip(context),
      ]),
    );
  }

  /// ═══ شريط الحضور جوه الهيدر (٢٠/٨) — زي الموك أب بالظبط ═══
  /// العرض بس هنا؛ الأكشنات كلها (حضور/بريك/انصراف بحراسها) في
  /// شاشة الحضور نفسها — الزرار بيوديك عليها.
  Widget _attStrip(BuildContext context) {
    final a = Session.I.att;
    final working = a.state == 'working';
    final onBreak = a.state == 'break';

    final dotC = working
        ? const Color(0xFF33E086)
        : onBreak
            ? const Color(0xFFFFB74D)
            : const Color(0xFFFF8A80);

    final title = working
        ? (a.firstIn != null
            ? L.t('hdr_working_since', {'t': _clock(a.firstIn!)})
            : L.t('att_working'))
        : onBreak
            ? L.t('att_break')
            : L.t('hdr_not_in');

    final sub = working || onBreak
        ? L.t('hdr_worked_today', {'d': a.liveWorkedLabel})
        : L.t('hdr_checkin_sub');

    final btn =
        working || onBreak ? L.t('hdr_checkout') : L.t('hdr_checkin');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotC, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 1),
              Text(sub,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 10.5)),
            ],
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AttendanceScreen())),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              border: Border.all(color: Colors.white38),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(btn,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900)),
          ),
        ),
      ]),
    );
  }

  Widget _langBtn(BuildContext context) {
    final other = L.locale == 'ar' ? 'en' : 'ar';

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final err = await Session.I.setLocale(other);
        if (err != null && context.mounted) snack(context, err, bad: true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white38),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(other == 'en' ? 'EN' : 'ع',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w900)),
      ),
    );
  }

  // ═══════════ الزيارة الجاية — كارت البطل ═══════════

  Widget _nextVisitCard(BuildContext context, Session s) {
    // ⚠️ **خط السير الأول، وعملاء الزون فولباك** (بلاغ ٢٠/٨) —
    // بس الفولباك **بيقول إنه اقتراح** (بلاغ ٢١/٨ مساءً): مندوب من
    // غير خطة كان الكارت بيقوله «الزيارة الجاية 1 من 2» وكأن فيه
    // خط سير، ولما يخلص يقوله «شغل نضيف 🎉» — أرقام واحتفال لخطة
    // مش موجودة أصلاً. دلوقتي: فيه خطة → أرقامها الحقيقية؛ مفيش →
    // «زيارة مقترحة من منطقتك» من غير عدادات، والقفلة بتقول الحقيقة.
    final planned = s.journey.isNotEmpty;
    var total = s.journey.length;
    var doneN = s.journey.where((x) => x.status == VisitStatus.done).length;
    Client? next;

    if (planned) {
      final st =
          firstOrNull(s.journey.where((x) => x.status != VisitStatus.done));
      if (st != null) next = s.clientForStop(st) ?? st.asClient();
    } else {
      final zone = s.todayZone;
      if (zone == null || zone.clients.isEmpty) {
        return const SizedBox.shrink();
      }
      total = zone.clients.length;
      doneN =
          zone.clients.where((x) => x.status == VisitStatus.done).length;
      // الزيارة المفتوحة ليها بانرها فوق — الجاية غيرها
      next = firstOrNull(zone.clients.where((x) =>
          x.status != VisitStatus.done && x.id != s.activeClient?.id));
    }

    if (next == null) {
      // 🎉 **بس لو كان فيه خطة واتخلصت فعلاً** — من غير خطة الاحتفال
      // كذبة، والكارت بيقول إن مفيش خط سير متظبط النهاردة.
      if (planned) {
        return Card(
          color: const Color(0xFFE9F9F0),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Text('🎉', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(L.t('journey_all_done'),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        );
      }

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(Icons.alt_route, size: 20, color: Brand.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(L.t('home_no_plan'),
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                      color: Brand.muted)),
            ),
          ]),
        ),
      );
    }

    final c = next;
    final color = Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // فيه خطة → «الزيارة n من N» بأرقامها الحقيقية؛
              // مفيش → «زيارة مقترحة» من غير عدادات وهمية (٢١/٨)
              Chip2(
                  text: planned
                      ? L.t('next_visit_n',
                          {'i': '${doneN + 1}', 'n': '$total'})
                      : L.t('home_suggested'),
                  color: planned ? color : Brand.orange),
              const Spacer(),
              if (_distanceLabel(c) != null)
                Text(_distanceLabel(c)!,
                    style:
                        TextStyle(fontSize: 10.5, color: Brand.muted)),
            ]),
            const SizedBox(height: 8),
            Text(c.name,
                style: const TextStyle(
                    fontSize: 16.5, fontWeight: FontWeight.w900)),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                  [
                    if (c.zone.isNotEmpty) c.zone,
                    if (c.address.isNotEmpty) c.address,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: Brand.muted)),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 5, children: [
              if (c.balance > 0)
                Chip2(
                    text: L.t('balance_due', {'n': money(c.balance)}),
                    color: const Color(0xFFB45309)),
              if (c.daysSinceVisit != null)
                Chip2(
                    text: L.t('last_visit_days',
                        {'n': '${c.daysSinceVisit}'}),
                    color: Brand.muted),
            ]),
            const SizedBox(height: 11),
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => ClientScreen(client: c))),
                  child: Text(L.t('start_visit'),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w900)),
                ),
              ),
              if (c.phone.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                _sqBtn(Icons.phone_outlined,
                    () => Locator.openUrl('tel:${c.phone.trim()}')),
              ],
              if (c.directionsUrl != null) ...[
                const SizedBox(width: 8),
                _sqBtn(Icons.place_outlined,
                    () => Locator.openUrl(c.directionsUrl!)),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  Widget _sqBtn(IconData icon, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 46,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE0DDD4)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 19, color: Brand.royalBlue),
        ),
      );

  // ═══════════ «محتاج منك» — الأكشنات المستنية ═══════════

  List<Widget> _needYou(BuildContext context, Session s) {
    final cards = <Widget>[];

    // أمر توريد متأخر — أهم حاجة، بحد أحمر
    final latePo = firstOrNull(
        s.pos.where((p) => p.status != 'delivered' && p.late));
    if (latePo != null) {
      cards.add(_actionCard(
        context,
        color: const Color(0xFFB00020),
        icon: Icons.local_shipping_outlined,
        title: '${L.t('act_po_late')} · ${latePo.client}',
        sub:
            '${latePo.number}${latePo.dueAt != null ? ' · ${L.t('act_po_due', {'t': '${fmtDate(latePo.dueAt!)} ${fmtTime(latePo.dueAt!)}'})}' : ''}',
        action: L.t('act_deliver'),
        // ⚠️ (بلاغ ٢١/٨) كان بيفتح التسليم مباشرة من غير تشيك إن —
        // نفس فلو كارت الأمر: شاشة العميل الأول، والبانر جواها
        onTap: () {
          final c = latePo.clientId == null
              ? null
              : Session.I.clientById(latePo.clientId!);
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => c != null
                  ? ClientScreen(client: c)
                  : PoDeliveryScreen(poId: latePo.id)));
        },
      ));
    }

    // عملاء جداد اتوافق عليهم — جاهزين للبيع
    final approved = s.requests
        .where((r) => r.status == 'approved' && r.clientId != null)
        .length;
    if (approved > 0) {
      cards.add(_actionCard(
        context,
        color: Brand.green,
        icon: Icons.person_add_alt,
        title: L.t('act_new_clients', {'n': '$approved'}),
        sub: L.t('act_new_clients_sub'),
        action: L.t('act_open_them'),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const ClientRequestsScreen())),
      ));
    }

    // تحصيل مستحق — عملاء زون النهاردة اللي عليهم فلوس، من نفس
    // الأرصدة اللي الليدجر حاسبها (عقيدة الأرقام: مفيش رقم مخترع)
    final zone = s.todayZone;
    if (zone != null) {
      final debtors = zone.clients.where((x) => x.balance > 0).toList();
      if (debtors.isNotEmpty) {
        final due = debtors.fold(0.0, (t, x) => t + x.balance);
        cards.add(_actionCard(
          context,
          color: const Color(0xFFB86E00),
          icon: Icons.payments_outlined,
          title: '${L.t('act_collect_due')} · ${money(due)}',
          sub: L.t('act_collect_sub', {'n': '${debtors.length}'}),
          action: L.t('act_see_them'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ZoneScreen(zone: zone))),
        ));
      }
    }

    final needCount = cards.length;

    // حوافزي — مدخل دايم بنسبة تارجت الشهر، مش محسوب في العداد
    cards.add(_actionCard(
      context,
      color: const Color(0xFF7D40D6),
      icon: Icons.emoji_events_outlined,
      title: _incPct != null
          ? L.t('act_inc_pct', {'p': '${_incPct!.round()}'})
          : L.t('my_incentives'),
      sub: _incPct != null ? '' : L.t('my_incentives_hint'),
      action: '',
      progress: _incPct != null ? (_incPct! / 100).clamp(0.0, 1.0) : null,
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const IncentivesScreen())),
    ));

    return [
      Row(children: [
        Text(L.t('need_you'),
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 7),
        if (needCount > 0)
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: Color(0xFFB00020), shape: BoxShape.circle),
            child: Text('$needCount',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900)),
          ),
      ]),
      const SizedBox(height: 8),
      ...cards,
      const SizedBox(height: 6),
    ];
  }

  Widget _actionCard(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String title,
    required String sub,
    required String action,
    required VoidCallback onTap,
    double? progress,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: .35)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w900)),
                  if (sub.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10.5, color: Brand.muted)),
                    ),
                  if (progress != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: const Color(0xFFEFEDE6),
                          color: color,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (action.isNotEmpty)
              Text(action,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: color)),
            Icon(Icons.chevron_left, size: 17, color: color),
          ]),
        ),
      ),
    );
  }
}
