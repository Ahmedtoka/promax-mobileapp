import 'package:flutter/material.dart';
import '../l10n.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../locator.dart';
import '../models.dart';
import '../promoter_models.dart';
import '../session.dart';
import 'multi_item_picker.dart';
import 'shared.dart';
import 'shelf_count.dart';

/// فتح فرع للمنسق — **المكان الواحد** (٢١/٩). كان منسوخ في تلات شاشات
/// (خط السير · المناطق · فروعي) وكل نسخة بتتصرف شوية مختلف:
///   • زيارة مفتوحة على نفس الفرع → كمّلها.
///   • الفرع اتزار النهارده → **بيسأل** «تبدأ زيارة تانية؟» بدل ما يقفل
///     الفرع برسالة (بلاغ: «كل ما أدوس على فرع يقولي اتزار النهارده»).
///   • مؤشر تحميل فوري — الضغطة كانت بتبان ميتة لحد ما السيرفر يرد.
Future<void> openMerchBranch(BuildContext context, Branch branch) async {
  // امسكهم قبل أي await — الرسالة بعد الرجوع بتضيع (درس ٩/٨)
  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context, rootNavigator: true);
  final s = Session.I;

  if (s.openMerchVisit != null && s.openMerchVisit!.clientId == branch.id) {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VisitScreen(visit: s.openMerchVisit!)));
    return;
  }

  if (branch.status == BranchVisitStatus.done) {
    final again = await confirmAction(
      context,
      title: L.t('branch_visited'),
      message: L.t('pv_revisit_body', {'b': branch.name}),
      confirmLabel: L.t('pv_revisit_go'),
      icon: Icons.replay,
    );
    if (!again || !context.mounted) return;
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
        canPop: false, child: Center(child: CircularProgressIndicator())),
  );

  final err = await s.startMerchVisit(branch);
  nav.pop();

  if (err != null) {
    messenger.showSnackBar(SnackBar(content: Text(err)));
    return;
  }

  if (s.openMerchVisit != null && context.mounted) {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VisitScreen(visit: s.openMerchVisit!)));
  }
}

/// شاشة زيارة الفرع: صورة قبل ← ريفيل ← طلب ناقص ← صورة بعد ← خروج
class VisitScreen extends StatefulWidget {
  final MerchVisit visit;
  const VisitScreen({super.key, required this.visit});

  @override
  State<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends State<VisitScreen> {
  bool _busy = false;
  bool _sendingLoc = false;

  MerchVisit get visit => Session.I.openMerchVisit ?? widget.visit;

  /// تأكيد العنوان (٢٨/٨): سحب النقطة → طلب تعديل عنوان للأدمن —
  /// نفس مسار المندوب بالحرف (المندوب بيبعت والأدمن بيأكد)
  Future<void> _confirmAddress() async {
    // امسك قبل الـawait — الرسالة بعد الرجوع بتضيع (درس ٩/٨)
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sendingLoc = true);

    final pos = await Locator.get();

    if (pos == null) {
      if (!mounted) return;
      setState(() => _sendingLoc = false);
      messenger.showSnackBar(SnackBar(content: Text(L.t('nc_gps_failed'))));

      return;
    }

    try {
      await Api.I.saveClientLocation(visit.clientId, lat: pos.$1, lng: pos.$2);
      if (!mounted) return;
      setState(() => _sendingLoc = false);
      messenger.showSnackBar(SnackBar(content: Text(L.t('pv_addr_sent'))));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sendingLoc = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _sendingLoc = false);
      messenger.showSnackBar(SnackBar(content: Text(L.t('server_down'))));
    }
  }

  Future<void> _run(Future<String?> Function() action, [String? okMsg]) async {
    setState(() => _busy = true);
    final err = await action();
    if (!mounted) return;
    setState(() => _busy = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else if (okMsg != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(okMsg)));
    }
  }

  /// الكاميرا ولا الجاليري (طلب المالك ٢١/٩) — فرع مانع التصوير جوّاه،
  /// أو صورة اتاخدت بكاميرا التليفون قبل فتح الأبلكيشن
  Future<ImageSource?> _askSource() => showModalBottomSheet<ImageSource>(
        context: context,
        builder: (sheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(L.t('pv_src_camera')),
                onTap: () => Navigator.of(sheet).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(L.t('pv_src_gallery')),
                onTap: () => Navigator.of(sheet).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

  Future<void> _shootShelf(String stage) async {
    final source = await _askSource();
    if (source == null || !mounted) return;

    try {
      final x = await ImagePicker()
          .pickImage(source: source, imageQuality: 75, maxWidth: 1800);
      if (x == null) return;
      await _run(
        () => Session.I.uploadShelfPhoto(visit.id, stage, x.path),
        stage == 'before' ? L.t('before_photo_taken') : L.t('after_photo_taken'),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(L.t('camera_failed', {'e': '$e'}))));
      }
    }
  }

  /// إنهاء بدون تصوير (طلب المالك ٢١/٩): سبب مكتوب إجباري، والسيرفر
  /// بيعلّم الزيارة وبيبعت تنبيه لمدير المنسق
  Future<String?> _askNoPhotoReason() {
    final ctrl = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (dlg) => AlertDialog(
        title: Text(L.t('pv_no_photos_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(L.t('pv_no_photos_body'), style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 190,
              maxLines: 2,
              decoration: InputDecoration(labelText: L.t('pv_no_photos_reason')),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dlg).pop(),
              child: Text(L.t('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB00020)),
            onPressed: () {
              final r = ctrl.text.trim();
              if (r.length < 3) return;
              Navigator.of(dlg).pop(r);
            },
            child: Text(L.t('pv_no_photos_confirm')),
          ),
        ],
      ),
    );
  }

  Future<void> _close() async {
    final v = visit;

    if (!v.hasPhotoBefore || !v.hasPhotoAfter) {
      final reason = await _askNoPhotoReason();
      if (reason == null || !mounted) return;
      await _run(() =>
          Session.I.closeMerchVisit(v.id, noPhotos: true, reason: reason));
    } else {
      await _run(() => Session.I.closeMerchVisit(v.id));
    }

    if (mounted && Session.I.openMerchVisit == null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final v = visit;
        final primary = Theme.of(context).colorScheme.primary;
        final closed = Session.I.openMerchVisit == null;

        return Scaffold(
          appBar: AppBar(title: Text(v.client)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InfoRow(icon: Icons.place_outlined, text: v.address),
                      if (v.checkedInAt != null)
                        InfoRow(
                            icon: Icons.login,
                            text: L.t('entered_at', {'t': '${fmtTime(v.checkedInAt!)}'})),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Chip2(
                              text: L.t('n_to_shelf', {'n': '${v.movedTotal}'}),
                              color: const Color(0xFF16A34A)),
                          if (v.outOfStock > 0)
                            Chip2(
                                text: L.t('n_short', {'n': '${v.outOfStock}'}),
                                color: const Color(0xFFB00020)),
                          if (v.hasRequest)
                            Chip2(
                                text: L.t('refill_sent'),
                                color: Color(0xFFEA8C1C)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (_busy) const LinearProgressIndicator(),
              const SizedBox(height: 10),

              // ---- 1. صورة الرف قبل ----
              _StepCard(
                step: '1',
                title: L.t('shelf_before'),
                done: v.hasPhotoBefore,
                color: primary,
                child: _PhotoBox(
                  url: v.photoBefore,
                  done: v.hasPhotoBefore,
                  label: L.t('shoot_before'),
                  // ⚠️ `_busy` كمان — دوستين ورا بعض كانوا بيرفعوا صورتين
                  onTap: (closed || _busy) ? null : () => _shootShelf('before'),
                ),
              ),

              // ---- 2. الريفيل ----
              _StepCard(
                step: '2',
                title: L.t('refill_from_backstore'),
                done: v.refills.isNotEmpty,
                color: primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (v.refills.isEmpty)
                      Text(L.t('refill_hint'),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600))
                    else
                      ...v.refills.map((r) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Icon(
                                    r.outOfStock
                                        ? Icons.error_outline
                                        : Icons.check_circle_outline,
                                    size: 15,
                                    color: r.outOfStock
                                        ? const Color(0xFFB00020)
                                        : const Color(0xFF16A34A)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(r.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12)),
                                ),
                                Text(
                                    r.outOfStock
                                        ? L.t('short')
                                        : '${r.shelfBefore} ← ${r.shelfAfter}',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: r.outOfStock
                                            ? const Color(0xFFB00020)
                                            : Colors.black87)),
                              ],
                            ),
                          )),
                    const SizedBox(height: 10),
                    if (!closed)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42)),
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: Text(
                            v.refills.isEmpty ? L.t('start_refill') : L.t('edit_refill'),
                            style: const TextStyle(fontSize: 13.5)),
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => RefillScreen(visit: v))),
                      ),
                  ],
                ),
              ),

              // ---- جرد الرف بإيد المنسق (٢١/٩): كميات بوحداتها +
              // تواريخ إنتاج وانتهاء. اختياري، ومحفوظ على الفرع ----
              Card(
                child: ListTile(
                  leading: Icon(Icons.fact_check_outlined,
                      color: v.counts.isEmpty ? primary : const Color(0xFF16A34A)),
                  title: Text(L.t('sc_title'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: Text(
                      v.counts.isNotEmpty
                          ? L.t('sc_done_n', {'n': '${v.counts.length}'})
                          : v.lastCounts.isNotEmpty
                              ? L.t('sc_last_hint', {'n': '${v.lastCounts.length}'})
                              : L.t('sc_card_hint'),
                      style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: closed
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ShelfCountScreen(visit: v))),
                ),
              ),

              // ---- 3. طلب ريفيل للناقص ----
              if (v.outOfStock > 0 || v.hasRequest)
                _StepCard(
                  step: '3',
                  title: L.t('request_short_items'),
                  done: v.hasRequest,
                  color: primary,
                  child: v.hasRequest
                      ? Text(L.t('sent_to_manager_assign'),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade700))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                L.t('n_out_everywhere', {'n': '${v.outOfStock}'}),
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFFB00020))),
                            const SizedBox(height: 10),
                            if (!closed)
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFEA8C1C),
                                    minimumSize: const Size.fromHeight(42)),
                                icon: const Icon(Icons.local_shipping_outlined,
                                    size: 18),
                                label: Text(L.t('request_branch_supply'),
                                    style: TextStyle(fontSize: 13.5)),
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            ReplenishmentScreen(visit: v))),
                              ),
                          ],
                        ),
                ),

              // ---- تأكيد العنوان (٢٨/٨ — طلب المالك: تالت زرار
              // الزيارة). بيسحب النقطة ويبعت **طلب** تعديل عنوان —
              // نفس فلو المندوب: المندوب بيبعت نقطة والأدمن بيأكد ----
              // ⚠️ وبيختفي على الفرع المؤكَّد من الداشبورد (١٥/٩) —
              // نفس قاعدة زرار المندوب، والسيرفر بيرفض 409 كمان
              if (!closed && !v.locationConfirmed)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.share_location,
                        color: Color(0xFF0F766E)),
                    title: Text(L.t('pv_confirm_addr'),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13.5)),
                    subtitle: Text(L.t('pv_confirm_addr_hint'),
                        style: const TextStyle(fontSize: 11)),
                    trailing: _sendingLoc
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: _sendingLoc ? null : _confirmAddress,
                  ),
                ),

              // ---- 4. صورة الرف بعد ----
              _StepCard(
                step: v.outOfStock > 0 || v.hasRequest ? '4' : '3',
                title: L.t('shelf_after'),
                done: v.hasPhotoAfter,
                color: primary,
                child: _PhotoBox(
                  url: v.photoAfter,
                  done: v.hasPhotoAfter,
                  label: L.t('shoot_after'),
                  onTap: (closed || _busy) ? null : () => _shootShelf('after'),
                ),
              ),

              const SizedBox(height: 8),

              if (closed)
                Card(
                  color: const Color(0xFFE7F7EE),
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF16A34A)),
                        SizedBox(width: 10),
                        Text(L.t('visit_closed'),
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                )
              else
                FilledButton.icon(
                  icon: const Icon(Icons.logout),
                  label:
                      Text(L.t('end_visit'), style: TextStyle(fontSize: 16)),
                  onPressed: _busy ? null : _close,
                ),
              const SizedBox(height: 8),
              if (!closed && (!v.hasPhotoBefore || !v.hasPhotoAfter))
                Text(L.t('need_both_photos'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11.5, color: Colors.orange.shade800)),
            ],
          ),
        );
      },
    );
  }
}

// ================= خطوة في الفلو =================

class _StepCard extends StatelessWidget {
  final String step;
  final String title;
  final bool done;
  final Color color;
  final Widget child;

  const _StepCard({
    required this.step,
    required this.title,
    required this.done,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor:
                      done ? const Color(0xFF16A34A) : color.withValues(alpha: 0.15),
                  child: done
                      ? const Icon(Icons.check, size: 15, color: Colors.white)
                      : Text(step,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: color)),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _PhotoBox extends StatelessWidget {
  final String? url;
  final bool done;
  final String label;
  final VoidCallback? onTap;

  const _PhotoBox({
    required this.url,
    required this.done,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: done ? 150 : 92,
        decoration: BoxDecoration(
          color: done ? const Color(0xFFE7F7EE) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: done ? const Color(0xFF16A34A) : Colors.grey.shade400),
        ),
        clipBehavior: Clip.antiAlias,
        child: done && url != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(url!, cacheWidth: 800,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.check_circle,
                              color: Color(0xFF16A34A), size: 34))),
                  if (onTap != null)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Text(L.t('tap_retake'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white, fontSize: 11)),
                      ),
                    ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_camera_outlined,
                        size: 26, color: Colors.grey.shade600),
                    const SizedBox(height: 6),
                    Text(label,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
      ),
    );
  }
}

// ================= شاشة الريفيل =================

class RefillScreen extends StatefulWidget {
  final MerchVisit visit;
  const RefillScreen({super.key, required this.visit});

  @override
  State<RefillScreen> createState() => _RefillScreenState();
}

class _RefillScreenState extends State<RefillScreen> {
  late final Map<int, RefillLine> _lines;

  /// الأصناف الظاهرة على الشاشة — اللي البروموتر علّم عليها في
  /// المنتقي المتعدد (أو اللي اتسجل فيها حاجة قبل كده). الحفظ لسه
  /// بيبعت **كل** السطور زي الأول — الفلترة عرض بس.
  final Set<int> _shown = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // نبدأ من الكتالوج ونملا اللي اتسجل قبل كده
    _lines = {
      for (final p in Session.I.catalog)
        p.id: RefillLine(productId: p.id, name: p.name, unit: p.unit),
    };
    for (final r in widget.visit.refills) {
      _lines[r.productId] = r;
      if (r.touched) _shown.add(r.productId);
    }
  }

  /// المنتقي المتعدد: علّم على الأصناف اللي اشتغلت عليها — وشيل
  /// العلامة بيشيل السطر **وبيصفّر أرقامه** عشان مايتحفظش بالغلط.
  Future<void> _openPicker() async {
    final entries = <PickEntry>[
      for (final p in Session.I.catalog)
        PickEntry(
            id: p.id,
            name: p.name,
            code: p.code,
            image: p.image,
            subtitle: p.unit),
    ];

    final res = await showMultiItemPicker(
      context,
      entries: entries,
      preSelected: Set<int>.of(_shown),
    );
    if (res == null || !mounted) return;

    setState(() {
      for (final p in Session.I.catalog) {
        if (res.contains(p.id)) {
          _shown.add(p.id);
          _lines[p.id]?.removed = false;
        } else if (_shown.remove(p.id)) {
          final l = _lines[p.id];
          if (l != null) {
            l.shelfBefore = 0;
            l.storeQty = 0;
            l.movedQty = 0;
            l.outOfStock = false;
            // متعلّم للحذف — بيتبعت بأصفاره والسيرفر بيمسح صفه
            l.removed = true;
          }
        }
      }
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final err =
        await Session.I.saveRefill(widget.visit.id, _lines.values.toList());
    if (!mounted) return;
    setState(() => _busy = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    // ⚠️ امسك الاتنين **قبل** الـpop — بعده الكونتكست ميت والرسالة
    // كانت بتضيع (نفس فخ collect.dart الموثّق)
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text(L.t('refill_saved'))));
  }

  @override
  Widget build(BuildContext context) {
    // الظاهر بس — بترتيب الكتالوج الثابت
    final list = [
      for (final p in Session.I.catalog)
        if (_shown.contains(p.id) && _lines[p.id] != null) _lines[p.id]!,
    ];
    final moved = _lines.values.fold<int>(0, (a, l) => a + l.movedQty);
    final oos = _lines.values.where((l) => l.outOfStock).length;

    return Scaffold(
      appBar: AppBar(title: Text(L.t('shelf_refill'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: PickerBox(onTap: _openPicker),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.checklist_rounded,
                            size: 46, color: Colors.grey.shade500),
                        const SizedBox(height: 10),
                        Text(L.t('pick_then_refill_hint'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: list.length,
                    itemBuilder: (context, i) => _RefillRow(
                      line: list[i],
                      onChanged: () => setState(() {}),
                    ),
                  ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.viewPaddingOf(context).bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_busy) const LinearProgressIndicator(),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(L.t('n_will_move', {'n': '$moved'}),
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w900)),
                            if (oos > 0)
                              Text(L.t('n_short', {'n': '$oos'}),
                                  style: const TextStyle(
                                      fontSize: 11.5, color: Color(0xFFB00020))),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(140, 48)),
                        icon: const Icon(Icons.check),
                        label: Text(L.t('save')),
                        onPressed: _busy ? null : _save,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RefillRow extends StatelessWidget {
  final RefillLine line;
  final VoidCallback onChanged;
  const _RefillRow({required this.line, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final active = line.touched;

    return Card(
      color: line.outOfStock
          ? const Color(0xFFFDECEC)
          : (active ? const Color(0xFFF1F8F5) : null),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(line.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                Text(line.unit,
                    style: TextStyle(
                        fontSize: 10.5, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _NumField(
                  label: L.t('on_shelf'),
                  value: line.shelfBefore,
                  onChanged: (v) {
                    line.shelfBefore = v;
                    onChanged();
                  },
                ),
                const SizedBox(width: 8),
                _NumField(
                  label: L.t('in_store'),
                  value: line.storeQty,
                  onChanged: (v) {
                    line.storeQty = v;
                    if (line.movedQty > v) line.movedQty = v;
                    onChanged();
                  },
                ),
                const SizedBox(width: 8),
                _NumField(
                  label: L.t('moved_qty'),
                  value: line.movedQty,
                  max: line.storeQty,
                  highlight: true,
                  onChanged: (v) {
                    line.movedQty = v;
                    onChanged();
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () {
                line.outOfStock = !line.outOfStock;
                if (line.outOfStock) {
                  line.storeQty = 0;
                  line.movedQty = 0;
                }
                onChanged();
              },
              child: Row(
                children: [
                  Icon(
                      line.outOfStock
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: line.outOfStock
                          ? const Color(0xFFB00020)
                          : Colors.grey),
                  const SizedBox(width: 6),
                  Text(L.t('out_of_stock'),
                      style: TextStyle(
                          fontSize: 11.5,
                          color: line.outOfStock
                              ? const Color(0xFFB00020)
                              : Colors.grey.shade700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final int value;
  final int? max;
  final bool highlight;
  final ValueChanged<int> onChanged;

  const _NumField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.max,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          const SizedBox(height: 3),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: highlight && value > 0
                      ? primary
                      : Colors.grey.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: value > 0 ? () => onChanged(value - 1) : null,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.remove, size: 15),
                  ),
                ),
                Text('$value',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 14)),
                InkWell(
                  onTap: (max == null || value < max!)
                      ? () => onChanged(value + 1)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.add,
                        size: 15,
                        color: (max == null || value < max!)
                            ? primary
                            : Colors.grey.shade400),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= شاشة طلب الريفيل =================

class ReplenishmentScreen extends StatefulWidget {
  final MerchVisit visit;
  const ReplenishmentScreen({super.key, required this.visit});

  @override
  State<ReplenishmentScreen> createState() => _ReplenishmentScreenState();
}

class _ReplenishmentScreenState extends State<ReplenishmentScreen> {
  final Map<int, int> _qty = {};
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // نبدأ بالأصناف الناقصة بكمية مقترحة
    for (final r in widget.visit.refills.where((r) => r.outOfStock)) {
      _qty[r.productId] = 24;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// المنتقي المتعدد: الصنف الجديد بينزل بالكمية المقترحة (٢٤)
  /// والعداد بعدها ±٦ — وشيل العلامة بيشيل السطر من الطلب.
  Future<void> _openPicker() async {
    final entries = <PickEntry>[
      for (final p in Session.I.catalog)
        PickEntry(
            id: p.id,
            name: p.name,
            code: p.code,
            image: p.image,
            subtitle: p.unit),
    ];

    final res = await showMultiItemPicker(
      context,
      entries: entries,
      preSelected: _qty.keys.toSet(),
    );
    if (res == null || !mounted) return;

    setState(() {
      for (final p in Session.I.catalog) {
        final had = _qty.containsKey(p.id);
        final want = res.contains(p.id);

        if (want && !had) {
          _qty[p.id] = 24;
        } else if (!want && had) {
          _qty.remove(p.id);
        }
      }
    });
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    final err = await Session.I.requestReplenishment(
        widget.visit.id, _qty, _note.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    // ⚠️ امسك الاتنين **قبل** الـpop — بعده الكونتكست ميت والرسالة
    // كانت بتضيع (نفس فخ collect.dart الموثّق)
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text(L.t('sent_to_manager'))));
  }

  @override
  Widget build(BuildContext context) {
    final catalog = Session.I.catalog;
    final total = _qty.values.fold<int>(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(title: Text(L.t('branch_supply_request'))),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: const Color(0xFFFFF4E0),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFFB86E00)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              L.t('supply_flow_hint'),
                              style: TextStyle(fontSize: 12.5)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                PickerBox(onTap: _openPicker),
                const SizedBox(height: 10),
                if (_qty.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 26),
                    child: Column(
                      children: [
                        Icon(Icons.checklist_rounded,
                            size: 46, color: Colors.grey.shade500),
                        const SizedBox(height: 10),
                        Text(L.t('pick_then_qty_hint'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ...catalog.where((p) => _qty.containsKey(p.id)).map((p) {
                  final q = _qty[p.id] ?? 0;
                  return Card(
                    color: q > 0 ? const Color(0xFFFFF9EF) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5)),
                                Text(p.unit,
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            // حارس السالب: كمية مش من مضاعفات ٦ متنزلش تحت الصفر
                            onPressed: q > 0
                                ? () => setState(
                                    () => _qty[p.id] = q > 6 ? q - 6 : 0)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          SizedBox(
                            width: 34,
                            child: Text('$q',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                setState(() => _qty[p.id] = q + 6),
                            icon: Icon(Icons.add_circle,
                                color: Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                TextField(
                  controller: _note,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: L.t('note_to_manager'),
                    hintText: L.t('note_example'),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_busy) const LinearProgressIndicator(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(L.t('n_requested', {'n': '$total'}),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFEA8C1C),
                            minimumSize: const Size(150, 48)),
                        icon: const Icon(Icons.send),
                        label: Text(L.t('send_request')),
                        onPressed: (total <= 0 || _busy) ? null : _send,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
