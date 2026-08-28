import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n.dart';
import '../models.dart';
import '../sharer.dart';

/// ═══════════════════════════════════════════════════════════════
/// ورقة أمر التوريد — النسخة اللي بتتبعت للعميل (2026-08-08)
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ **دي مش شاشة تأكيد، دي مستند.** المندوب بيصوّرها ويبعتها
/// للعميل واتساب — فترتيبها ترتيب ورقة رسمية مش ترتيب واجهة:
///
///     أمر توريد            ← نوع المستند في النص
///     INV-1006             ← الرقم كبير ومميّز، ده مرجع الاتنين
///     جولدز جيم            ← مين
///     المعادي — القاهرة    ← فين، بخط خفيف
///     كاش                  ← إزاي هيتحاسب
///     ─────────
///     البنود
///     ─────────
///     الحساب
///
/// ⚠️ **الكارت كله جوه `RepaintBoundary`.** التصوير بياخد الكارت
/// لوحده من غير البار ولا الساعة ولا الأزرار — سكرين شوت المندوب
/// كان بيبعت للعميل شكل الأبلكيشن مش الورقة.
class OrderSummaryScreen extends StatefulWidget {
  final String title;
  final String clientName;

  // ⚠️ عنوان العميل اتشال من الورقة خالص (طلب المالك ٢١/٨) —
  // الاسم والرقم وطريقة الدفع كفاية، والعناوين الطويلة كانت
  // بتاكل نص الهيدر.
  final String? docNumber;
  final String? paymentLabel;

  /// (اسم الصنف، الكمية، الصورة) — الصورة ريفرنس بصري ضد الغلط
  /// (الاسم، الكمية، الصورة، لابل اختياري زي «سليم»/«تالف»)
  ///
  /// ⚠️ اللابل انضاف في ١٥/٨ لما المرتجع بقى بيتقسّم سليم/تالف —
  /// السطرين كانوا بيطلعوا بنفس الاسم والكمية مختلفة ومحدش يعرف
  /// أنهي واحد فيهم إيه. الخانة **اختيارية** فباقي الشاشات
  /// (الفاتورة، أمر التوريد) مالهاش دعوة بيها.
  final List<(String, int, String?, String?)> lines;
  final double subtotal;
  final double discount;
  final double tax;
  final double grand;

  const OrderSummaryScreen({
    super.key,
    required this.title,
    required this.clientName,
    required this.lines,
    required this.grand,
    this.docNumber,
    this.paymentLabel,
    this.subtotal = 0,
    this.discount = 0,
    this.tax = 0,
  });

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  /// المفتاح اللي بيتصوّر — الكارت بس مش الشاشة
  final _paper = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);

    // ⚠️ **فريم كامل قبل التصوير.** لو صوّرنا في نفس الفريم اللي
    // فيه `_sharing = true`، الزرار بيبان فيه سبينر جوه الصورة
    // المتبعتة — والعميل بيستلم ورقة فيها لودر.
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final ok = await Sharer.shareBoundary(
      _paper,
      name: '${widget.docNumber ?? 'invoice'}.png',
      text: '${widget.title} ${widget.docNumber ?? ''} — ${widget.clientName}',
    );

    if (!mounted) return;
    setState(() => _sharing = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.t('share_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ **`PopScope` مش شيل الزرار بس** (تدقيق ٩/٨): زرار أندرويد
    // الفيزيائي كان لسه بيرجّع لشاشة البيع بنفس الأصناف — نفس
    // سيناريو الفاتورتين اللي الشاشة دي اتعملت تمنعه.
    return PopScope(
      canPop: false,
      child: Scaffold(
      // ⚠️ **مفيش زرار رجوع.** الفاتورة اتحفظت على السيرفر خلاص —
      // «رجوع» هنا كان بيرجّع لشاشة بيع فيها نفس الأصناف، والمندوب
      // بيحفظ تاني ويطلع فاتورتين لنفس البضاعة.
      appBar: AppBar(
        title: Text(widget.title),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        // ⚠️ viewPadding صريح (بلاغ ٢١/٨) — زراري «ابعتها للعميل»
        // و«تم» كانوا واقعين تحت بار النظام
        padding: EdgeInsets.fromLTRB(14, 14, 14,
            24 + MediaQuery.viewPaddingOf(context).bottom),
        children: [
          RepaintBoundary(
            key: _paper,
            child: Container(
              decoration: BoxDecoration(
                color: Brand.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Brand.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _header(),
                  _items(),
                  _totals(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ═══ الأزرار — بره الورقة عشان ماتتصوّرش ═══
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: const BorderSide(color: Brand.border),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.ios_share, size: 19),
              label: Text(L.t('send_to_client'),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.done_all, size: 20),
              label: Text(L.t('ok_done'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ═══════════════════ رأس الورقة ═══════════════════

  Widget _header() => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        decoration: const BoxDecoration(gradient: Brand.gradient),
        child: Column(
          children: [
            Text(widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .6)),
            const SizedBox(height: 6),

            // ⚠️ **الرقم أكبر حاجة في الورقة.** ده المرجع اللي المندوب
            // والعميل والمحاسب بيتكلموا بيه — «الأمر بتاع 1006» —
            // وكان مكتوب صغير في الركن جنب العنوان.
            if (widget.docNumber != null)
              Text(widget.docNumber!,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: .5)),

            const SizedBox(height: 14),
            Container(height: 1, color: Colors.white.withValues(alpha: .22)),
            const SizedBox(height: 14),

            Text(widget.clientName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.3)),

            if (widget.paymentLabel != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .17),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${L.t('payment')}: ${widget.paymentLabel}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        ),
      );

  // ═══════════════════ البنود ═══════════════════

  Widget _items() {
    final totalQty = widget.lines.fold<int>(0, (t, l) => t + l.$2);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(
        children: [
          for (final l in widget.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  // الصورة كبيرة — المندوب والعميل يتأكدوا بعينهم
                  if (l.$3 != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(l.$3!,
                          width: 46,
                          height: 46,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox(width: 46, height: 46)),
                    ),
                    const SizedBox(width: 11),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.$1,
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                height: 1.4)),
                        if (l.$4 != null) ...[
                          const SizedBox(height: 3),
                          _CondBadge(label: l.$4!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('× ${l.$2}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Brand.royalBlue)),
                ],
              ),
            ),
          const Divider(height: 12, color: Brand.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                      L.t('n_items', {'n': '${widget.lines.length}'}),
                      style: const TextStyle(
                          fontSize: 11.5, color: Brand.muted)),
                ),
                Text(L.t('n_units', {'n': '$totalQty'}),
                    style:
                        const TextStyle(fontSize: 11.5, color: Brand.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════ الحساب ═══════════════════

  Widget _totals() => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        color: const Color(0xFFF7F7FB),
        child: Column(
          children: [
            if (widget.subtotal > 0)
              _row(L.t('before_discount'), widget.subtotal),
            if (widget.discount > 0)
              _row(L.t('discount'), -widget.discount, color: Brand.royalBlue),
            if (widget.tax > 0) _row(L.t('tax'), widget.tax),

            const SizedBox(height: 10),
            Container(height: 1, color: Brand.border),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Text(L.t('total_due'),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                ),
                Text(money(widget.grand),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Brand.royalBlue)),
              ],
            ),
          ],
        ),
      );

  Widget _row(String label, double value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: Brand.muted)),
            ),
            Text(money(value),
                textDirection: TextDirection.ltr,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color ?? Brand.text)),
          ],
        ),
      );
}

/// ═══════════════════════════════════════════════════════════════
/// لابل حالة البند — «سليم» / «تالف»  ·  ١٥ أغسطس ٢٠٢٦
/// ═══════════════════════════════════════════════════════════════
///
/// بلاغ المالك: «المرتجع المقسوم طلع المنتجات مقسومين، بس محتاجين
/// نضيف Label عليهم».
///
/// ⚠️ **اللون مش وحده اللي بيفرّق** — فيه أيقونة ونص كمان. قاعدة
/// `color-not-only`: المندوب ممكن يكون عنده عمى ألوان، والورقة
/// ممكن تتطبع أبيض وأسود.
class _CondBadge extends StatelessWidget {
  final String label;

  const _CondBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    // التالف بيتعرف من مفتاح اللغة مش من النص المترجم — النص
    // بيتغير مع اللغة، والمقارنة بيه كانت هتكسر على الإنجليزي.
    final bad = label == L.t('return_cond_damaged');
    final color = bad ? Brand.red : Brand.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(bad ? Icons.report_gmailerrorred : Icons.check_circle_outline,
              size: 12, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
