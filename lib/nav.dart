import 'package:flutter/widgets.dart';

/// ═══════════════════════════════════════════════════════════════
/// وجهة الإشعار — «افتح الحاجة نفسها» (٨ أغسطس ٢٠٢٦)
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ **قبل الملف ده الإشعار كان بيفتح الرئيسية وبس.** السيرفر بيبعت
/// `data` صح ومحدش بيقراها، ومفيش `onMessageOpenedApp` ولا
/// `getInitialMessage` مكتوبين أصلاً — فالمندوب بياخد «أمر توريد
/// PO-1042 جاهز»، يدوس، ويلاقي نفسه على الرئيسية بيدوّر بإيده.
///
/// ⚠️ **الوجهة نص قصير مش مسار Flutter.** ثلاث مصادر بتكتب فيها
/// (إشعار النظام والأبلكيشن مقفول · إشعار وهو مفتوح · الضغط على
/// إشعار من القايمة)، وشاشة كل رول بتترجمها لتاب أو شاشة عندها هي.
/// لو ربطناها بمسارات `Navigator` كان كل رول محتاج مساراته، وأي
/// وجهة جديدة من السيرفر تكسر النسخ القديمة.
///
/// ⚠️ **وجهة مش معروفة = تتتجاهل** — مش كراش ومش رجوع للرئيسية
/// بالغصب. السيرفر ممكن يبعت وجهة اتضافت في نسخة أحدث.
class AppNav {
  AppNav._();

  /// الوجهة المستنية تنفيذ — شاشة الرول بتسمعها وبتصفّرها بعد ما تنفّذ.
  ///
  /// ⚠️ `ValueNotifier` مش `Stream`: الوجهة ممكن توصل **قبل** ما شاشة
  /// الرول تتبني (الأبلكيشن كان مقفول والإشعار هو اللي فتحه)، والقيمة
  /// بتفضل مستنية لحد ما حد يقراها. الستريم كان هيضيّعها.
  static final ValueNotifier<String?> pending = ValueNotifier(null);

  static void go(String? link) {
    if (link == null || link.trim().isEmpty) return;

    pending.value = link.trim();
  }

  /// بتقرا الوجهة وبتصفّرها — عشان مايتنفّذش مرتين مع أي إعادة بناء
  static String? take() {
    final v = pending.value;
    pending.value = null;

    return v;
  }

  /// نوع الوجهة: `po:12` → `po`
  static String kindOf(String link) => link.split(':').first;

  /// رقم الوجهة: `po:12` → `12`، و`null` لو مفيش رقم
  static int? idOf(String link) {
    final parts = link.split(':');

    return parts.length > 1 ? int.tryParse(parts[1]) : null;
  }
}

/// ═══════════════════════════════════════════════════════════════
/// مِكسِن استقبال الوجهة — لكل شاشة رول
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ **كان في شاشة المندوب بس**، والسواق هو أكتر واحد بياخد إشعارات
/// أوامر توريد، والبروموتر بياخد قرارات طلبات الريفيل. الاتنين كانوا
/// بيدوسوا على الإشعار والوجهة بتتحط في `AppNav.pending` ومحدش بياخدها
/// — يعني الأبلكيشن بيفتح على التاب الافتراضي، وده بالظبط اللي الملف
/// ده اتكتب يمنعه.
///
/// الاستخدام:
/// ```dart
/// class _CourierHomeState extends State<CourierHome> with NavTarget {
///   @override
///   int? tabForLink(String kind) => switch (kind) {
///     'po' => 1,
///     _ => null,
///   };
///
///   @override
///   void goToTab(int i) => setState(() => _index = i);
/// }
/// ```
mixin NavTarget<T extends StatefulWidget> on State<T> {
  /// التاب اللي يقابل نوع الوجهة — `null` = الشاشة دي مش بتعرفها
  int? tabForLink(String kind);

  /// الانتقال للتاب — الشاشة بتعرف اسم المتغير بتاعها
  void goToTab(int index);

  /// وجهة مالهاش تاب (شاشة بتتفتح فوق) — اختياري
  void openLink(String link) {}

  @override
  void initState() {
    super.initState();

    // ⚠️ **بعد أول رسمة** — الوجهة ممكن تكون وصلت والأبلكيشن مقفول
    // (`getInitialMessage`)، يعني قبل ما الشاشة دي تتبني أصلاً.
    WidgetsBinding.instance.addPostFrameCallback((_) => resolveNavTarget());

    AppNav.pending.addListener(resolveNavTarget);
  }

  @override
  void dispose() {
    AppNav.pending.removeListener(resolveNavTarget);
    super.dispose();
  }

  /// ⚠️ **وجهة مش معروفة بتتتجاهل** — مابنرجعش للرئيسية بالغصب،
  /// عشان نسخة أبلكيشن قديمة ماتوديش المستخدم مكان غلط لما السيرفر
  /// يبعت وجهة اتضافت بعدها.
  void resolveNavTarget() {
    // ⚠️ **`mounted` قبل `take()`** — `take()` بتصفّر الوجهة، فلو
    // اتنادت بعد `dispose` (كولباك ما بعد الرسمة) كانت بتاكل الوجهة
    // وترميها، والشاشة الجاية ماتلاقيش حاجة.
    if (!mounted) return;

    final link = AppNav.take();
    if (link == null) return;

    final tab = tabForLink(AppNav.kindOf(link));

    if (tab != null) {
      goToTab(tab);

      return;
    }

    openLink(link);
  }
}
