import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'brand.dart';
import 'l10n.dart';
import 'models.dart';
import 'push.dart';
import 'nav.dart';
import 'session.dart';
import 'updater.dart';
import 'screens/office_home.dart';
import 'screens/login.dart';
import 'screens/rep_home.dart';
import 'screens/courier_home.dart';
import 'screens/manager_home.dart';
import 'screens/promoter_home.dart';
import 'screens/splash.dart';
import 'screens/attendance.dart';
import 'screens/warehouse_visit.dart';
import 'screens/suspended.dart';
import 'screens/update_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ═══ إشعارات فاير بيز ═══
  // ⚠️ **قبل `runApp` وبـ`await`.** الإيزوليت اللي بيستقبل الرسايل
  // والأبلكيشن مقفول لازم يلاقي فاير بيز متسجّلة وقت ما أندرويد
  // يصحّي التطبيق — والتسجيل ده بيحصل هنا. لو اتأخر لبعد ما الشاشة
  // تفتح، أول إشعار بييجي والتليفون مقفول بيضيع.
  //
  // بترجع بهدوء لو مفيش Google Play Services — الأبلكيشن بيكمّل عادي.
  await Push.init();

  // ═══ فحص الإصدار ═══
  // ⚠️ **قبل `runApp` وبـ`await`** — عشان `Root` تلاقي النتيجة جاهزة
  // من أول رسمة. لو اتنادت بعدها، المندوب بنسخة مرفوضة كان هيشوف
  // شاشة اللوجين لثانية ويقدر يبدأ يكتب قبل ما البوابة تقفل.
  //
  // بترجع بهدوء لو الشبكة واقعة — مفيش نت مايمنعش الشغل.
  await Updater.check();

  runApp(const PromaxApp());

  // ⚠️ بعد `runApp` — بيقرا توكن الجلسة المتخزن ويدخل بيه على طول.
  // اللوجين بيفضل شغال لحد ما اليوزر يدوس خروج بنفسه.
  Session.I.restore();
}

// ألوان الرولز — كلها من باليت الهوية الرسمية (Brand Guidelines 2024).
// الأسماء القديمة متسيبة عشان الشاشات القديمة ما تكسرش.
const kGreen = Brand.royalBlue;   // سيلز إيجينت
const kBlue = Brand.blue500;      // سواق
const kPurple = Brand.purpleHeart; // مدير
const kTeal = Brand.purple500;    // بروموتر
const kGold = Brand.yellow;
const kInk = Brand.ink;

class PromaxApp extends StatelessWidget {
  const PromaxApp({super.key});

  /// ⚠️ **مفتاح النافيجيتور — بوابة الحضور محتاجاه.** البوب أب
  /// بيترسم في `builder` بتاعة `MaterialApp`، وده **فوق** الـ
  /// `Navigator` — يعني `Navigator.of(context)` هناك بترمي. المفتاح
  /// ده هو الطريقة الوحيدة للتنقل من المكان ده.
  static final navKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // ⚠️ **MaterialApp لازم يعيد البناء مع تغيير اللغة.** كان
    // StatelessWidget ساكن، فالـDirectionality اللي في الـbuilder
    // بتتحسب مرة واحدة بالافتراضي (en/LTR) وتفضل شمال حتى والواجهة
    // عربي — التابات كانت بتبدأ من الشمال والصفوف كلها مقلوبة.
    // Session بينادي notifyListeners بعد ما اللغة تيجي من السيرفر
    // وبعد كل تبديل — فالاتجاه والفونت بيتقلبوا فوراً.
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) => MaterialApp(
        // ⚠️ **المفتاح على اللغة — ده اللي بيخلّي التبديل يشتغل فعلاً**
        // (إصلاح 2026-08-07). من غيره فلاتر بيعيد بناء الـWidgets بس
        // وبيحتفظ بالـElements والـStates القديمة، فالشاشات اللي
        // كانت مبنية بتفضل بنصوصها القديمة: التابات تحت (بتترسم في
        // نفس البناء) بتطلع إنجليزي والهيدر والكروت (State محفوظة)
        // يفضلوا عربي — واجهة نص عربي ونص إنجليزي.
        //
        // تغيير المفتاح بيرمي شجرة العناصر كلها ويبنيها من الأول،
        // فكل `L.t` في الأبلكيشن بيتقرا تاني باللغة الجديدة. وده
        // بيصفّر ستاك التنقّل كمان — مقصود: الشاشة اللي جوّاها داتا
        // سيرفر باللغة القديمة بتترسم من جديد نضيفة.
        key: ValueKey(L.locale),
        navigatorKey: navKey,
        title: 'PROMAX',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brand.royalBlue),
        // ⚠️ الاتجاه بيتبع اللغة مش متبتّت RTL. الإنجليزي في واجهة
        // RTL بيخلّي علامات الترقيم والأرقام تقفز لآخر السطر ويبان غلط.
        builder: (context, child) => Directionality(
          textDirection: L.dir,
          // ⚠️ **التنبيه لازم يبقى فوق كل الشاشات مش جوه واحدة.**
          // الإشعار بيوصل والمندوب ممكن يكون في أي تاب أو جوه شاشة
          // بيع — لو البانر مربوط بشاشة، الإشعار بيضيع.
          child: _IncomingBanner(child: _AttendanceGate(child: child!)),
        ),
        home: const Root(),
      ),
    );
  }

  static ThemeData _theme(Color seed) => ThemeData(
        useMaterial3: true,
        // الفونت بيتبع اللغة، والتاني fallback للحروف المختلطة
        fontFamily: L.isRtl ? Brand.fontAr : Brand.fontEn,
        fontFamilyFallback: const [Brand.fontEn, Brand.fontAr],
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          primary: seed,
          secondary: Brand.purple500,
        ),
        scaffoldBackgroundColor: Brand.paper,
        appBarTheme: AppBarTheme(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            fontFamily: Brand.fontAr,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Brand.card,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Brand.border),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: seed,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFamily: Brand.fontAr,
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Brand.card,
          indicatorColor: seed.withValues(alpha: .13),
          elevation: 3,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        chipTheme: ChipThemeData(
          side: const BorderSide(color: Brand.border),
          selectedColor: seed.withValues(alpha: .14),
        ),
        dividerColor: Brand.border,
        // ═══ بوليش 2026-08-07 — توحيد على مستوى الثيم ═══
        // كل سبينر في الأبلكيشن بياخد لون رول الشاشة أوتوماتيك —
        // بدل ما كل شاشة تفتكر تحدد اللون بنفسها
        progressIndicatorTheme: ProgressIndicatorThemeData(color: seed),
        // الإنبتس كلها بنفس الشكل: حواف مدورة وتعبئة خفيفة وفوكس
        // بلون الرول — من غير ما نعدل 30 شاشة
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Brand.card,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Brand.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Brand.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: seed, width: 1.6),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        dialogTheme: DialogThemeData(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          showDragHandle: true,
        ),
      );
}

/// بيوجّه حسب حالة الدخول والرول
class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    // ⚠️ **تلات مستمعين فوق الشجرة كلها.** الحظر والتحديث الإجباري
    // مش حالات شاشة — دول قرارات إدارية بتنزل والمندوب في نص شغله،
    // ولازم تغطّي أي شاشة هو واقف عليها.
    return ListenableBuilder(
      listenable: Listenable.merge([
        Session.I,
        Api.suspended,
        Updater.forcedNow,
      ]),
      builder: (context, _) {
        final s = Session.I;

        // ⚠️ **الحظر قبل كل حاجة — حتى قبل التحديث.** الموظف الموقوف
        // مالوش لازمة يحدّث نسخة مش هيستخدمها، وشاشة تحديث قدام
        // موقوف بتخلّيه يفتكر إن المشكلة تقنية ويفضل يحاول.
        final blockedMsg = Api.suspended.value;
        if (blockedMsg != null) return SuspendedScreen(message: blockedMsg);

        // ⚠️ **بوابة التحديث قبل السبلاش واللوجين.** النسخة اللي
        // الأدمن قال إنها ماينفعش تشتغل ماينفعش تشوف أي شاشة أصلاً،
        // ولا حتى تسجّل دخول: لو دخلت، هتبدأ تبعت داتا بنسخة
        // السيرفر رافضها.
        //
        // ⚠️ و`forcedNow` بتغطّي الحالة اللي النبضة اكتشفتها **وسط
        // الشغل** — `Updater.info` بتكون لسه محمّلة من فتح الأبلكيشن
        // وبتقول إن كله تمام.
        final u = Updater.info;
        if (u != null && (u.forced || Updater.forcedNow.value)) {
          return UpdateGate(info: u);
        }

        // السبلاش بيفضل ظاهر وإحنا بنسترجع **الجلسة المحفوظة** بس.
        // ⚠️ (إصلاح ١١/٨): كان على `loading` العامة — واللوجين بيرفعها —
        // فأول ما تدوس «دخول» شاشة اللوجين بتتشال ويظهر السبلاش، ولو
        // فشل بترجع شاشة لوجين **جديدة** ورسالة الخطأ ضاعت مع القديمة:
        // «بيحمّل ويرجع للوجين من غير رسالة». دلوقتي اللوجين بيفضل
        // مكانه بسبينر زراره ورسالة خطئه.
        if (s.restoring && s.user == null) return const SplashScreen();
        if (s.user == null) return const LoginScreen();

        // كل رول وله لونه وشاشاته
        //
        // ⚠️ **الـ`_` كان بيدي `RepHome` لأي رول مش معروف.** يعني أول
        // ما اتضاف المحاسب وأمين المخزن، الاتنين هبطوا على شاشة السيلز
        // إيجينت بزرار «بيع» وعهدة وتشيك إن — ومحاسب بيدوس «بيع»
        // بيحاول يعمل فاتورة من عهدة مش موجودة.
        // دلوقتي كل رول مكتوب صراحةً، والمجهول بياخد شاشة بتقوله
        // «الرول ده مالوش شاشة» بدل ما يعمل حاجة غلط.
        final Widget home = switch (s.user!.role) {
          'sales_agent' => const RepHome(),
          'driver' => const CourierHome(),
          'promoter' => const PromoterHome(),
          'manager' || 'admin' => const ManagerHome(),
          'accountant' || 'warehouse_keeper' => const OfficeHome(),
          _ => const UnknownRoleScreen(),
        };
        final color = Brand.forRole(s.user!.role);

        return Theme(data: PromaxApp._theme(color), child: home);
      },
    );
  }
}

/// شاشة تحميل / خطأ مشتركة
class Loader extends StatelessWidget {
  final String? error;
  final VoidCallback? onRetry;
  const Loader({super.key, this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (error == null) {
      // لودينج موحد: سبينر بلون الرول (من الثيم) + «بيحمّل...» —
      // سبينر صامت لوحده بيخلي المندوب يفتكر الشاشة هنجت
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(L.t('loading'),
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Brand.muted)),
          ],
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 44, color: Colors.grey),
            const SizedBox(height: 12),
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (onRetry != null)
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(L.t('retry')),
              ),
          ],
        ),
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════
/// بانر الإشعار الوارد — بيطلع من فوق فوق أي شاشة
/// ═══════════════════════════════════════════════════════════
///
/// ⚠️ **ده بديل مؤقت للبوش نوتفيكيشن.** الفاير بيز لسه ماتظبطتش،
/// فالإشعار كان بيتحط في القايمة والمندوب مايعرفش غير لما يفتحها.
/// دلوقتي أول ما النبضة تلاقي إشعار جديد، البانر ده بيتزحلق من فوق
/// لخمس ثواني. لما البوش يشتغل، ده يفضل مكانه — البوش مابيبانش
/// والأبلكيشن مفتوح أصلاً.
class _IncomingBanner extends StatefulWidget {
  final Widget child;

  const _IncomingBanner({required this.child});

  @override
  State<_IncomingBanner> createState() => _IncomingBannerState();
}

class _IncomingBannerState extends State<_IncomingBanner> {
  AppNotification? _n;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    Session.I.incoming.addListener(_onIncoming);
  }

  @override
  void dispose() {
    Session.I.incoming.removeListener(_onIncoming);
    _hide?.cancel();
    super.dispose();
  }

  void _onIncoming() {
    final n = Session.I.incoming.value;
    if (n == null || !mounted) return;

    setState(() => _n = n);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _n = null);
    });
  }

  /// كارت التنبيه.
  ///
  /// ⚠️ **أبيض مرفوع بظل — مش أزرق** (إصلاح 2026-08-07). كان بلون
  /// البراند نفسه، فلما بيطلع فوق الآبار الأزرق بيبقى أزرق على أزرق
  /// ومحدش واخد باله إن فيه حاجة ظهرت أصلاً.
  ///
  /// قاعدة عامة: **التنبيه المؤقت لازم يبان إنه طبقة فوق الشاشة**،
  /// مش جزء منها — سطح فاتح + ظل حقيقي + حد رفيع. اللون بيتحط في
  /// الشريط الجانبي والأيقونة بس، فيدّي المعنى (أزرق = تمام، أحمر =
  /// مشكلة) من غير ما ياكل التباين.
  Widget _card(AppNotification n) {
    final accent = n.isGood ? Brand.royalBlue : Brand.red;
    final tint = n.isGood ? Brand.blue050 : const Color(0xFFFDECEC);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Brand.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Brand.border),
          boxShadow: [
            // ظل قوي ومتّجه لتحت — ده اللي بيقول للعين «ده فوق الشاشة»
            BoxShadow(
              color: Brand.ink.withValues(alpha: .22),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        // ⚠️ `clipBehavior` مهم: الشريط الجانبي الملوّن لازم يتقص
        // على الزوايا المدوّرة وإلا بيطلع مربع من تحت الحد
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            // ⚠️ **الضغط بيودّي للحاجة نفسها.** كان بيقفل البانر وبس
            // — يعني الإشعار بيقول «أمر جاهز» والمندوب لازم يدوّر
            // عليه بإيده في التبويبات.
            onTap: () {
              final link = n.link;
              setState(() => _n = null);
              AppNav.go(link);
            },
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // الشريط الملوّن — هوية اللون من غير ما يغرق الكارت
                  Container(width: 5, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: tint,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              n.isGood
                                  ? Icons.notifications_active
                                  : Icons.warning_amber_rounded,
                              color: accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Brand.text,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13.5,
                                    height: 1.3,
                                  ),
                                ),
                                if (n.body.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    n.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Brand.muted,
                                      fontSize: 11.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // ⚠️ 40×40 مش 18: الأيقونة صغيرة بس مساحة
                          // اللمس لازم توصل الحد الأدنى (44dp تقريباً)
                          // وإلا المندوب بإيد كبيرة مش هيقفله
                          SizedBox(
                            width: 40,
                            height: 40,
                            // ⚠️ **من غير `tooltip` عن قصد.** الويدجت
                            // دي بترسم في `MaterialApp.builder` — يعني
                            // **فوق** الـ`Navigator`، واللي بيوفّر
                            // الـ`Overlay` هو الـ`Navigator`. أي
                            // `Tooltip` هنا بيرمي «No Overlay widget
                            // found» ويرسم مربع أحمر مكان الزرار
                            // (اتشاف على الشاشة 2026-08-08).
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              icon: const Icon(Icons.close,
                                  color: Brand.muted),
                              onPressed: () => setState(() => _n = null),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = _n;

    return Stack(
      children: [
        widget.child,
        // ⚠️ `IgnorePointer` لما مفيش بانر — الستاك بيغطي الشاشة
        // كلها، ومن غيره كل الدوسات كانت هتتاكل
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedSlide(
            offset: n == null ? const Offset(0, -1.4) : Offset.zero,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: IgnorePointer(
              ignoring: n == null,
              child: n == null
                  ? const SizedBox(height: 1, width: double.infinity)
                  : SafeArea(bottom: false, child: _card(n)),
            ),
          ),
        ),
      ],
    );
  }
}


/// ═══════════════════════════════════════════════════════════════
/// بوابة الحضور — بوب أب لما أي أكشن يترفض (2026-08-08)
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ **نقطة واحدة لكل الشاشات.** السيرفر بيرد `423` على أي أكشن
/// قبل تسجيل الحضور، و`Api.blocked` بيتبلّغ من `_decode`. بدل ما
/// كل شاشة تمسك الحالة دي وتعرض رسالة بشكل مختلف، الويدجت دي فوق
/// الأبلكيشن كله وبتعرض نفس البوب أب مهما كان الأكشن.
class _AttendanceGate extends StatefulWidget {
  final Widget child;

  const _AttendanceGate({required this.child});

  @override
  State<_AttendanceGate> createState() => _AttendanceGateState();
}

class _AttendanceGateState extends State<_AttendanceGate> {
  /// ⚠️ بيمنع بوب أبين فوق بعض لو المندوب دوس مرتين بسرعة
  bool _open = false;

  /// ⚠️ **فترة هدوء بعد ما المندوب يقفل البوب أب** (إصلاح 2026-08-08).
  ///
  /// اللي كان بيحصل: المندوب يدوس «إلغاء»، يرجع للشاشة، الشاشة تعمل
  /// رفرش أو البلس يشتغل، السيرفر يرد 423 تاني، والبوب أب يفتح تاني
  /// **على طول**. يعني مفيش طريقة يخرج منه غير إنه يسجّل حضور —
  /// وهو ساعتها كان لسه بيقرا الرسالة.
  ///
  /// دلوقتي بعد الإلغاء بنسكت 30 ثانية. الأكشن اللي هو بيحاول يعمله
  /// لسه بيترفض من السيرفر (الحارس مكانه) — بس الشاشة بتسيبه يتحرك.
  DateTime? _snoozeAtt;

  /// ونفس الفكرة لحارس المخزن — منفصل عن الحضور
  DateTime? _snoozeWh;

  @override
  void initState() {
    super.initState();
    Api.blocked.addListener(_onBlocked);
  }

  @override
  void dispose() {
    Api.blocked.removeListener(_onBlocked);
    super.dispose();
  }

  /// ⚠️ **شاشة واحدة مفتوحة بس** (إصلاح 2026-08-08). البوابة كانت
  /// بتعمل `push` كل مرة من غير ما تسأل — والموظف اللي رد عليه
  /// السيرفر 423 مرتين كان بيلاقي **شاشتين حضور فوق بعض**، يقفل
  /// واحدة يلاقي التانية تحتها ويفتكر الأبلكيشن علّق.
  static bool _screenOpen = false;

  void _onBlocked() {
    final msg = Api.blocked.value;
    if (msg == null || _open) return;

    // ⚠️ **بنفضّي الإشارة أول حاجة** — قبل أي `return` تحت. لو سبناها
    // مليانة، أول مرة الشروط تسمح البوب أب بيفتح على رسالة قديمة من
    // أكشن المندوب نسيه خالص.
    Api.blocked.value = null;

    // ⚠️ **`code` بيفرّق بين حارسين مختلفين** (2026-08-08): الحضور
    // (`attendance_required`) ودخول المخزن (`warehouse_required`).
    // الاتنين بيردّوا 423، والبوابة كانت عاملاهم واحد — فاللي واقف
    // في مخزن المعادي عايز يستلم عهدته كان بياخد بوب أب «سجّل
    // حضورك» ويتودّي لشاشة الحضور وهو مسجّل من الصبح، ويفضل يلف
    // في نفس اللفة من غير ما يستلم. ده كان أكتر بلاغ متكرر.
    final wh = Api.blockedCode.value == 'warehouse_required';

    // ⚠️ **الحالة الحالية بتلغي البوب أب.** الرد 423 ممكن يكون من
    // ريكوست اتبعت قبل ما يسجّل ورجع بعده — والبوب أب ساعتها
    // بيطلب منه حاجة عاملها فعلاً.
    if (wh ? Session.I.insideWarehouse : Session.I.att.working) return;

    // ⚠️ **هدوء لكل حارس لوحده.** لو الاتنين بيشاركوا نفس التايمر،
    // إغلاق بوب أب المخزن كان بيخرّس بوب أب الحضور 30 ثانية كمان
    // وهو سبب مختلف تماماً.
    final snooze = wh ? _snoozeWh : _snoozeAtt;
    if (snooze != null && DateTime.now().isBefore(snooze)) return;

    final ctx = PromaxApp.navKey.currentContext;
    if (ctx == null) return;

    _open = true;

    showDialog<void>(
      context: ctx,
      // ⚠️ **الضغط بره بيقفل.** كان `false` ضمنياً في نسخة، والمندوب
      // اللي مش عايز يسجّل دلوقتي ماكانش عنده أي مخرج غير الزرار.
      barrierDismissible: true,
      builder: (d) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (wh ? Brand.royalBlue : Brand.orange)
                    .withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(wh ? Icons.warehouse : Icons.schedule,
                  color: wh ? Brand.royalBlue : Brand.orange, size: 22),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(L.t(wh ? 'wh_required' : 'att_required'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ),
            // ⚠️ **علامة X ظاهرة.** «إلغاء» كنص جنب زرار ملوّن بتتقري
            // كأنها إلغاء **العملية** مش إغلاق الرسالة — والمندوب
            // بيتردد يدوسها. الـX مالهاش معنى تاني.
            IconButton(
              onPressed: () => Navigator.pop(d),
              icon: const Icon(Icons.close, size: 20),
              color: Brand.muted,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        content: Text(
          msg.isEmpty
              ? L.t(wh ? 'wh_required_hint' : 'att_required_hint')
              : msg,
          style: const TextStyle(fontSize: 13, height: 1.65, color: Brand.muted),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: wh ? Brand.royalBlue : Brand.green,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(d);
                _openScreen(ctx, wh);
              },
              icon: Icon(wh ? Icons.warehouse : Icons.login, size: 19),
              label: Text(L.t(wh ? 'wh_go' : 'att_go'),
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    ).whenComplete(() {
      _open = false;

      // ⚠️ الهدوء بيتحسب من لحظة القفل — سواء قفل بالـX أو بالضغط
      // بره أو رجع من الشاشة من غير ما يعمل اللي عليه.
      final quiet = DateTime.now().add(const Duration(seconds: 30));
      if (wh) {
        if (!Session.I.insideWarehouse) _snoozeWh = quiet;
      } else {
        if (!Session.I.att.working) _snoozeAtt = quiet;
      }
    });
  }

  /// فتح الشاشة المطلوبة — مرة واحدة مهما اتنده عليها
  void _openScreen(BuildContext ctx, bool wh) {
    if (_screenOpen) return;
    _screenOpen = true;

    Navigator.of(ctx)
        .push(MaterialPageRoute(
            builder: (_) =>
                wh ? const WarehouseVisitScreen() : const AttendanceScreen()))
        .whenComplete(() => _screenOpen = false);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
