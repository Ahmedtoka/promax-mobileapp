import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n.dart';
import '../models.dart';
import '../session.dart';
import 'item_cart.dart';
import 'order_summary.dart';
import 'sale.dart';

/// ═══════════════════════════════════════════════════════════════
/// المرتجع — بضاعة راجعة من العميل للعربية
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ **الشاشة دي اتعادت من الأول في ٨ أغسطس ٢٠٢٦.** قبل كده كانت
/// بتشتغل على العهدة (اللي في العربية) وبسعر النهارده وبلا سقف —
/// يعني المندوب كان يقدر يرجّع صنف العميل ماشتراهوش أصلاً، بسعر
/// اتغيّر بعد البيع، وبكمية بلا حد.
///
/// دلوقتي:
///   1. الشاشة بتنده `returnable` → **كتالوج البيع كله بسعر العميل**
///      (قرار المالك ١٢/٨: العميل ممكن يكون ماسك بضاعة من قبل
///      السيستم — الأرصدة الافتتاحية للبضاعة ماتسجلتش، فشرط
///      «اشتراه الأول» كان بيقفل مرتجعات حقيقية). السيرفر بيسعّر:
///      سطور الفواتير الأصلية أولاً بسعرها، والباقي بـPricing.
///   2. المندوب بيختار **طريقة المرتجع** من المسموح للعميل بس
///   3. شاشة مراجعة زي البيع — وفيها **سليم / تالف** لكل صنف
///   4. الحفظ بمفتاح منع تكرار مولّد مرة واحدة — والسقف 9999 للصنف
///
/// ⚠️ التبديل بيفتح شاشة البيع بعده على طول — البضاعة البديلة
/// بتخرج بفاتورة عادية، ولو المندوب نسي بتبقى بضاعة خرجت من غير
/// فاتورة وتصفيته تطلع عجز.
class ClientReturnScreen extends StatefulWidget {
  final Client client;
  const ClientReturnScreen({super.key, required this.client});

  @override
  State<ClientReturnScreen> createState() => _ClientReturnScreenState();
}

class _ClientReturnScreenState extends State<ClientReturnScreen> {
  final Map<int, int> qty = {}; // الكمية بوحدة السطر
  final Map<int, String> units = {}; // piece/box/case
  final Map<int, String> conditions = {}; // good/damaged/split

  /// ملاحظات التالف/المنتهي (١٩ أغسطس ٢٠٢٦) — طلب المالك: «مادام
  /// فيه على الأقل منتج تالف أو منتهي، لازم ملاحظة قبل التأكيد».
  /// الخانة بتظهر في شاشة المراجعة بس لما يكون فيه تالف، وإجبارية
  /// ساعتها — والسيرفر بيخزنها على مستند المرتجع (`note`).
  final noteCtrl = TextEditingController();
  /// كام **قطعة** تالفة لكل صنف — بيتملّى مع «مقسوم» بس (١٥/٨)
  final Map<int, int> damaged = {};
  /// إجمالي قطع السطر وقت المراجعة — الأساس اللي التالف بيتقص منه
  final Map<int, int> linePieces = {};

  bool _busy = false;
  bool _loading = true;
  String? _error;

  /// كتالوج المرتجع — كل الأصناف المتسعّرة للعميل (مش عهدة ومش فواتير)
  List<CustodyItem> _catalog = const [];

  /// السياسات المسموحة للعميل ده: [{code, label, hint}]
  List<Map<String, dynamic>> _policies = const [];
  String? _policy;

  /// ⚠️ **مفتاح منع التكرار بيتولّد مرة واحدة للشاشة.** لو اتولّد مع
  /// كل ضغطة، إعادة المحاولة بعد انقطاع شبكة كانت هتكتب مرتجع تاني.
  late final String _idemKey =
      'ret-${widget.client.id}-${DateTime.now().microsecondsSinceEpoch}';

  static const _accent = Color(0xFFB45309);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (err, res) = await Session.I.returnable(widget.client.id);
    if (!mounted) return;

    if (err != null || res == null) {
      setState(() {
        _loading = false;
        _error = err ?? L.t('error');
      });
      return;
    }

    final items = (res['items'] as List? ?? const [])
        .map((e) => e as Map<String, dynamic>)
        .map((m) => CustodyItem.fromJson({
              'product_id': m['product_id'],
              'name': m['name'],
              'name_ar': m['name'],
              'name_en': m['name'],
              'image': m['image'],
              'unit': m['unit'],
              'price': m['price'] ?? 0,
              // ⚠️ `qty` من السيرفر = المتاح من فواتير السيستم —
              // معلومة مش حد (١٢/٨): المرتجع اتفتح على الكتالوج
              // كله والسقف بقى 9999 جوه ItemCart والسيرفر.
              'assigned': m['qty'] ?? 0,
              'sold': 0,
              'remaining': m['qty'] ?? 0,
              'box_units': m['box_units'] ?? 0,
              'case_units': m['case_units'] ?? 0,
              'tax_rate': m['tax_rate'] ?? 0,
            }))
        .toList();

    final policies = (res['policies'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    setState(() {
      _loading = false;
      _catalog = items;
      _policies = policies;
      // اختيار واحدة تلقائياً لو مفيش غيرها — سؤال بإجابة واحدة
      // مش سؤال.
      _policy = policies.length == 1 ? policies.first['code'] as String : null;
    });
  }

  int _pieces(CustodyItem i) =>
      (qty[i.productId] ?? 0) * i.factorOf(units[i.productId] ?? i.defaultUnit);

  int get totalQty {
    var t = 0;
    for (final i in _catalog) {
      t += _pieces(i);
    }
    return t;
  }

  /// قيمة تقريبية للعرض — الرقم النهائي من السيرفر بعد التوزيع على
  /// سطور الفواتير (الصنف ممكن يكون اتباع بسعرين).
  double get totalValue {
    double t = 0;
    for (final i in _catalog) {
      t += _pieces(i) * i.price;
    }
    return t;
  }

  List<CustodyItem> get _chosen =>
      _catalog.where((i) => (qty[i.productId] ?? 0) > 0).toList();

  /// شاشة المراجعة — زي البيع، وفيها اختيار سليم/تالف لكل صنف
  Future<void> _review() async {
    if (_policy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.t('return_policy_pick'))));
      return;
    }

    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _ReturnReviewScreen(
        clientName: widget.client.name,
        policyLabel: _policies
                .firstWhere((p) => p['code'] == _policy,
                    orElse: () => const {'label': ''})['label']
                ?.toString() ??
            '',
        lines: [
          for (final i in _chosen)
            (i, _pieces(i), conditions[i.productId] ?? 'good'),
        ],
        onCondition: (pid, c) => setState(() {
          conditions[pid] = c;
          if (c != 'split') damaged.remove(pid);
        }),
        onSplit: (pid, dmg, tot) => setState(() {
          damaged[pid] = dmg;
          linePieces[pid] = tot;
        }),
        total: totalValue,
        noteCtrl: noteCtrl,
      ),
    ));

    if (ok == true && mounted) await _save();
  }

  Future<void> _save() async {
    setState(() => _busy = true);

    final (err, ret) = await Session.I.createReturn(
      widget.client,
      qty,
      units: units,
      conditions: conditions,
      damagedPieces: damaged,
      totalPieces: linePieces,
      policy: _policy!,
      idemKey: _idemKey,
      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (err != null || ret == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err ?? L.t('error'))));
      return;
    }

    final serverLines = (ret['lines'] ?? []) as List;
    final needsSale = ret['needs_exchange_sale'] == true;

    // ⚠️ **الـNavigator بيتمسك قبل الـ`await`.** `pushReplacement`
    // بيشيل الشاشة دي ويعمل لها `dispose` — فبعد الـ`await` بتاعها
    // `mounted` بترجع `false` **دايماً**، وأي `Navigator.of(context)`
    // بعدها بيرمي. النتيجة كانت إن التبديل عمره ما بيفتح شاشة البيع،
    // فالبضاعة البديلة تخرج من غير فاتورة والتصفية تطلع عجز.
    final nav = Navigator.of(context);
    final msg = ScaffoldMessenger.of(context);

    await nav.pushReplacement(MaterialPageRoute(
      builder: (_) => OrderSummaryScreen(
        title: L.t('return_doc'),
        clientName: widget.client.name,
        docNumber: ret['number']?.toString(),
        paymentLabel: ret['policy_label']?.toString(),
        lines: [
          // ⚠️ `condition_label` من السيرفر — البند المقسوم بيطلع
          // سطرين بنفس الاسم، واللابل هو الفرق الوحيد بينهم.
          for (final l in serverLines)
            (
              (l['name'] ?? '') as String,
              (l['qty'] ?? 0) as int,
              l['image'] as String?,
              l['condition_label']?.toString(),
            ),
        ],
        tax: ((ret['tax_total'] ?? 0) as num).toDouble(),
        grand: ((ret['grand_total'] ?? 0) as num).toDouble(),
      ),
    ));

    // ⚠️ **التبديل خطوتين.** المرتجع سجّل الراجع، والبضاعة البديلة
    // لسه لازم تخرج بفاتورة — ولو مخرجتش، العهدة هتبان ناقصة في
    // التصفية بلا سبب. بنفتح البيع تلقائياً بدل الاعتماد على إن
    // المندوب هيفتكر.
    if (needsSale) {
      msg.showSnackBar(SnackBar(content: Text(L.t('return_exchange_next'))));

      nav.push(MaterialPageRoute(
        builder: (_) => SaleScreen(client: widget.client),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(L.t('return_from', {'c': widget.client.name}))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _message(_error!, Brand.red)
              : _catalog.isEmpty
                  ? _message(L.t('return_none_returnable'), Brand.muted)
                  : _form(),
    );
  }

  Widget _message(String text, Color color) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ),
      );

  Widget _form() => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.u_turn_left, size: 18, color: _accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(L.t('return_note'),
                        style: const TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
            ),
          ),

          // ═══ طريقة المرتجع — المسموح للعميل ده بس ═══
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(L.t('return_policy'),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w900)),
            ),
          ),
          SizedBox(
            height: 62,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final p in _policies)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      selected: _policy == p['code'],
                      label: Text('${p['label']}'),
                      tooltip: '${p['hint'] ?? ''}',
                      selectedColor: _accent.withValues(alpha: .18),
                      onSelected: (_) =>
                          setState(() => _policy = p['code'] as String),
                    ),
                  ),
              ],
            ),
          ),

          // ═══ البحث + اللاينات — نفس ودجت البيع ═══
          Expanded(
            child: ItemCart(
              catalog: _catalog,
              qty: qty,
              units: units,
              onChanged: () => setState(() {}),
              // ⚠️ **رجعت `false` بقرار مالك (١٢/٨)** — العميل ممكن
              // يرجّع بضاعة قديمة من قبل السيستم مالهاش فاتورة،
              // فمفيش حد بالمشترى. الأمان: سقف 9999 هنا وفي السيرفر،
              // وسويتش المرتجعات في الإعدادات بيقفل الفيتشر كله.
              limitToRemaining: false,
              accent: _accent,
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
                            Text(
                                '${L.t('return_doc')} • ${L.t('total_units', {'n': '$totalQty'})}',
                                style: TextStyle(
                                    fontSize: 12, color: Brand.muted)),
                            Text(money(totalValue),
                                style: const TextStyle(
                                    fontSize: 19, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(150, 50),
                          backgroundColor: _accent,
                        ),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: Text(L.t('review')),
                        onPressed: (totalQty <= 0 || _busy) ? null : _review,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}

/// ═══════════════════════════════════════════════════════════════
/// مراجعة المرتجع — آخر فرصة يصلّح قبل ما القيد يتكتب
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ **سليم/تالف بيتحدد هنا مش في شاشة الاختيار.** المندوب بيعد
/// البضاعة وهو بيراجعها مع العميل، مش وهو بيدوّر عليها في البحث —
/// وحطّ السويتش في السطر كان بيخلّي كل صف مزدحم بحاجة بتتقرر بعدين.
class _ReturnReviewScreen extends StatefulWidget {
  final String clientName;
  final String policyLabel;
  final List<(CustodyItem, int, String)> lines;
  final void Function(int productId, String condition) onCondition;
  /// التقسيم: كام قطعة تالفة من إجمالي قطع السطر (١٥/٨)
  final void Function(int productId, int damaged, int total) onSplit;
  final double total;

  /// ملاحظات التالف — الكنترولر بتاع الشاشة الأم عشان النص يعيش
  /// لو المندوب رجع يعدّل وفتح المراجعة تاني
  final TextEditingController noteCtrl;

  const _ReturnReviewScreen({
    required this.clientName,
    required this.policyLabel,
    required this.lines,
    required this.onCondition,
    required this.onSplit,
    required this.total,
    required this.noteCtrl,
  });

  @override
  State<_ReturnReviewScreen> createState() => _ReturnReviewScreenState();
}

class _ReturnReviewScreenState extends State<_ReturnReviewScreen> {
  late final Map<int, String> _cond = {
    for (final l in widget.lines) l.$1.productId: l.$3,
  };

  /// كام قطعة تالفة لكل صنف — بيتملّى مع «مقسوم» بس
  final Map<int, int> _dmg = {};

  /// فيه تالف/منتهي في المرتجع؟ — «مقسوم» بيتحسب تالف بطبيعته
  /// (مفيش تقسيم من غير قطع تالفة). دي اللي بتظهر خانة الملاحظات
  /// وبتخليها إجبارية.
  bool get _hasDamaged => widget.lines.any((l) {
        final c = _cond[l.$1.productId] ?? 'good';
        return c == 'damaged' || c == 'split';
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.t('review'))),
      body: Column(
        children: [
          // ═══ كارت العميل بالستايل الجديد (٢١/٨) — متدرج ومن غير
          // عنوان: الاسم كبير والسياسة شيب واضح ═══
          Container(
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
            decoration: BoxDecoration(
              gradient: Brand.gradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.clientName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: .35)),
                  ),
                  child: Text(widget.policyLabel,
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(L.t('return_cond_hint'),
                  style: TextStyle(fontSize: 11.5, color: Brand.muted)),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: widget.lines.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, idx) {
                final (item, pieces, _) = widget.lines[idx];
                final c = _cond[item.productId] ?? 'good';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(item.name,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800)),
                          ),
                          Text('$pieces',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // ═══ سليم · تالف · مقسوم (١٥ أغسطس ٢٠٢٦) ═══
                      //
                      // «مقسوم» اتضافت لأن الكرتونة بتيجي نصها سليم
                      // ونصها تالف (بلاغ المالك)، والاختيار الثنائي
                      // كان بيجبر المندوب يكدب على السطر كله.
                      Row(
                        children: [
                          for (final opt in const ['good', 'damaged', 'split'])
                            Padding(
                              padding:
                                  const EdgeInsetsDirectional.only(end: 6),
                              child: ChoiceChip(
                                selected: c == opt,
                                label: Text(L.t('return_cond_$opt')),
                                selectedColor: switch (opt) {
                                  'damaged' => Brand.red.withValues(alpha: .18),
                                  'split' => Brand.orange.withValues(alpha: .22),
                                  _ => Brand.green.withValues(alpha: .18),
                                },
                                onSelected: (_) {
                                  setState(() {
                                    _cond[item.productId] = opt;
                                    // الخروج من «مقسوم» بيصفّر التالف —
                                    // وإلا رقم قديم بيفضل مخبّي ويتبعت
                                    if (opt != 'split') {
                                      _dmg.remove(item.productId);
                                    }
                                  });
                                  widget.onCondition(item.productId, opt);
                                },
                              ),
                            ),
                        ],
                      ),

                      // ═══ خانة التالف — بتبان مع «مقسوم» بس ═══
                      if (c == 'split') ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            SizedBox(
                              width: 110,
                              child: TextFormField(
                                initialValue:
                                    '${_dmg[item.productId] ?? 0}',
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: L.t('return_damaged_qty'),
                                  border: const OutlineInputBorder(),
                                ),
                                onChanged: (v) {
                                  // ⚠️ **مقيّد بين ١ و(الكمية − ١)** —
                                  // صفر أو الكل معناه إنها مش مقسومة
                                  // أصلاً، والسطرين كانوا هيطلعوا
                                  // واحد منهم بصفر.
                                  final n = int.tryParse(v.trim()) ?? 0;
                                  setState(() => _dmg[item.productId] =
                                      n.clamp(0, pieces));
                                  widget.onSplit(item.productId,
                                      _dmg[item.productId] ?? 0, pieces);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                L.t('return_split_hint', {
                                  'good':
                                      '${pieces - (_dmg[item.productId] ?? 0)}',
                                  'bad': '${_dmg[item.productId] ?? 0}',
                                }),
                                style: TextStyle(
                                    fontSize: 12, color: Brand.muted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
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
                  // ═══ ملاحظات التالف/المنتهي (١٩ أغسطس ٢٠٢٦) ═══
                  // بتظهر بس لما فيه تالف — وإجبارية ساعتها (الحارس
                  // على زرار التأكيد تحت). بتتخزن على مستند المرتجع.
                  if (_hasDamaged) ...[
                    TextField(
                      controller: widget.noteCtrl,
                      maxLines: 2,
                      maxLength: 500,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: L.t('return_note_label'),
                        hintText: L.t('return_note_hint'),
                        counterText: '',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.edit_note),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(L.t('total'),
                                style: TextStyle(
                                    fontSize: 12, color: Brand.muted)),
                            Text(money(widget.total),
                                style: const TextStyle(
                                    fontSize: 19, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(L.t('back_to_edit')),
                      ),
                      const SizedBox(width: 6),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(140, 50),
                          backgroundColor: const Color(0xFFB45309),
                        ),
                        icon: const Icon(Icons.check),
                        label: Text(L.t('save_return')),
                        onPressed: () {
                          // فيه تالف؟ الملاحظة شرط — دي عين الإدارة
                          // على البضاعة اللي بتتكسر من غير سبب
                          if (_hasDamaged &&
                              widget.noteCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text(L.t('return_note_required'))));
                            return;
                          }
                          Navigator.of(context).pop(true);
                        },
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
