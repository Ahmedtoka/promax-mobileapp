import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n.dart';
import '../locator.dart';
import '../models.dart';
import '../promoter_models.dart';
import '../session.dart';
import 'promoter_visit.dart' show openMerchBranch;
import 'zones.dart' show ClientScreen, ZonesScreen, kmTo, kmLabel;

/// ═══════════════════════════════════════════════════════════════
/// خط سير النهارده — إعادة تصميم بموك أب المالك (٢١/٨)
/// ═══════════════════════════════════════════════════════════════
///
/// هيدر متدرج: «2 من 6 زيارات» + بروجرس أصفر + مبيعات النهاردة +
/// شيبس (لسه · برّه الخطة · من غير لوكيشن). وتحته **تايم لاين**
/// مرقّم: المتزار أخضر بأرقام زيارته (وقت · مدة · مبيعات · حصّل ·
/// مرتجع)، «الجاي دلوقتي» كارت كبير بالمسافة وأزرار الزيارة،
/// والباقي سطور مختصرة. وآخر حاجة «زيارة برّه الخطة».
///
/// ⚠️ الترتيب من السيرفر (`sort`) ومابيتغيّرش هنا — المندوب بيمشي
/// على الترتيب ده في الشارع.
class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key});

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  final _s = Session.I;

  /// نقطة المندوب — لمسافة «1.2 كم · 4 دقايق» على كارت الجاي
  (double, double)? _pos;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    final p = await Locator.get();
    if (mounted && p != null) setState(() => _pos = p);
  }

  Future<void> _refresh() async {
    await _s.refreshJourney();
    if (mounted) setState(() {});
  }

  /// ⚠️ **الفلو كله من صفحة العميل** (قرار المالك 2026-08-03):
  /// الضغط على المحطة بيفتح صفحة العميل — التشيك إن من هناك.
  ///
  /// ⚠️ **إلا البروموتر (٢٨/٨)** — الشاشة دي بقت تابه بعد ما خط
  /// سيره وصل للأبلكيشن، وزيارته **زيارة رف** (MerchVisit): صورة
  /// قبل → ريفيل → صورة بعد. فتح صفحة العميل كان هيوديه لفلو
  /// البيع والفاتورة اللي مالوش فيه أصلاً.
  Future<void> _open(JourneyStop stop) async {
    if (_s.user?.isPromoter == true) {
      await _openMerch(stop);
      if (mounted) setState(() {});

      return;
    }

    final client = _s.clientForStop(stop) ?? stop.asClient();

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClientScreen(client: client)),
    );

    if (mounted) setState(() {});
  }

  /// محطة البروموتر — نفس منطق كارت الفرع في شاشته بالحرف
  Future<void> _openMerch(JourneyStop stop) async {
    final s = Session.I;

    // ⚠️ **بدء الزيارة مايعتمدش على قايمة الفروع** (٢٨/٨ — بلاغ
    // «مفيش فروع متخصصة ليك» تاني): `startMerchVisit` محتاجة رقم
    // العميل بس، والمحطة فيها كل بياناته. لو الفرع مش في القايمة
    // (بوت ستراب قديم متكاش، أو عميل بره الزون) بنبني كارت مؤقت
    // من المحطة ونكمّل — والحارس الحقيقي عند السيرفر، اللي بقى
    // بيسمح بأي عميل في خطة النهارده.
    final branch = firstOrNull(s.branches.where((b) => b.id == stop.clientId)) ??
        Branch.fromJson({
          'id': stop.clientId,
          'name': stop.name,
          'address': stop.address,
          'phone': stop.phone,
        });

    // الباقي (اتزار النهارده؟ · مؤشر التحميل · البدء والفتح) في المكان المشترك
    await openMerchBranch(context, branch);
  }

  /// رقم بفواصل من غير عملة — أرقام التايم لاين
  static String _n(num v) {
    final s =
        v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    final parts = s.split('.');
    final whole = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

    return whole + (parts.length > 1 ? '.${parts[1]}' : '');
  }

  /// «الخميس 21 أغسطس» — الأسماء من طبقة اللغة مش من باكدج
  String _dateLabel() {
    final d = DateTime.now();

    return '${L.weekday(d.weekday % 7)} ${d.day} ${L.t('mo_${d.month}')}';
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ **ListenableBuilder إجبارية** — الشاشة const جوه التابات
    // وفلاتر بيتخطى إعادة بناء الودجت الثابتة (باج موثّق ٣/٨).
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) => _body(context),
    );
  }

  Widget _body(BuildContext context) {
    // ═══ الفصل (طلب المالك ٢٨/٨): فروع السلاسل سكشن لوحدهم وبعديهم
    // الكاش فان/الفرادى — كل مجموعة بترتيبها الأصلي، والترقيم عام
    // على الاتنين. العناوين بتظهر **بس** لما الخطة تكون مخلوطة —
    // خطة كلها نوع واحد بتتعرض زي زمان من غير دوشة.
    final chains = _s.journey.where((s) => s.isChain).toList();
    final solo = _s.journey.where((s) => !s.isChain).toList();
    final stops = [...chains, ...solo];
    final mixed = chains.isNotEmpty && solo.isNotEmpty;
    final sum = _s.journeySummary;

    // «الجاي دلوقتي» = الزيارة المفتوحة لو فيه، وإلا أول محطة لسه
    // — على الترتيب المعروض نفسه
    final current = stops.indexWhere((s) => s.status == VisitStatus.inVisit);
    final next = current >= 0
        ? current
        : stops.indexWhere((s) => s.status == VisitStatus.pending);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: stops.isEmpty
              ? _empty()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  children: [
                    _header(stops, sum, next),
                    const SizedBox(height: 14),
                    if (mixed) _sectionHead('🔗 ${L.t('jr_chains')}', chains.length),
                    for (var i = 0; i < chains.length; i++)
                      _stopRow(chains[i], i, i == next,
                          !mixed && i == stops.length - 1),
                    if (mixed) _sectionHead('🚐 ${L.t('jr_cash_van')}', solo.length),
                    for (var i = 0; i < solo.length; i++)
                      _stopRow(
                          solo[i],
                          chains.length + i,
                          chains.length + i == next,
                          chains.length + i == stops.length - 1),
                    const SizedBox(height: 4),
                    _offPlanCard(),
                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ),
    );
  }

  /// عنوان سكشن — بيفصل فروع السلاسل عن الكاش فان في التايم لاين
  Widget _sectionHead(String title, int n) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Row(
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$n',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
      );

  Widget _empty() => ListView(
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.map_outlined, size: 62, color: Brand.muted),
          const SizedBox(height: 14),
          Text(
            L.t('no_journey'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            L.t('no_journey_hint'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Brand.muted),
          ),
          const SizedBox(height: 18),
          _offPlanCard(),
        ],
      );

  /// ═══ الهيدر المتدرج (موك أب ٢١/٨) ═══
  Widget _header(
      List<JourneyStop> stops, JourneySummary sum, int nextIdx) {
    final zone = _s.todayZone;
    final noLoc =
        stops.where((s) => s.directionsUrl == null).length;
    final pct = sum.planned == 0 ? 0.0 : (sum.done / sum.planned).clamp(0.0, 1.0);

    // زرار الخريطة — اتجاهات الجاي دلوقتي
    final target = nextIdx >= 0 ? stops[nextIdx] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: Brand.gradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L.t('journey_today'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                      '${_dateLabel()}${zone == null ? '' : ' · ${L.t('jr_zone', {'z': zone.name})}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11.5)),
                ],
              ),
            ),
            if (target?.directionsUrl != null)
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => Locator.openUrl(target!.directionsUrl!),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.map_outlined,
                      size: 19, color: Colors.white),
                ),
              ),
          ]),
          const SizedBox(height: 12),

          // «2 من 6 زيارات» + مبيعات النهاردة
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${sum.done}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            height: 1,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                          L.t('jr_of_visits', {'n': '${sum.planned}'}),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11.5)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(L.t('jr_sales_today'),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 10.5)),
                  Text(_n(_s.today.sales),
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // البروجرس الأصفر البراندي
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 7,
              color: Colors.white.withValues(alpha: .22),
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: pct,
                child: Container(color: Brand.yellow),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // الشيبس: لسه · برّه الخطة · من غير لوكيشن
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (sum.pending > 0)
              _hdrChip(L.t('jr_left_n', {'n': '${sum.pending}'})),
            if (sum.offPlan > 0)
              _hdrChip(L.t('jr_offplan_n', {'n': '${sum.offPlan}'})),
            if (noLoc > 0)
              _hdrChip(L.t('jr_noloc_n', {'n': '$noLoc'}), yellow: true),
          ]),
        ],
      ),
    );
  }

  Widget _hdrChip(String text, {bool yellow = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: yellow ? Brand.yellow : Colors.white.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: yellow ? Brand.ink : Colors.white)),
      );

  // ═══════════════════════════════════════════════════════════
  // صف في التايم لاين: الدايرة والخط يمين + الكارت شمال
  // ═══════════════════════════════════════════════════════════
  Widget _stopRow(JourneyStop stop, int i, bool isNext, bool isLast) {
    final isDone = stop.status == VisitStatus.done;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // عمود التايم لاين — في العربي أول عنصر = أقصى اليمين
          SizedBox(
            width: 34,
            child: Column(children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDone
                      ? Brand.green
                      : isNext
                          ? Brand.royalBlue
                          : Colors.white,
                  shape: BoxShape.circle,
                  border: isDone || isNext
                      ? null
                      : Border.all(color: Brand.border, width: 1.4),
                ),
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 15)
                    : Text('${i + 1}',
                        style: TextStyle(
                            color: isNext ? Colors.white : Brand.muted,
                            fontWeight: FontWeight.w900,
                            fontSize: 12)),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: isDone
                        ? Brand.green.withValues(alpha: .35)
                        : Brand.border,
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: isNext
                  ? _nextCard(stop)
                  : isDone
                      ? _doneCard(stop)
                      : _pendingCard(stop),
            ),
          ),
        ],
      ),
    );
  }

  /// ═══ محطة اتزارت — أرقام الزيارة في سطرين ═══
  Widget _doneCard(JourneyStop stop) {
    final mins = stop.visitMinutes;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _open(stop),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Brand.border),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(
                      [
                        if (stop.checkedInAt != null)
                          fmtTime(stop.checkedInAt!),
                        if (mins != null && mins > 0)
                          L.t('jr_min_n', {'n': '$mins'}),
                        if (stop.visitReturnQty > 0)
                          L.t('jr_return_n',
                              {'n': '${stop.visitReturnQty}'}),
                      ].join(' · '),
                      style:
                          TextStyle(fontSize: 10.5, color: Brand.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(stop.visitSales > 0 ? _n(stop.visitSales) : '—',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900)),
                if (stop.visitCollected > 0)
                  Text(
                      L.t('jr_collected_n',
                          {'n': _n(stop.visitCollected)}),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Brand.green)),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  /// ═══ «الجاي دلوقتي» — الكارت الكبير بالمسافة والأزرار ═══
  Widget _nextCard(JourneyStop stop) {
    final km = kmTo(_pos, stop.lat, stop.lng);
    final inVisit = stop.status == VisitStatus.inVisit;
    final lvDays = stop.lastVisitAt == null
        ? null
        : DateTime.now().difference(stop.lastVisitAt!).inDays;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Brand.royalBlue, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF101C4A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                  inVisit ? L.t('in_visit') : L.t('jr_now_next'),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
            const Spacer(),
            if (km != null)
              Text(
                  L.t('dist_km_min', {
                    'k': km.toStringAsFixed(1),
                    'm': '${(km / 0.3).ceil().clamp(1, 999)}',
                  }),
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Brand.muted)),
          ]),
          const SizedBox(height: 8),
          Text(stop.name,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900)),
          if (stop.address.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(stop.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Brand.muted)),
          ],
          const SizedBox(height: 8),

          // شيبس: عليه · آخر زيارة · متوسّط فاتورته
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (stop.balance > 0)
              _chip(L.t('cc_on_him_n', {'n': _n(stop.balance)}),
                  const Color(0xFFFDECEC), Brand.red),
            _chip(
                lvDays == null
                    ? L.t('first_visit')
                    : lvDays == 0
                        ? L.t('cc_last_visit_today')
                        : L.t('cc_last_visit_n', {'n': '$lvDays'}),
                const Color(0xFFF3F2EC),
                const Color(0xFF52525B)),
            if (stop.avgInvoice > 0)
              _chip(L.t('jr_avg_n', {'n': _n(stop.avgInvoice)}),
                  Brand.purple050, Brand.purpleHeart),
          ]),
          const SizedBox(height: 11),

          // ابدأ الزيارة (متدرج) + تليفون + اتجاهات
          Row(children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: () => _open(stop),
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: Brand.gradient,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                      inVisit
                          ? L.t('continue_visit')
                          : L.t('start_visit'),
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ),
              ),
            ),
            if (stop.directionsUrl != null) ...[
              const SizedBox(width: 8),
              _iconBtn(Icons.near_me_outlined,
                  () => Locator.openUrl(stop.directionsUrl!)),
            ],
            if (stop.phone.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              _iconBtn(Icons.phone_outlined,
                  () => Locator.openUrl('tel:${stop.phone.trim()}')),
            ],
          ]),
        ],
      ),
    );
  }

  /// ═══ محطة جاية — سطر مختصر ═══
  Widget _pendingCard(JourneyStop stop) {
    final km = kmTo(_pos, stop.lat, stop.lng);
    final noLoc = stop.directionsUrl == null;

    final sub = [
      if (stop.address.isNotEmpty) stop.address,
      if (km != null) kmLabel(km),
    ].join(' · ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _open(stop),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Brand.border),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10.5, color: Brand.muted)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // «ضيف لوكيشن» بالأصفر أهم من «عليه» — من غير نقطة
            // المندوب مش هيعرف يوصل أصلاً
            if (noLoc)
              _chip(L.t('jr_add_loc'), Brand.yellow, Brand.ink,
                  icon: Icons.add_location_alt_outlined)
            else if (stop.balance > 0)
              _chip(L.t('cc_on_him_n', {'n': _n(stop.balance)}),
                  const Color(0xFFFFF6DE), const Color(0xFF8A6D00)),
            const SizedBox(width: 5),
            Icon(Icons.chevron_left, size: 17, color: Brand.muted),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg, {IconData? icon}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(text,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
        ]),
      );

  Widget _iconBtn(IconData icon, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Brand.border),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, size: 18, color: Brand.royalBlue),
        ),
      );

  /// ═══ «زيارة برّه الخطة» — عميل مش في خط سير النهاردة ═══
  ///
  /// ⚠️ الشاشة نفسها بتوري **المخطط بس** — العميل اللي بره الخطة
  /// بيتزار من شاشة الزونز، والزرار ده هو الطريق ليها.
  Widget _offPlanCard() => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          // «برّه الخطة» بتفتح المناطق — بقت متملية للمنسق كمان
          // بعد ما بوت سترابه بقى بيبعت `zones` بالتسكين (٢٨/٨)
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ZonesScreen())),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Brand.border),
            ),
            child: Row(children: [
              Icon(Icons.alt_route, size: 18, color: Brand.purpleHeart),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(L.t('jr_off_plan'),
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w900)),
                    Text(L.t('jr_off_plan_sub'),
                        style: TextStyle(
                            fontSize: 10.5, color: Brand.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, size: 18, color: Brand.muted),
            ]),
          ),
        ),
      );
}
