import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n.dart';
import '../models.dart';

/// ═══════════════════════════════════════════════════════════════
/// مراجعة قبل التأكيد (2026-08-08)
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ **الشاشة دي حاجز مقصود بين «خلصت» و«اتحفظت».** قبلها كان زرار
/// واحد اسمه «حفظ الفاتورة» بيخلق الفاتورة على طول — والمندوب اللي
/// كتب كمية غلط أو نسي صنف مكانش بيكتشف غير بعد ما تتسجّل، وساعتها
/// محتاج مرتجع عشان يصلّح رقم.
///
/// ⚠️ **بتعرض نفس الأرقام اللي هتتبعت بالظبط** — مش بتحسب من جديد.
/// شاشة البيع بتبعت الحساب اللي هي حسبته، فلو الاتنين حسبوا كل واحد
/// لوحده وأي فرق بسيط في التقريب طلع، المندوب بيشوف رقمين لنفس
/// الفاتورة ومايعرفش أنهي واحد اللي اتسجّل.
///
/// بترجّع `true` من `Navigator.pop` لو المندوب أكّد.
class SaleReviewScreen extends StatelessWidget {
  final String clientName;

  /// عنوان وزرار مخصوصين — مراجعة أمر التوريد بتسميها باسمها (٢١/٨)
  final String? title;
  final String? confirmLabel;

  /// كاش / آجل — النص المعروض زي ما هو
  final String paymentLabel;

  /// ⚠️ **علم صريح مش مقارنة نص** (تدقيق ٩/٨): `paymentLabel ==
  /// L.t('cash')` كانت بتبوظ مع أي ليبل تاني (مراجعة تسليم الأمر
  /// بتبعت «Sales Order PO-1042») ومع تبديل اللغة نص الجلسة.
  final bool isCash;

  /// (اسم الصنف، الكمية بوحدتها، ليبل الوحدة، سعر السطر، الصورة)
  final List<(String, int, String, double, String?)> lines;

  final double subtotal;
  final double discount;
  final double tax;
  final double grand;

  /// سيريال الفاتورة الورقية المختومة (١٩/٨) — بيتكتب هنا فوق زرار
  /// التأكيد. `null` = الشاشة مش شاشة بيع (مراجعة تسليم أمر توريد
  /// بتستخدم نفس الودجت) فالخانة مش بتظهر أصلاً.
  final TextEditingController? paperCtrl;

  const SaleReviewScreen({
    super.key,
    required this.clientName,
    required this.paymentLabel,
    this.isCash = false,
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.grand,
    this.title,
    this.confirmLabel,
    this.paperCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final totalUnits = lines.fold<int>(0, (t, l) => t + l.$2);

    return Scaffold(
      appBar: AppBar(title: Text(title ?? L.t('review_invoice'))),
      body: Column(
        children: [
          // ⚠️ **شريط تنبيه فوق كل حاجة.** المندوب المستعجل بيدوس
          // الزرار الأزرق من غير ما يقرا — السطر ده بيقول له إن
          // اللي جاي نهائي، وبيخلّي «رجوع للتعديل» تبان كخيار.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            color: const Color(0xFFFFF6E5),
            child: Row(
              children: [
                const Icon(Icons.fact_check_outlined,
                    size: 18, color: Brand.orange),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(L.t('review_hint'),
                      style: const TextStyle(
                          fontSize: 11.5, height: 1.5, color: Brand.orange)),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
              children: [
                _clientCard(),
                const SizedBox(height: 12),
                _itemsCard(totalUnits),
                const SizedBox(height: 12),
                _totalsCard(),
              ],
            ),
          ),

          _bar(context),
        ],
      ),
    );
  }

  // ═══════════════════ العميل وطريقة الدفع ═══════════════════

  /// ⚠️ **العنوان اتشال خالص وبقى كارت متدرج** (طلب المالك ٢١/٨) —
  /// نفس لغة كارت العميل الجديدة في كل الأبلكيشن: الاسم كبير أبيض
  /// وطريقة الدفع شيب واضح، من غير سطور عنوان بتاخد نص الشاشة.
  Widget _clientCard() {
    final cash = isCash;

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        gradient: Brand.gradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(clientName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
          ),
          const SizedBox(width: 10),
          // ⚠️ طريقة الدفع بلون مختلف — دي الحاجة اللي لو غلط بتفتح
          // مديونية محدش قررها، فلازم تخطف العين في المراجعة.
          // الكاش أخضر مليان — والآجل أبيض شفاف على التدرج.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: cash
                  ? const Color(0xFF16A34A)
                  : Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(20),
              border: cash
                  ? null
                  : Border.all(color: Colors.white.withValues(alpha: .35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(cash ? Icons.payments_outlined : Icons.schedule,
                    size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Text(paymentLabel,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════ البنود ═══════════════════

  Widget _itemsCard(int totalUnits) => Container(
        decoration: BoxDecoration(
          color: Brand.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Brand.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          children: [
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    if (l.$5 != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.network(l.$5!, cacheWidth: 800,
                            width: 42,
                            height: 42,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox(width: 42, height: 42)),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.$1,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.4)),
                          const SizedBox(height: 2),
                          // ⚠️ الوحدة مكتوبة صراحةً — «3 كرتونة» غير
                          // «3 قطعة» بـ24 ضعف، والمراجعة هي آخر فرصة
                          // يشوف إنه اختار الوحدة الغلط
                          Text('${l.$2} × ${l.$3}',
                              style: const TextStyle(
                                  fontSize: 11, color: Brand.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(money(l.$4),
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            const Divider(height: 10, color: Brand.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(L.t('n_items', {'n': '${lines.length}'}),
                        style: const TextStyle(
                            fontSize: 11.5, color: Brand.muted)),
                  ),
                  Text(L.t('n_units', {'n': '$totalUnits'}),
                      style: const TextStyle(
                          fontSize: 11.5, color: Brand.muted)),
                ],
              ),
            ),
          ],
        ),
      );

  // ═══════════════════ الحساب ═══════════════════

  Widget _totalsCard() => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7FB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Brand.border),
        ),
        child: Column(
          children: [
            if (subtotal > 0) _row(L.t('before_discount'), subtotal),
            if (discount > 0)
              _row(L.t('discount'), -discount, color: Brand.royalBlue),
            if (tax > 0) _row(L.t('tax'), tax),
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
                Text(money(grand),
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

  // ═══════════════════ شريط القرار ═══════════════════

  /// ⚠️ **التأكيد أعرض والتعديل جنبه** — مش الاتنين بنفس الحجم.
  /// المراجعة اللي بتخلص بالتأكيد هي الحالة الغالبة، والتعديل
  /// استثناء؛ وتساويهم كان بيخلّي المندوب يتردد في كل فاتورة.
  Widget _bar(BuildContext context) => Container(
        // viewPadding صريح (مسح ٢١/٨)
        padding: EdgeInsets.fromLTRB(14, 12, 14, 16 + MediaQuery.viewPaddingOf(context).bottom),
        decoration: const BoxDecoration(
          color: Brand.card,
          border: Border(top: BorderSide(color: Brand.border)),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ═══ سيريال الفاتورة الورقية (١٩ أغسطس ٢٠٢٦) ═══
              // المندوب كتب فاتورة دفترية مختومة بإيده؟ يسجل سيريالها
              // هنا قبل التأكيد — بيتخزن على فاتورة السيستم للمطابقة.
              // اختياري: مش كل بيعة معاها ورقية.
              if (paperCtrl != null) ...[
                TextField(
                  controller: paperCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 30,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: L.t('paper_ref_label'),
                    hintText: '65221',
                    counterText: '',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.receipt_long_outlined),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: Brand.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(context).maybePop(false),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(L.t('back_to_edit'),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  // ⚠️ `maybePop` — دوستين سريعتين على «تأكيد» كانوا بيقفلوا
                  // المراجعة **والبيع اللي تحتها**، والفاتورة تتبعت مرتين
                  // ⚠️ **السيريال إجباري** (قرار المالك ٢١/٨): كل فاتورة
                  // سيستم لازم يقابلها ورقية مختومة برقمها — التأكيد
                  // مش بيعدي من غيره. مراجعة التوريد (`paperCtrl == null`)
                  // مالهاش دعوة بالشرط.
                  onPressed: () {
                    if (paperCtrl != null &&
                        paperCtrl!.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(L.t('paper_ref_required'))));

                      return;
                    }
                    Navigator.of(context).maybePop(true);
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(confirmLabel ?? L.t('confirm_invoice'),
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
            ],
          ),
        ),
      );
}
