import 'package:flutter/material.dart';
import '../l10n.dart';

import '../api.dart';
import '../models.dart';
import '../pick_models.dart';
import '../session.dart';
import 'shared.dart';
import 'warehouse_visit.dart';

const _gold = Color(0xFFE4B23C);
const _ok = Color(0xFF16A34A);
const _bad = Color(0xFFB00020);
const _warn = Color(0xFFB86E00);
const _line = Color(0xFFE7E3DA);
const _paper = Color(0xFFF4F2EC);

/// أوامر التجهيز بتاعت المندوب:
/// المخزن بيجهّز البضاعة ويعلّمها «جاهز» → المندوب بيفتح الأمر، يعدّ،
/// يعدّل الكميات لو فيه فرق → يأكد → البضاعة تنزل عهدته.
class PickOrdersScreen extends StatelessWidget {
  const PickOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final all = Session.I.picks;
        final ready = all.where((p) => p.canReceive).toList();
        final rest = all.where((p) => !p.canReceive).toList();

        return Scaffold(
          appBar: AppBar(title: Text(L.t('receive_from_wh'))),
          body: Column(children: [
            const _WarehouseBanner(),
            Expanded(
              child: RefreshIndicator(
            onRefresh: Session.I.refresh,
            child: all.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 160),
                      Icon(Icons.move_to_inbox_outlined,
                          size: 54, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(L.t('no_picks'),
                            style: TextStyle(color: Colors.grey.shade600)),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(L.t('no_picks_hint'),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500)),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      if (ready.isNotEmpty) ...[
                        _title(L.t('ready_count', {'n': '${ready.length}'})),
                        ...ready.map((p) => _ReadyPickCard(order: p)),
                        const SizedBox(height: 10),
                      ],
                      if (rest.isNotEmpty) ...[
                        _title(L.t('other_orders', {'n': '${rest.length}'})),
                        ...rest.map((p) => _PickCard(order: p)),
                      ],
                    ],
                  ),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 2),
        child: Text(text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );
}


/// ═══════════════════════════════════════════════════════════════
/// بانر المخزن — المدخل الدائم لدخول وخروج المخزن (2026-08-08)
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ **قبل كده ماكانش فيه أي مدخل لشاشة المخزن خالص.** الشاشة
/// اتبنت، والحارس اتحط، والسيرفر بيرد «لازم تسجّل دخول المخزن» —
/// بس مافيش زرار واحد في الأبلكيشن بيوصّل لها. الطريق الوحيد كان
/// بوب أب البوابة، وهو كان بيودّي **لشاشة الحضور** بالغلط. النتيجة:
/// المندوب واقف في مخزن المعادي، بيدوس استلام، بياخد رفض، بيتودّي
/// للحضور اللي هو مسجّله من الصبح، ويلف في نفس اللفة للأبد.
///
/// فالبانر ده مش زينة — هو المخرج من اللفة دي، ومكانه بالظبط فوق
/// الشاشة اللي الاستلام بيحصل فيها.
class _WarehouseBanner extends StatelessWidget {
  const _WarehouseBanner();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final stop = Session.I.whStop;
        final inside = stop != null;
        final tone = inside ? _ok : _warn;

        return Material(
          color: inside ? const Color(0xFFE8F5EC) : const Color(0xFFFFF3E0),
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const WarehouseVisitScreen())),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
              child: Row(
                children: [
                  Icon(inside ? Icons.lock_open : Icons.warehouse,
                      size: 21, color: tone),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inside
                              ? L.t('wh_inside') + ' ' + stop.warehouse
                              : L.t('wh_required'),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: tone),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          inside
                              ? stop.liveLabel + ' · ' + L.t('wh_can_receive')
                              : L.t('wh_required_hint'),
                          style: TextStyle(
                              fontSize: 11,
                              height: 1.5,
                              color: tone.withValues(alpha: .85)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios, size: 13, color: tone),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ================= كروت القايمة =================

Widget _meta(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
      ],
    );

Widget _badge(Color color, String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );

/// أمر جاهز — بارز بإطار دهبي وزرار استلام
class _ReadyPickCard extends StatelessWidget {
  final PickOrder order;
  const _ReadyPickCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final (color, label) = order.info;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _gold, width: 1.8),
      ),
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
                      Text(
                        order.warehouse.isEmpty ? L.t('warehouse') : order.warehouse,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${order.number}${order.purposeLabel.isEmpty ? '' : ' • ${order.purposeLabel}'}',
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                _badge(color, label),
              ],
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _meta(Icons.inventory_2_outlined,
                    L.t('n_prepared', {'n': '${order.qtyPicked}'})),
                _meta(Icons.list_alt_outlined, L.t('n_items', {'n': '${order.items.length}'})),
                if (order.readyAt != null)
                  _meta(Icons.schedule, L.t('ready_at', {'t': '${fmtTime(order.readyAt!)}'})),
              ],
            ),

            if (order.qtyPicked < order.qtyRequested) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 15, color: _warn),
                  const SizedBox(width: 4),
                  Text(
                    L.t('requested_vs_picked', {'a': '${order.qtyRequested}', 'b': '${order.qtyPicked}'}),
                    style: const TextStyle(fontSize: 11.5, color: _warn),
                  ),
                ],
              ),
            ],

            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _paper,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(order.notes!, style: const TextStyle(fontSize: 12)),
              ),
            ],

            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PickReceiveScreen(order: order))),
              icon: const Icon(Icons.move_to_inbox, size: 19),
              label: Text(L.t('receive_goods')),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
            ),
          ],
        ),
      ),
    );
  }
}

/// أمر لسه مش جاهز (أو اتسلّم/اتلغى) — كارت عادي بالحالة بس
class _PickCard extends StatelessWidget {
  final PickOrder order;
  const _PickCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final (color, label) = order.info;

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
                      Text(
                        order.warehouse.isEmpty ? L.t('warehouse') : order.warehouse,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${order.number}${order.purposeLabel.isEmpty ? '' : ' • ${order.purposeLabel}'}',
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                _badge(color, label),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _meta(Icons.inventory_2_outlined,
                    L.t('n_requested', {'n': '${order.qtyRequested}'})),
                if (order.isHanded)
                  _meta(Icons.done_all, L.t('n_received', {'n': '${order.qtyReceived}'})),
                // ⚠️ الهدايا بتبان في الكارت قبل ما يفتحه — عشان
                // يعرف إن جوه الشحنة كمية مش للبيع من غير ما يدخل.
                if (order.giftTotal > 0)
                  _meta(Icons.card_giftcard_outlined,
                      L.t('n_gifts', {'n': '${order.giftTotal}'})),
                _meta(Icons.schedule,
                    fmtTime(order.handedAt ?? order.readyAt ?? order.time)),
              ],
            ),
            if (order.isHanded && order.hasVariance) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.report_problem_outlined,
                      size: 15, color: _warn),
                  const SizedBox(width: 4),
                  Text(L.t('received_with_diff'),
                      style: TextStyle(fontSize: 11.5, color: _warn)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ================= شاشة الاستلام والعدّ =================

class PickReceiveScreen extends StatefulWidget {
  final PickOrder order;
  const PickReceiveScreen({super.key, required this.order});

  @override
  State<PickReceiveScreen> createState() => _PickReceiveScreenState();
}

class _PickReceiveScreenState extends State<PickReceiveScreen> {
  late PickOrder _order;
  final _note = TextEditingController();
  final Map<int, TextEditingController> _qty = {};
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _buildControllers();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    for (final c in _qty.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _buildControllers() {
    for (final c in _qty.values) {
      c.dispose();
    }
    _qty.clear();
    for (final i in _order.items) {
      _qty[i.id] = TextEditingController(text: '${i.qtyToReceive}');
    }
  }

  /// بنجيب نسخة طازة من الأمر عشان الكميات تبدأ من اللي المخزن جهّزه
  Future<void> _load() async {
    try {
      final d = await Api.I.pick(_order.id);
      final fresh = PickOrder.fromJson((d['pick'] ?? {}) as Map<String, dynamic>);
      if (!mounted) return;
      setState(() {
        _order = fresh;
        _buildControllers();
        _loading = false;
      });
    } catch (_) {
      // ⚠️ **الفشل بيبان** (تدقيق ٩/٨): كان بيتبلع في صمت والمندوب
      // بيعدّ على كميات قديمة من القايمة. بنكمّل بالقديم فعلاً
      // (أحسن من شاشة فاضية) بس بسناك بيقول اسحب للتحديث.
      if (!mounted) return;
      setState(() => _loading = false);
      snack(context, L.t('pick_stale_warning'), bad: true);
    }
  }

  int get _totalPicked => _order.items.fold(0, (s, i) => s + i.qtyPicked);
  int get _totalReceive => _order.qtyToReceive;
  bool get _variance => _order.touched;
  bool get _needsNote => _variance && _note.text.trim().isEmpty;

  bool get _canConfirm =>
      !_busy && _order.canReceive && _order.items.isNotEmpty && !_needsNote;

  void _setQty(PickItem item, int v) {
    final max = item.qtyPicked;
    final clamped = v < 0 ? 0 : (v > max ? max : v);
    setState(() => item.qtyToReceive = clamped);

    final c = _qty[item.id];
    if (c != null && c.text != '$clamped') {
      c.text = '$clamped';
      c.selection = TextSelection.collapsed(offset: c.text.length);
    }
  }

  Future<void> _confirm() async {
    if (!_canConfirm) return;

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final total = _totalReceive;
    final note = _note.text.trim();

    setState(() => _busy = true);

    final err = await Session.I.receivePick(
      _order.id,
      _order.items.map((i) => i.toReceiveJson()).toList(),
      note: note.isEmpty ? null : note,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (err != null) {
      messenger.showSnackBar(
          SnackBar(content: Text(err), backgroundColor: _bad));
      return;
    }

    nav.pop(true);
    messenger.showSnackBar(SnackBar(
      content: Text(L.t('received_onto_van', {'n': '$total'})),
      backgroundColor: _ok,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.t('receive_number', {'n': '${_order.number}'}))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _header(),
                const SizedBox(height: 4),
                if (_order.items.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(L.t('pick_no_items'),
                            style: TextStyle(color: Colors.grey.shade600)),
                      ),
                    ),
                  ),
                ..._order.items.map(_itemCard),
                if (_variance) _noteBox(),
                const SizedBox(height: 8),
              ],
            ),
            ),
      bottomNavigationBar: _loading ? null : _bottomBar(),
    );
  }

  // ---------- رأس الشاشة ----------

  Widget _header() {
    final (color, label) = _order.info;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _order.warehouse.isEmpty ? L.t('warehouse') : _order.warehouse,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                _badge(color, label),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _meta(Icons.receipt_long_outlined, _order.number),
                if (_order.purposeLabel.isNotEmpty)
                  _meta(Icons.flag_outlined, _order.purposeLabel),
                _meta(Icons.list_alt_outlined, L.t('n_items', {'n': '${_order.items.length}'})),
                if (_order.readyAt != null)
                  _meta(Icons.schedule, L.t('ready_at', {'t': '${fmtTime(_order.readyAt!)}'})),
              ],
            ),
            if (_order.notes != null && _order.notes!.isNotEmpty) ...[
              const SizedBox(height: 9),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _paper,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_order.notes!, style: const TextStyle(fontSize: 12)),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              _order.canReceive
                  ? L.t('count_hint')
                  : L.t('pick_not_receivable'),
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- كارت الصنف ----------

  Widget _itemCard(PickItem i) {
    final diff = i.hasVariance;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: diff ? _warn : _line, width: diff ? 1.4 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // الصورة — المندوب بيطابق اللي قدامه باللي على الشاشة
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE7E3DA)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: i.image == null
                      ? Icon(Icons.inventory_2_outlined,
                          size: 26, color: Colors.grey.shade400)
                      : Image.network(i.image!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.inventory_2_outlined,
                              size: 26,
                              color: Colors.grey.shade400)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14.5)),
                      const SizedBox(height: 2),
                      Text(
                        '${i.code}${i.unit.isEmpty ? '' : ' • ${i.unit}'}',
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                _badge(const Color(0xFF2563EB), L.t('picked_n', {'n': '${i.qtyPicked}'})),
              ],
            ),
            const SizedBox(height: 9),

            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _meta(Icons.label_outline, L.t('batch_n', {'n': '${i.batchNo}'})),
                _meta(Icons.calendar_today, L.t('expiry_n', {'n': '${i.expiryLabel}'})),
                _meta(Icons.place_outlined, L.t('shelf_n', {'n': '${i.location}'})),
              ],
            ),

            // ⚠️ **الهدية لازم تبان في السطر قبل ما يعدّ.** لو مابانتش،
            // بيستلم الكمية كلها وهو فاكرها كلها للبيع، وبعدين بيلاقي
            // في عهدته كمية «مجانية» مش عارف مصدرها.
            if (i.hasGift) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EAFD),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.card_giftcard_outlined,
                        size: 15, color: Color(0xFF602D90)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        L.t('gift_in_line',
                            {'g': '${i.giftQty}', 's': '${i.saleQty}'}),
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF602D90),
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (i.shortPicked) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: _warn),
                  const SizedBox(width: 4),
                  Text(L.t('was_requested', {'n': '${i.qtyRequested}'}),
                      style: const TextStyle(fontSize: 11.5, color: _warn)),
                ],
              ),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            Row(
              children: [
                Text(L.t('what_you_counted'),
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                const Spacer(),
                _stepBtn(
                  Icons.remove,
                  _order.canReceive && i.qtyToReceive > 0
                      ? () => _setQty(i, i.qtyToReceive - 1)
                      : null,
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 74,
                  child: TextField(
                    controller: _qty[i.id],
                    enabled: _order.canReceive,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                    ),
                    onChanged: (t) {
                      final s = t.trim();
                      if (s.isEmpty) {
                        setState(() => i.qtyToReceive = 0);
                        return;
                      }
                      final v = int.tryParse(s);
                      if (v == null) {
                        _setQty(i, i.qtyToReceive);
                        return;
                      }
                      _setQty(i, v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _stepBtn(
                  Icons.add,
                  _order.canReceive && i.qtyToReceive < i.qtyPicked
                      ? () => _setQty(i, i.qtyToReceive + 1)
                      : null,
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 34,
                  child: Text('/${i.qtyPicked}',
                      style: TextStyle(
                          fontSize: 12.5, color: Colors.grey.shade600)),
                ),
              ],
            ),

            if (diff) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: _warn.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  L.t(
                    i.qtyToReceive < i.qtyPicked ? 'diff_short' : 'diff_over',
                    {'n': '${(i.qtyToReceive - i.qtyPicked).abs()}'},
                  ),
                  style: const TextStyle(
                      fontSize: 11.5, color: _warn, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(42, 42),
          fixedSize: const Size(42, 42),
          shape: const CircleBorder(),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Icon(icon, size: 19),
      );

  // ---------- سبب الفرق ----------

  Widget _noteBox() => Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _warn, width: 1.4),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_note, size: 19, color: _warn),
                  const SizedBox(width: 6),
                  Text(L.t('write_diff_reason'),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: _warn)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                L.t('diff_explain'),
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                maxLines: 3,
                maxLength: 500,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: L.t('diff_example'),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _warn, width: 1.6)),
                ),
              ),
            ],
          ),
        ),
      );

  // ---------- الشريط السفلي ----------

  Widget _bottomBar() {
    return SafeArea(
      bottom: false,
      child: Container(
        // viewPadding صريح (مسح ٢١/٨)
        padding: EdgeInsets.fromLTRB(14, 12, 14, 12 + MediaQuery.viewPaddingOf(context).bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _line)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(L.t('what_you_received'),
                          style: TextStyle(
                              fontSize: 11.5, color: Colors.grey.shade600)),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('$_totalReceive',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: _variance ? _warn : _ok)),
                          Text(' / ${L.t('n_units', {'n': '$_totalPicked'})}',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_variance)
                  _badge(_warn, L.t('has_diff'))
                else
                  _badge(_ok, L.t('matching')),
              ],
            ),
            if (_needsNote) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: _warn),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(L.t('need_diff_reason'),
                        style: TextStyle(fontSize: 11.5, color: _warn)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            if (_busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 10),
            ],
            FilledButton.icon(
              onPressed: _canConfirm ? _confirm : null,
              icon: const Icon(Icons.done_all),
              label: Text(
                _order.canReceive
                    ? L.t('confirm_receipt', {'n': '$_totalReceive'})
                    : L.t('pick_closed'),
                style: const TextStyle(fontSize: 15.5),
              ),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ),
      ),
    );
  }
}
