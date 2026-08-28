import 'dart:async';

import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n.dart';
import '../models.dart';
import '../session.dart';

/// ═══════════════════════════════════════════════════════════════
/// دخول وخروج المخزن (2026-08-08)
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ **دي مش شاشة الحضور — ولا علاقة بينهم.**
///
///   • **الحضور** = «أنا شغال النهارده». مرة واحدة الصبح، وبيقفل
///     بالانصراف. من غيره مفيش أي أكشن في الأبلكيشن.
///   • **دخول المخزن** = «أنا واقف جوه مخزن المعادي دلوقتي». بيتفتح
///     ويتقفل كذا مرة في اليوم، ومطلوب **بس** عشان تستلم بضاعة.
///
/// المندوب اللي بيلف على العملاء طول اليوم مالوش أي علاقة بالشاشة
/// دي. اللي بيدخل المخزن يستلم عهدة أو PO هو اللي بيفتحها.
///
/// ⚠️ **الحضور شرط قبل الدخول** — والسيرفر هو اللي بيرفض، مش الشاشة.
class WarehouseVisitScreen extends StatefulWidget {
  const WarehouseVisitScreen({super.key});

  @override
  State<WarehouseVisitScreen> createState() => _WarehouseVisitScreenState();
}

class _WarehouseVisitScreenState extends State<WarehouseVisitScreen> {
  bool _busy = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();

    // ⚠️ **ثانية بثانية** (طلب المالك ٨/٨/٢٠٢٦). كان كل ٣٠ ثانية
    // والعدّاد بالدقايق — فالمندوب بيدخل وبيبص ويلاقي «0:00» واقف
    // نص دقيقة، ويفتكر إن الدخول ماتسجّلش فيدوس تاني.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && Session.I.insideWarehouse) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _in(int id) async {
    setState(() => _busy = true);
    final err = await Session.I.warehouseIn(id);
    if (!mounted) return;
    setState(() => _busy = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Brand.red),
      );
      return;
    }

    // ⚠️ **بيرجّعه لشغله على طول.** الشاشة دي حاجز مش وجهة — اللي كان
    // عايز يستلمه لسه مستنيه، ولو سيبناه هنا كان هيرجع بإيده كل مرة.
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  Future<void> _out() async {
    setState(() => _busy = true);
    final err = await Session.I.warehouseOut();
    if (!mounted) return;
    setState(() => _busy = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Brand.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final s = Session.I;
        final stop = s.whStop;

        return Scaffold(
          appBar: AppBar(title: Text(L.t('wh_title'))),
          body: ListView(
            // viewPadding صريح (مسح ٢١/٨)
            padding: EdgeInsets.fromLTRB(16, 16, 16, 28 + MediaQuery.viewPaddingOf(context).bottom),
            children: [
              if (stop != null) _inside(stop) else _picker(s),
              const SizedBox(height: 16),
              _today(s),
            ],
          ),
        );
      },
    );
  }

  /// ═══ سامري النهارده — زي شاشة الحضور (طلب المالك ٨/٨/٢٠٢٦) ═══
  ///
  /// ⚠️ **بيتعرض في الحالتين**، جوّه المخزن وبره. اللي بره محتاج
  /// يعرف إنه استلم خلاص أكتر من اللي جوّه.
  Widget _today(Session s) {
    final d = s.whToday;

    // مفيش أي حركة النهارده = مفيش سامري، مش كارت أصفار
    if (d.visits == 0 && d.picks == 0 && d.pos == 0) {
      return const SizedBox.shrink();
    }

    Widget cell(IconData icon, String label, String value) => Expanded(
          child: Column(
            children: [
              Icon(icon, size: 19, color: Brand.royalBlue),
              const SizedBox(height: 5),
              Text(value,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10.5, color: Brand.muted)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Brand.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Brand.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, right: 2, left: 2),
            child: Text(L.t('wh_today'),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w900)),
          ),
          Row(children: [
            cell(Icons.inventory_2_outlined, L.t('wh_today_picks'), '${d.picks}'),
            cell(Icons.local_shipping_outlined, L.t('wh_today_pos'), '${d.pos}'),
            cell(Icons.timer_outlined, L.t('wh_today_minutes'),
                '${d.minutes ~/ 60}:${(d.minutes % 60).toString().padLeft(2, '0')}'),
            cell(Icons.repeat, L.t('wh_today_visits'), '${d.visits}'),
          ]),
        ],
      ),
    );
  }

  // ═══════════════════ جوه المخزن ═══════════════════

  Widget _inside(WarehouseStop stop) => Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
            decoration: BoxDecoration(
              gradient: Brand.gradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Brand.royalBlue.withValues(alpha: .25),
                  blurRadius: 20,
                  offset: const Offset(0, 9),
                )
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.warehouse, color: Colors.white, size: 30),
                const SizedBox(height: 10),
                Text(L.t('wh_inside'),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text(stop.warehouse,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                Text(stop.liveLabel,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1)),
                const SizedBox(height: 3),
                Text(
                  '${L.t('wh_since')} ${fmtTime(stop.checkedInAt)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ⚠️ **سطر بيقول إن الاستلام مفتوح دلوقتي.** المندوب اللي
          // دخل المخزن عشان يستلم محتاج يعرف إن الحاجز اتفك — من
          // غيره بيرجع للشاشة اللي رفضته وهو مش متأكد.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5EC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_open, color: Brand.green, size: 19),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(L.t('wh_can_receive'),
                      style: const TextStyle(
                          fontSize: 12, height: 1.6, color: Brand.green)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_busy)
            const Center(child: CircularProgressIndicator())
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Brand.red,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _out,
                icon: const Icon(Icons.logout, size: 20),
                label: Text(L.t('wh_out'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      );

  // ═══════════════════ اختيار المخزن ═══════════════════

  Widget _picker(Session s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: Brand.royalBlue, size: 19),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(L.t('wh_pick_hint'),
                      style: const TextStyle(
                          fontSize: 12, height: 1.65, color: Brand.royalBlue)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(L.t('wh_pick'),
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),

          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 26),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (s.warehouses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Center(
                child: Text(L.t('wh_none'),
                    style: const TextStyle(fontSize: 12.5, color: Brand.muted)),
              ),
            )
          else
            for (final w in s.warehouses)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Material(
                  color: Brand.card,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () => _in(w.id),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Brand.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Brand.royalBlue.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.warehouse,
                                color: Brand.royalBlue, size: 21),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(w.name,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900)),
                                if (w.address.trim().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(w.address,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11, color: Brand.muted)),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              size: 13, color: Brand.muted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ],
      );
}
