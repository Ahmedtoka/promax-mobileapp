import 'package:flutter/material.dart';
import '../l10n.dart';

import '../models.dart';
import '../session.dart';

/// شاشة المدير لطلبات الريفيل:
/// البروموتر بيصوّر الرف ويطلب الناقص → المدير هنا يوافق ويوزّعه على مندوب
/// → بيتحول لأمر توريد (PO) يوصله السواق ويخصمه من عهدته.
class ManagerReplenishmentsScreen extends StatefulWidget {
  const ManagerReplenishmentsScreen({super.key});

  @override
  State<ManagerReplenishmentsScreen> createState() =>
      _ManagerReplenishmentsScreenState();
}

class _ManagerReplenishmentsScreenState
    extends State<ManagerReplenishmentsScreen> {
  String _filter = 'pending';

  // ⚠️ **getter مش `static const`.** الخريطة دي فيها نصوص مترجمة،
  // و`const` معناها إنها بتتقيّم مرة واحدة عند التجميع — فأولاً
  // `L.t()` مش تعبير ثابت (خطأ تجميع)، وثانياً حتى لو `final`
  // الترجمة كانت هتتجمّد على اللغة اللي اتقرت أول مرة ومش هتتغير
  // لما اليوزر يبدّل اللغة.
  Map<String, String> get _filters => {
        'pending': L.t('awaiting_you'),
        'assigned': L.t('assigned'),
        'delivered': L.t('supplied'),
        'all': L.t('all'),
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final all = Session.I.mgrReplenishments;
        final rows =
            _filter == 'all' ? all : all.where((r) => r.status == _filter).toList();

        return Scaffold(
          appBar: AppBar(
            // ⚠️ اتحيّد (١١/٨ مساءً): الطلبات بقت من كل رولز الشغل
            // الميداني مش من البروموتر بس — «طلب بضاعة من المحل / ريفيل»
            title: Text(L.t('goods_refill_requests')),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(
                  children: _filters.entries.map((e) {
                    final n = e.key == 'all'
                        ? all.length
                        : all.where((r) => r.status == e.key).length;
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: ChoiceChip(
                        selected: _filter == e.key,
                        onSelected: (_) => setState(() => _filter = e.key),
                        label: Text('${e.value} ($n)',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          body: RefreshIndicator(
            onRefresh: Session.I.refresh,
            child: rows.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 160),
                      Icon(Icons.inventory_2_outlined,
                          size: 54, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(L.t('no_requests'),
                            style: TextStyle(color: Colors.grey.shade600)),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: rows.length,
                    itemBuilder: (context, i) => _ReplCard(r: rows[i]),
                  ),
          ),
        );
      },
    );
  }
}

// ================= كارت الطلب =================

class _ReplCard extends StatelessWidget {
  final MgrReplenishment r;
  const _ReplCard({required this.r});

  /// ⚠️ **حارس الدوس المزدوج** (تدقيق ٩/٨): «موافقة وتنزيل» بيعمل
  /// أمر توريد + أمر تجهيز حقيقيين ومفيش idem key على المسار ده —
  /// دوستين سريعتين كانوا بيطلّعوا أمرين. ستاتيك عن قصد: الكارت
  /// Stateless والحارس لازم يعيش بره أي rebuild.
  static bool _inFlight = false;

  @override
  Widget build(BuildContext context) {
    final (color, label) = r.info;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.client,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        '${r.number}${r.channel == null ? '' : ' • ${r.channel}'}',
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _meta(Icons.person_outline, r.promoter ?? '—'),
                _meta(Icons.inventory_2_outlined, L.t('n_units', {'n': '${r.qtyTotal}'})),
                _meta(Icons.payments_outlined, money(r.value)),
                _meta(Icons.schedule, fmtTime(r.time)),
              ],
            ),

            // ═══ مصدر الطلب (2026-08-09): مندوب عند العميل ولا
            // بروموتر من زيارة رف — بيغيّر مين المرشّح يستلمه ═══
            if (r.originLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: r.origin == 'rep'
                      ? const Color(0xFFE8F1FF)
                      : const Color(0xFFF1F1F4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(r.originLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: r.origin == 'rep'
                            ? const Color(0xFF12399B)
                            : const Color(0xFF6B6B7B))),
              ),
            ],

            if (r.address != null && r.address!.isNotEmpty) ...[
              const SizedBox(height: 6),
              _meta(Icons.place_outlined, r.address!),
            ],

            if (r.assignee != null) ...[
              const SizedBox(height: 6),
              _meta(Icons.local_shipping_outlined, L.t('with_person', {'p': '${r.assignee}'})),
            ],

            if (r.note != null && r.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F2EC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(r.note!, style: const TextStyle(fontSize: 12)),
              ),
            ],

            // صور الرف قبل وبعد
            if (r.photoBefore != null || r.photoAfter != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  _shelfPhoto(context, L.t('before'), r.photoBefore),
                  const SizedBox(width: 8),
                  _shelfPhoto(context, L.t('after'), r.photoAfter),
                ],
              ),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            ...r.items.map((i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(i.product,
                              style: const TextStyle(fontSize: 12.5))),
                      Text('${i.qty} ×',
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 76,
                        child: Text(money(i.total),
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                )),

            if (r.canDecide) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reject(context),
                      icon: const Icon(Icons.close, size: 17),
                      label: Text(L.t('reject')),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB00020),
                          minimumSize: const Size.fromHeight(46)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => _assign(context),
                      icon: const Icon(Icons.local_shipping_outlined, size: 18),
                      label: Text(L.t('approve_assign')),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(46)),
                    ),
                  ),
                ],
              ),
            ] else if (r.status == 'pending') ...[
              const SizedBox(height: 10),
              Text(L.t('not_your_channel'),
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
        ],
      );

  Widget _shelfPhoto(BuildContext context, String label, String? url) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(L.t('shelf_label', {'n': '$label'}),
                style: const TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: url == null
                  ? Container(
                      height: 90,
                      color: const Color(0xFFF4F2EC),
                      child: Icon(Icons.image_not_supported_outlined,
                          color: Colors.grey.shade400),
                    )
                  : GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: InteractiveViewer(
                              child: Image.network(url, cacheWidth: 800)),
                        ),
                      ),
                      child: Image.network(url, cacheWidth: 800,
                        height: 90,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 90,
                          color: const Color(0xFFF4F2EC),
                          child: Icon(Icons.broken_image_outlined,
                              color: Colors.grey.shade400),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );

  Future<void> _assign(BuildContext context) async {
    final drivers = Session.I.drivers;
    if (drivers.isEmpty) {
      _snack(context, L.t('no_reps_available'), ok: false);
      return;
    }

    // ⚠️ **الطلب بيترشّح صاحبه يستلمه** (2026-08-09 — واتعمّم ١١/٨
    // مساءً على البروموتر كمان): «نفس المندوب اللي طلبه ولا مندوب
    // تاني» — القايمة بقت كل رولز الشغل الميداني والبروموتر بقى
    // يستلم زي غيره. لو الطالب مش في قايمة المتاحين (اتوقف مثلاً)
    // بنرجع لأول واحد عادي.
    int driverId = drivers.first.id;
    if (r.requestedById > 0) {
      final self = firstOrNull(drivers.where((d) => d.id == r.requestedById));
      if (self != null) driverId = self.id;
    }
    String priceMode = 'client';

    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(L.t('assign_to_rep', {'n': '${r.number}'}),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              Text('${r.client} • ${L.t('n_units', {'n': '${r.qtyTotal}'})}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 16),

              Text(L.t('delivering_rep'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              // DropdownButton عادي (مش FormField) عشان يشتغل على أي إصدار فلاتر
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButton<int>(
                  value: driverId,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: drivers
                      .map((d) => DropdownMenuItem(
                            value: d.id,
                            child: Text('${d.name} — ${d.roleLabel}',
                                style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) => setSheet(() => driverId = v ?? driverId),
                ),
              ),
              const SizedBox(height: 14),

              Text(L.t('price_list'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                // ⚠️ من غير `const` — النصوص مترجمة وقت التشغيل
                //
                // ⚠️ **القيم لازم تطابق فاليديشن السيرفر** (إصلاح ١١/٨
                // مساءً): الشيبس كانت لسه بتبعت `hold`/`p70`/`cash` —
                // قوايم أسعار **اندفنت** من مايجريشن 000011، والسيرفر
                // بيقبل `client`/`old`/`new` بس، فتلات شيبس من أربعة
                // كانوا بيرجّعوا خطأ فاليديشن على طول.
                children: {
                  'client': L.t('price_client'),
                  'new': L.t('price_new'),
                  'old': L.t('price_old'),
                }.entries.map((e) {
                  return ChoiceChip(
                    selected: priceMode == e.key,
                    onSelected: (_) => setSheet(() => priceMode = e.key),
                    label: Text(e.value, style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              Text(
                priceMode == 'client'
                    ? L.t('value_at_client', {'n': '${money(r.value)}'})
                    : L.t('price_note'),
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      child: Text(L.t('cancel')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      child: Text(L.t('approve_assign_short')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (go != true || !context.mounted) return;
    if (_inFlight) return;
    _inFlight = true;

    try {
      final err = await Session.I
          .assignReplenishment(r.id, driverId, priceMode: priceMode);
      if (!context.mounted) return;

      _snack(context, err ?? L.t('assigned_done'),
          ok: err == null);
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _reject(BuildContext context) async {
    final note = TextEditingController();

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L.t('reject_n', {'n': '${r.number}'})),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(L.t('notify_will_go', {'p': '${r.promoter ?? L.t("role_promoter")}'}),
                style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: L.t('reject_reason'),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L.t('back'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB00020)),
            child: Text(L.t('reject_request')),
          ),
        ],
      ),
    );

    // ⚠️ النص بيتقري وبعدها الكنترولر بيتقفل — كان بيتسرّب مع كل رفض
    final reason = note.text.trim();
    note.dispose();

    if (go != true || !context.mounted) return;
    if (_inFlight) return;
    _inFlight = true;

    try {
      final err = await Session.I
          .rejectReplenishment(r.id, note: reason.isEmpty ? null : reason);
      if (!context.mounted) return;

      _snack(context, err ?? L.t('request_was_rejected'), ok: err == null);
    } finally {
      _inFlight = false;
    }
  }

  void _snack(BuildContext context, String msg, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          ok ? const Color(0xFF16A34A) : const Color(0xFFB00020),
    ));
  }
}
