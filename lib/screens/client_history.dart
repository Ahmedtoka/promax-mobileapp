import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n.dart';
import '../models.dart';
import '../session.dart';

/// ═══════════════════════════════════════════════════════════════
/// تاريخ العميل — الشبكة والليستة والتفاصيل  ·  ١٦ أغسطس ٢٠٢٦
/// ═══════════════════════════════════════════════════════════════
///
/// طلب المالك: «مربعات كليكابل — كل مبيعاته، كل تحصيلاته، كل
/// مرتجعاته، كل هداياه، كل صور ترتيب الأرفف. في المربع السامري،
/// ولما أدوس تطلع ليستة، وأدخل على الليست أشوف التفاصيل».
///
/// ⚠️ **ده مش عرض بيانات، ده إنهاء نقاش في الزيارة.** العميل بيقول
/// «أنا دفعتلك الأسبوع اللي فات» أو «الكرتونة دي رجعتهالك» —
/// ومن غير الشاشة دي رد المندوب الوحيد «هراجع وأرجعلك»، والزيارة
/// بتخلص من غير تحصيل.

/// الأنواع الخمسة — **نفس مفاتيح السيرفر بالحرف**.
///
/// ⚠️ الراوت على السيرفر محصور بـ`whereIn` على نفس القيم دي؛ أي
/// اختلاف في الكتابة بيدي 404 مالوش تفسير في الشاشة.
enum HistoryKind {
  sales('sales', Icons.receipt_long_outlined, Brand.royalBlue),
  collections('collections', Icons.payments_outlined, Brand.green),
  returns('returns', Icons.assignment_return_outlined, Brand.orange),
  gifts('gifts', Icons.card_giftcard_outlined, Brand.purpleHeart),
  shelf('shelf', Icons.photo_library_outlined, Brand.razzmatazz);

  final String key;
  final IconData icon;
  final Color color;

  const HistoryKind(this.key, this.icon, this.color);

  String get label => L.t('hist_$key');

  /// الهدايا بالقطع وصور الأرفف مالهاش قيمة — الباقي بالجنيه
  bool get isMoney => this == sales || this == collections || this == returns;
}

// ═══════════════════════════════════════════════════════════════
// ٠. الشاشة — مدخلها من كارت العميل في الليستة
// ═══════════════════════════════════════════════════════════════
//
// ⚠️ **قبل التشيك إن مش بعده** (طلب المالك ١٦/٨). كانت الشبكة
// جوّه شاشة الزيارة، فالمندوب مايشوفش تاريخ العميل غير بعد ما
// يفتح الزيارة — والقرار «أدخل ولا أعدّي» بيتاخد قبلها. دلوقتي
// أيقونة على الكارت في الليستة.
class ClientHistoryScreen extends StatelessWidget {
  final int clientId;
  final String clientName;

  const ClientHistoryScreen({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(L.t('client_history'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              Text(clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70)),
            ],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClientHistoryGrid(
              clientId: clientId,
              clientName: clientName,
              showTitle: false,
            ),
          ],
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
// ١. الشبكة — ودجت مستقلة تتحط في أي شاشة
// ═══════════════════════════════════════════════════════════════

/// شبكة المربعات الخمسة.
///
/// ⚠️ **بتحمّل نفسها ومابتوقفش الصفحة.** لو الشبكة وقعت الشاشة
/// بتخفي الشبكة وخلاص — التشيك إن والبيع أهم من التاريخ ومايصحّش
/// يستنّوا نداء إضافي.
class ClientHistoryGrid extends StatefulWidget {
  final int clientId;
  final String clientName;

  /// العنوان بيتشال لما الشاشة الحاضنة بتقوله في الأب بار
  final bool showTitle;

  const ClientHistoryGrid({
    super.key,
    required this.clientId,
    required this.clientName,
    this.showTitle = true,
  });

  @override
  State<ClientHistoryGrid> createState() => _ClientHistoryGridState();
}

class _ClientHistoryGridState extends State<ClientHistoryGrid> {
  Map<String, HistoryStat> _stats = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await Session.I.clientHistory(widget.clientId);
    if (!mounted) return;
    setState(() {
      _stats = s;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }

    if (_stats.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showTitle)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
            child: Text(L.t('client_history'),
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
        // ═══ صفّين: اتنين فوق وتلاتة تحت (طلب المالك ١٦/٨) ═══
        //
        // ⚠️ **مش خمسة متساويين.** المبيعات والتحصيلات هما اللي
        // المندوب بيفتحهم في كل زيارة تقريباً — العميل بيقول «أنا
        // دفعت» أو «أنا مااشتريتش الكمية دي». المرتجعات والهدايا
        // وصور الأرفف بيتفتحوا لما يحصل نقاش بس. الحجم بيقول
        // الأهمية من غير كلام.
        //
        // ⚠️ الصف التحتاني **مختصر** (`dense`): رقم واسم من غير
        // القيمة والتاريخ — تلاتة في سطر مافيهمش مكان لأربع سطور
        // نص، والزحمة كانت هتخلّي الحروف تتقص.
        // ⚠️⚠️ **`IntrinsicHeight` إجبارية هنا** — وده اللي خلّى
        // المربعات تختفي خالص في أول تشغيلة. `Row` بـ
        // `CrossAxisAlignment.stretch` بيدّي ولاده ارتفاع **ثابت =
        // ارتفاع الصف**؛ وجوّه `ListView` الارتفاع الوارد
        // **لانهائي**، فالقيد بيبقى «ارتفاع لانهائي مضبوط»
        // والليَي أوت بيقع والمربعات مابتترسمش أصلاً.
        // `IntrinsicHeight` بتحسب أطول مربع الأول وتدّي الصف ارتفاع
        // حقيقي، فالـ`stretch` بيبقى ليها معنى وكل المربعات
        // بتطلع بنفس الطول.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _box(context, HistoryKind.sales),
              const SizedBox(width: 10),
              _box(context, HistoryKind.collections),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _box(context, HistoryKind.returns, dense: true),
              const SizedBox(width: 8),
              _box(context, HistoryKind.gifts, dense: true),
              const SizedBox(width: 8),
              _box(context, HistoryKind.shelf, dense: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _box(BuildContext context, HistoryKind k, {bool dense = false}) =>
      Expanded(
        child: _StatBox(
          kind: k,
          dense: dense,
          stat: _stats[k.key] ?? const HistoryStat.empty(),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ClientHistoryListScreen(
                clientId: widget.clientId,
                clientName: widget.clientName,
                kind: k,
              ),
            ),
          ),
        ),
      );
}

class _StatBox extends StatelessWidget {
  final HistoryKind kind;
  final HistoryStat stat;
  final bool dense;
  final VoidCallback onTap;

  const _StatBox({
    required this.kind,
    required this.stat,
    required this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    // ⚠️ **المربع الفاضي بيفضل ظاهر بس مطفّي.** إخفاؤه كان معناه إن
    // المندوب مايعرفش إن العميل ده معندوش مرتجعات — يفتكر إن الشاشة
    // ناقصة. الرمادي بيقول «مفيش» بوضوح.
    final empty = stat.count == 0;
    final tint = empty ? Brand.muted : kind.color;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: empty ? null : onTap,
        child: Container(
          padding: dense
              ? const EdgeInsets.fromLTRB(8, 9, 8, 9)
              : const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Brand.border),
          ),
          child: dense
              // ═══ المختصر — تلاتة في سطر ═══
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(kind.icon, size: 17, color: tint),
                    const SizedBox(height: 5),
                    Text('${stat.count}',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: tint)),
                    const SizedBox(height: 1),
                    Text(kind.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Brand.muted)),
                  ],
                )
              // ═══ الكامل — اتنين في سطر ═══
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: tint.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(kind.icon, size: 15, color: tint),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(kind.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700)),
                        ),
                        if (!empty)
                          Icon(Icons.chevron_right,
                              size: 16, color: Brand.muted),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      // الرقم الكبير = **العدد**، وتحته القيمة. المندوب
                      // بيدوّر على «كام مرة» الأول وبعدين «بكام».
                      '${stat.count}',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: tint),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      empty ? L.t('hist_none') : money(stat.total),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Brand.muted),
                    ),
                    if (stat.lastAt != null) ...[
                      const SizedBox(height: 3),
                      Text(L.t('hist_last', {'d': fmtDate(stat.lastAt!)}),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 10.5, color: Brand.muted)),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ٢. الليستة
// ═══════════════════════════════════════════════════════════════

class ClientHistoryListScreen extends StatefulWidget {
  final int clientId;
  final String clientName;
  final HistoryKind kind;

  const ClientHistoryListScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.kind,
  });

  @override
  State<ClientHistoryListScreen> createState() =>
      _ClientHistoryListScreenState();
}

class _ClientHistoryListScreenState extends State<ClientHistoryListScreen> {
  List<HistoryEntry> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows =
          await Session.I.clientHistoryList(widget.clientId, widget.kind.key);
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kind;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(k.label,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            Text(widget.clientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState()
              : _items.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 9),
                        itemBuilder: (context, i) => _EntryTile(
                          entry: _items[i],
                          kind: k,
                          onTap: () => _openDetail(_items[i]),
                        ),
                      ),
                    ),
    );
  }

  void _openDetail(HistoryEntry e) {
    // ⚠️ **شيت مش شاشة.** التفاصيل قراءة سريعة والمندوب راجع
    // للّيستة على طول — شاشة كاملة كانت بتضيف دوستين رجوع.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(entry: e, kind: widget.kind),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.kind.icon, size: 50, color: Brand.muted),
              const SizedBox(height: 12),
              Text(L.t('hist_none'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 50, color: Brand.muted),
              const SizedBox(height: 12),
              Text(L.t('error'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text(L.t('retry')),
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
}

class _EntryTile extends StatelessWidget {
  final HistoryEntry entry;
  final HistoryKind kind;
  final VoidCallback onTap;

  const _EntryTile(
      {required this.entry, required this.kind, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tag = _tagOf(entry, kind);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Brand.border),
          ),
          child: Row(
            children: [
              _thumb(entry, kind),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        kind == HistoryKind.shelf
                            ? L.t('shelf_${entry.stage ?? 'before'}')
                            : entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    // ⚠️ Wrap مش Row (١٩/٨) — التاريخ + شارة السياسة
                    // كانوا بيعملوا RIGHT OVERFLOWED على الشاشات
                    // الضيقة (بلاغ المالك بسكرين شوت). الـWrap بينزّل
                    // الشارة سطر لو المساحة ضاقت بدل ما يفيض.
                    Wrap(
                      spacing: 6,
                      runSpacing: 3,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (entry.time != null)
                          Text(
                              '${fmtDate(entry.time!)} · ${fmtTime(entry.time!)}',
                              style: TextStyle(
                                  fontSize: 11, color: Brand.muted)),
                        if (tag != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: kind.color.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(tag,
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: kind.color)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (kind.isMoney)
                Text(money(entry.amount),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: kind.color))
              else if (kind == HistoryKind.gifts)
                Text(L.t('total_pieces_n', {'n': '${entry.qty}'}),
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: kind.color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// اللابل الجانبي — بيختلف حسب النوع، و`null` لما مفيش
String? _tagOf(HistoryEntry e, HistoryKind kind) => switch (kind) {
      HistoryKind.sales =>
        e.payment == null ? null : L.t(e.payment == 'cash' ? 'cash' : 'credit'),
      // ⚠️ الطريقة بتتترجم في الأبلكيشن — السيرفر بيبعت المفتاح خام.
      // `pay_method_*` هي **المفاتيح الموجودة** اللي شاشة التحصيل
      // بتستخدمها؛ مفاتيح جديدة بنفس المعنى كانت هتخلّي نفس الكلمة
      // مترجمة في مكانين وتفترق أول ما واحدة تتعدّل.
      HistoryKind.collections =>
        e.method == null ? null : L.t('pay_method_${e.method}'),
      HistoryKind.returns => e.policyLabel,
      // ⚠️ **السبب مش الاسم** — `title` بتاع الهدية هو اسم الصنف
      // وهو مطبوع فوق بالفعل؛ تكراره في اللابل كان بيملا السطر
      // بنفس الكلمة مرتين.
      HistoryKind.gifts => e.reason,
      HistoryKind.shelf => null,
    };

/// الصورة الجانبية: صورة رف أو إثبات تحصيل أو صورة منتج الهدية،
/// وإلا أيقونة النوع.
Widget _thumb(HistoryEntry e, HistoryKind kind) {
  final url = e.photo ?? e.image;

  if (url == null) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: kind.color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(kind.icon, size: 20, color: kind.color),
    );
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Image.network(
      url,
      width: 44,
      height: 44,
      fit: BoxFit.cover,
      // ⚠️ الصورة الواقعة مابترميش الليستة — أيقونة بديلة
      errorBuilder: (_, __, ___) => Container(
        width: 44,
        height: 44,
        color: const Color(0xFFF0EEE8),
        child: Icon(kind.icon, size: 20, color: Brand.muted),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
// ٣. التفاصيل
// ═══════════════════════════════════════════════════════════════

class _DetailSheet extends StatelessWidget {
  final HistoryEntry entry;
  final HistoryKind kind;

  const _DetailSheet({required this.entry, required this.kind});

  @override
  Widget build(BuildContext context) {
    final url = entry.photo ?? entry.image;

    return DraggableScrollableSheet(
      initialChildSize: .62,
      minChildSize: .35,
      maxChildSize: .92,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            // مقبض السحب
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: Brand.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                children: [
                  Text(
                      kind == HistoryKind.shelf
                          ? L.t('shelf_${entry.stage ?? 'before'}')
                          : entry.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                  if (entry.time != null) ...[
                    const SizedBox(height: 4),
                    Text('${fmtDate(entry.time!)} · ${fmtTime(entry.time!)}',
                        style: TextStyle(fontSize: 12.5, color: Brand.muted)),
                  ],
                  const SizedBox(height: 14),

                  if (kind.isMoney)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: kind.color.withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(kind.icon, size: 18, color: kind.color),
                          const SizedBox(width: 9),
                          Text(kind.label,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Brand.muted)),
                          const Spacer(),
                          Text(money(entry.amount),
                              style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: kind.color)),
                        ],
                      ),
                    ),

                  // ⚠️ **الصورة كبيرة هنا مش مصغّرة.** صورة الرف أو
                  // الشيك هي المحتوى نفسه — عرضها ٤٤ بكسل زي الليستة
                  // كان بيخلّي الشيت مالوش لازمة.
                  if (url != null) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        url,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: const Color(0xFFF0EEE8),
                          child: Icon(Icons.broken_image_outlined,
                              color: Brand.muted),
                        ),
                      ),
                    ),
                  ],

                  if (entry.lines.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(L.t('n_items', {'n': '${entry.lines.length}'}),
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    for (final l in entry.lines) _LineRow(line: l, kind: kind),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  final HistoryLine line;
  final HistoryKind kind;

  const _LineRow({required this.line, required this.kind});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: line.image == null
                  ? Container(
                      width: 40,
                      height: 40,
                      color: const Color(0xFFF0EEE8),
                      child: Icon(Icons.inventory_2_outlined,
                          size: 18, color: Brand.muted),
                    )
                  : Image.network(line.image!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                            width: 40,
                            height: 40,
                            color: const Color(0xFFF0EEE8),
                            child: Icon(Icons.inventory_2_outlined,
                                size: 18, color: Brand.muted),
                          )),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(line.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700)),
                  // ⚠️ **سليم/تالف بيظهر في المرتجعات بس** — الحقل
                  // بيرجع `null` في الفواتير، وطباعته كانت هتقول
                  // «سليم» على بند مبيعات مالوش حالة أصلاً.
                  if (line.condition != null)
                    Text(L.t(line.condition == 'damaged'
                        ? 'return_cond_damaged'
                        : 'return_cond_good'),
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: line.condition == 'damaged'
                                ? Brand.red
                                : Brand.green)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('× ${line.qty}',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w900)),
                if (kind.isMoney)
                  Text(money(line.total),
                      style: TextStyle(fontSize: 11, color: Brand.muted)),
              ],
            ),
          ],
        ),
      );
}
