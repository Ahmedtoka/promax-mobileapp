import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../brand.dart';
import 'shared.dart';
import '../l10n.dart';
import '../prefs.dart';
import '../session.dart';
import '../version.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ⚠️ **فاضيين.** كانوا متملّيين بـ`ahmed@promax.local` و
  // `promax123` من أيام الديمو — الحساب ده مش موجود على السيستم
  // اللايف خالص، فأي حد بيفتح الأبلكيشن ويدوس دخول على طول بياخد
  // «اسم المستخدم أو الباسورد غلط» ويفتكر إن الأبلكيشن باظ.
  // ودي كانت باسورد شغّالة مكتوبة في الكود المتشحن على كل تليفون.
  final _login = TextEditingController();
  final _pass = TextEditingController();
  final _passFocus = FocusNode();
  bool _busy = false;
  bool _showPass = false;

  // ═══ تذكرني (طلب المالك ٩ أغسطس ٢٠٢٦) ═══
  //
  // ⚠️ الجلسة نفسها أصلاً بتفضل شغالة بالتوكن المحفوظ — ده **شبكة
  // أمان** للحالة الوحيدة اللي بترجع للوجين فعلاً (توكن اتلغى من
  // السيرفر): الخانات بتيجي متملية والموظف بيدوس «دخول» وخلاص.
  // شغال افتراضياً، وشيله بيمسح المحفوظ.
  bool _remember = true;
  String? _err;
  // عنوان تشخيصي فوق الرسالة — بيقول المشكلة في أنهي طبقة
  String? _errTitle;

  @override
  void initState() {
    super.initState();
    _prefill();

    // ⚠️ شبكة أمان (١١/٨): لو رجعنا للوجين بعد ما الجلسة اتطردت
    // (توكن اترفض بعد دخول ناجح مثلاً)، الشاشة دي instance جديدة
    // ورسالة الخطأ اللي على القديمة ضاعت — فبنلقطها من Session
    // ونعرضها هنا بدل ما الموظف يتقفل في صمت.
    final leftover = Session.I.error;
    if (leftover != null && leftover.isNotEmpty) {
      _err = leftover;
      _errTitle = null;
      Session.I.error = null;
    }
  }

  /// تعبئة آخر بيانات دخول محفوظة — عشان «يدوس لوجين على طول»
  Future<void> _prefill() async {
    final savedLogin = await Prefs.get('saved_login');
    final savedPass = await Prefs.get('saved_pass');

    if (!mounted || savedLogin == null || savedLogin.isEmpty) return;

    setState(() {
      _login.text = savedLogin;
      _pass.text = savedPass ?? '';
      _remember = true;
    });
  }

  @override
  void dispose() {
    _login.dispose();
    _pass.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  /// ⚠️ **الكيبورد العربي بيكتب ١٢٣ مش 123** (بوليش 2026-08-07).
  /// كود الموظف والباسوردات متسجلين بأرقام لاتيني على السيرفر —
  /// المندوب بيكتب كوده بكيبورده العربي واللوجين بيرفض وهو مش فاهم
  /// «أنا كاتب الكود صح!». التطبيع بيحوّل الأرقام العربي والفارسي
  /// قبل الإرسال، وبيشيل أي مسافات اتلزقت من النسخ.
  ///
  /// ⚠️ **النطاقات مكتوبة بأكواد يونيكود مش بالحروف نفسها.** دول
  /// نطاقين أرقام في ريجيكس — **مش نص معروض** — فمالهمش مكان في
  /// `l10n.dart`، وحارس «مفيش عربي متبتّت» بيشوف الحرف مايفرقش.
  /// `٠-٩` أرقام عربي-هندي و`۰-۹` فارسي.
  static String _latinize(String s) => s
      .replaceAllMapped(
          RegExp('[\u0660-\u0669]'), (m) => '${m[0]!.codeUnitAt(0) - 0x0660}')
      .replaceAllMapped(
          RegExp('[\u06F0-\u06F9]'), (m) => '${m[0]!.codeUnitAt(0) - 0x06F0}');

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await Session.I.login(
        _latinize(_login.text).replaceAll(RegExp(r'\s+'), ''),
        _latinize(_pass.text),
      );

      // ⚠️ **بعد نجاح الدخول بس** — بيانات غلط ماتتحفظش. والمسح
      // لما «تذكرني» متشال عشان اللي شاله قاصد إن الجهاز مشترك.
      if (_remember) {
        await Prefs.set('saved_login', _login.text.trim());
        await Prefs.set('saved_pass', _pass.text);
      } else {
        await Prefs.remove('saved_login');
        await Prefs.remove('saved_pass');
      }
    } catch (e) {
      // ⚠️ **التشخيص قبل الرسالة.** «اسم المستخدم غلط» و«السيرفر مش
      // بيرد» شكلهم واحد لليوزر لو الرسالة عامة — العنوان بيقول
      // المشكلة فين: البيانات، الصلاحية، السيرفر، ولا الاتصال.
      final status = e is ApiException ? e.status : -1;
      setState(() {
        _err = e.toString();
        _errTitle = switch (status) {
          0 => L.t('err_network'),
          401 => L.t('err_credentials'),
          403 => L.t('err_forbidden'),
          422 => L.t('err_validation'),
          429 => L.t('err_throttled'),
          >= 500 => L.t('err_server'),
          _ => null,
        };
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// ليبل فوق الخانة — **مش بلايس هولدر**.
  ///
  /// ⚠️ البلايس هولدر بيختفي أول ما تكتب حرف، فاليوزر اللي بيراجع
  /// اللي كتبه مابيعرفش الخانة دي كانت بتطلب إيه. الليبل الظاهر
  /// قاعدة أساسية في فورمات الدخول.
  Widget _label(String text) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Brand.muted,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: Brand.paper,
      // ⚠️ **`resizeToAvoidBottomInset` مسيبة true والمحتوى بيسكرول** —
      // الكيبورد على شاشة صغيرة كان بيغطي زرار الدخول ومحدش يوصله.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: bottomInset > 0 ? 16 : 0),
                child: Column(
                  children: [
                    // ═══ ترويسة الهوية — اللوجو لوحده، من غير أي تحكّم ═══
                    // ⚠️ **زرار اللغة اتشال من على البانر** (بوليش 2026-08-07).
                    // كان قاعد فوق التدرج جنب اللوجو، فبيتحوّل لعنصر
                    // تحكّم على هوية الشركة — وبصرياً بيزاحم اللوجو
                    // ويكسر هدوء الترويسة. مكانه دلوقتي تحت في الفوتر
                    // بعيد تماماً، وهو المكان اللي عين اليوزر بتروحه
                    // لما يدوّر على إعداد مش على أكشن أساسي.
                    SizedBox(
                      height: 208,
                      width: double.infinity,
                      child: BrandBackdrop(
                        boltOpacity: .12,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 62),
                              child: Image.asset(
                                'assets/brand/logo/logo-h-white.png',
                                errorBuilder: (_, __, ___) => const Text(
                                  'PROMAX',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'FOOD INDUSTRIES',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .68),
                                fontSize: 9.5,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ═══ كارت الدخول — بيركب على البانر ═══
                    // التداخل بيربط الترويسة بالفورم بصرياً وبيدي
                    // الصفحة عمق، وهو النمط المعتاد في شاشات الدخول.
                    Transform.translate(
                      offset: const Offset(0, -26),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                          decoration: BoxDecoration(
                            color: Brand.card,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Brand.border),
                            boxShadow: [
                              BoxShadow(
                                color: Brand.ink.withValues(alpha: .07),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [

                // ═══ ترحيب — بيقول لليوزر هو فين وبيعمل إيه ═══
                Text(
                  L.t('login_welcome'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Brand.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  L.t('login_sub'),
                  style: const TextStyle(fontSize: 12.5, color: Brand.muted),
                ),
                const SizedBox(height: 18),

                if (_err != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Brand.red.withValues(alpha: .35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errTitle != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('⛔ $_errTitle',
                                style: const TextStyle(
                                    color: Brand.red,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900)),
                          ),
                        Text(_err!,
                            style: const TextStyle(
                                color: Brand.red,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),

                _label(L.t('email_or_code')),
                TextField(
                  controller: _login,
                  // إيميل أو كود — من غير تصحيح تلقائي بيغيّر المكتوب
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _passFocus.requestFocus(),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                _label(L.t('password')),
                TextField(
                  controller: _pass,
                  focusNode: _passFocus,
                  obscureText: !_showPass,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    // 👁 إظهار الباسورد — نص اللوجينات الفاشلة سببها
                    // حرف متكتب غلط ومحدش شايفه
                    suffixIcon: IconButton(
                      // ⚠️ ليبل للقارئ الشاشي — زرار بأيقونة لوحده
                      // مبيتقريش، والمكفوف مش هيعرف هو بيعمل إيه
                      tooltip: L.t('password'),
                      icon: Icon(
                        _showPass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: Brand.muted,
                      ),
                      onPressed: () => setState(() => _showPass = !_showPass),
                    ),
                  ),
                ),
                // ⚠️ **زرار «عنوان السيرفر» اتشال.** كان لمرحلة التطوير —
                // على تليفون مندوب هو باب لكتابة عنوان غلط والأبلكيشن
                // يفضل «مافيش سيرفر» ومحدش فاهم ليه. العنوان اللايف
                // متثبّت في `Api.liveBase`، والتطوير المحلي بياخد
                // `10.0.2.2` أوتوماتيك في وضع الديبج بس.
                const SizedBox(height: 8),

                // ═══ تذكرني — الخانات تيجي متملية المرة الجاية ═══
                InkWell(
                  onTap: () => setState(() => _remember = !_remember),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _remember,
                            onChanged: (v) =>
                                setState(() => _remember = v ?? true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(L.t('remember_me'),
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white))
                      : Text(L.t('login'), style: const TextStyle(fontSize: 17)),
                ),

                // ⚠️ **بوكس «حسابات تجريبية» اتشال خالص.**
                // كان بيعرض 6 إيميلات جاهزة بضغطة واحدة — وكلها
                // `@promax.local` من الديمو، يعني مش موجودة أصلاً
                // على السيستم اللايف: اللي بيدوس عليها بياخد «اسم
                // المستخدم غلط» ويفتكر إن الأبلكيشن باظ.
                // وعلى سيستم شغّال، عرض إيميلات موظفين لأي حد
                // بيفتح الشاشة نص بيانات الدخول متسلّمة.
                //
                // ⚠️ **وممنوع ترجع تاني.** أي «دخول سريع» على
                // شاشة لوجين حقيقية هو باب خلفي بشكل مختلف.
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ═══ الفوتر — بعيد تماماً عن البانر ═══
            // ⚠️ **مكان زرار اللغة الجديد.** إعداد مش أكشن، فمكانه
            // آخر الشاشة مع باقي معلومات النظام — بيملا الفراغ اللي
            // كان تحت الفورم، وبيبعد عن الهوية اللي فوق.
            Padding(
              padding: EdgeInsets.fromLTRB(
                20, 4, 20, 14 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    L.t('login_lang_hint'),
                    style: const TextStyle(fontSize: 10.5, color: Brand.muted),
                  ),
                  const SizedBox(height: 6),
                  // ⚠️ اللون هنا داكن مش أبيض — الخلفية بقت فاتحة،
                  // والأبيض على الرمادي الفاتح كان هيختفي تماماً.
                  const LangSwitch(color: Brand.muted),
                  const SizedBox(height: 14),
                  Container(height: 1, color: Brand.border),
                  const SizedBox(height: 10),
                  Text(
                    L.t('login_footer'),
                    style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                      color: Brand.muted.withValues(alpha: .75),
                    ),
                  ),
                  // ⚠️ **رقم الإصدار ظاهر دايماً — مش في الديبج بس**
                  // (طلب المالك 2026-08-07). أول سؤال في أي مشكلة من
                  // الشارع هو «انت على أنهي نسخة؟» — والمندوب لازم
                  // يلاقي الإجابة قدامه من غير ما يدوّر في الإعدادات.
                  const SizedBox(height: 6),
                  Text(
                    'Application Version $appVersion',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .3,
                      color: Brand.muted.withValues(alpha: .9),
                    ),
                  ),
                  // ⚠️ في الديبج بس — عشان وانت بتجرب على الإيموليتور
                  // تعرف فوراً الأبلكيشن بيكلم مين (المحلي ولا اللايف).
                  // مكانه الفوتر مش فوق زرار الدخول: سطر تقني جنب
                  // الأكشن الأساسي بيوحي إنه جزء من الفلو.
                  if (kDebugMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'API: ${Api.baseUrl}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9.5, color: Colors.grey.shade500),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
