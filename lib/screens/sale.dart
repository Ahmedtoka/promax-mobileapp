import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n.dart';
import '../models.dart';
import '../session.dart';
import 'item_cart.dart';
import 'order_summary.dart';
import 'sale_review.dart';

/// ═══════════════════════════════════════════════════════════════
/// البيع — فاتورة كاش فان من العهدة
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ **كاش/آجل مش هنا.** قرار إدارة متسجل على العميل في الـERP
/// (قرار المالك 2026-08-03) — الشاشة بتعرضه بس، والسيرفر بيتجاهل أي
/// حاجة تانية أصلاً.
///
/// الكمية بتتكتب بالإيد **أو** بالـ +/- — الاتنين على نفس الخانة.
class SaleScreen extends StatefulWidget {
  final Client client;
  const SaleScreen({super.key, required this.client});

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final Map<int, int> qty = {}; // productId -> الكمية بوحدة السطر
  final Map<int, String> units = {}; // productId -> piece/box/case

  /// سيريال الفاتورة الورقية المختومة (١٩/٨) — بيتكتب في شاشة
  /// المراجعة وبيتبعت مع الفاتورة للمطابقة الدفترية
  final paperCtrl = TextEditingController();
  bool _busy = false;

  /// ⚠️ **الافتراضي كاش للعميل المختلط.** لو بدأنا بآجل، المندوب
  /// المستعجل بيدوس «حفظ» على طول وبيفتح مديونية من غير ما ياخد باله —
  /// وتحصيل فلوس مش مقبوضة أصعب من تحويل فاتورة كاش لآجل بعدين.
  /// والعميل اللي مش مختلط الحقل ده مابيتقريش أصلاً.
  String _payment = 'cash';

  /// تفصيل الإجماليات مفتوح ولا مقفول.
  ///
  /// ⚠️ **مقفول افتراضياً** (إعادة تصميم ١٦ أغسطس). الفوتر كان بيعرض
  /// ٥ صفوف دايماً — قبل الخصم، الخصم، الصافي، الضريبة، الإجمالي —
  /// فارتفاعه بيتغيّر حسب العميل، وعلى موبايل صغير والكيبورد مفتوح
  /// كان بياكل قايمة الأصناف. الرقم اللي المندوب بيقوله للعميل هو
  /// **الإجمالي**؛ الباقي مراجعة بيفتحها لما يحتاجها.
  bool _showDetails = false;

  /// طريقة الدفع اللي الفاتورة دي هتتسجل بيها فعلاً.
  ///
  /// ⚠️ **مصدر واحد للشاشة كلها** — الشريط العلوي وليبل السامري
  /// وقيمة الإرسال كلهم بيقروا من هنا. لما كانوا بيحسبوها كل واحد
  /// لوحده، الشريط كان بيقول «كاش» والسامري «آجل» لنفس الفاتورة.
  String get _effectivePayment =>
      widget.client.paymentChoice ? _payment : widget.client.paymentTerms;

  /// أسعار **قايمة العميل** — بتتحمّل أول ما الشاشة تفتح.
  ///
  /// ⚠️ **سعر العهدة سعر استرشادي مش سعر العميل.** العهدة مالهاش
  /// عميل، فالسيرفر بيسعّرها بقايمة مشتقة من رول المندوب — والفاتورة
  /// بتتحسب من قايمة العميل. الاتنين كانوا بيختلفوا والمندوب يقول
  /// رقم ويطلع في الفاتورة رقم تاني (تدقيق ٨/٨/٢٠٢٦).
  Map<int, double> _clientPrice = const {};

  @override
  void initState() {
    super.initState();
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    final p = await Session.I.clientListPrices(widget.client.id);
    if (!mounted || p.isEmpty) return;
    setState(() => _clientPrice = p);
  }

  /// سعر القائمة للعميل ده — وإلا سعر العهدة الاسترشادي
  double _priceOf(CustodyItem i) => _clientPrice[i.productId] ?? i.price;

  /// قطع السطر = الكمية × مضاعِف الوحدة — نفس ضرب السيرفر بالظبط
  int _pieces(CustodyItem i) =>
      (qty[i.productId] ?? 0) * i.factorOf(units[i.productId] ?? i.defaultUnit);

  double get subtotal {
    double t = 0;
    for (final i in Session.I.custody.byProduct) {
      t += _pieces(i) * _priceOf(i);
    }
    return t;
  }

  double get discount => subtotal * widget.client.discount;

  /// الصافي بعد الخصم وقبل الضريبة — ده اللي بيتسجّل كمبيعات
  double get total => subtotal - discount;

  /// ⚠️ الضريبة بتتحسب **سطر بسطر على الصافي بعد الخصم**، بنفس
  /// قاعدة السيرفر بالظبط. حساب مختلف هنا معناه إن الرقم اللي
  /// المندوب قاله للعميل غير الرقم اللي اتسجّل.
  double get tax {
    if (!widget.client.taxable) return 0;

    final d = widget.client.discount;
    double t = 0;

    for (final i in Session.I.custody.byProduct) {
      final q = _pieces(i);
      if (q == 0 || !i.taxable) continue;

      final rate = i.taxRate > 0 ? i.taxRate : widget.client.taxRate;
      final net = q * _priceOf(i) * (1 - d);

      t += _round2(net * rate);
    }

    return _round2(t);
  }

  double get grandTotal => _round2(total + tax);

  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  int get lines => qty.values.where((q) => q > 0).length;

  /// إجمالي القطع في الفاتورة — «٣ أصناف» مش معلومة كافية لما
  /// المندوب بيحمّل الكرتون في إيده؛ «٣ أصناف · ٧٢ قطعة» هي.
  int get totalPieces {
    var n = 0;
    for (final i in Session.I.custody.byProduct) {
      n += _pieces(i);
    }

    return n;
  }

  /// الأصناف اللي فعلاً معاه في العربية
  List<CustodyItem> get _available =>
      Session.I.custody.byProduct.where((i) => i.remaining > 0).toList();

  /// ⚠️ **المراجعة قبل الحفظ** (2026-08-08). الزرار كان بيخلق
  /// الفاتورة على طول — والمندوب اللي كتب كمية غلط أو اختار
  /// «كرتونة» بدل «قطعة» مكانش بيكتشف غير بعد ما تتسجّل، وساعتها
  /// محتاج مرتجع عشان يصلّح رقم.
  ///
  /// ⚠️ **بنبعت الأرقام المحسوبة هنا مش بنسيب المراجعة تحسب.** لو
  /// الاتنين حسبوا كل واحد لوحده، أي فرق تقريب بيخلّي المندوب يشوف
  /// رقمين لنفس الفاتورة ومايعرفش أنهي واحد اللي هيتسجّل.
  Future<void> _review() async {
    final items = Session.I.custody.byProduct;

    final rows = <(String, int, String, double, String?)>[];

    for (final e in qty.entries) {
      if (e.value <= 0) continue;

      final item = firstOrNull(items.where((i) => i.productId == e.key));
      if (item == null) continue;

      final unit = units[e.key] ?? item.defaultUnit;
      final pieces = e.value * item.factorOf(unit);

      rows.add((
        item.name,
        e.value,
        CustodyItem.unitName(unit),
        pieces * _priceOf(item) * (1 - widget.client.discount),
        item.image,
      ));
    }

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SaleReviewScreen(
          clientName: widget.client.name,
          paymentLabel: _effectivePayment == 'cash' ? L.t('cash') : L.t('credit'),
          isCash: _effectivePayment == 'cash',
          lines: rows,
          subtotal: subtotal,
          discount: discount,
          tax: tax,
          grand: grandTotal,
          paperCtrl: paperCtrl,
        ),
      ),
    );

    // `null` = رجع بزرار الجهاز، `false` = دوس «رجوع للتعديل»
    if (ok == true && mounted) await _save();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final (err, inv) = await Session.I.createInvoice(
      widget.client, qty,
      units: units,
      payment: _payment,
      paperRef: paperCtrl.text.trim().isEmpty ? null : paperCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (err != null || inv == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err ?? L.t('error'))));
      return;
    }

    // ⚠️ السامري بياخد مكان شاشة البيع (pushReplacement) — «رجوع»
    // من السامري بترجّع لصفحة العميل مش لفاتورة اتحفظت خلاص.
    final items = Session.I.custody.byProduct;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => OrderSummaryScreen(
        // ⚠️ «أمر توريد» — الاسم اللي الورق بيتسمى بيه قدام العميل
        // (قرار المالك 2026-08-03). جوه السيستم لسه فاتورة INV.
        title: L.t('supply_order'),
        clientName: widget.client.name,
        docNumber: inv['number']?.toString(),
        // ⚠️ من `_effectivePayment` مش من `paymentTerms` — العميل
        // المختلط `paymentTerms` بتاعه `both`، والمقارنة القديمة كانت
        // هتكتب «آجل» على ورقة اتقبض فلوسها كاش.
        paymentLabel: _effectivePayment == 'cash' ? L.t('cash') : L.t('credit'),
        // ⚠️ `firstOrNull()` بتاعتنا من models.dart — الامتداد
        // `.firstOrNull` محتاج package:collection (الفخ المعروف)
        lines: [
          // الكمية **بالقطع** — نفس اللي السيرفر سجّله في الفاتورة
          for (final e in qty.entries)
            if (e.value > 0)
              (
                firstOrNull(items.where((i) => i.productId == e.key))?.name ??
                    '#${e.key}',
                e.value *
                    (firstOrNull(items.where((i) => i.productId == e.key))
                            ?.factorOf(units[e.key] ?? 'piece') ??
                        1),
                firstOrNull(items.where((i) => i.productId == e.key))?.image,
                null, // مفيش حالة سليم/تالف في البيع
              ),
        ],
        subtotal: ((inv['subtotal'] ?? 0) as num).toDouble(),
        discount: ((inv['discount'] ?? 0) as num).toDouble(),
        tax: ((inv['tax_total'] ?? 0) as num).toDouble(),
        // ⚠️ grand_total — اللي بيتحصّل فعلاً شامل الضريبة
        grand: ((inv['grand_total'] ?? inv['total'] ?? 0) as num).toDouble(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    final available = _available;

    return Scaffold(
      // ⚠️ **الاسم في الأب بار مرة واحدة بس.** `invoice_for` كانت
      // بتطلع «فاتورة لـ<اسم طويل>» وتتقص في النص على موبايل صغير،
      // فالمندوب مايعرفش هو على أنهي عميل. الاسم بقى سطر لوحده
      // والنوع سطر خافت تحته.
      appBar: AppBar(
        // ⚠️ **متمركز زي كل الشاشات** — الثيم `centerTitle: true`،
        // وعمود بمحاذاة `start` جواه كان هيبان مزحلق ناحية.
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800)),
            Text(L.t('supply_order'),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        children: [
          _contextStrip(c),

          // ═══ البحث + اللاينات — الودجت المشترك مع المرتجع ═══
          Expanded(
            child: available.isEmpty
                ? _emptyCustody()
                : ItemCart(
                    catalog: available,
                    qty: qty,
                    units: units,
                    onChanged: () => setState(() {}),
                    limitToRemaining: true,
                    accent: Theme.of(context).colorScheme.primary,
                    // الرقم المعروض في السطر = الرقم اللي هيتحسب في الفاتورة
                    priceOverride: _clientPrice,
                  ),
          ),

          _footer(c),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // شريط سياق العميل — إعادة تصميم ١٦ أغسطس ٢٠٢٦
  // ═══════════════════════════════════════════════════════════════
  //
  // نفس لغة كارت العميل وشاشة الزيارة (تدرّج + لابلز) عشان المندوب
  // مايحسّش إنه دخل أبلكيشن تاني.
  //
  // ⚠️ **«عليه» موجودة هنا مش في الشاشة اللي فاتت بس.** المندوب
  // بيقرر يبيع آجل وهو واقف قدام المحل، والقرار ده معناه إنه بيزوّد
  // مديونية عميل عليه فلوس من قبل كده. إخفاء الرقم في الشاشة اللي
  // قبلها معناه إنه بياخد القرار وهو مش شايفه.
  Widget _contextStrip(Client c) {
    final isCash = _effectivePayment == 'cash';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        gradient: Brand.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _chip(
                isCash ? Icons.payments_outlined : Icons.schedule,
                isCash ? L.t('cash') : L.t('credit'),
                strong: true,
              ),
              // ⚠️ **مدة السداد قدام المندوب وهو بيبيع آجل.** هو اللي
              // هيقول للعميل «الفلوس بعد كام يوم» — ولو ماشفهاش، بيقول
              // رقم من دماغه والمحاسب بيلاحق ميعاد تاني.
              if (!isCash && c.paymentDays != null)
                _chip(Icons.event_outlined,
                    L.t('days_n', {'n': '${c.paymentDays}'})),
              if (c.discount > 0)
                _chip(Icons.sell_outlined,
                    L.t('discount_n', {'n': '${(c.discount * 100).round()}'})),
            ],
          ),

          // ═══ عليه — بتظهر بس لما يكون عليه فعلاً ═══
          if (c.balance > 0) ...[
            const SizedBox(height: 11),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(L.t('on_him'),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70)),
                  const Spacer(),
                  Text(money(c.balance),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ],
              ),
            ),
          ],

          // ═══ اختيار الدفع — سطر كامل لوحده ═══
          //
          // ⚠️ **كان جنب النص في نفس الصف** والصف كان بيطفح على شاشة
          // ضيقة بالعربي (أيقونة + «الدفع: كاش» + المدة + سويتش
          // بأيقونتين). سطر كامل بعرض الشاشة بيمنع الطفح نهائياً
          // ويكبّر مساحة اللمس في نفس الوقت.
          //
          // ⚠️ **بيظهر للمختلط بس.** العميل الكاش الصافي أو الآجل
          // الصافي مايشوفش أي اختيار — مفيش زرار يتداس بالغلط.
          if (c.paymentChoice) ...[
            const SizedBox(height: 11),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: const WidgetStatePropertyAll(
                      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                  side: const WidgetStatePropertyAll(
                      BorderSide(color: Colors.white54)),
                  backgroundColor: WidgetStateProperty.resolveWith((s) =>
                      s.contains(WidgetState.selected)
                          ? Colors.white
                          : Colors.transparent),
                  foregroundColor: WidgetStateProperty.resolveWith((s) =>
                      s.contains(WidgetState.selected)
                          ? Brand.royalBlue
                          : Colors.white),
                ),
                segments: [
                  ButtonSegment(
                      value: 'cash',
                      label: Text(L.t('cash')),
                      icon: const Icon(Icons.payments_outlined, size: 15)),
                  ButtonSegment(
                      value: 'credit',
                      label: Text(L.t('credit')),
                      icon: const Icon(Icons.schedule, size: 15)),
                ],
                selected: {_payment},
                onSelectionChanged: (v) =>
                    setState(() => _payment = v.first),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text, {bool strong = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: strong ? .22 : .13),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13.5, color: Colors.white),
            const SizedBox(width: 5),
            Text(text,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ],
        ),
      );

  /// ⚠️ **العربية الفاضية حالة مستقلة مش قايمة فاضية.** المنتقي كان
  /// بيفتح على لستة فاضية والمندوب يفضل يدوّر على الصنف وهو أصلاً
  /// مش معاه بضاعة. الرسالة بتقوله السبب والخطوة الجاية.
  Widget _emptyCustody() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_shipping_outlined,
                  size: 52, color: Brand.muted),
              const SizedBox(height: 12),
              Text(L.t('no_custody_items'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              // ⚠️ المفتاح ده **موجود قبل كده** ومستخدم في شاشة
              // العهدة — استخدمته زي ما هو بدل ما أضيف واحد بنفس
              // الاسم. مفتاح مكرر في ماب دارت = **البيلد بيقع**.
              Text(L.t('no_custody_hint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: Brand.muted)),
            ],
          ),
        ),
      );

  // ═══════════════════════════════════════════════════════════════
  // الفوتر — إجمالي ثابت + تفصيل بيتفتح
  // ═══════════════════════════════════════════════════════════════
  Widget _footer(Client c) {
    final hasBreakdown = (c.hasContract && discount > 0) || tax > 0;
    final ready = total > 0 && !_busy;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      // ⚠️ SafeArea معطّلة + viewPadding صريح (مسح ٢١/٨) — ماكانتش
      // بتزق البار فوق بار النظام على الجهاز
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.viewPaddingOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasBreakdown) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _showDetails = !_showDetails),
                  child: Padding(
                    // ⚠️ ارتفاع ≥44 لمساحة اللمس
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                            _showDetails
                                ? Icons.expand_more
                                : Icons.chevron_right,
                            size: 18,
                            color: Brand.muted),
                        const SizedBox(width: 4),
                        Text(L.t('details'),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Brand.muted)),
                      ],
                    ),
                  ),
                ),
                if (_showDetails) ...[
                  _line(L.t('before_discount'), money(subtotal)),
                  if (discount > 0)
                    _line(
                        L.t('contract_discount_n',
                            {'n': '${(c.discount * 100).round()}'}),
                        '- ${money(discount)}',
                        color: Brand.blue500),
                  if (tax > 0) ...[
                    _line(L.t('net_before_tax'), money(total)),
                    _line(L.t('tax'), '+ ${money(tax)}',
                        color: Brand.royalBlue),
                  ],
                  const SizedBox(height: 4),
                ],
                const Divider(height: 1),
                const SizedBox(height: 10),
              ],

              // ═══ الرقم اللي المندوب بيقوله للعميل ═══
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tax > 0 ? L.t('total_due') : L.t('total'),
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Brand.muted)),
                        Text(money(grandTotal),
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  // ⚠️ **الأصناف والقطع مع بعض.** «٣ أصناف» لوحدها
                  // مش بتقول للمندوب هو شايل كام في إيده — والقطع هي
                  // اللي بيعدّها قدام العميل.
                  if (lines > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${L.t('n_items', {'n': '$lines'})} · '
                        '${L.t('total_pieces_n', {'n': '$totalPieces'})}',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Brand.muted),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // ⚠️ **زرار بعرض الشاشة.** كان ١٥٠ بكسل جنب الإجمالي،
              // و«مراجعة الفاتورة» بالعربي كانت بتتقص جواه. ده الفعل
              // الوحيد في الشاشة فمالوش داعي يزاحم رقم.
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: Colors.white),
                        )
                      : const Icon(Icons.fact_check_outlined),
                  label: Text(L.t('review_invoice'),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  onPressed: ready ? _review : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontSize: 12, color: color ?? Brand.muted)),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color ?? Brand.text)),
          ],
        ),
      );
}
