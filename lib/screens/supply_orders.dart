import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../brand.dart';
import '../l10n.dart';
import '../models.dart';
import 'order_summary.dart';
import '../locator.dart';
import 'sale_review.dart';
import 'zones.dart';
import '../session.dart';

/// ═══════════════════════════════════════════════════════════════
/// أوامر التوريد — تاب المندوب (فلو الكي أكاونت 2026-08-04)
/// ═══════════════════════════════════════════════════════════════
///
/// الأمر بييجي معتمد من الحسابات ومتجهز من المخزن — المندوب بيوصل
/// الفرع، بيعمل «وصلت»، وبيسلم. وقت التسليم يقدر يعدل الكميات
/// («9 كراتين مش 10») — والسيرفر بيقيّد **بالمسلَّم فعلاً** وبيرجّع
/// السامري: سلم إيه وإيه الفرق.
class SupplyOrdersScreen extends StatefulWidget {
  const SupplyOrdersScreen({super.key});

  @override
  State<SupplyOrdersScreen> createState() => _SupplyOrdersScreenState();
}

/// فلاتر الشاشة — الترتيب هو ترتيب الأهمية عند المندوب.
///
/// ⚠️ **الفلتر مش زينة — هو اللي بيحدد المندوب هيبدأ منين.** الشاشة
/// كانت بتعرض كل الأوامر ورا بعض، والمتأخر بيضيع وسط اللي جاي
/// الأسبوع الجاي. دلوقتي بيفتح على أخطر حاجة عنده.
enum _PoFilter { late, today, tomorrow, week, month, custom, delivered, all }

class _SupplyOrdersScreenState extends State<SupplyOrdersScreen> {
  _PoFilter? _filter;          // null = «الكل» (ديفولت الموك أب ٢١/٨)
  DateTimeRange? _range;       // للفلتر المخصص

  /// بحث سريع من أيقونة الهيدر — بالعميل أو رقم الأمر أو المرجع
  bool _searching = false;
  final _searchCtrl = TextEditingController();
  String _q = '';

  /// آخر نقطة GPS — لسطر «جملة · آجل · 6.4 كم» على الكارت
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// أول يوم في الأسبوع (السبت — أسبوع الشغل في مصر)
  DateTime _weekStart(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    // DateTime.saturday = 6
    final back = (day.weekday % 7 + 1) % 7;   // السبت = 0

    return day.subtract(Duration(days: back));
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// هل الأمر ده يدخل في الفلتر ده؟
  ///
  /// ⚠️ **المتأخر بيتشال من فلاتر التواريخ** (إصلاح 2026-08-07).
  /// كل الأوامر كانت بتطلع في كل فلتر — أمر متأخر معاده النهارده
  /// كان بيتعدّ في «متأخر» و«النهارده» و«الأسبوع ده» و«الشهر ده»،
  /// فالأربع شيبس بيقولوا نفس الرقم والليستة مابتتغيّرش مهما دوست.
  /// شكلها إن الفلاتر «مش شغالة» وهي شغالة — بس كل حاجة في كل حتة.
  ///
  /// دلوقتي فلاتر التواريخ معناها **الجاي** بس؛ المتأخر ليه فلتره
  /// لوحده لأنه حالة مختلفة تماماً: ده شغل فات مش شغل جاي.
  bool _match(PurchaseOrder po, _PoFilter f) {
    final delivered = po.status == 'delivered';
    final now = DateTime.now();
    final due = po.dueAt;

    // الأوامر «الجاية» = مش متسلّمة ومش متأخرة ولها معاد
    final upcoming = !delivered && !po.late && due != null;

    switch (f) {
      case _PoFilter.late:
        return !delivered && po.late;
      case _PoFilter.today:
        return upcoming && _sameDay(due, now);
      case _PoFilter.tomorrow:
        return upcoming && _sameDay(due, now.add(const Duration(days: 1)));
      case _PoFilter.week:
        if (!upcoming) return false;
        final start = _weekStart(now);

        return !due.isBefore(start) &&
            due.isBefore(start.add(const Duration(days: 7)));
      case _PoFilter.month:
        return upcoming && due.year == now.year && due.month == now.month;
      case _PoFilter.custom:
        if (!upcoming || _range == null) return false;

        return !due.isBefore(_range!.start) &&
            due.isBefore(_range!.end.add(const Duration(days: 1)));
      case _PoFilter.delivered:
        return delivered;
      case _PoFilter.all:
        // ⚠️ «الكل» = كل الشغل **المفتوح** (موك أب ٢١/٨) — المتسلّم
        // ليه شيبه لوحده؛ خلطه هنا كان بيخلي عداد «الكل» رقم مالوش
        // معنى عملي للمندوب.
        return !delivered;
    }
  }

  String _label(_PoFilter f) => switch (f) {
        _PoFilter.late => L.t('po_late'),
        _PoFilter.today => L.t('po_today'),
        _PoFilter.tomorrow => L.t('po_tomorrow'),
        _PoFilter.week => L.t('po_week'),
        _PoFilter.month => L.t('po_month'),
        // لما يختار فترة، الشيب بيعرضها بدل كلمة «تاريخ محدد» —
        // عشان يفضل شايف هو مفلتر على إيه من غير ما يفتح التقويم
        _PoFilter.custom => _range == null
            ? L.t('po_custom')
            : L.t('po_from_to', {
                'from': _day(_range!.start),
                'to': _day(_range!.end),
              }),
        _PoFilter.delivered => L.t('po_delivered'),
        _PoFilter.all => L.t('po_all'),
      };

  String _day(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range ??
          DateTimeRange(start: now, end: now.add(const Duration(days: 7))),
      helpText: L.t('po_pick_range'),
    );

    if (picked != null && mounted) {
      setState(() {
        _range = picked;
        _filter = _PoFilter.custom;
      });
    }
  }

  int _dueCompare(PurchaseOrder a, PurchaseOrder b) {
    final ad = a.dueAt, bd = b.dueAt;
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;

    return ad.compareTo(bd);
  }

  bool _isToday(PurchaseOrder p) =>
      p.dueAt != null && _sameDay(p.dueAt!, DateTime.now());

  /// سكشن الكارت في الليستة المجمّعة (موك أب ٢١/٨) — المتأخر فوق
  /// بعنوانه الأحمر، وبعده النهاردة فبكرة فالجاي فالمتسلّم.
  int _section(PurchaseOrder p) {
    if (p.status == 'delivered') return 4;
    if (p.late) return 0;
    if (_isToday(p)) return 1;
    if (p.dueAt != null &&
        _sameDay(p.dueAt!, DateTime.now().add(const Duration(days: 1)))) {
      return 2;
    }

    return 3;
  }

  String _secLabel(int s) => switch (s) {
        0 => L.t('po_sec_late'),
        1 => L.t('po_today'),
        2 => L.t('po_tomorrow'),
        3 => L.t('po_sec_upcoming'),
        _ => L.t('po_delivered'),
      };

  Color _secColor(int s) => switch (s) {
        0 => Brand.red,
        4 => Brand.green,
        _ => Brand.royalBlue,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final pos = Session.I.pos;
        final filter = _filter ?? _PoFilter.all;

        // كفاية البضاعة بتتحسب على **كل المفتوح** بأولوية المعاد —
        // مش على المعروض بس، عشان بادج الهيدر يقول الحقيقة كلها
        final open = pos.where((p) => p.status != 'delivered').toList()
          ..sort(_dueCompare);
        final cover = _coverage(open);

        var shown = pos.where((p) => _match(p, filter)).toList()
          ..sort(_dueCompare);

        final q = _q.trim().toLowerCase();
        if (q.isNotEmpty) {
          shown = shown
              .where((p) =>
                  p.client.toLowerCase().contains(q) ||
                  p.number.toLowerCase().contains(q) ||
                  (p.reference ?? '').toLowerCase().contains(q))
              .toList();
        }

        // ═══ التجميع بسكاشن — المتأخر فوق بعنوانه الأحمر ═══
        final groups = <int, List<PurchaseOrder>>{};
        for (final p in shown) {
          groups.putIfAbsent(_section(p), () => []).add(p);
        }
        final secs = groups.keys.toList()..sort();

        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: Session.I.refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                children: [
                  _header(context, open, cover),
                  const SizedBox(height: 10),
                  if (_searching) ...[
                    _searchField(),
                    const SizedBox(height: 10),
                  ],
                  if (pos.isEmpty) ...[
                    const SizedBox(height: 80),
                    Icon(Icons.local_shipping_outlined,
                        size: 52, color: Brand.muted),
                    const SizedBox(height: 12),
                    Center(
                        child: Text(L.t('no_supply_orders'),
                            style: TextStyle(color: Brand.muted))),
                  ] else ...[
                    _filters(pos, filter),
                    const SizedBox(height: 4),
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Center(
                          child: Text(L.t('po_none_in_filter'),
                              style: const TextStyle(color: Brand.muted)),
                        ),
                      ),
                    for (final s in secs) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
                        child: Row(children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _secColor(s),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(_secLabel(s),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: s == 0 ? Brand.red : Brand.text)),
                        ]),
                      ),
                      for (final po in groups[s]!)
                        _PoCard(
                          po: po,
                          client: po.clientId == null
                              ? null
                              : Session.I.clientById(po.clientId!),
                          pos: _pos,
                          short: cover[po.id] ?? const [],
                          onShort: cover[po.id] == null
                              ? null
                              : () => _showShortages(
                                    {po.id: cover[po.id]!},
                                    shown,
                                  ),
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// ═══ الهيدر بالتدرج (موك أب ٢١/٨) ═══
  ///
  /// العنوان و«معاك :n أمر النهاردة» + قيمة الأوامر والقطع بأرقام
  /// كبيرة + بادج كفاية البضاعة (أخضر مطمّن / أحمر بيفتح تفصيل
  /// النقص) + أيقونة البحث.
  Widget _header(BuildContext context, List<PurchaseOrder> open,
      Map<int, List<_Short>> cover) {
    final value = open.fold<double>(0, (s, p) => s + p.total);
    final pieces = open.fold<int>(0, (s, p) => s + p.qtyTotal);
    final today = open.where((p) => p.late || _isToday(p)).length;
    final ok = cover.isEmpty;
    final missing = _missingPieces(cover);

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
                  Text(L.t('supply_orders'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                      today > 0
                          ? L.t('po_hdr_sub_today', {'n': '$today'})
                          : L.t('po_hdr_sub_open', {'n': '${open.length}'}),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11.5)),
                ],
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchCtrl.clear();
                  _q = '';
                }
              }),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  shape: BoxShape.circle,
                ),
                child: Icon(_searching ? Icons.close : Icons.search,
                    size: 19, color: Colors.white),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _hStat(L.t('po_orders_value'), money(value)),
              const SizedBox(width: 20),
              _hStat(L.t('po_pieces_lbl'), '$pieces'),
              const Spacer(),
              if (open.isNotEmpty)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: ok
                    ? null
                    : () => _showShortages(
                        cover, Session.I.pos.where((p) => cover.containsKey(p.id)).toList()),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: ok
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(ok ? Icons.check_circle : Icons.error_outline,
                        size: 13, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                        ok
                            ? L.t('po_stock_ok')
                            : L.t('po_short_badge', {'q': '$missing'}),
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hStat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
          const SizedBox(height: 2),
          Text(value,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900)),
        ],
      );

  Widget _searchField() => TextField(
        controller: _searchCtrl,
        autofocus: true,
        onChanged: (v) => setState(() => _q = v),
        decoration: InputDecoration(
          hintText: L.t('po_search_hint'),
          hintStyle: TextStyle(fontSize: 12.5, color: Brand.muted),
          prefixIcon: const Icon(Icons.search, size: 19),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Brand.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Brand.border),
          ),
        ),
      );

  /// شريط الفلاتر بستايل الموك أب (٢١/٨) — «الكل · 2» الأول، وشيب
  /// التقويم أيقونة لوحده في الآخر. الفاضي بيتخفي عشان مايزحمش.
  Widget _filters(List<PurchaseOrder> pos, _PoFilter active) {
    const order = [
      _PoFilter.all,
      _PoFilter.late,
      _PoFilter.today,
      _PoFilter.tomorrow,
      _PoFilter.week,
      _PoFilter.month,
      _PoFilter.delivered,
      _PoFilter.custom,
    ];

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final f in order) ...[
            Builder(builder: (_) {
              final n = pos.where((p) => _match(p, f)).length;
              final on = f == active;
              if (n == 0 && f != _PoFilter.all && f != _PoFilter.custom) {
                return const SizedBox.shrink();
              }

              final danger = f == _PoFilter.late;
              final calendar = f == _PoFilter.custom;

              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 7),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => calendar
                      ? _pickRange()
                      : setState(() => _filter = f),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: calendar && _range == null ? 10 : 14,
                        vertical: 8),
                    decoration: BoxDecoration(
                      color: on
                          ? (danger ? Brand.red : Brand.royalBlue)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: on
                              ? Colors.transparent
                              : (danger ? Brand.red.withValues(alpha: .35)
                                        : Brand.border)),
                    ),
                    child: Row(
                      children: [
                        if (calendar)
                          Icon(Icons.calendar_month_outlined,
                              size: 15,
                              color: on ? Colors.white : Brand.muted),
                        if (!calendar || _range != null)
                          Text(
                            (calendar ? ' ' : '') +
                                _label(f) +
                                (calendar || n == 0 ? '' : ' · $n'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: on
                                  ? Colors.white
                                  : (danger ? Brand.red : Brand.text),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// كفاية البضاعة — **لكل أمر على حدة**، بتخصيص بالأولوية.
  ///
  /// ⚠️ **بيقارن بالمتبقي في العهدة مش بالمحمّل** — المندوب ممكن يكون
  /// باع نص العهدة الصبح، والمقارنة بالمحمّل كانت هتقوله «معاك كفاية»
  /// وهو مش معاه.
  ///
  /// ⚠️ **الرصيد بيتخصّص بالترتيب مش بالجمع** (طلب المالك 2026-08-07).
  /// النسخة الأولى كانت بتجمع طلب كل الأوامر وتقارنه بالرصيد، فتقول
  /// «ناقصك 5 أصناف» من غير ما تقول **أنهي أمر** هيقف. دلوقتي كل أمر
  /// بياخد نصيبه بالترتيب — الأقرب معاداً الأول (وده اللي المندوب
  /// هيسلّمه الأول فعلاً) — واللي بعده بيشوف الباقي. كده الأمر اللي
  /// هيقف بيبان بالظبط، مش «فيه نقص في حتة ما».
  Map<int, List<_Short>> _coverage(List<PurchaseOrder> shown) {
    // الرصيد المتاح دلوقتي في العربية
    final have = <int, int>{};
    for (final c in Session.I.custody.items) {
      have[c.productId] = (have[c.productId] ?? 0) + c.remaining;
    }

    final out = <int, List<_Short>>{};

    // `shown` جاية مرتّبة بالمعاد من `build` — الترتيب ده هو أساس
    // التخصيص، فممنوع نعيد ترتيبها هنا
    for (final po in shown.where((p) => p.status != 'delivered')) {
      final lines = <_Short>[];

      for (final it in po.items) {
        final avail = have[it.productId] ?? 0;
        final take = avail < it.qty ? avail : it.qty;

        have[it.productId] = avail - take;

        if (take < it.qty) {
          lines.add(_Short(it.name, it.qty, take));
        }
      }

      if (lines.isNotEmpty) out[po.id] = lines;
    }

    return out;
  }

  /// مجموع القطع الناقصة في كل الأوامر المعروضة
  int _missingPieces(Map<int, List<_Short>> cover) => cover.values
      .expand((l) => l)
      .fold<int>(0, (s, x) => s + (x.need - x.have));

  /// تفصيل النقص كله — مجمّع تحت كل أمر
  void _showShortages(
      Map<int, List<_Short>> cover, List<PurchaseOrder> shown) {
    final byId = {for (final p in shown) p.id: p};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .78,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(L.t('po_stock_title'),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(L.t('po_short_hint'),
                        style: const TextStyle(
                            fontSize: 11.5, color: Brand.muted, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    for (final e in cover.entries) ...[
                      // رأس الأمر — العميل ومجموع نقصه
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                byId[e.key]?.client ?? '#${e.key}',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900),
                              ),
                            ),
                            Text(
                              L.t('po_short_pieces', {
                                'n': '${e.value.fold<int>(0, (s, x) => s + (x.need - x.have))}'
                              }),
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: Brand.red),
                            ),
                          ],
                        ),
                      ),
                      for (final s in e.value)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Brand.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Brand.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.remove_circle_outline,
                                  color: Brand.red, size: 18),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                                    Text(
                                      L.t('po_stock_detail', {
                                        'need': '${s.need}',
                                        'have': '${s.have}',
                                      }),
                                      style: const TextStyle(
                                          fontSize: 11, color: Brand.muted),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '-${s.need - s.have}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Brand.red,
                                    fontSize: 13.5),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// سطر نقص واحد — الاسم والمطلوب والمتاح
class _Short {
  final String name;
  final int need;
  final int have;

  const _Short(this.name, this.need, this.have);
}

/// ═══ كارت الأمر بستايل الموك أب (٢١/٨) ═══
///
/// المعاد فوق يمين (أحمر لو متأخر) والرقم فوق شمال، اسم العميل
/// كبير والفلوس كبيرة قصاده، سطر «القناة · الدفع · المسافة»، شيبس
/// الأصناف وكفاية البضاعة والخصم، وتحت «ابدأ الزيارة» عريض +
/// تليفون ولوكيشن. المتأخر كارته وردي بحدود حمرا — يتشاف من بعيد.
class _PoCard extends StatelessWidget {
  final PurchaseOrder po;

  /// عميل الأمر من البول — منه القناة وشروط الدفع والخصم
  final Client? client;

  /// آخر نقطة GPS للمندوب — لحساب المسافة
  final (double, double)? pos;

  /// النقص الخاص بالأمر ده — فاضية يعني بضاعته كاملة
  final List<_Short> short;

  final VoidCallback? onShort;

  const _PoCard(
      {required this.po,
      this.client,
      this.pos,
      this.short = const [],
      this.onShort});

  /// رقم بفواصل الآلاف من غير عملة — العملة في السطر الصغير تحته
  static String _num(num v) {
    final s = v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(2);
    final parts = s.split('.');
    final whole = parts[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

    return whole + (parts.length > 1 ? '.${parts[1]}' : '');
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// «متأخر من امبارح 3:02 م» / «النهاردة 5:00 م» / «بكرة …» / تاريخ
  String _timeLabel() {
    final d = po.dueAt;
    if (d == null) return po.statusLabel;

    final now = DateTime.now();
    final t = fmtTime(d);
    final late = po.late && po.status != 'delivered';

    if (late) {
      if (_sameDay(d, now.subtract(const Duration(days: 1)))) {
        return L.t('po_late_since_y', {'t': t});
      }
      if (_sameDay(d, now)) return L.t('po_late_since', {'d': t});

      return L.t('po_late_since',
          {'d': '${fmtDate(d).split(' ').first} $t'});
    }
    if (_sameDay(d, now)) return L.t('po_due_today_t', {'t': t});
    if (_sameDay(d, now.add(const Duration(days: 1)))) {
      return L.t('po_due_tomorrow_t', {'t': t});
    }

    return '${fmtDate(d).split(' ').first} · $t';
  }

  /// ═══ الفلو (٢١/٨): الكارت بيفتح شاشة العميل نفسها ═══
  /// تشيك إن عادي → بانر «سلّم الأمر» → تسليم → **الزيارة لسه
  /// مفتوحة** فيبيع ويرجّع ويصوّر. لو العميل مش في البول (نادر)
  /// بنقع على شاشة التسليم المباشرة القديمة.
  void _open(BuildContext context) {
    final c = client ??
        (po.clientId == null ? null : Session.I.clientById(po.clientId!));

    if (c != null && po.status != 'delivered') {
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ClientScreen(client: c)));
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PoDeliveryScreen(poId: po.id)));
  }

  Widget _chip(String text, Color bg, Color fg, {VoidCallback? onTap}) =>
      InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(20)),
          child: Text(text,
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
        ),
      );

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) =>
      InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          width: 48,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Brand.border),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final delivered = po.status == 'delivered';
    final late = po.late && !delivered;
    final c = client;

    final lat = po.lat ?? c?.lat, lng = po.lng ?? c?.lng;
    final km = kmTo(pos, lat, lng);
    final mapsUrl = (lat != null && lng != null)
        ? 'https://www.google.com/maps?q=$lat,$lng'
        : c?.directionsUrl;
    final phone = (po.clientPhone ?? c?.phone ?? '').trim();

    // «جملة · آجل · 6.4 كم» — الفاضي بيتشال بدل نقط يتيمة
    final subParts = <String>[
      if ((c?.channelLabel ?? '').isNotEmpty) c!.channelLabel,
      if (c != null)
        c.paymentTerms == 'cash'
            ? L.t('cash')
            : c.paymentTerms == 'both'
                ? L.t('payment_both')
                : L.t('credit'),
      if (km != null) kmLabel(km),
    ];

    final disc = c?.discount ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        // المتأخر وردي بحدود حمرا — يتشاف قبل ما يتقري
        color: late ? const Color(0xFFFFF6F5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: late ? const Color(0xFFF3CBC7) : Brand.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══ الصف الأول: المعاد يمين (أحمر لو متأخر) · الرقم شمال ═══
              Row(children: [
                if (delivered)
                  _chip(po.statusLabel, const Color(0xFFE8F7EE), Brand.green)
                else ...[
                  Icon(Icons.schedule,
                      size: 13, color: late ? Brand.red : Brand.muted),
                  const SizedBox(width: 4),
                  Text(_timeLabel(),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: late ? Brand.red : Brand.muted)),
                  if (po.status == 'arrived') ...[
                    const SizedBox(width: 6),
                    _chip(po.statusLabel, const Color(0xFFFFF3E0),
                        Brand.orange),
                  ],
                ],
                const Spacer(),
                if (po.image != null) ...[
                  const Icon(Icons.image_outlined,
                      size: 14, color: Brand.muted),
                  const SizedBox(width: 4),
                ],
                Text(po.number,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Brand.muted)),
              ]),
              const SizedBox(height: 8),

              // ═══ الاسم الكبير + الفلوس الكبيرة قصاده ═══
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(po.client,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                height: 1.25)),
                        if (subParts.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(subParts.join(' · '),
                              style: TextStyle(
                                  fontSize: 11, color: Brand.muted)),
                        ],
                        if (po.reference != null &&
                            po.reference!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text('${L.t('po_ref')}: ${po.reference}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10, color: Brand.muted)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_num(po.total),
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900)),
                      Text(
                          '${L.t('currency')} · ${L.t('total_units', {
                                'n': '${po.qtyTotal}'
                              })}',
                          style: TextStyle(
                              fontSize: 10, color: Brand.muted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 9),

              // ═══ الشيبس: أصناف · كفاية البضاعة · الخصم ═══
              Wrap(spacing: 6, runSpacing: 6, children: [
                _chip(L.t('items_n', {'n': '${po.items.length}'}),
                    const Color(0xFFF3F2EC), const Color(0xFF52525B)),
                if (!delivered)
                  short.isEmpty
                      ? _chip(L.t('po_goods_ok'),
                          const Color(0xFFE8F7EE), Brand.green)
                      : _chip(
                          L.t('po_goods_missing',
                              {'n': '${short.length}'}),
                          const Color(0xFFFFF3E0),
                          Brand.orange,
                          onTap: onShort),
                // ⚠️ الخصم كسر (0.25) زي كل الأبلكيشن — العرض ×100
                if (disc > 0)
                  _chip(
                      L.t('disc_pct_n', {'n': '${(disc * 100).round()}'}),
                      Brand.purple050,
                      Brand.purpleHeart),
                if (delivered && po.varianceQty > 0)
                  _chip('${L.t('po_variance')}: ${po.varianceQty}',
                      const Color(0xFFFFF3E0), Brand.orange),
              ]),

              // ═══ الأكشن: «ابدأ الزيارة» عريض + لوكيشن + تليفون ═══
              // المتأخر زراره متدرج مليان، والعادي أوتلاين أزرق
              if (!delivered) ...[
                const SizedBox(height: 11),
                Row(children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: () => _open(context),
                      child: Container(
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: late ? Brand.gradient : null,
                          color: late ? null : Colors.white,
                          borderRadius: BorderRadius.circular(13),
                          border: late
                              ? null
                              : Border.all(
                                  color: Brand.royalBlue, width: 1.3),
                        ),
                        child: Text(L.t('start_visit'),
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: late
                                    ? Colors.white
                                    : Brand.royalBlue)),
                      ),
                    ),
                  ),
                  if (mapsUrl != null) ...[
                    const SizedBox(width: 8),
                    _iconBtn(Icons.place_outlined, Brand.royalBlue,
                        () => Locator.openUrl(mapsUrl)),
                  ],
                  if (phone.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _iconBtn(Icons.phone_outlined, Brand.royalBlue,
                        () => Locator.openUrl('tel:$phone')),
                  ],
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ═══════════ رفيو صورة أمر الشراء الأصلي (٨ أغسطس ٢٠٢٦) ═══════════
///
/// ⚠️ **`InteractiveViewer` مش `Image` عادية.** الصور دي ورق مصوّر
/// بخط صغير — من غير تكبير المندوب مش هيقرا الكميات، وهو واقف عند
/// الفرع بيطابق سطر بسطر.
class _PoImageScreen extends StatelessWidget {
  final String url;
  final String title;

  const _PoImageScreen({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            // ⚠️ حالة الفشل لازم تقول سبب — صورة سودا فاضية بتخلّي
            // المندوب يفتكر إن الأبلكيشن واقف
            errorBuilder: (_, __, ___) => Padding(
              padding: const EdgeInsets.all(30),
              child: Text(L.t('image_failed'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70)),
            ),
            loadingBuilder: (_, child, p) => p == null
                ? child
                : const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}

/// ═══════════ تفاصيل الأمر + التسليم بكميات فعلية ═══════════
class PoDeliveryScreen extends StatefulWidget {
  final int poId;

  const PoDeliveryScreen({super.key, required this.poId});

  @override
  State<PoDeliveryScreen> createState() => _PoDeliveryScreenState();
}

class _PoDeliveryScreenState extends State<PoDeliveryScreen> {
  bool _busy = false;

  /// ⚠️ سنابشوت آخر نسخة من الأمر (٢١/٨) — وقت التأكيد الريفريش
  /// بيلمس قايمة الأوامر والشاشة كانت بتفلّش «مفيش نتايج» لثواني
  PurchaseOrder? _last;

  /// «وصلت الفرع» اتلغت (٢١/٨) — الوصول بيتسجل أوتوماتيك أول ما
  /// الشاشة تفتح: المندوب أصلاً عامل تشيك إن عند الفرع
  bool _autoArrived = false;

  /// الكمية المسلَّمة لكل بند **بوحدة السطر** — بتبدأ = المطلوب بالقطعة
  final Map<int, int> _qty = {};
  final Map<int, String> _units = {};
  final Map<int, TextEditingController> _ctrl = {};

  PurchaseOrder? get _po {
    final p = firstOrNull(Session.I.pos.where((p) => p.id == widget.poId));
    if (p != null) _last = p;

    return p ?? _last;
  }

  /// ⚠️ الوصول الأوتوماتيك **بس لو فيه زيارة مفتوحة على نفس
  /// العميل** (بلاغ ٢١/٨) — من غيرها كان بيسلّم من الرئيسية من
  /// غير تشيك إن خالص، وده بيكسر بوابة الزيارة.
  void _maybeAutoArrive() {
    final p = _po;
    if (p == null || p.status != 'pending' || _autoArrived) return;

    final visiting = Session.I.openVisitClientId != null &&
        Session.I.openVisitClientId == p.clientId;
    if (!visiting) return;

    _autoArrived = true;
    _arrive();
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _factor(PoItem i) => i.factorOf(_units[i.productId] ?? 'piece');

  int _pieces(PoItem i) => (_qty[i.productId] ?? i.qty) * _factor(i);

  TextEditingController _ctrlFor(PoItem i) => _ctrl.putIfAbsent(
      i.productId,
      () => TextEditingController(text: '${_qty[i.productId] ?? i.qty}'));

  void _setQty(PoItem i, int v) {
    // ⚠️ المسلَّم مقفول بالمطلوب — الزيادة بيع عادي بفاتورة
    final maxUnits = i.qty ~/ _factor(i);
    final clamped = v.clamp(0, maxUnits);

    setState(() {
      _qty[i.productId] = clamped;
      final c = _ctrlFor(i);
      if (c.text != '$clamped') {
        c.text = '$clamped';
        c.selection = TextSelection.collapsed(offset: c.text.length);
      }
    });
  }

  void _setUnit(PoItem i, String unit) {
    final factor = i.factorOf(unit);

    // ⚠️ **تبديل الوحدة كان بيقصّ الكمية في صمت** (تدقيق ٨/٨/٢٠٢٦):
    // ٢٥ قطعة ÷ ١٢ = كرتونتين = ٢٤ قطعة، والقطعة الناقصة بتختفي
    // من غير ما حد ياخد باله — والمندوب بيسلّم ٢٤ وهو فاكر إنه سلّم
    // ٢٥. لو الكمية مش قابلة للقسمة على الوحدة، بنرفض التبديل
    // ونقول ليه بدل ما ناخد قرار مكانه.
    if (factor > 1 && i.qty % factor != 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L.t('unit_not_divisible', {
          'q': '${i.qty}',
          'u': PoItem.unitName(unit),
        })),
      ));

      return;
    }

    setState(() {
      _units[i.productId] = unit;
      // نرجّع الكمية للمطلوب كامل بالوحدة الجديدة — أوضح للمندوب
      final c = _ctrl[i.productId];
      _qty[i.productId] = i.qty ~/ factor;
      if (c != null) c.text = '${_qty[i.productId]}';
    });
  }

  Future<void> _arrive() async {
    setState(() => _busy = true);
    final err = await Session.I.arrivePo(_po!);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }

  /// إلغاء التسليم بسبب إجباري (١١/٨) — الأمر بيرجع «مستني»
  /// والمندوب يقدر يتحرك لمحل تاني وينصرف آخر اليوم.
  Future<void> _abort() async {
    final po = _po!;
    final reasonCtrl = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dlg) => AlertDialog(
        title: Text(L.t('po_abort_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(L.t('po_abort_hint'),
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              autofocus: true,
              maxLength: 190,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: L.t('po_abort_reason'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlg).pop(),
            child: Text(L.t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB00020)),
            onPressed: () {
              // ⚠️ السبب إجباري — إلغاء صامت بيضيّع المعلومة
              if (reasonCtrl.text.trim().length < 3) return;
              Navigator.of(dlg).pop(reasonCtrl.text.trim());
            },
            child: Text(L.t('po_abort_confirm')),
          ),
        ],
      ),
    );

    reasonCtrl.dispose();
    if (reason == null || !mounted) return;

    // ⚠️ الماسنجر قبل الـawait — الدرس الموثّق
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final err = await Session.I.cancelArrival(po, reason);
    if (!mounted) return;
    setState(() => _busy = false);

    messenger.showSnackBar(SnackBar(
      content: Text(err ?? L.t('po_abort_done')),
      backgroundColor: err == null ? null : const Color(0xFFB00020),
    ));
  }

  Future<void> _deliver() async {
    final po = _po!;

    // نبعت البنود اللي المندوب شافها — بوحدتها والسيرفر بيضرب
    final items = [
      for (final i in po.items)
        {
          'product_id': i.productId,
          'qty': _qty[i.productId] ?? i.qty,
          'unit': _units[i.productId] ?? 'piece',
        },
    ];

    final totalPieces =
        po.items.fold<int>(0, (t, i) => t + _pieces(i));

    // قيمة اللي هيتسلّم فعلاً — بأسعار بنود الأمر
    final deliveredValue =
        po.items.fold<double>(0, (t, i) => t + _pieces(i) * i.price);

    // ضريبة المسلَّم بنسبته من صافي الأمر — تقريب عرض، والسيرفر
    // هو اللي بيحسب القيد النهائي سطر بسطر
    final deliveredTax = po.netTotal > 0
        ? po.taxTotal * (deliveredValue / po.netTotal)
        : 0.0;

    // ═══ شاشة مراجعة زي البيع بالظبط (طلب المالك ٨/٨/٢٠٢٦) ═══
    //
    // ⚠️ **دايالوج بسطرين مش مراجعة.** فلو البيع بيوري كل سطر
    // بصورته وكميته قبل الحفظ، والتوريد كان بيقول «هتسلّم ٢٤ من
    // ٢٥؟» وخلاص — فالمندوب بيوافق وهو مش شايف أنهي صنف الناقص
    // فيه، والفرق بيتكتشف عند المحاسب.
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => SaleReviewScreen(
        title: L.t('po_review_title'),
        confirmLabel: L.t('po_confirm_deliver'),
        clientName: po.client,
        // العنوان اتشال من الودجت نفسه (طلب المالك ٢١/٨)
        paymentLabel: '${L.t('supply_order')} ${po.number}',
        lines: [
          for (final i in po.items)
            (
              i.name,
              _qty[i.productId] ?? i.qty,
              PoItem.unitName(_units[i.productId] ?? 'piece'),
              _pieces(i) * i.price,
              i.image,
            ),
        ],
        // ⚠️ **بقيمة المسلَّم مش المطلوب.** السطور بتتعرض بالكميات
        // اللي المندوب عدّلها (٢٤ بدل ٢٥)، فلو الإجمالي فضل بقيمة
        // الأمر الأصلية المندوب بيوافق على ورقة سطورها مش بتجمّع
        // للرقم اللي تحتها.
        // ⚠️ **والضريبة بنسبة المسلَّم** (تدقيق ٩/٨): كانت صفر،
        // فالمندوب بيأكد على رقم قبل الضريبة والسيرفر بيقيّد
        // الشامل — والعميل يدفع رقم غير اللي اتقال له.
        subtotal: deliveredValue,
        discount: 0,
        tax: deliveredTax,
        grand: deliveredValue + deliveredTax,
      ),
    ));

    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final (err, res) = await Session.I.deliverPo(po, items: items);
    if (!mounted) return;
    setState(() => _busy = false);

    if (err != null || res == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err ?? L.t('error'))));
      return;
    }

    // السامري من السيرفر: سلم إيه وإيه الفرق
    final ordered = (res['qty_ordered'] ?? 0) as int;
    final deliveredQty = (res['qty_delivered'] ?? 0) as int;
    final diff = ordered - deliveredQty;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(diff > 0
            ? L.t('delivered_with_diff', {'n': '$deliveredQty', 'd': '$diff'})
            : L.t('delivered_full', {'n': '$deliveredQty'}))));

    // ═══ ورقة «أمر توريد PO-xxxx» — قابلة للتحميل والإرسال ═══
    //
    // ⚠️ **الفرع بياخد ورقة، مش سناك بار.** فلو البيع بيقفل على
    // سامري بيتبعت واتساب؛ التوريد كان بيقفل على رسالة بتختفي بعد
    // تلات ثواني، والفرع مايطلعش بحاجة تثبت اللي استلمه.
    //
    // ⚠️ `pushReplacement` عشان «رجوع» ترجّع لقايمة الأوامر مش
    // لشاشة أمر اتسلّم خلاص.
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => OrderSummaryScreen(
        title: L.t('supply_order'),
        clientName: po.client,
        docNumber: po.number,
        paymentLabel: po.reference,
        lines: [
          for (final i in po.items)
            if ((_pieces(i)) > 0) (i.name, _pieces(i), i.image, null),
        ],
        grand: ((res['delivered_value'] ?? po.total) as num).toDouble(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final p = _po;

        if (p == null) {
          return Scaffold(
            appBar: AppBar(title: Text(L.t('supply_orders'))),
            body: Center(child: Text(L.t('no_results'))),
          );
        }

        final delivering = p.status == 'arrived';
        final delivered = p.status == 'delivered';

        WidgetsBinding.instance
            .addPostFrameCallback((_) => _maybeAutoArrive());

        return Scaffold(
          appBar: AppBar(title: Text(p.number)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ═══ (٢١/٨) الهيدر القديم اتشال — الاسم والفلوس
              // موجودين على الكارت برا، والرقم في الآب بار.
              // المنتجات على طول، وصورة أمر الشراء الأصلي لو موجودة.
                if (p.image != null) ...[
                  const SizedBox(height: 10),
                  Material(
                    color: Brand.blue050,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _PoImageScreen(
                              url: p.image!, title: p.number),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 9),
                        child: Row(children: [
                          const Icon(Icons.receipt_long,
                              size: 18, color: Brand.royalBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(L.t('po_original_image'),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Brand.royalBlue)),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              size: 18, color: Brand.royalBlue),
                        ]),
                      ),
                    ),
                  ),
                ],

              const SizedBox(height: 4),
              // ═══ البنود ═══
              for (final i in p.items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // صورة الصنف — ريفرنس بصري وقت التسليم
                            if (i.image != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(i.image!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox(
                                            width: 56, height: 56)),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(i.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                            ),
                            Text('${money(i.price)} / ${i.unit}',
                                style: TextStyle(
                                    fontSize: 11, color: Brand.muted)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                            '${L.t('po_requested')}: ${i.qty}'
                            '${i.packBd(i.qty) != null ? ' (${i.packBd(i.qty)})' : ''}',
                            style: TextStyle(
                                fontSize: 11.5, color: Brand.muted)),
                        if (delivered)
                          Text(
                              '${L.t('po_delivered_label')}: ${i.deliveredQty}'
                              '${i.qty != i.deliveredQty ? ' • ${L.t('po_variance')}: ${i.qty - i.deliveredQty}' : ' ✓'}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: i.qty == i.deliveredQty
                                      ? const Color(0xFF0E7C5A)
                                      : const Color(0xFFB86E00))),

                        // ═══ تعديل المسلَّم — وقت التسليم بس ═══
                        if (delivering) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: (_qty[i.productId] ?? i.qty) > 0
                                    ? () => _setQty(i,
                                        (_qty[i.productId] ?? i.qty) - 1)
                                    : null,
                                icon: const Icon(
                                    Icons.remove_circle_outline),
                              ),
                              SizedBox(
                                width: 52,
                                child: TextField(
                                  controller: _ctrlFor(i),
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(5),
                                  ],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding:
                                        EdgeInsets.symmetric(vertical: 6),
                                    border: UnderlineInputBorder(),
                                  ),
                                  onChanged: (v) =>
                                      _setQty(i, int.tryParse(v) ?? 0),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _setQty(
                                    i, (_qty[i.productId] ?? i.qty) + 1),
                                icon: Icon(Icons.add_circle,
                                    color: Brand.royalBlue),
                              ),
                              if (i.unitFactors.length > 1) ...[
                                const SizedBox(width: 4),
                                DropdownButton<String>(
                                  value: _units[i.productId] ?? 'piece',
                                  isDense: true,
                                  underline: const SizedBox.shrink(),
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Brand.royalBlue),
                                  items: [
                                    for (final u in i.unitFactors.keys)
                                      DropdownMenuItem(
                                        value: u,
                                        child: Text(
                                            CustodyItem.unitName(u) +
                                                (i.factorOf(u) > 1
                                                    ? ' (${i.factorOf(u)})'
                                                    : '')),
                                      ),
                                  ],
                                  onChanged: (u) {
                                    if (u != null) _setUnit(i, u);
                                  },
                                ),
                              ],
                              const Spacer(),
                              Text('= ${_pieces(i)} ${L.t('unit_piece')}',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: _pieces(i) == i.qty
                                          ? const Color(0xFF0E7C5A)
                                          : const Color(0xFFB86E00))),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 10),

              // «وصلت الفرع» اتلغت — بيتسجل أوتوماتيك مع فتح الشاشة.
              // الأزرار نزلت بار سفلي ثابت جوه SafeArea (٢١/٨).
              if (p.status == 'pending')
                Builder(builder: (context) {
                  final visiting = Session.I.openVisitClientId != null &&
                      Session.I.openVisitClientId == p.clientId;

                  if (visiting) {
                    // الوصول بيتسجل أوتوماتيك — ثانية وهتفتح الكميات
                    return const Padding(
                      padding: EdgeInsets.all(14),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  // ═══ بوابة التشيك إن (٢١/٨) — التسليم جوه الزيارة بس ═══
                  final c = p.clientId == null
                      ? null
                      : Session.I.clientById(p.clientId!);

                  return Card(
                    color: const Color(0xFFFFF4E5),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(children: [
                        Text(L.t('po_checkin_first'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB45309))),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          icon: const Icon(Icons.login, size: 18),
                          label: Text(L.t('start_visit')),
                          onPressed: c == null
                              ? null
                              : () => Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          ClientScreen(client: c))),
                        ),
                      ]),
                    ),
                  );
                }),
              if (delivered)
                Card(
                  color: const Color(0xFFE7F7EE),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                        '✅ ${L.t('po_closed', {
                              'n': '${p.deliveredQtyTotal}'
                            })}'
                        '${p.varianceQty > 0 ? '\n${L.t('po_variance')}: ${p.varianceQty} ${L.t('unit_piece')}' : ''}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, height: 1.6)),
                  ),
                ),
            ],
          ),
          // ═══ (٢١/٨) بار الأزرار الثابت — ٧٠٪ تسليم و٣٠٪ إلغاء ═══
          bottomNavigationBar: delivering
              ? Container(
                  // ⚠️ viewPadding صريح (٢١/٨) — SafeArea ماكانتش
                  // بتزق الأزرار فوق بار النظام على الجهاز
                  padding: EdgeInsets.fromLTRB(14, 10, 14,
                      10 + MediaQuery.viewPaddingOf(context).bottom),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 8)
                    ],
                  ),
                  child: Row(children: [
                      Expanded(
                        flex: 7,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.fact_check_outlined),
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50)),
                          // بيودّي على شاشة المراجعة — والتأكيد هناك
                          label: Text(L.t('po_review_go'),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900)),
                          onPressed: _busy ? null : _deliver,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB00020),
                            side: const BorderSide(
                                color: Color(0xFFB00020)),
                            minimumSize: const Size.fromHeight(50),
                          ),
                          onPressed: _busy ? null : _abort,
                          child: Text(L.t('cancel'),
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ]),
                )
              : null,
        );
      },
    );
  }
}
