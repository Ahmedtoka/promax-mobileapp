import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../attendance.dart';
import '../brand.dart';
import '../l10n.dart';
import '../models.dart';
import '../session.dart';

/// ═══════════════════════════════════════════════════════════════
/// شاشة الحضور والانصراف (2026-08-08)
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ **زرار واحد كبير، والحالة هي اللي بتحدد وظيفته.** الموظف في
/// الشارع مش هيقرا قايمة اختيارات — هو عايز يدوس ويمشي. الزرار
/// بيقول «ابدأ شغل» أو «انصراف» حسب حالته، والبريك زرار تاني أصغر.
///
/// ⚠️ **العداد بيمشي محلياً بس الرقم من السيرفر.** الدقايق المخزنة
/// بتيجي محسوبة، والتايمر هنا بيزوّد الثواني للعرض بس — من غير
/// كده الموظف بيبص على رقم واقف ويفتكر الأبلكيشن معلّق.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _busy = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();

    // ⚠️ **ثانية بثانية** (2026-08-08). كان 20 ثانية لأن الرقم كان
    // بالدقيقة — والنتيجة إن المندوب يدوس «ابدأ شغل» ويقعد يبص على
    // «0:00» واقف، فيفتكر إن الحاجة ماتسجلتش ويدوس تاني. الثانية
    // اللي بتتحرك هي الدليل الوحيد إن الشيفت شغال.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && Session.I.att.openSince != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _punch(String type) async {
    setState(() => _busy = true);

    final err = await Session.I.punch(type);

    if (!mounted) return;
    setState(() => _busy = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Brand.red),
      );
      return;
    }

    // ⚠️ **أول حضور بيرجّع المندوب لشغله.** الشاشة دي حاجز مش وجهة —
    // لما يخلّص الحضور، اللي كان عايز يعمله لسه مستنيه. الانصراف
    // والبريك بيفضلوا هنا عشان يشوف ساعاته اتقفلت.
    if (type == 'in' && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final a = Session.I.att;

        return Scaffold(
          appBar: AppBar(title: Text(L.t('attendance'))),
          body: RefreshIndicator(
            onRefresh: Session.I.refresh,
            child: ListView(
              // viewPadding صريح (مسح ٢١/٨) — زرار الحضور/الانصراف في آخر الليستة
              padding: EdgeInsets.fromLTRB(16, 16, 16, 28 + MediaQuery.viewPaddingOf(context).bottom),
              children: [
                _statusCard(a),
                const SizedBox(height: 14),
                _actions(a),

                // ⚠️ **الأرقام بعد الحضور بس.** المندوب اللي لسه
                // ماسجّلش، الشاشة دي حاجز قدامه — أرقام تحت الحاجز
                // بتشتّته عن الحاجة الوحيدة المطلوبة منه.
                if (!a.neverStarted) ...[
                  const SizedBox(height: 20),
                  _todayNumbers(),
                ],

                if (a.punches.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _timeline(a),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════ الكارت الكبير ═══════════════════

  Widget _statusCard(Attendance a) {
    final (color, icon, label) = switch (a.state) {
      'working' => (Brand.green, Icons.play_circle_fill, L.t('att_working')),
      'break' => (Brand.orange, Icons.pause_circle_filled, L.t('att_break')),
      _ => (Brand.muted, Icons.stop_circle, L.t('att_off')),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        gradient: a.working ? Brand.gradient : null,
        color: a.working ? null : Brand.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: a.working ? Colors.transparent : Brand.border),
        boxShadow: a.working
            ? [
                BoxShadow(
                  color: Brand.royalBlue.withValues(alpha: .28),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                )
              ]
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // ⚠️ **نقطة نابضة للشغال.** المندوب لازم يفرق من بعيد
              // بين «مسجّل» و«شايف شاشة قديمة» — والحركة أسرع من
              // القراية في إن الشيفت شغال دلوقتي.
              if (a.working) const _Pulse() else Icon(icon, color: color, size: 24),
              const SizedBox(width: 9),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: a.working ? Colors.white : color,
                ),
              ),
              const Spacer(),
              if (a.status == 'auto')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE8E8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(L.t('att_auto_closed'),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Brand.red)),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // ⚠️ **`tabularFigures` ضرورية للعدّاد.** من غيرها عرض
          // الأرقام بيختلف كل ثانية والعدّاد كله بيهتز يمين وشمال.
          Text(
            a.liveWorkedLong,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: -1,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: a.working ? Colors.white : Brand.text,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            L.t('att_worked_today'),
            style: TextStyle(
              fontSize: 11.5,
              color: a.working ? Colors.white70 : Brand.muted,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _mini(L.t('att_first_in'),
                  a.firstIn == null ? '—' : fmtTime(a.firstIn!), a.working),
              _mini(L.t('att_break_total'), a.breakLabel, a.working),
              _mini(L.t('att_sessions'), '${a.sessions}', a.working),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value, bool onGradient) => Column(
        children: [
          Text(value,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: onGradient ? Colors.white : Brand.text)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: onGradient ? Colors.white70 : Brand.muted)),
        ],
      );

  // ═══════════════════ الأزرار ═══════════════════

  /// ⚠️ **الانصراف أحمر ومنفصل.** لو كان بنفس شكل «ابدأ»، الموظف
  /// اللي بيدوس بسرعة الصبح كان بينهي شيفته بالغلط.
  Widget _actions(Attendance a) {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return switch (a.state) {
      'working' => Row(
          children: [
            Expanded(child: _big(L.t('att_break_btn'), Icons.pause, Brand.orange, 'break')),
            const SizedBox(width: 10),
            Expanded(child: _big(L.t('att_out_btn'), Icons.logout, Brand.red, 'out')),
          ],
        ),
      'break' => Row(
          children: [
            Expanded(child: _big(L.t('att_back_btn'), Icons.play_arrow, Brand.green, 'back')),
            const SizedBox(width: 10),
            Expanded(child: _big(L.t('att_out_btn'), Icons.logout, Brand.red, 'out')),
          ],
        ),
      _ => _big(L.t('att_in_btn'), Icons.login, Brand.green, 'in'),
    };
  }

  Widget _big(String label, IconData icon, Color color, String type) => SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
          ),
          onPressed: () => _punch(type),
          icon: Icon(icon, size: 20),
          label: Text(label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        ),
      );

  // ═══════════════════ أرقام النهارده ═══════════════════

  /// ⚠️ **كلها من الداتا المحمّلة في `Session` — صفر ريكوستات.**
  /// الأرقام دي بتتحسب من نفس القوايم اللي التابات بتعرضها، فلو
  /// عدد هنا خالف عدد في تابه يبقى الفلترة اختلفت مش الداتا.
  Widget _todayNumbers() {
    final s = Session.I;

    final stops = s.journey;
    final doneVisits = stops.where((v) => v.status == VisitStatus.done).length;

    // ⚠️ المستنية بس — الطلب اللي اتوافق عليه بقى عميل، ومالوش
    // لازمة في عداد «شغل لسه عندك»
    final newClients = s.requests.where((r) => r.status == 'pending').length;

    final picks = s.readyPickOrders.length;

    // ⚠️ اللي لسه ماتسلّمش — المسلَّم خلص ومش شغل النهارده
    final pos = s.pos.where((p) => p.status != 'delivered').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.today_outlined, size: 17, color: Brand.royalBlue),
            const SizedBox(width: 7),
            Text(L.t('att_today_board'),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _num(L.t('visits'), '$doneVisits/${stops.length}',
                Icons.route_outlined, Brand.royalBlue),
            const SizedBox(width: 9),
            _num(L.t('new_client_requests'), '$newClients',
                Icons.person_add_alt, Brand.purple500),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            _num(L.t('pick_orders'), '$picks',
                Icons.inventory_2_outlined, Brand.orange),
            const SizedBox(width: 9),
            _num(L.t('supply_orders'), '$pos',
                Icons.local_shipping_outlined, Brand.green),
          ],
        ),
      ],
    );
  }

  Widget _num(String label, String value, IconData icon, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: Brand.card,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Brand.border),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            fontFeatures: [FontFeature.tabularFigures()])),
                    const SizedBox(height: 1),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10.5, color: Brand.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  // ═══════════════════ حركة اليوم ═══════════════════

  /// ⚠️ **ارتفاع ثابت وبيسكرول جواه** (2026-08-08). الشيفت اللي فيه
  /// بريكات كتير بيولّد سطور كتير، والليستة كانت بتمتد لآخر الصفحة
  /// وتدفن الأزرار والأرقام تحتها — فالمندوب لازم يسكرول لفوق تاني
  /// عشان يدوس أي حاجة. دلوقتي الصندوق بياخد حجمه ويقف.
  Widget _timeline(Attendance a) {
    // بيكبر مع عدد السطور لحد سقف — الشيفت البسيط مايخدش صندوق فاضي
    final rows = a.punches.length;
    final height = (rows * 52.0).clamp(52.0, 250.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.timeline, size: 17, color: Brand.royalBlue),
            const SizedBox(width: 7),
            Text(L.t('att_timeline'),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
            const Spacer(),
            Text(L.t('n_items', {'n': '$rows'}),
                style: const TextStyle(fontSize: 11, color: Brand.muted)),
          ],
        ),
        const SizedBox(height: 9),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: Brand.card,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Brand.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: rows,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Brand.border),
            itemBuilder: (_, i) {
              // ⚠️ **الأحدث فوق** (2026-08-08). السيرفر بيبعتهم
              // بالترتيب الزمني (الأقدم أول) عشان حساب الفترات
              // بيعتمد عليه — بس اللي بيبص على الشاشة بيدوّر على
              // «آخر حاجة عملتها»، ولو كانت تحت في صندوق بيسكرول
              // كان لازم ينزّل كل مرة.
              final p = a.punches[rows - 1 - i];

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(
                  children: [
                    Text(p.icon, style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(p.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w800)),
                    ),
                    if (p.auto)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: Text(L.t('att_auto_closed'),
                            style: const TextStyle(
                                fontSize: 10, color: Brand.red)),
                      ),
                    Text(fmtTime(p.at),
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: Brand.muted,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// نقطة خضرا نابضة — دليل بصري إن الشيفت شغال دلوقتي
class _Pulse extends StatefulWidget {
  const _Pulse();

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween<double>(begin: .35, end: 1).animate(_c),
        child: Container(
          width: 13,
          height: 13,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      );
}

class AttendanceCard extends StatelessWidget {
  const AttendanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final a = Session.I.att;

        final (bg, fg, icon, title, sub) = switch (a.state) {
          'working' => (
              const Color(0xFFE8F5EC),
              Brand.green,
              Icons.play_circle_fill,
              L.t('att_working'),
              '${L.t('att_worked_today')}: ${a.liveWorkedLabel}',
            ),
          'break' => (
              const Color(0xFFFFF3E0),
              Brand.orange,
              Icons.pause_circle_filled,
              L.t('att_break'),
              L.t('att_back_btn'),
            ),
          _ => (
              const Color(0xFFFDECEC),
              Brand.red,
              Icons.login,
              L.t('att_card_title'),
              L.t('att_card_off'),
            ),
        };

        // ⚠️ **المندوب اللي لسه ماسجّلش بياخد زرار حقيقي مش كارت
        // بيتنقر عليه** (إصلاح 2026-08-08). الكارت كله كان `InkWell`
        // من غير أي حاجة شكلها زرار — فأول شاشة في الأبلكيشن بتقول
        // «سجّل حضورك» ومفيش حاجة واضح إنها بتتداس. والحضور هو
        // الحاجز الوحيد قدام يومه كله، فمينفعش يبقى مبهم.
        final blocked = a.neverStarted;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AttendanceScreen()),
              ),
              child: Padding(
                padding: EdgeInsets.all(a.working ? 11 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: fg, size: a.working ? 21 : 26),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: TextStyle(
                                      fontSize: a.working ? 12.5 : 14.5,
                                      fontWeight: FontWeight.w900,
                                      color: fg)),
                              const SizedBox(height: 2),
                              Text(sub,
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      height: 1.45,
                                      color: fg.withValues(alpha: .85))),
                            ],
                          ),
                        ),
                        // ⚠️ السهم بيختفي لما يكون فيه زرار تحت —
                        // إشارتين لنفس الحاجة بتلخبط اللي بيبص بسرعة
                        if (!blocked)
                          Icon(Icons.arrow_forward_ios, size: 13, color: fg),
                      ],
                    ),

                    if (blocked) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Brand.green,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13)),
                          ),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const AttendanceScreen()),
                          ),
                          icon: const Icon(Icons.login, size: 19),
                          label: Text(L.t('att_in_btn'),
                              style: const TextStyle(
                                  fontSize: 14.5, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
