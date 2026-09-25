import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n.dart';
import '../models.dart';
import '../nav.dart';
import '../session.dart';
import 'gifts.dart';
import 'pick_history.dart';
import 'warehouse_visit.dart';
import 'pick_orders.dart';
import 'custody_product.dart';

// ================= شارة صغيرة =================

/// رسالة سريعة أسفل الشاشة.
///
/// ⚠️ بتتأكد من `context.mounted` — النداء بعد `await` والشاشة
/// اتقفلت بيرمي استثناء بيوقّف الأكشن كله.
void snack(BuildContext context, String message, {bool bad = false}) {
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: bad ? Brand.red : Brand.royalBlue,
    behavior: SnackBarBehavior.floating,
  ));
}

/// زرار تبديل اللغة.
///
/// ⚠️ التبديل بيروح للسيرفر (`users.locale`) مش للتخزين المحلي —
/// الإشعارات بتترندر عند السيرفر بلغة المستقبِل، ولو الاتنين
/// مختلفين المندوب بيلاقي شاشة بلغة وإشعار بلغة تانية.
///
/// ⚠️ بيعمل `Navigator.pushAndRemoveUntil` مش `setState` — الاتجاه
/// (RTL/LTR) بيتحدد في `MaterialApp.builder`، والشاشات المبنية
/// خلاص مابتعيدش بناء نفسها لوحدها.
class LangSwitch extends StatelessWidget {
  final Color? color;

  const LangSwitch({super.key, this.color});

  Future<void> _switch(BuildContext context, String code) async {
    if (code == L.locale) return;

    final err = await Session.I.setLocale(code);

    if (!context.mounted) return;

    if (err != null) {
      snack(context, err, bad: true);

      return;
    }

    // ⚠️ **مفيش pop ولا markNeedsBuild هنا** (إصلاح 2026-08-07).
    // `MaterialApp` معاه `key: ValueKey(L.locale)` في `main.dart`،
    // فأول ما `Session` ينادي `notifyListeners` الشجرة كلها —
    // بالنافيجيتور وكل الشاشات المبنية — بتتبني من الأول باللغة
    // الجديدة. النداء على `popUntil` هنا كان بيلمس نافيجيتور على
    // وشك إنه يتبدّل، والكاست القديم كان بيرمي استثناء ويهنّج
    // التبديل. التبديل دلوقتي بيحصل لوحده وبالكامل.
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(context, 'ar', L.t('arabic'), c),
        const SizedBox(width: 4),
        _btn(context, 'en', L.t('english'), c),
      ],
    );
  }

  Widget _btn(BuildContext context, String code, String label, Color c) {
    final on = L.locale == code;

    return InkWell(
      onTap: () => _switch(context, code),
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: on ? c.withValues(alpha: 0.22) : Colors.transparent,
          border: Border.all(color: c.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: on ? FontWeight.w900 : FontWeight.w600,
            color: c,
          ),
        ),
      ),
    );
  }
}

class Chip2 extends StatelessWidget {
  final String text;
  final Color color;
  const Chip2({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ================= كارت KPI =================

class Kpi extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  /// الكارت يبقى زرار — مبيعات النهارده بتودّي لشاشة المبيعات مثلاً
  final VoidCallback? onTap;

  const Kpi(
      {super.key,
      required this.title,
      required this.value,
      required this.icon,
      required this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        clipBehavior: onTap == null ? Clip.none : Clip.antiAlias,
        child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              FittedBox(
                child: Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15)),
              ),
              const SizedBox(height: 4),
              Text(title,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

// ================= صف معلومة =================

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const InfoRow({super.key, required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: color != null ? FontWeight.w600 : null)),
          ),
        ],
      ),
    );
  }
}

// ================= شاشة العهدة (مشتركة) =================

class CustodyScreen extends StatefulWidget {
  const CustodyScreen({super.key});

  @override
  State<CustodyScreen> createState() => _CustodyScreenState();
}

/// ⚠️ Stateful عشان تابات «بالعائلة / صنف صنف» وفرد كروت العائلات
/// (طلب المالك ٢٠/٨) — من غير ما نعيد تحميل أي حاجة من السيرفر.
class _CustodyScreenState extends State<CustodyScreen> {
  /// 0 = بالعائلة · 1 = صنف صنف — الافتراضي صنف صنف (طلب المالك ٢١/٨)
  int _tab = 1;

  /// العائلات المفرودة — بالاسم عشان تفضل مفرودة بعد الريفريش
  final Set<String> _open = {};

  /// ⚠️ **بانر الاستلام فوق العهدة** — أوامر التجهيز بقت جوه تاب
  /// العهدة: لو فيه أمر جاهز مستني استلامه، بانر برتقالي بيوديه
  /// لشاشة الاستلام. من غيره كان لازم تاب مستقل لحاجة بتحصل
  /// مرة واحدة الصبح.
  /// ⚠️ **من غير بادينج خارجي** — كل مكان بيستدعيه بيحطّه في مكانه.
  /// كان بيضيف 14 لوحده جوّه ListView بادينجها 16، فيطلع 30 من
  /// الجنبين ويبان أضيق من الكروت اللي تحته.
  /// ═══ مخرج المخزن الدائم (تدقيق ٨/٨/٢٠٢٦) ═══
  ///
  /// ⚠️ **المندوب ماكانش عنده أي طريق يخرج من المخزن.** بانر
  /// المخزن كان في شاشة أوامر التجهيز بس، فأول ما يستلم آخر أمر
  /// البانر بيختفي — والزيارة بتفضل مفتوحة لحد الانصراف الأوتوماتيك
  /// آخر الليل. النتيجة: «قعد في المخزن ٩ ساعات» في تقرير الحركة.
  ///
  /// السطر ده بيظهر **طول ما هو جوّه** بغض النظر عن الأوامر.
  Widget _whExit(BuildContext context) {
    final stop = Session.I.whStop;

    if (stop == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFFE8F5EC),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WarehouseVisitScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.logout, color: Brand.green, size: 21),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(L.t('wh_inside_now', {'w': stop.warehouse}),
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w900)),
                      Text(stop.liveLabel,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                              fontSize: 11.5, color: Brand.muted)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Brand.green),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiveBanner(BuildContext context) {
    final ready = Session.I.readyPicks;

    if (ready == 0) return const SizedBox.shrink();

    const orange = Color(0xFFE65100);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PickOrdersScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // الأيقونة في دايرة — بتفصلها عن النص فالسطر بيبقى
                // مقروء بدل ما الأيقونة والكلام يبقوا كتلة واحدة
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE0B2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.move_to_inbox_outlined,
                      color: orange, size: 19),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    L.t('picks_awaiting', {'count': '$ready'}),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      height: 1.35,
                      color: orange,
                    ),
                  ),
                ),
                // ⚠️ `chevron_left` كان متبتّت — في الواجهة الإنجليزي
                // (LTR) بيبقى شايل لورا. الأيقونة الاتجاهية بتقلب لوحدها.
                const Icon(Icons.arrow_forward_ios,
                    size: 13, color: orange),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// زرار الهيستوري — «استلمت إيه وإمتى» في أي وقت
  @override
  Widget build(BuildContext context) {
    // ⚠️ **ListenableBuilder إجبارية هنا.** الشاشة const جوه تابات
    // الرئيسية، وفلاتر بيتخطى إعادة بناء الودجت الثابتة — فلما
    // العهدة كانت بتوصل بعد فتح الأبلكيشن، «حسابي» (اللي بيسمع)
    // كان بيقول 19 والتاب ده فاضل مكتوب «مفيش عهدة». حصلت فعلاً
    // على اللايف 2026-08-03.
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) => _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final s = Session.I;
    final c = s.custody;
    final color = Theme.of(context).colorScheme.primary;

    // ⚠️ **الأب بار اتشال (طلب المالك ٢١/٨)** — أيقونتي السجل
    // والهدايا اتضمّوا لهيدر «عهدتي» المتدرج، والشاشة بقت بنفس
    // ستايل الرئيسية والتوريد: خلفية فاتحة + كارت هيدر جوه SafeArea،
    // فأيقونات شريط الحالة ثابتة غامقة في كل التابات.
    if (!c.exists) {
      return Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            children: [
              _miniHeader(context),
              const SizedBox(height: 12),
              _whExit(context),
              // ⚠️ البانر أهم هنا من أي مكان: «مفيش عهدة» + فيه أمر
              // تجهيز مستنيه = عهدته النهارده لسه مستنية استلامه
              _receiveBanner(context),
              const SizedBox(height: 60),
              Icon(Icons.inventory_2_outlined,
                  size: 46, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Center(
                child: Text(L.t('no_custody'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(L.t('no_custody_hint'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12.5, color: Colors.grey.shade600)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
        onRefresh: s.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            // ═══ هيدر «عهدتي» — فوق خالص زي الرئيسية (٢١/٨) ═══
            _headerCard(context, c, color),

            const SizedBox(height: 12),

            // ⚠️ المخرج فوق الباقي — طول ما هو جوّه المخزن
            _whExit(context),
            // أوامر تجهيز مستنية استلامه
            _receiveBanner(context),

            const SizedBox(height: 12),

            // ═══ تابات «بالعائلة · N» / «صنف صنف · N» ═══
            _tabsBar(c, color),
            const SizedBox(height: 12),

            // ⚠️ byProduct مش items — نفس رقم الداشبورد (دمج الباتشات)
            if (_tab == 0) ..._familyTab(context, c, color),
            if (_tab == 1) _gridTab(context, c, color),
          ],
        ),
        ),
      ),
    );
  }

  /// أيقونة دايرية على الهيدر المتدرج — بديل أيقونات الأب بار (٢١/٨)
  Widget _hdrIcon(IconData icon, String tooltip, VoidCallback onTap) =>
      Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white.withValues(alpha: .14),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(icon, size: 17, color: Colors.white)),
          ),
        ),
      );

  /// هيدر مصغّر لحالة «مفيش عهدة» — نفس التدرج والأيقونات
  Widget _miniHeader(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          gradient: Brand.gradient,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          Expanded(
            child: Text(L.t('my_custody'),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
          ),
          _hdrIcon(
              Icons.history,
              L.t('custody_history'),
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const PickHistoryScreen()))),
          const SizedBox(width: 6),
          _hdrIcon(
              Icons.card_giftcard_outlined,
              L.t('gifts'),
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const GiftsScreen()))),
        ]),
      );

  // ═══════════ هيدر «عهدتي» — البار الملون بكل حاجة ═══════════

  double _spentVal(Custody c) => c.byProduct
      .fold(0.0, (t, i) => t + (i.sold + i.gifted) * i.price);

  double _retVal(Custody c) => c.byProduct
      .fold(0.0, (t, i) => t + (i.returnedIn + i.damagedIn) * i.price);

  String _clock(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? L.t('am') : L.t('pm')}';
  }

  Widget _headerCard(BuildContext context, Custody c, Color color) {
    final byP = c.byProduct;
    final fams = byP.map((e) => e.familyLabel).toSet().length;
    final spentV = _spentVal(c);
    final retV = _retVal(c);
    final total = c.assignedValue <= 0 ? 1.0 : c.assignedValue;

    final meta = <String>[
      if (c.vehicle.isNotEmpty) L.t('vehicle_n', {'n': c.vehicle}),
      if (c.loadedAt != null)
        L.t('loaded_time', {'t': _clock(c.loadedAt!.toLocal())}),
      L.t('families_n', {'n': '$fams'}),
      L.t('items_n', {'n': '${byP.length}'}),
    ].join(' · ');

    // ألوان البار — كلها من باليت البراند
    const cSpent = Color(0xFFC4A6FF); // بنفسجي فاتح — اتصرف
    const cLeft = Color(0xFFFFF927); // أصفر البراند — الباقي
    const cRet = Color(0xFFD74297); // رازماتاز — مرتجع

    int flex(double v) => (v / total * 1000).round().clamp(1, 100000);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: Brand.gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(L.t('my_custody'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16)),
              ),
              // ═══ أيقونتا الأب بار القديم اتضمّوا هنا (٢١/٨) ═══
              _hdrIcon(
                  Icons.history,
                  L.t('custody_history'),
                  () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PickHistoryScreen()))),
              const SizedBox(width: 6),
              _hdrIcon(
                  Icons.card_giftcard_outlined,
                  L.t('gifts'),
                  () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const GiftsScreen()))),
            ],
          ),
          if (meta.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(meta,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11)),
            ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(money(c.remainingValue),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                      '${L.t('left_in_van')} · ${L.t('of_total', {'v': money(c.assignedValue)})}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: (spentV <= 0 && c.remainingValue <= 0 && retV <= 0)
                  ? Container(color: Colors.white24)
                  : Row(children: [
                      if (spentV > 0)
                        Expanded(
                            flex: flex(spentV),
                            child: Container(color: cSpent)),
                      if (c.remainingValue > 0)
                        Expanded(
                            flex: flex(c.remainingValue),
                            child: Container(color: cLeft)),
                      if (retV > 0)
                        Expanded(
                            flex: flex(retV),
                            child: Container(color: cRet)),
                    ]),
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _legend(cSpent, L.t('lg_sales'), money(spentV)),
              _legend(cLeft, L.t('lg_left'), money(c.remainingValue)),
              _legend(
                  cRet,
                  L.t('lg_returns'),
                  // المبلغ + الكمية (سليم + تالف) — «علشان تبقى واقعية»
                  // (طلب المالك ٢٠/٨) بعد ما البانر البرتقالي اتشال
                  '${money(retV)}${(c.returnedInUnits + c.damagedInUnits) > 0 ? ' · ${c.returnedInUnits + c.damagedInUnits}' : ''}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String label, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('$label $value',
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700)),
        ],
      );

  // ═══════════ التابات ═══════════

  Widget _tabsBar(Custody c, Color color) {
    final fams = c.byProduct.map((e) => e.familyLabel).toSet().length;

    return Row(children: [
      Expanded(
          child: _tabBtn(0, L.t('tab_by_family'), fams, color)),
      const SizedBox(width: 8),
      Expanded(
          child: _tabBtn(1, L.t('tab_by_item'), c.byProduct.length, color)),
    ]);
  }

  /// العدد بخط أصغر جنب الاسم (طلب المالك ٢١/٨)
  Widget _tabBtn(int i, String label, int count, Color color) {
    final on = _tab == i;
    final fg = on ? Colors.white : Brand.muted;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _tab = i),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? color : const Color(0xFFE0DDD4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: fg)),
            const SizedBox(width: 5),
            Text('$count',
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: fg.withValues(alpha: .75))),
          ],
        ),
      ),
    );
  }

  /// عمود إحصائية: الرقم فوق والوصف تحته (طلب المالك ٢١/٨)
  Widget _statCol(String label, String value, Color? c) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w900, color: c)),
          const SizedBox(height: 1),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, color: Brand.muted)),
        ]),
      );

  Widget _statDiv() => Container(
        width: 1,
        height: 24,
        color: const Color(0xFFE7E3DA),
      );

  // ═══════════ حالات الصنف — قرب يخلص / خلصت ═══════════

  bool _isDone(CustodyItem p) => p.remaining <= 0;

  bool _isLow(CustodyItem p) =>
      !_isDone(p) &&
      p.assigned > 0 &&
      p.remaining * 10 <= p.assigned;

  void _openProduct(BuildContext context, CustodyItem p, Custody c) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CustodyProductScreen(
            item: p,
            rows: c.items
                .where((x) => x.productId == p.productId)
                .toList())));
  }

  // ═══════════ تاب «بالعائلة» ═══════════

  List<Widget> _familyTab(BuildContext context, Custody c, Color color) {
    final list = c.byProduct.toList()
      ..sort((a, b) {
        final f = a.familyLabel.compareTo(b.familyLabel);
        return f != 0 ? f : a.name.compareTo(b.name);
      });

    final groups = <String, List<CustodyItem>>{};
    for (final p in list) {
      final fl = p.familyLabel.isEmpty ? L.t('no_family') : p.familyLabel;
      groups.putIfAbsent(fl, () => []).add(p);
    }

    return [
      for (final e in groups.entries) _famCard(context, e.key, e.value, c, color),
    ];
  }

  Widget _famCard(BuildContext context, String fam, List<CustodyItem> items,
      Custody c, Color color) {
    final open = _open.contains(fam);
    final assigned = items.fold(0, (t, i) => t + i.assigned);
    final spent = items.fold(0, (t, i) => t + i.sold + i.gifted);
    final ret = items.fold(0, (t, i) => t + i.returnedIn + i.damagedIn);
    final left = items.fold(0, (t, i) => t + i.remaining);
    final leftVal = items.fold(0.0, (t, i) => t + i.remaining * i.price);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        InkWell(
          onTap: () => setState(() {
            open ? _open.remove(fam) : _open.add(fam);
          }),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(children: [
                // شارة الباقي الكبيرة — أول حاجة العين تشوفها
                Container(
                  width: 52,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: (left > 0 ? color : Brand.green)
                        .withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(children: [
                    Text('$left',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: left > 0 ? color : Brand.green)),
                    Text(L.t('lg_left'),
                        style: TextStyle(
                            fontSize: 9.5, color: Brand.muted)),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fam,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text(
                          '${L.t('items_n', {'n': '${items.length}'})} · ${money(leftVal)} ${L.t('lg_left')}',
                          style: TextStyle(
                              fontSize: 11, color: Brand.muted)),
                    ],
                  ),
                ),
                Icon(open ? Icons.expand_less : Icons.expand_more,
                    color: Brand.muted),
              ]),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: assigned == 0 ? 0 : spent / assigned,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFEFEDE6),
                  color: color,
                ),
              ),
              const SizedBox(height: 7),
              // الرقم فوق والوصف تحته بفواصل — نفس ستايل كارت الصنف
              Row(children: [
                _statCol(L.t('assigned'), '$assigned', null),
                _statDiv(),
                _statCol(L.t('spent_lbl'), '$spent',
                    const Color(0xFF1565C0)),
                _statDiv(),
                _statCol(L.t('returned_stock'), '$ret',
                    ret > 0 ? const Color(0xFFB45309) : null),
              ]),
            ]),
          ),
        ),
        if (open) const Divider(height: 1),
        if (open)
          for (final p in items) _famRow(context, p, c, color),
      ]),
    );
  }


  Widget _famRow(
      BuildContext context, CustodyItem p, Custody c, Color color) {
    final done = _isDone(p);
    final low = _isLow(p);
    final spent = p.sold + p.gifted;
    final ret = p.returnedIn + p.damagedIn;

    return InkWell(
      onTap: () => _openProduct(context, p, c),
      child: Container(
        color: low ? const Color(0xFFFFF8E6) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(children: [
          SizedBox(
            width: 40,
            child: done
                ? const Icon(Icons.check_circle,
                    color: Brand.green, size: 20)
                : Column(children: [
                    Text('${p.remaining}',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: low
                                ? const Color(0xFFB45309)
                                : color)),
                    Text(L.t('lg_left'),
                        style: TextStyle(
                            fontSize: 9, color: Brand.muted)),
                  ]),
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF0EEE8),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: p.image == null
                ? Icon(Icons.inventory_2_outlined,
                    size: 16, color: Brand.muted)
                : Image.network(p.image!, cacheWidth: 800,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                        Icons.inventory_2_outlined,
                        size: 16,
                        color: Brand.muted)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: done ? Brand.muted : null)),
                const SizedBox(height: 2),
                Text(
                    done
                        ? '${L.t('st_done')} · ${L.t('st_low_sub', {'s': '$spent', 'a': '${p.assigned}'})}'
                        : low
                            ? '${L.t('st_low')} — ${L.t('st_low_sub', {'s': '$spent', 'a': '${p.assigned}'})}'
                            : '${L.t('assigned')} ${p.assigned} · ${L.t('spent_lbl')} $spent · ${L.t('returned_stock')} $ret',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight:
                            low ? FontWeight.w800 : FontWeight.w400,
                        color: low
                            ? const Color(0xFFB45309)
                            : Brand.muted)),
              ],
            ),
          ),
          Icon(Icons.chevron_left, size: 17, color: Brand.muted),
        ]),
      ),
    );
  }

  // ═══════════ تاب «صنف صنف» — جريد كروت ═══════════

  Widget _gridTab(BuildContext context, Custody c, Color color) {
    final list = c.byProduct.toList()
      ..sort((a, b) {
        final f = a.familyLabel.compareTo(b.familyLabel);
        return f != 0 ? f : a.name.compareTo(b.name);
      });

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: .64,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) => _gridCard(context, list[i], c, color),
    );
  }

  Widget _gridCard(
      BuildContext context, CustodyItem p, Custody c, Color color) {
    final done = _isDone(p);
    final low = _isLow(p);
    final spent = p.sold + p.gifted;
    final ret = p.returnedIn + p.damagedIn;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openProduct(context, p, c),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══ الصف الأعلى (٢١/٨): السعر يمين · الباقي شمال ═══
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(money(p.price),
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${p.remaining}',
                          style: TextStyle(
                              fontSize: 18,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              color: done
                                  ? Brand.green
                                  : low
                                      ? const Color(0xFFB45309)
                                      : color)),
                      Text(L.t('left_unit'),
                          style: TextStyle(
                              fontSize: 8.5, color: Brand.muted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Center(
                  child: p.image == null
                      ? Icon(Icons.inventory_2_outlined,
                          size: 34, color: Brand.muted)
                      : Image.network(p.image!, cacheWidth: 800,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.inventory_2_outlined,
                              size: 34,
                              color: Brand.muted)),
                ),
              ),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: Text(p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800)),
                ),
                if (done)
                  _miniChip(L.t('st_done'), Brand.green)
                else if (low)
                  _miniChip(L.t('st_low'), const Color(0xFFB45309)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: p.assigned == 0 ? 0 : spent / p.assigned,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFEFEDE6),
                  color: low ? const Color(0xFFB45309) : color,
                ),
              ),
              const SizedBox(height: 7),
              // ═══ الرقم فوق والوصف تحته بفواصل (٢١/٨) ═══
              Row(children: [
                _statCol(L.t('assigned'), '${p.assigned}', null),
                _statDiv(),
                _statCol(L.t('spent_lbl'), '$spent',
                    const Color(0xFF1565C0)),
                _statDiv(),
                _statCol(L.t('returned_stock'), '$ret',
                    ret > 0 ? const Color(0xFFB45309) : null),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  /// شارة صغيرة ملونة — مرتجع/تالف على كارت الصنف
  Widget _miniChip(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w800, color: c)),
      );

  // تقسيمة الباتشات اتنقلت لشاشة تفاصيل الصنف (custody_product.dart)
}

// ================= شاشة التراكينج (مشتركة) =================

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

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
    final events = Session.I.events;
    final list = events.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: Text(L.t('tracking_page'))),
      body: RefreshIndicator(
        onRefresh: Session.I.refresh,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EEE8),
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                      child: CustomPaint(painter: _RoutePainter(events))),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(L.t('day_route'),
                          style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              // ⚠️ الفاضي لازم يكون سكرولابل — `Center` كانت بتقفل
              // السحب للتحديث بالظبط لما مفيش تحركات (تدقيق ٩/٨)
              child: list.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 90),
                      Center(child: Text(L.t('no_activity'))),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final e = list[i];
                        final (icon, color) = switch (e.type) {
                          'start' => (Icons.flag, const Color(0xFF7C3AED)),
                          'check_in' => (Icons.login, const Color(0xFF2563EB)),
                          'check_out' => (Icons.logout, const Color(0xFFDC2626)),
                          'sale' => (Icons.receipt_long, const Color(0xFF16A34A)),
                          'deliver' =>
                            (Icons.local_shipping, const Color(0xFF0F766E)),
                          'request' =>
                            (Icons.person_add_alt, const Color(0xFFEA8C1C)),
                          _ => (Icons.circle, Colors.grey),
                        };
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.12),
                              child: Icon(icon, color: color, size: 19),
                            ),
                            title: Text(e.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5)),
                            subtitle: e.subtitle.isEmpty
                                ? null
                                : Text(e.subtitle,
                                    style: const TextStyle(fontSize: 11.5)),
                            trailing: Text(fmtTime(e.time),
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.grey.shade600)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final List<TrackEvent> events;
  _RoutePainter(this.events);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 26) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final pts = events.where((e) => e.lat != 0 && e.lng != 0).toList();
    if (pts.isEmpty) return;

    double minLat = pts.first.lat, maxLat = pts.first.lat;
    double minLng = pts.first.lng, maxLng = pts.first.lng;
    for (final e in pts) {
      minLat = e.lat < minLat ? e.lat : minLat;
      maxLat = e.lat > maxLat ? e.lat : maxLat;
      minLng = e.lng < minLng ? e.lng : minLng;
      maxLng = e.lng > maxLng ? e.lng : maxLng;
    }
    final latSpan = (maxLat - minLat) == 0 ? 1e-6 : (maxLat - minLat);
    final lngSpan = (maxLng - minLng) == 0 ? 1e-6 : (maxLng - minLng);
    const pad = 26.0;

    final points = pts
        .map((e) => Offset(
              pad + (e.lng - minLng) / lngSpan * (size.width - pad * 2),
              size.height -
                  pad -
                  (e.lat - minLat) / latSpan * (size.height - pad * 2),
            ))
        .toList();

    final line = Paint()
      ..color = const Color(0xFFE4B23C)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, line);

    for (int i = 0; i < points.length; i++) {
      final isFirst = i == 0;
      final isLast = i == points.length - 1;
      canvas.drawCircle(
          points[i],
          isFirst || isLast ? 7 : 5,
          Paint()
            ..color = isFirst
                ? const Color(0xFF7C3AED)
                : isLast
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF16A34A));
      canvas.drawCircle(
          points[i],
          isFirst || isLast ? 7 : 5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) =>
      old.events.length != events.length;
}

// ================= شيت الإشعارات =================

/// ⚠️ **ستايل موحّد لأزرار البوب أبات** (2026-08-08). بدل ما نعيد
/// كتابة 8 دايالوجات بمنطقها، بنوحّد الشكل: الإلغاء بحدود بنفس
/// ارتفاع الأساسي. الشكل الافتراضي كان نص رمادي صغير جنب زرار
/// ملوّن كبير — المندوب بيشوف زرار واحد بس فيدوسه غصب عنه.
final ButtonStyle kDialogCancel = OutlinedButton.styleFrom(
  minimumSize: const Size(0, 48),
  side: const BorderSide(color: Brand.border),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
  foregroundColor: Brand.muted,
);

final ButtonStyle kDialogConfirm = FilledButton.styleFrom(
  minimumSize: const Size(0, 48),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
);

/// ═══════════════════════════════════════════════════════════════
/// بوب أب تأكيد موحّد لكل الأبلكيشن (2026-08-08)
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ **الشكل الافتراضي بتاع `AlertDialog` مش صالح للميدان.**
/// `TextButton` جنب `FilledButton` بيطلع نص رمادي صغير جنب زرار
/// ملوّن كبير — والاتنين تحت بعض على الشاشة الضيقة. المندوب اللي
/// بيبص بسرعة بيشوف زرار واحد بس، فيدوسه غصب عنه حتى لو كان عايز
/// يلغي.
///
/// القاعدة هنا: **الاتنين جنب بعض، بنفس الارتفاع، والأساسي أعرض.**
/// الإلغاء زرار حقيقي بحدود مش نص عايم.
///
/// ⚠️ **الرسالة بتقول اللي هيحصل مش بتسأل «متأكد؟».** «هتخرج
/// وهتحتاج تسجّل دخول تاني» بتخلّي القرار واضح؛ «متأكد؟» بتخلّي
/// المستخدم يدوس بدون ما يفهم.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  IconData? icon,
  Color? color,
  bool danger = false,
}) async {
  final accent = color ?? (danger ? Brand.red : Brand.royalBlue);

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      title: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: accent, size: 21),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16.5, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
      content: Text(message,
          style: const TextStyle(
              fontSize: 13, height: 1.7, color: Brand.muted)),
      actions: [
        Row(
          children: [
            // ⚠️ الإلغاء **زرار بحدود** مش نص — النص العايم بيتقري
            // كأنه لينك مش خيار، والناس بتتجاهله
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  side: const BorderSide(color: Brand.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                ),
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(L.t('cancel'),
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Brand.muted)),
              ),
            ),
            const SizedBox(width: 10),
            // ⚠️ `flex: 2` — الأساسي أعرض بس مش لوحده في سطر
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirmLabel,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  return ok == true;
}

/// تأكيد الخروج — مشتركة لكل الشاشات
Future<void> confirmLogout(BuildContext context) async {
  final ok = await confirmAction(
    context,
    title: L.t('logout'),
    message: L.t('logout_confirm'),
    confirmLabel: L.t('logout'),
    icon: Icons.logout,
    danger: true,
  );

  if (ok) Session.I.logout();
}

/// شيت الإشعارات.
///
/// ⚠️ **كان `Column` بـ`mainAxisSize.min` جوّه شيت بارتفاع تلقائي.**
/// مع 6 إشعارات أو أكتر كان بيطلع «BOTTOM OVERFLOWED BY 114 PIXELS»
/// والباقي مايتقراش ولا بيسكرول. دلوقتي: هيدر ثابت + ليستة بتسكرول
/// جوّه ارتفاع محدود، وكل الإشعارات بتبان مش أول 8.
void showNotifications(BuildContext context) {
  final s = Session.I;

  // ⚠️ **بنمسك المش-مقروء قبل ما نعلّم عليه مقروء.** الترتيب ده مهم:
  // `markNotificationsRead` بتقلبهم كلهم `isRead` في نفس اللحظة عشان
  // الشارة تفضى فوراً — لو قريناها بعدها، المندوب مكانش هيعرف أنهي
  // إشعار جديد وأنهي شافه من إمبارح.
  final fresh = {
    for (var i = 0; i < s.notifications.length; i++)
      if (!s.notifications[i].isRead) i
  };

  s.markNotificationsRead();

  showModalBottomSheet(
    context: context,
    // ⚠️ من غيرها الشيت بيتحبس في نص الشاشة مهما كان المحتوى
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _NotificationsSheet(fresh: fresh),
  );
}

class _NotificationsSheet extends StatelessWidget {
  /// أرقام الإشعارات اللي كانت لسه مش مقروءة لما الشيت اتفتح
  final Set<int> fresh;

  const _NotificationsSheet({required this.fresh});

  /// عنوان اليوم — «النهارده / إمبارح / التاريخ»
  String _dayLabel(DateTime t) {
    final now = DateTime.now();
    final d = DateTime(t.year, t.month, t.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;

    if (diff == 0) return L.t('today');
    if (diff == 1) return L.t('notif_yesterday');

    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final list = Session.I.notifications;

    return SafeArea(
      child: ConstrainedBox(
        // ⚠️ 78% مش `double.infinity`: الشيت لازم يفضل باين إن وراه
        // شاشة — المندوب بيقفله بالسحب لتحت، ولو غطى الشاشة كلها
        // بيبقى شكله زي صفحة اتفتحت ويدوّر على زرار رجوع مش موجود.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * .78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.notifications_none,
                      size: 19, color: Brand.royalBlue),
                  const SizedBox(width: 8),
                  Text(L.t('notifications'),
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  if (list.isNotEmpty)
                    Text('${list.length}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Brand.muted)),
                ],
              ),
            ),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 30, 16, 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.notifications_off_outlined,
                          size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text(L.t('no_notifications'),
                          style: const TextStyle(color: Brand.muted)),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final n = list[i];
                    final isNew = fresh.contains(i);
                    // فاصل اليوم بيتحط أول ما التاريخ يتغيّر
                    final showDay = i == 0 ||
                        _dayLabel(list[i - 1].time) != _dayLabel(n.time);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showDay)
                          Padding(
                            padding: EdgeInsets.only(top: i == 0 ? 0 : 12, bottom: 6),
                            child: Text(
                              _dayLabel(n.time),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Brand.muted),
                            ),
                          ),
                        // ⚠️ **الإشعار اللي ليه وجهة قابل للضغط**
                        // (٨/٨/٢٠٢٦). كان مجرد كارت — المندوب يقرا
                        // «أمر توريد جاهز» ويقفل الشيت ويدوّر بإيده.
                        // اللي مالوش وجهة بيفضل كارت عادي، فمفيش
                        // ضغطة مالهاش نتيجة.
                        GestureDetector(
                          onTap: n.link == null
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  AppNav.go(n.link);
                                },
                          child: Container(
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            // الجديد بخلفية زرقا خفيفة — بيبان من بعيد
                            // من غير ما نحتاج شارة زيادة
                            color: isNew ? Brand.blue050 : Brand.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isNew ? Brand.blue200 : Brand.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: n.isGood
                                      ? const Color(0xFFE7F7EE)
                                      : const Color(0xFFFDECEC),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  n.isGood
                                      ? Icons.check_circle
                                      : Icons.error_outline,
                                  size: 18,
                                  color: n.isGood ? Brand.green : Brand.red,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            n.title,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                                height: 1.3),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          fmtTime(n.time),
                                          style: const TextStyle(
                                              fontSize: 10.5,
                                              color: Brand.muted),
                                        ),
                                      ],
                                    ),
                                    if (n.body.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        n.body,
                                        style: const TextStyle(
                                            fontSize: 11.5,
                                            height: 1.4,
                                            color: Brand.muted),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
