import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'api.dart';
import 'version.dart';
import 'updater.dart';
import 'attendance.dart';
import 'l10n.dart';
import 'locator.dart';
import 'models.dart';
import 'prefs.dart';
import 'pick_models.dart';
import 'promoter_models.dart';
import 'push.dart';

/// حالة الأبلكيشن — كلها بتيجي من الـ API
class Session extends ChangeNotifier {
  static final Session I = Session._();
  Session._();

  AppUser? user;
  Custody custody = Custody.empty();
  List<Zone> zones = [];
  List<PurchaseOrder> pos = [];
  List<TrackEvent> events = [];
  List<AppNotification> notifications = [];
  List<ClientRequestRow> requests = [];
  TodayStats today = TodayStats.empty();

  /// خط سير النهارده — مرتّب زي ما المدير حطه
  List<JourneyStop> journey = [];
  JourneySummary journeySummary = JourneySummary.empty();

  /// ═══ الحضور والانصراف — HR (2026-08-08) ═══
  ///
  /// ⚠️ **بييجي مع البوت ستراب** فالشاشة بتعرف الحالة من أول رسمة.
  /// الافتراضي `off` — الأبلكيشن بيفترض إن الموظف مش حاضر لحد ما
  /// السيرفر يقول العكس.
  Attendance att = Attendance.empty();

  /// ═══ زيارة المخزن المفتوحة — إذن الاستلام (2026-08-08) ═══
  ///
  /// ⚠️ **مستقلة تماماً عن `att`.** الحضور بيقول «شغال النهارده»،
  /// ودي بتقول «واقف جوه المخزن دلوقتي». خلطهم كان بيخلّي المندوب
  /// المسجّل حضور يفتكر إنه يقدر يستلم — والعكس.
  WarehouseStop? whStop;

  /// المخازن المتاحة للدخول — بتيجي مع البوت ستراب
  List<WarehouseOption> warehouses = [];

  /// سامري المخزن النهارده — استلم كام وقعد قد إيه
  WarehouseToday whToday = const WarehouseToday.empty();

  bool get insideWarehouse => whStop != null;

  /// ═══ الزيارة المفتوحة من السيرفر — أياً كان يومها (١١/٨) ═══
  ///
  /// ⚠️ **مصدر الحقيقة بدل مسح القوايم.** `openVisitClient()` بتدور
  /// في زونز وخطة **النهارده** — فزيارة اتنست من يوم قديم كانت
  /// «مخفية»: البانر مش بيظهر والسيرفر بيرفض التشيك إن والمندوب
  /// محتار (حالة «هيد باديل»). دول بييجوا من `open_visit` في
  /// البوت ستراب ودايماً صح.
  int? openVisitId;
  int? openVisitClientId;
  String? openVisitName;

  void _readOpenVisit(dynamic raw) {
    if (raw is Map) {
      openVisitId = raw['visit_id'];
      openVisitClientId = raw['client_id'];
      openVisitName = raw['client']?.toString();
    } else {
      openVisitId = null;
      openVisitClientId = null;
      openVisitName = null;
    }
  }

  /// تشيك أوت مباشر من الزيارة المفتوحة — للبانر لما العميل مش في
  /// قوايم النهارده ومفيش شاشة نوديه لها
  Future<String?> checkOutOpenVisit() async {
    final id = openVisitId;
    if (id == null) return null;

    try {
      final pos = await Locator.get();
      await Api.I.post('/visits/$id/check-out', {'lat': pos?.$1, 'lng': pos?.$2});
      await refresh();

      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  /// أوامر التجهيز اللي المخزن جهّزها للمندوب/السواق
  List<PickOrder> picks = [];
  int readyPicks = 0;

  bool loading = false;
  String? error;

  /// لغة اتاختارت من شاشة اللوجين (قبل ما يبقى فيه توكن) —
  /// بتتحفظ على اليوزر في السيرفر أول ما يدخل
  String? _pendingLocale;

  // ═══════════════════════════════════════════════════════════
  //  المزامنة اللايف (2026-08-07)
  // ═══════════════════════════════════════════════════════════
  //
  // ⚠️ **المشكلة اللي بتحلها:** المندوب بيستنى عهدة أو أمر توريد،
  // والمدير بينزّله من الداشبورد — والأبلكيشن مكانش بيعرف غير لما
  // المندوب يقفل ويفتح أو يسحب لتحت. يعني شغل جاهز وقاعد مستني
  // حد يعمل رفرش بإيده.
  //
  // ⚠️ **بولينج مش سوكيت.** السوكيت محتاج باكدج وسيرفر تاني، وسياسة
  // المشروع إن الاعتماديات ثابتة. `/bootstrap` كويري خفيفة والفاصل
  // 45 ثانية — الحمل مقبول والمندوب بيلاقي الشغل قدامه لوحده.
  //
  // ⚠️ **بيقف لما الأبلكيشن يروح للخلفية.** تايمر شغال والشاشة مقفولة
  // بياكل بطارية وباقة المندوب من غير فايدة — محدش بيبص.

  Timer? _sync;
  bool _syncing = false;

  /// آخر تحديث ناجح — الشاشات بتستخدمه تقول «آخر تحديث من X دقيقة»
  DateTime? lastSyncAt;

  /// المزامنة الكاملة — شبكة أمان بس، اللايف الحقيقي جاي من البلس.
  ///
  /// ⚠️ **المدير والبروموتر لسه على الدورة القصيرة.** البلس مبني على
  /// أرقام المندوب (عهدته، أوامره، إشعاراته) — بصمة المدير مش
  /// بتتغيّر منها، فلو خلّيناه على الدقيقتين كان هيبقى أبطأ من
  /// الأول. لما نعمل بلس للمدير كمان، الاتنين يبقوا دقيقتين.
  // ⚠️ 90 ثانية للمدير والبروموتر (تدقيق الأداء ١٥/٩): البوت ستراب
  // حوالي 1 ميجا، وكل 45 ثانية كان بيسحبه 80 مرة في الساعة لكل جهاز.
  Duration get _syncEvery => (isManager || isPromoter)
      ? const Duration(seconds: 90)
      : const Duration(minutes: 2);

  /// ⚠️ **الـ10 ثواني دي هي «اللايف» اللي المندوب حاسس بيه.**
  /// كانت المزامنة الكاملة كل 45 ثانية، فأمر التجهيز كان بيوصل
  /// بعد نص دقيقة والمندوب واقف قدام المخزن يبص في التليفون.
  /// البلس ريكوست COUNT بس — 6 مرات في الدقيقة عادي خالص.
  static const _pulseEvery = Duration(seconds: 10);

  Timer? _pulse;
  bool _pulsing = false;

  /// آخر بصمة جت من السيرفر — التغيير فيها معناه فيه جديد
  String? _lastPulse;

  /// أكبر id إشعار شافه الأبلكيشن — عشان يعرف الجديد من القديم
  int _lastNotifId = 0;

  /// إشعار جديد وصل والأبلكيشن مفتوح — الشاشة بتسمع وتوريه بانر.
  ///
  /// ⚠️ موجود عشان **الفاير بيز لسه ماتظبطتش**. لما تشتغل، البوش
  /// هيوصل والتليفون مقفول كمان — وده يفضل مكانه للأبلكيشن المفتوح
  /// (البوش مابيظهرش وانت جوه الأبلكيشن أصلاً).
  final ValueNotifier<AppNotification?> incoming = ValueNotifier(null);

  /// مراقب دورة حياة الأبلكيشن — بيتسجّل مرة واحدة
  AppLifecycleListener? _lifecycle;

  /// تشغيل المزامنة — بيتنادى بعد أي دخول ناجح
  void startSync() {
    _sync?.cancel();

    if (user == null) {
      return;
    }

    _sync = Timer.periodic(_syncEvery, (_) => syncNow());

    _pulse?.cancel();
    _pulse = Timer.periodic(_pulseEvery, (_) => pulseNow());

    // ⚠️ **هنا مش في `login()` بس.** التوكن بيتغيّر من فاير بيز
    // لوحده (إعادة تنصيب، مسح داتا، ترقية أندرويد)، والمندوب ممكن
    // مايعملش لوجين تاني لشهور — فالتسجيل بيتكرر مع كل تشغيل ومع كل
    // رجوع من الخلفية، مش مرة واحدة عند الدخول.
    Push.register();

    // ⚠️ **الرجوع من الخلفية أهم من التايمر نفسه.** المندوب بيقفل
    // الشاشة ويمشي، والمدير بينزّل الأمر في الوقت ده — أول ما
    // يفتح التليفون لازم يلاقيه قدامه، مش يستنى 45 ثانية كمان.
    _lifecycle ??= AppLifecycleListener(
      onResume: () {
        startSync();   // التايمرات بتتعاد تشغيلها كمان
        syncNow();
      },
      onPause: () {
        // شاشة مقفولة = مفيش داعي لأي طلب. التايمرات بتقف والباقة
        // والبطارية بيرتاحوا لحد ما يفتح تاني.
        _sync?.cancel();
        _sync = null;
        _pulse?.cancel();
        _pulse = null;
      },
    );
  }

  void stopSync() {
    _sync?.cancel();
    _sync = null;
    _pulse?.cancel();
    _pulse = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  /// تسجيل حضور/بريك/رجعت/انصراف. بترجع رسالة الخطأ أو `null`.
  ///
  /// ⚠️ **الحالة بتتحدث من رد السيرفر مش محلياً.** لو حدّثناها هنا
  /// وقت الضغط، أي رفض من السيرفر كان هيسيب الأبلكيشن شايف نفسه
  /// شغال وهو مش شغال — وكل أكشن بعدها بيترفض من غير سبب مفهوم.
  Future<String?> punch(String type) async {
    try {
      // ⚠️ **اللوكيشن اختياري هنا مش إجباري.** «حضر من فين» سؤال
      // مهم، بس لو الـGPS مقفول أو الإذن مرفوض مايصحّش نمنع الموظف
      // من تسجيل حضوره — كان هيقف الشغل كله على إعداد في التليفون.
      final pos = await Locator.get();

      final d = await Api.I.punch(type, lat: pos?.$1, lng: pos?.$2);

      att = Attendance.fromJson(d['attendance'] ?? {});
      notifyListeners();

      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  /// ⚠️ **تحديث إجباري وسط الشغل.** بيتنادى من كل نبضة؛ لو السيرفر
  /// بقى بيطلب إصدار أعلى من اللي شغال، `Updater.forcedNow` بتتبلّغ
  /// و`main.dart` بيرمي شاشة التحديث فوق كل حاجة من غير رجوع.
  ///
  /// ⚠️ **مش بيقفل على `latest` — بيقفل على `min` بس.** رفع إصدار
  /// جديد اختياري مالوش لازمة يوقف مندوب في نص فاتورة؛ الإجبار
  /// قرار منفصل الإدارة بتاخده لما ترفع الحد الأدنى.
  void _checkVersion(Map<String, dynamic> d) {
    final min = '${d['app_min_version'] ?? ''}';
    if (min.isEmpty) return;

    if (isOlder(appVersion, min)) {
      Updater.forcedNow.value = true;
    }
  }

  /// دخول مخزن — بيرجّع رسالة الخطأ أو `null`
  ///
  /// ⚠️ **اللوكيشن اختياري زي الحضور.** الـGPS مقفول أو الإذن مرفوض
  /// مايصحّش يمنع المندوب من الاستلام — بيتسجّل من غير نقطة وبيبان
  /// كده في شاشة الـERP.
  Future<String?> warehouseIn(int warehouseId) async {
    try {
      final pos = await Locator.get();
      final d = await Api.I.warehouseIn(warehouseId, lat: pos?.$1, lng: pos?.$2);

      whStop = WarehouseStop.fromJson(d['visit'] ?? {});
      notifyListeners();

      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  /// رفع صورة الموظف من «حسابي» (٩/٨) — بيرجّع رسالة الخطأ أو null
  Future<String?> uploadAvatar(String path) async {
    try {
      final d = await Api.I.uploadAvatar(path);

      if (d['user'] != null) {
        user = AppUser.fromJson(Map<String, dynamic>.from(d['user']));
      }
      notifyListeners();

      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  Future<String?> warehouseOut() async {
    try {
      final pos = await Locator.get();
      await Api.I.warehouseOut(lat: pos?.$1, lng: pos?.$2);

      whStop = null;
      notifyListeners();

      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  /// نبضة — بتسأل السيرفر «فيه جديد؟» وبتنده الرفرش الكامل بس لما
  /// يبقى فيه.
  ///
  /// ⚠️ **بتتجاهل أي خطأ في صمت.** المندوب في الشارع على شبكة
  /// بتقطع؛ لو النبضة وقعت مش هنوريه ولا رسالة — النبضة الجاية بعد
  /// 10 ثواني هتمسكها.
  Future<void> pulseNow() async {
    if (user == null || _pulsing || _syncing || Api.I.token == null) {
      return;
    }

    _pulsing = true;

    try {
      final d = await Api.I.pulse();
      final stamp = '${d['stamp']}';
      final lastId = (d['last_notification_id'] ?? 0) as int;

      // ⚠️ **الإصدار بيتفحص في كل نبضة** (2026-08-08). لما المدير
      // يرفع إصدار جديد من الداشبورد، المندوب الشغال كان بيفضل على
      // النسخة القديمة لحد ما يقفل الأبلكيشن ويفتحه — ممكن يوم
      // كامل بيشتغل بنسخة الإدارة قررت إنها مش صالحة.
      //
      // ⚠️ وبنقارن **قبل** فحص البصمة: لو رجعنا من `stamp == _lastPulse`
      // كان الفحص بيتخطّى في الحالة الغالبة.
      _checkVersion(d);

      if (_lastPulse == null) {
        // أول نبضة بعد الدخول — بنسجّل الحالة من غير ما نعتبرها جديد
        _lastPulse = stamp;
        _lastNotifId = lastId;

        return;
      }

      if (stamp == _lastPulse) {
        return;
      }

      _lastPulse = stamp;

      // ⚠️ **البصمة بتتقارن قبل `refresh()`، والتحديث بعده.**
      // `refresh()` نفسها بتحدّث `_lastNotifId`، فلو حدّثناه هنا
      // كنا هنخسر المقارنة. بنحتفظ بالقديم ونقارن بيه بعد الرفرش.
      final seen = _lastNotifId;

      await refresh();
      lastSyncAt = DateTime.now();
      notifyListeners();

      // ⚠️ البانر بعد الرفرش مش قبله — عشان لما يدوس عليه يلاقي
      // الشاشة اللي وراه فيها الجديد فعلاً
      if (notifications.isNotEmpty && notifications.first.id > seen) {
        incoming.value = notifications.first;
      }
    } catch (_) {
      // شبكة — النبضة الجاية هتعوّض
    } finally {
      _pulsing = false;
    }
  }

  /// تحديث صامت — من غير سبينر ومن غير ما يمسح اللي على الشاشة.
  ///
  /// ⚠️ **مش بينادي `notifyListeners` غير لو فيه جديد فعلاً** — كل
  /// تحديث بيعيد بناء الشاشة، ولو حصل كل 45 ثانية على طول المندوب
  /// اللي بيكتب في فاتورة كان هيلاقي الشاشة بتترسم تحت إيده.
  Future<void> syncNow() async {
    if (user == null || _syncing || Api.I.token == null) {
      return;
    }

    _syncing = true;

    try {
      // البصمة قبل وبعد — التحديث بيتبلّغ بس لما حاجة تتغير
      final before = _stamp();

      await refresh();
      lastSyncAt = DateTime.now();

      if (_stamp() != before) {
        notifyListeners();
      }
    } catch (_) {
      // الشبكة وقعت — اللي على الشاشة يفضل زي ما هو والمحاولة
      // الجاية بعد 45 ثانية. عمر ما نوري خطأ لتحديث خلفي.
    } finally {
      _syncing = false;
    }
  }

  /// بصمة مختصرة للحالة — أرخص من مقارنة الكائنات كلها.
  ///
  /// ⚠️ الأرقام دي بالظبط هي اللي المندوب مستنيها: أمر توريد نزل،
  /// عهدة اتجهزت، إشعار جه، طلب عميل اترد عليه، خطة اتعدّلت.
  String _stamp() => [
        pos.length,
        pos.map((p) => p.status).join(','),
        picks.length,
        readyPicks,
        notifications.length,
        requests.map((r) => r.status).join(','),
        journey.length,
        journeySummary.done,
        custody.items.length,
        custody.remainingUnits,
        att.state,
        att.workedMinutes,
      ].join('|');

  bool get isCourier => user?.isCourier ?? false;
  bool get isManager => user?.isManager ?? false;
  bool get isPromoter => user?.isPromoter ?? false;

  // ---------- داتا البروموتر ----------
  PromoterStats promoStats = PromoterStats.empty();
  List<Branch> branches = [];
  List<CatalogProduct> catalog = [];
  List<ReplenishmentRow> replenishments = [];
  MerchVisit? openMerchVisit;

  // ---------- داتا المدير ----------
  ManagerStats mgrStats = ManagerStats.empty();
  List<RepOverview> reps = [];
  List<PendingRequest> pendingRequests = [];
  List<TeamEvent> teamEvents = [];
  List<MgrReplenishment> mgrReplenishments = [];
  List<DriverOption> drivers = [];

  List<PendingRequest> get openRequests =>
      pendingRequests.where((r) => r.isOpen).toList();

  /// طلبات الريفيل المستنية موافقة المدير
  List<MgrReplenishment> get pendingReplenishments =>
      mgrReplenishments.where((r) => r.status == 'pending').toList();

  /// أوامر التجهيز الجاهزة عند المخزن ومستنية المندوب يستلمها
  List<PickOrder> get readyPickOrders =>
      picks.where((p) => p.canReceive).toList();

  Zone? get todayZone =>
      firstOrNull(zones.where((z) => z.isToday)) ?? firstOrNull(zones);

  Client? get activeClient {
    for (final z in zones) {
      for (final c in z.clients) {
        if (c.status == VisitStatus.inVisit) return c;
      }
    }
    return null;
  }

  PurchaseOrder? get activePo =>
      firstOrNull(pos.where((p) => p.status == 'arrived'));

  Client? clientById(int id) {
    for (final z in zones) {
      for (final c in z.clients) {
        if (c.id == id) return c;
      }
    }
    return null;
  }

  // ---------- Auth ----------

  /// ⚠️ **اللوجين بيفضل شغال بعد قفل الأبلكيشن** — زي أي أبلكيشن.
  /// التوكن متخزن على التليفون (`Prefs` — SharedPreferences أصلية)،
  /// وأول ما الأبلكيشن يفتح بنحاول بيه. 401 = التوكن اتلغى من
  /// السيرفر (باسورد اتغير مثلاً) فبنمسحه ونوري اللوجين. أي فشل
  /// تاني (نت واقع) بنسيب التوكن وبنوري اللوجين — أول لوجين ناجح
  /// أو فتحة جاية والنت شغال هترجّعه.
  /// فتح الأبلكيشن وبنسترجع الجلسة المحفوظة — **دي بس** اللي بتوري
  /// السبلاش. ⚠️ (إصلاح ١١/٨): `main` كان بيوري السبلاش على `loading`
  /// العامة — واللوجين بيرفعها — فأول ما تدوس «دخول» شاشة اللوجين
  /// بتتشال ويظهر السبلاش، ولو اللوجين فشل بترجع **شاشة لوجين جديدة**
  /// ورسالة الخطأ كانت اتكتبت على القديمة اللي اتشالت: «بيحمّل وبعدين
  /// يرجع للوجين من غير أي رسالة». السبلاش بقى على `restoring` بس،
  /// واللوجين بيفضل قدامك بسبينر زراره ورسالته.
  bool restoring = false;

  Future<void> restore() async {
    // ⚠️ **`loading = true` قبل أي await — مش بعد قراية التوكن**
    // (إصلاح ٩/٨). `restore()` بتتنادى fire-and-forget من `main`،
    // وأول build كان بيحصل قبل ما `Prefs.get` ترجع — فـ`loading`
    // لسه false و`user` لسه null → **شاشة اللوجين بتنوّر لثانية**
    // قبل ما الجلسة المحفوظة تتحمّل، والموظف يبدأ يكتب باسورده
    // على الفاضي. دي كانت نص شكوى «كل شوية أدخل الإيميل والباسورد».
    loading = true;
    restoring = true;
    notifyListeners();

    final saved = await Prefs.get('token');

    if (saved == null || saved.isEmpty) {
      loading = false;
      restoring = false;
      notifyListeners();

      return;
    }

    Api.I.token = saved;

    // بينج فتح الأبلكيشن — fire-and-forget، مايعطلش الفتح (2026-08-06)
    Api.I.appOpen().catchError((_) => <String, dynamic>{});

    // ⚠️ **النص التاني من الشكوى: النت الضعيف وقت الفتح.** المندوب
    // في الشارع بيفتح الأبلكيشن والشبكة بتقطّع — المحاولة الواحدة
    // كانت بتفشل بتايم أوت وترميه على اللوجين بحقول فاضية رغم إن
    // التوكن سليم. بنحاول تلات مرات بفواصل قصيرة والسبلاش ظاهر،
    // وبعدها بس بنسلّم للوجين (والتوكن بيفضل محفوظ للفتحة الجاية).
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await refresh();
        break;
      } on ApiException catch (e) {
        if (e.status == 401 || e.status == 403) {
          // التوكن اتلغى فعلاً من السيرفر (باسورد اتغير مثلاً)
          Api.I.token = null;
          await Prefs.remove('token');
          break;
        }
        // خطأ سيرفر مؤقت — نعيد زي خطأ الشبكة بالظبط
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      } catch (_) {
        // نت واقع — التوكن بيفضل والمحاولة الجاية هتنجح
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }

    // المزامنة اللايف بتشتغل بعد أي استرجاع ناجح (2026-08-07)
    startSync();
    loading = false;
    restoring = false;
    notifyListeners();

    // ⚠️ (بلاغ ٢١/٨ + عاد بالليل) أول فتحة ساعات بتيجي فاضية — لا
    // عهدة ولا مناطق — والريفريش اليدوي بيرجّع كل حاجة. المحاولة
    // الواحدة بعد ٣ ثواني ماكفتش: النت وقت الفتح بيفضل يقطّع أطول
    // من كده. بقت **لوب مثابرة**: كل ٣ ثواني لحد ما الداتا تيجي
    // (أو ١٠ محاولات = ٣٠ ثانية) — وأي نجاح، حتى السحب اليدوي،
    // بيوقفها لوحده لأن الشرط بيبقى false.
    _kickstart();
  }

  /// إعادة المحاولة الصامتة لما الفتحة تيجي فاضية — لكل الرولز
  Future<void> _kickstart() async {
    for (var i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 3));

      if (user == null) return;

      final empty = isManager
          ? reps.isEmpty
          : isPromoter
              ? branches.isEmpty && catalog.isEmpty
              : zones.isEmpty && custody.items.isEmpty && pos.isEmpty;

      if (!empty) return;

      try {
        await refresh();
      } catch (_) {
        // النت لسه واقع — اللفة الجاية بعد ٣ ثواني
      }
    }
  }

  Future<void> login(String login, String password) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await Api.I.login(login, password);
      Api.I.token = res['token'];
      // بينج فتح الأبلكيشن — أول لوجين بيتعد فتحة برضه (2026-08-06)
      Api.I.appOpen().catchError((_) => <String, dynamic>{});
      // التوكن بيتخزن قبل الـrefresh — لو الـbootstrap وقع بسبب
      // النت، الجلسة برضه محفوظة للفتحة الجاية
      await Prefs.set('token', '${res['token']}');
      user = AppUser.fromJson(res['user']);

      // اختار لغة من شاشة اللوجين؟ بنحفظها على اليوزر دلوقتي —
      // قبل الـrefresh اللي بيقرا locale من السيرفر
      if (_pendingLocale != null) {
        try {
          await Api.I.setLocale(_pendingLocale!);
        } catch (_) {
          // مش مشكلة — هتتظبط من شاشة حسابي
        }
        _pendingLocale = null;
      }

      // ⚠️ **فشل الـbootstrap مش فشل اللوجين** (إصلاح ١١/٨).
      // التوكن اتاخد والجلسة صحيحة — لو الداتا وقعت بسبب النت أو
      // خطأ سيرفر مؤقت، بندخّل الموظف والداتا هتيجي مع البلس/السحب.
      // 401/403 بس هما اللي بيفشّلوا اللوجين فعلاً (توكن اترفض أو
      // حساب موقوف) — وقتها بنمسح النص-جلسة عشان مانعلّقش في نص
      // حالة: شاشة رئيسية فاضية بتطرد لبره في صمت.
      try {
        await refresh();
      } on ApiException catch (e) {
        if (e.status == 401 || e.status == 403) {
          Api.I.token = null;
          await Prefs.remove('token');
          user = null;
          rethrow;
        }
        // غير كده: كمّل — الجلسة شغالة والداتا جاية
      } catch (_) {
        // نت واقع بعد لوجين ناجح — كمّل بنفس المنطق
      }

      // المزامنة اللايف — أوامر التوريد والعهدة بتوصل لوحدها
      startSync();
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    // ⚠️ **الإيقاف قبل أي حاجة.** تايمر شغال بعد الخروج بينادي
    // `/bootstrap` بتوكن اتلغى وبياخد 401 كل 45 ثانية للأبد.
    stopSync();
    lastSyncAt = null;

    // ⚠️ **قبل ما توكن الجلسة يتمسح** — الريكوست ده محتاج تصديق.
    // ولو التوكن فضل مسجّل على السيرفر والتليفون اتسلّم لموظف تاني،
    // هيفضل واصله إشعارات اللي قبله.
    await Push.forget();

    try {
      await Api.I.post('/logout');
    } catch (_) {}
    Api.I.token = null;
    // ⚠️ الخروج بيمسح التوكن من التليفون — الفتحة الجاية لوجين نضيف
    await Prefs.remove('token');
    user = null;
    zones = [];
    journey = [];
    journeySummary = JourneySummary.empty();
    pos = [];
    events = [];
    notifications = [];
    requests = [];
    picks = [];
    readyPicks = 0;
    att = Attendance.empty();
    // ⚠️ لازم تتصفّر مع الخروج — يوزر تاني على نفس التليفون كان
    // هيلاقي بصمة الأول محفوظة فمايجيلوش تحديث لحد ما حاجة تتغير
    _lastPulse = null;
    _lastNotifId = 0;
    incoming.value = null;
    custody = Custody.empty();
    today = TodayStats.empty();
    mgrStats = ManagerStats.empty();
    reps = [];
    pendingRequests = [];
    teamEvents = [];
    mgrReplenishments = [];
    drivers = [];
    promoStats = PromoterStats.empty();
    branches = [];
    catalog = [];
    replenishments = [];
    openMerchVisit = null;
    notifyListeners();
  }

  // ---------- Data ----------

  Future<void> refresh() async {
    if (isManager) {
      await _refreshManager();
      return;
    }
    if (isPromoter) {
      await _refreshPromoter();
      return;
    }

    final d = await Api.I.bootstrap();

    user = AppUser.fromJson(d['user']);

    // ⚠️ اللغة من السيرفر (`users.locale`) مش من التليفون — عشان
    // الشاشة والإشعارات يبقوا بنفس اللغة. الإشعار بيترندر عند
    // السيرفر بلغة المستقبِل، فلو الأبلكيشن بلغة تانية بيبقى مخلّط.
    L.use(d['user']['locale']);
    custody = Custody.fromJson(d['custody'] ?? {});
    zones = ((d['zones'] ?? []) as List).map((e) => Zone.fromJson(e)).toList();
    pos = ((d['purchase_orders'] ?? []) as List)
        .map((e) => PurchaseOrder.fromJson(e))
        .toList();
    events =
        ((d['events'] ?? []) as List).map((e) => TrackEvent.fromJson(e)).toList();
    notifications = ((d['notifications'] ?? []) as List)
        .map((e) => AppNotification.fromJson(e))
        .toList();

    // ⚠️ **`_lastNotifId` لازم يتحدّث هنا كمان** (تدقيق ٨/٨/٢٠٢٦).
    // كان بيتحدّث في `pulse()` بس — فلما المندوب يرجع للأبلكيشن بعد
    // ما يكون قرا الإشعار من تراي الأندرويد، `refresh()` بتجيب
    // الإشعار الجديد والنبضة اللي بعدها بتقارن بـ`_lastNotifId`
    // القديم وتطلّع بانر لحاجة هو قاريها خلاص. التكرار كان مضمون.
    if (notifications.isNotEmpty && notifications.first.id > _lastNotifId) {
      _lastNotifId = notifications.first.id;
    }
    requests = ((d['client_requests'] ?? []) as List)
        .map((e) => ClientRequestRow.fromJson(e))
        .toList();
    today = TodayStats.fromJson(d['today'] ?? {});
    att = Attendance.fromJson(d['attendance'] ?? {});

    // ⚠️ `null` معناها **مش جوه مخزن** — مش «مالقيناش». السيرفر
    // بيبعت المفتاح دايماً، والقيمة الفاضية قرار مش نقص داتا.
    final wv = d['warehouse_visit'];
    whStop = wv == null ? null : WarehouseStop.fromJson(wv);
    whToday = WarehouseToday.fromJson(
        Map<String, dynamic>.from((d['warehouse_today'] ?? const {}) as Map));

    warehouses = ((d['warehouses'] ?? []) as List)
        .map((e) => WarehouseOption.fromJson(e))
        .toList();

    _readOpenVisit(d['open_visit']);

    _readJourney(d['journey']);

    await _loadPicks();

    notifyListeners();
  }

  /// قراءة خط السير من رد السيرفر
  void _readJourney(dynamic raw) {
    if (raw is! Map) {
      // ⚠️ سيرفر قديم من غير الإندبوينت ده — بنسيب الخطة فاضية
      // بدل ما نرمي استثناء يمنع الدخول كله
      journey = [];
      journeySummary = JourneySummary.empty();

      return;
    }

    journey = ((raw['stops'] ?? []) as List)
        .map((e) => JourneyStop.fromJson(e))
        .toList();
    // ⚠️ `{} as Map<String, dynamic>` بترمي وقت التشغيل — الحرفي
    // الفاضي بيتستنتج `Map<dynamic, dynamic>` والكاست بيفشل.
    journeySummary = JourneySummary.fromJson(
        Map<String, dynamic>.from((raw['summary'] ?? const {}) as Map));
  }

  /// تبديل اللغة — بتتحفظ على اليوزر في السيرفر
  Future<String?> setLocale(String code) async {
    // ⚠️ **قبل الدخول مفيش توكن** — النداية على `/locale` كانت بترجع
    // «failed to authenticate» لما حد يبدّل اللغة من شاشة اللوجين.
    // من غير توكن: تبديل محلي بس، واللغة بتتحفظ على اليوزر أول ما
    // يدخل (اللوجين بيرجّع locale بتاعه من السيرفر أصلاً).
    if (Api.I.token == null) {
      L.use(code);
      // بنفتكر اختياره — أول ما يدخل بنحفظه على اليوزر في السيرفر،
      // وإلا اللوجين كان هيرجّعه للغة المحفوظة القديمة ويداس اختياره
      _pendingLocale = code;
      notifyListeners();

      return null;
    }

    try {
      final d = await Api.I.setLocale(code);
      L.use(d['user']?['locale'] ?? code);

      // ⚠️ ريفريش كامل: أسماء العملاء والمنتجات والحالات كلها
      // بتتعرض من السيرفر باللغة المطلوبة، مش بس نصوص الواجهة.
      await refresh();

      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  /// ريفريش خط السير لوحده — أخف من bootstrap كامل
  Future<void> refreshJourney() async {
    try {
      _readJourney(await Api.I.journey());
      notifyListeners();
    } catch (_) {
      // الشبكة وقعت — بنسيب اللي على الشاشة زي ما هو
    }
  }

  /// العميل المقابل لمحطة — عشان شاشة البيع اللي بتاخد `Client`
  Client? clientForStop(JourneyStop stop) {
    for (final z in zones) {
      final hit = firstOrNull(z.clients.where((c) => c.id == stop.clientId));
      if (hit != null) return hit;
    }

    return null;
  }

  Future<String?> checkInStop(JourneyStop stop) async {
    try {
      // ⚠️ اللوكيشن بيتاخد وقت التشيك إن — ولو مش متاح الزيارة
      // بتتسجل من غيره؛ التشيك إن مايتعطلش عشان GPS مقفول
      final pos = await Locator.get();
      final res = await Api.I.checkIn(stop.clientId, lat: pos?.$1, lng: pos?.$2);
      stop.visitId = res['visit_id'];
      stop.status = VisitStatus.inVisit;
      await refresh();

      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  /// العميل اللي عليه زيارة مفتوحة دلوقتي — من الخطة أو الزونز.
  /// الشاشات بتستخدمه عشان توري «اقفل زيارة فلان الأول» بدل ما
  /// المندوب ياكل إيرور من السيرفر.
  Client? openVisitClient() {
    for (final z in zones) {
      final hit = firstOrNull(
          z.clients.where((c) => c.status == VisitStatus.inVisit));
      if (hit != null) return hit;
    }

    for (final s in journey) {
      if (s.status == VisitStatus.inVisit) {
        return clientForStop(s) ?? s.asClient();
      }
    }

    return null;
  }

  Future<String?> checkOutStop(JourneyStop stop) async {
    if (stop.visitId == null) return L.t('no_open_visit');

    try {
      await Api.I.checkOut(stop.visitId!);
      stop.status = VisitStatus.done;
      await refresh();

      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  /// أوامر التجهيز — لو الإندبوينت وقع مش المفروض يكسّر الدخول
  Future<void> _loadPicks() async {
    try {
      final d = await Api.I.picks();
      picks = ((d['picks'] ?? []) as List)
          .map((e) => PickOrder.fromJson(e))
          .toList();
      readyPicks =
          d['ready_count'] ?? picks.where((p) => p.canReceive).length;
    } catch (_) {
      // سيبها زي ما هي — الشاشة هتفضل شغّالة بآخر داتا
    }
  }

  Future<void> _refreshManager() async {
    final d = await Api.I.managerBootstrap();

    user = AppUser.fromJson(d['user']);

    // ⚠️ اللغة من السيرفر (`users.locale`) مش من التليفون — عشان
    // الشاشة والإشعارات يبقوا بنفس اللغة. الإشعار بيترندر عند
    // السيرفر بلغة المستقبِل، فلو الأبلكيشن بلغة تانية بيبقى مخلّط.
    L.use(d['user']['locale']);

    // ⚠️ **الحضور والإشعارات للرول ده كمان** (تدقيق ٨/٨/٢٠٢٦).
    // السيرفر بقى بيبعتهم في البوت ستراب، والريفريش ده ماكانش
    // بيقراهم — فكارت الحضور بيفضل «مش حاضر» مهما سجّل، والجرس
    // بيفضل فاضي. الحتة اللي بتقرا كانت في مسار المندوب بس.
    att = Attendance.fromJson(d['attendance'] ?? {});

    notifications = ((d['notifications'] ?? []) as List)
        .map((e) => AppNotification.fromJson(e))
        .toList();

    if (notifications.isNotEmpty && notifications.first.id > _lastNotifId) {
      _lastNotifId = notifications.first.id;
    }

    mgrStats = ManagerStats.fromJson(d['today'] ?? {});
    reps = ((d['reps'] ?? []) as List)
        .map((e) => RepOverview.fromJson(e))
        .toList();
    pendingRequests = ((d['requests'] ?? []) as List)
        .map((e) => PendingRequest.fromJson(e))
        .toList();
    teamEvents = ((d['events'] ?? []) as List)
        .map((e) => TeamEvent.fromJson(e))
        .toList();
    mgrReplenishments = ((d['replenishments'] ?? []) as List)
        .map((e) => MgrReplenishment.fromJson(e))
        .toList();
    drivers = ((d['drivers'] ?? []) as List)
        .map((e) => DriverOption.fromJson(e))
        .toList();

    // ═══ المدير الميداني (١١ أغسطس ٢٠٢٦) ═══
    //
    // السيرفر بقى بيبعت في `/manager/bootstrap` نفس مفاتيح بوت ستراب
    // الميدان بالحرف (`zones` `journey` `custody` `purchase_orders`) —
    // بنقراها في **نفس حقول الجلسة** اللي شاشات المندوب بتقرا منها،
    // فشاشات الزونز وخط السير والتوريد بتشتغل للمدير من غير أي تفريع.
    //
    // ⚠️ **مفاتيح إضافية**: سيرفر قديم من غيرها = ديفولت فاضي زي
    // باقي القراية — مش كراش يمنع دخول المدير كله.
    custody = Custody.fromJson(d['custody'] ?? {});
    zones = ((d['zones'] ?? []) as List).map((e) => Zone.fromJson(e)).toList();
    pos = ((d['purchase_orders'] ?? []) as List)
        .map((e) => PurchaseOrder.fromJson(e))
        .toList();
    _readJourney(d['journey']);

    // المخزن — بوت ستراب المدير بيبعت نفس حزمة الميدان
    // (`warehouseBundle`)؛ القراية دفاعية لو الحزمة غابت لأي سبب.
    final wv = d['warehouse_visit'];
    whStop = wv == null ? null : WarehouseStop.fromJson(wv);
    whToday = WarehouseToday.fromJson(
        Map<String, dynamic>.from((d['warehouse_today'] ?? const {}) as Map));
    warehouses = ((d['warehouses'] ?? []) as List)
        .map((e) => WarehouseOption.fromJson(e))
        .toList();

    _readOpenVisit(d['open_visit']);

    // أوامر التجهيز — المدير بيستلم عهدته من المخزن زي المندوب
    await _loadPicks();

    notifyListeners();
  }

  // ---------- أكشنز المدير على طلبات الريفيل ----------

  /// موافقة + تنزيل على مندوب → بيتحول لأمر توريد يوصله السواق
  Future<String?> assignReplenishment(
    int requestId,
    int driverId, {
    String priceMode = 'channel',
  }) async {
    try {
      await Api.I.assignReplenishment(requestId, driverId, priceMode: priceMode);
      await refresh();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  Future<String?> rejectReplenishment(int requestId, {String? note}) async {
    try {
      await Api.I.cancelReplenishment(requestId, note: note);
      await refresh();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  Future<void> _refreshPromoter() async {
    final d = await Api.I.promoterBootstrap();

    user = AppUser.fromJson(d['user']);

    // ⚠️ اللغة من السيرفر (`users.locale`) مش من التليفون — عشان
    // الشاشة والإشعارات يبقوا بنفس اللغة. الإشعار بيترندر عند
    // السيرفر بلغة المستقبِل، فلو الأبلكيشن بلغة تانية بيبقى مخلّط.
    L.use(d['user']['locale']);

    // ⚠️ **الحضور والإشعارات للرول ده كمان** (تدقيق ٨/٨/٢٠٢٦).
    // السيرفر بقى بيبعتهم في البوت ستراب، والريفريش ده ماكانش
    // بيقراهم — فكارت الحضور بيفضل «مش حاضر» مهما سجّل، والجرس
    // بيفضل فاضي. الحتة اللي بتقرا كانت في مسار المندوب بس.
    att = Attendance.fromJson(d['attendance'] ?? {});

    notifications = ((d['notifications'] ?? []) as List)
        .map((e) => AppNotification.fromJson(e))
        .toList();

    if (notifications.isNotEmpty && notifications.first.id > _lastNotifId) {
      _lastNotifId = notifications.first.id;
    }

    promoStats = PromoterStats.fromJson(d['today'] ?? {});

    // ⚠️ **خط السير للبروموتر كمان** (بلاغ المالك ٢٨/٨): الجدولة
    // كانت بتتحفظ في الـERP والسيرفر بقى بيبعتها — من غير السطر ده
    // تاب خط السير بيفضل فاضي مهما المالك جدول.
    _readJourney(d['journey']);

    // تاب المناطق (٢٨/٨ — إعادة بناء المنسق): بالتسكين الحقيقي
    // زي المندوب بالظبط — مش heuristic الزون القديمة
    zones = ((d['zones'] ?? []) as List).map((e) => Zone.fromJson(e)).toList();

    branches =
        ((d['branches'] ?? []) as List).map((e) => Branch.fromJson(e)).toList();
    catalog = ((d['products'] ?? []) as List)
        .map((e) => CatalogProduct.fromJson(e))
        .toList();
    replenishments = ((d['requests'] ?? []) as List)
        .map((e) => ReplenishmentRow.fromJson(e))
        .toList();
    openMerchVisit =
        d['open_visit'] == null ? null : MerchVisit.fromJson(d['open_visit']);
    events =
        ((d['events'] ?? []) as List).map((e) => TrackEvent.fromJson(e)).toList();

    // ═══ البروموتر بقى يستلم ويسلّم أوامر توريد (١١/٨ مساءً) ═══
    // «نفس المندوب اللي طلبه ولا مندوب تاني» — السيرفر بقى بيبعت
    // العهدة والأوامر وحزمة المخزن في نفس البوت ستراب، بنفس مفاتيح
    // بوت ستراب الميدان بالحرف.
    custody = Custody.fromJson(d['custody'] ?? {});
    pos = ((d['purchase_orders'] ?? []) as List)
        .map((e) => PurchaseOrder.fromJson(e))
        .toList();

    // ⚠️ `null` معناها **مش جوه مخزن** — مش «مالقيناش».
    final wv = d['warehouse_visit'];
    whStop = wv == null ? null : WarehouseStop.fromJson(wv);
    whToday = WarehouseToday.fromJson(
        Map<String, dynamic>.from((d['warehouse_today'] ?? const {}) as Map));
    warehouses = ((d['warehouses'] ?? []) as List)
        .map((e) => WarehouseOption.fromJson(e))
        .toList();

    // أوامر التجهيز اللي مستنية استلامه — بانر «تعالى استلم»
    await _loadPicks();

    notifyListeners();
  }

  // ---------- أكشنز البروموتر ----------

  /// رد السيرفر فيه `visit` كاملة — بنعتمدها فوراً ونحدّث الباقي (عدادات
  /// اليوم وحالة الفروع) في الخلفية. لو الرد مافيهوش زيارة بنرجع للتحديث الكامل.
  void _adoptVisit(Map<String, dynamic> res) {
    final v = res['visit'];
    if (v is Map) {
      openMerchVisit = MerchVisit.fromJson(Map<String, dynamic>.from(v));
      notifyListeners();
    }
    unawaited(refresh());
  }

  Future<String?> startMerchVisit(Branch b) async {
    try {
      // نفس قاعدة التشيك إن: اللوكيشن لو متاح، والزيارة ماتتعطلش لو لأ
      // ⚠️ (٢١/٩) كانت بتستنى الـGPS لحد 25 ثانية وبعدها bootstrap كامل قبل
      // ما الشاشة تفتح. الرد نفسه فيه الزيارة — بنفتح عليها فوراً والتحديث
      // الكامل بيحصل في الخلفية.
      final pos = await Locator.quick();
      final res =
          await Api.I.startMerchVisit(b.id, lat: pos?.$1, lng: pos?.$2);
      _adoptVisit(res);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  Future<String?> uploadShelfPhoto(int visitId, String stage, String path) async {
    try {
      await Api.I.uploadShelfPhoto(visitId, stage, path);
      await refresh();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  Future<String?> saveRefill(int visitId, List<RefillLine> lines) async {
    // ⚠️ `removed` كمان — السطر اللي علامته اتشالت من المنتقي بيتبعت
    // بأصفاره عشان السيرفر يمسح صفه القديم (١٢/٨). فلتر touched
    // لوحده كان بيسقّطه والصف بيفضل معلّق في الزيارة.
    final payload =
        lines.where((l) => l.touched || l.removed).map((l) => l.toJson()).toList();
    if (payload.isEmpty) return L.t('pick_one_item');

    try {
      final pos = await Locator.quick();
      _adoptVisit(
          await Api.I.saveRefill(visitId, payload, lat: pos?.$1, lng: pos?.$2));
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  Future<String?> requestReplenishment(
      int visitId, Map<int, int> qtyByProduct, String? note) async {
    final items = qtyByProduct.entries
        .where((e) => e.value > 0)
        .map((e) => {'product_id': e.key, 'qty': e.value})
        .toList();
    if (items.isEmpty) return L.t('pick_items_qty');

    try {
      await Api.I.requestReplenishment(visitId, items, note);
      await refresh();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  Future<String?> saveShelfCount(int visitId, List<CountLine> lines) async {
    try {
      _adoptVisit(await Api.I.saveShelfCount(
          visitId, lines.map((l) => l.toJson()).toList()));
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  Future<String?> closeMerchVisit(int visitId,
      {bool noPhotos = false, String? reason}) async {
    try {
      await Api.I.closeMerchVisit(visitId, noPhotos: noPhotos, reason: reason);
      await refresh();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  /// قرار المدير على طلب عميل جديد
  Future<String?> decideRequest(
    PendingRequest r,
    String decision, {
    double? discount,
    String? note,
  }) async {
    try {
      await Api.I.decideRequest(r.id, decision, discount: discount, note: note);
      await refresh();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  Future<Map<String, dynamic>> repDetail(int userId) => Api.I.managerRep(userId);

  // ---------- Actions ----------

  Future<String?> checkIn(Client c) async {
    try {
      final pos = await Locator.get();
      final res = await Api.I.checkIn(c.id, lat: pos?.$1, lng: pos?.$2);
      c.visitId = res['visit_id'];
      c.checkInAt = parseTime(res['checked_in_at']);
      c.status = VisitStatus.inVisit;
      await refresh();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  // ═══ أوبشنات الزيارة التلاتة (2026-08-09) ═══

  /// تحصيل أثناء الزيارة — بيرجّع (خطأ، الرصيد الجديد)
  Future<(String?, double?)> collectVisit(
    Client c, {
    required double amount,
    required String method,
    String? reference,
    String? chequeBank,
    String? chequeDue,
    String? note,
    String? proofPath,
    String? idemKey,
  }) async {
    if (c.visitId == null) return (L.t('no_open_visit'), null);
    try {
      final res = await Api.I.collectVisit(
        c.visitId!,
        amount: amount,
        method: method,
        reference: reference,
        chequeBank: chequeBank,
        chequeDue: chequeDue,
        note: note,
        proofPath: proofPath,
        idemKey: idemKey,
      );

      // ⚠️ **الريفريش مش رفاهية** (تدقيق ٩/٨): من غيره كارت العميل
      // بيفضل يعرض المديونية اللي لسه متحصّلة — والمندوب يفتكر إن
      // التحصيل ماتسجلش ويسجّله تاني.
      await refresh();

      return (null, (res['balance'] as num?)?.toDouble());
    } on ApiException catch (e) {
      return (e.message, null);
    } catch (e) {
      return (L.t('error_with', {'e': '$e'}), null);
    }
  }

  /// صورة رف — بترجّع (خطأ، عدد صور المرحلة دي)
  Future<(String?, int?)> visitShelfPhoto(
      Client c, String stage, String path) async {
    if (c.visitId == null) return (L.t('no_open_visit'), null);
    try {
      final res = await Api.I.visitShelfPhoto(c.visitId!, stage, path);
      final counts =
          Map<String, dynamic>.from((res['counts'] ?? const {}) as Map);

      return (null, (counts[stage] as num?)?.toInt());
    } on ApiException catch (e) {
      return (e.message, null);
    } catch (e) {
      return (L.t('error_with', {'e': '$e'}), null);
    }
  }

  Future<Map<String, dynamic>> clientCatalog(Client c) =>
      Api.I.clientCatalog(c.id);

  // ═══ لوكيشن العميل من الأبلكيشن (١٤ أغسطس ٢٠٢٦) ═══

  /// المحافظات والمناطق من غير نقطة — للدروب داون في شاشة اللوكيشن.
  ///
  /// ⚠️ **الفشل بيرجّع خريطة فاضية مش استثناء.** الشاشة بتنده دي في
  /// `initState`، ورمي استثناء هناك كان هيمنع الشاشة من الفتح أصلاً
  /// لو الشبكة واقعة — والمندوب المفروض يقدر يشوف الشاشة ويسحب
  /// النقطة حتى وهو أوفلاين.
  Future<Map<String, dynamic>> geoOptions() async {
    try {
      return await Api.I.geoOptions();
    } catch (_) {
      return const {};
    }
  }

  /// اقتراح العنوان/المحافظة/المنطقة من نقطة — بيرجّع (خطأ، الرد).
  ///
  /// ⚠️ **الفشل هنا مش نهاية الشاشة.** النقطة اتسحبت خلاص وهي أهم
  /// حاجة؛ الجيوكودينج تجميل. الشاشة بتوري الرسالة وبتسيب الخانات
  /// فاضية قابلة للكتابة والحفظ شغّال.
  Future<(String?, Map<String, dynamic>?)> geocodeClientPoint(
      Client c, double lat, double lng) async {
    try {
      return (null, await Api.I.clientGeocode(c.id, lat, lng));
    } on ApiException catch (e) {
      return (e.message, null);
    } catch (e) {
      return (L.t('error_with', {'e': '$e'}), null);
    }
  }

  /// حفظ لوكيشن العميل — بيرجّع رسالة الخطأ أو `null` لو نجح.
  ///
  /// ⚠️ **`refresh()` بعد النجاح مش رفاهية**: كارت العميل وشاشة
  /// الزيارة بيقروا `lat/lng` من `Session.zones`، ومن غير المزامنة
  /// المندوب بيرجع للشاشة يلاقي «ليس له لوكيشن» أحمر بعد ما ضبطه
  /// بثانية — ويفتكر إن الحفظ ماتمّش ويعمله تاني.
  Future<String?> saveClientLocation(
    Client c, {
    required double lat,
    required double lng,
    String? address,
    String? addressAr,
    String? governorate,
    int? zoneId,
  }) async {
    try {
      await Api.I.saveClientLocation(
        c.id,
        lat: lat,
        lng: lng,
        address: address,
        addressAr: addressAr,
        governorate: governorate,
        zoneId: zoneId,
      );
      await refresh();

      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  /// طلب بضاعة — بيرجّع (خطأ، رقم الطلب)
  Future<(String?, String?)> createGoodsRequest(
      Client c, List<Map<String, dynamic>> items, String? note) async {
    if (c.visitId == null) return (L.t('no_open_visit'), null);
    try {
      final res = await Api.I.createGoodsRequest(c.visitId!, items, note);
      final req = Map<String, dynamic>.from((res['request'] ?? const {}) as Map);

      return (null, req['number']?.toString());
    } on ApiException catch (e) {
      return (e.message, null);
    } catch (e) {
      return (L.t('error_with', {'e': '$e'}), null);
    }
  }

  Future<String?> checkOut(Client c) async {
    if (c.visitId == null) return L.t('no_open_visit');
    try {
      await Api.I.checkOut(c.visitId!);
      c.status = VisitStatus.done;
      c.checkOutAt = DateTime.now();
      await refresh();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  /// أسعار **قايمة العميل** لكل صنف في العهدة — productId ← سعر القائمة.
  ///
  /// ⚠️ **الخصم مش داخل فيها بقصد.** الشاشة بتحسب الخصم بنفسها من
  /// `client.discount` عشان تعرضه سطر مستقل زي الفاتورة بالظبط. لو
  /// رجّعنا السعر مخصوم، الخصم كان هيتحسب مرتين.
  ///
  /// ⚠️ بترجّع فاضية لو الشبكة فشلت — الشاشة بترجع لسعر العهدة
  /// الاسترشادي بدل ما تقف. مايصحّش نمنع البيع بسبب نداء تجميلي.
  Future<Map<int, double>> clientListPrices(int clientId) async {
    try {
      final res = await Api.I.clientPrices(clientId);
      final out = <int, double>{};

      for (final r in (res['items'] as List? ?? const [])) {
        final m = r as Map<String, dynamic>;
        out[(m['product_id'] as num).toInt()] =
            (m['list_price'] as num?)?.toDouble() ?? 0;
      }

      return out;
    } catch (_) {
      return const {};
    }
  }

  /// سامري تاريخ العميل — عدادات المربعات.
  ///
  /// ⚠️ **بترجّع خريطة فاضية عند أي خطأ مش بترمي.** دي معلومة
  /// إضافية في صفحة العميل؛ لو الشبكة وقعت، المندوب لازم يفضل
  /// قادر يعمل تشيك إن ويبيع. الشاشة بتخفي المربعات وخلاص.
  Future<Map<String, HistoryStat>> clientHistory(int clientId) async {
    try {
      final res = await Api.I.clientHistory(clientId);
      final raw = (res['summary'] ?? {}) as Map<String, dynamic>;

      return raw.map((k, v) =>
          MapEntry(k, HistoryStat.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      return const {};
    }
  }

  /// ليستة نوع واحد — بترمي `ApiException` عشان شاشة الليستة
  /// تقدر توري الخطأ وزرار «جرّب تاني».
  Future<List<HistoryEntry>> clientHistoryList(int clientId, String type) async {
    final res = await Api.I.clientHistoryList(clientId, type);

    return ((res['items'] ?? []) as List)
        .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// بترجع (رسالة الخطأ، رقم الفاتورة، الإجمالي)
  /// بترجّع (خطأ، رد الفاتورة كاملاً) — السامري بيتبني من رد السيرفر
  /// مش من حساب الأبلكيشن، عشان الرقم المعروض هو المتسجل بالظبط.
  /// [payment] بيتبعت للعميل المختلط بس — غير كده السيرفر بيتجاهله.
  Future<(String?, Map<String, dynamic>?)> createInvoice(
    Client c,
    Map<int, int> qtyByProduct, {
    Map<int, String>? units,
    String? payment,
    String? paperRef,
  }) async {
    // ⚠️ الكمية بتتبعت بوحدتها المكتوبة (2 كرتونة = qty:2 + unit:case)
    // — السيرفر هو اللي بيضرب للقطع، الأبلكيشن عمره ما يضرب
    final items = qtyByProduct.entries
        .where((e) => e.value > 0)
        .map((e) => <String, dynamic>{
              'product_id': e.key,
              'qty': e.value,
              'unit': units?[e.key] ?? 'piece',
            })
        .toList();

    if (items.isEmpty) return (L.t('invoice_no_items'), null);

    // ⚠️ **الزيارة بقت إجبارية على السيرفر** (تدقيق ٨/٨/٢٠٢٦) — من
    // غير الفحص ده المندوب بياخد رسالة فاليديشن مالهاش معنى بدل ما
    // نقوله يعمل تشيك إن.
    if (c.visitId == null) return (L.t('invoice_needs_visit'), null);

    try {
      // ⚠️ **الموقع مع كل حدث** (تدقيق ٨/٨/٢٠٢٦). السيرفر بيستقبله
      // من زمان والأبلكيشن ماكانش بيبعته — فالفاتورة بتقع على
      // الخريطة بلا مكان والشاشة اللايف بتوري مسار فيه فجوات.
      // اختياري: GPS مقفول مايوقفش بيعة.
      final pos = await Locator.get();

      final res = await Api.I.createInvoice(
        clientId: c.id,
        visitId: c.visitId,
        lat: pos?.$1,
        lng: pos?.$2,
        items: items,
        // ⚠️ **بنبعت للمختلط بس.** إرساله دايماً مش هيكسر حاجة (السيرفر
        // بيتجاهله)، بس بيخلّي اللوج يقول إن الأبلكيشن اختار وهو ماختارش.
        payment: c.paymentChoice ? payment : null,
        paperRef: paperRef,
      );
      final inv = res['invoice'] as Map<String, dynamic>;
      await refresh();

      return (null, inv);
    } on ApiException catch (e) {
      return (e.message, null);
    } catch (e) {
      return (L.t('error_with', {'e': '$e'}), null);
    }
  }

  /// المتاح للرد + السياسات المسموحة — بترجّع الرد الخام للشاشة.
  ///
  /// ⚠️ **بترمي بدل ما ترجّع فاضي.** ده مش نداء تجميلي زي الأسعار:
  /// من غيره الشاشة مش عارفة العميل مسموح له إيه ولا متاح منه كام،
  /// والمندوب هيكتب أرقام والسيرفر يرفضها بعد ما يكون قال للعميل رقم.
  Future<(String?, Map<String, dynamic>?)> returnable(int clientId) async {
    try {
      return (null, await Api.I.returnable(clientId));
    } on ApiException catch (e) {
      return (e.message, null);
    } catch (e) {
      return (L.t('error_with', {'e': '$e'}), null);
    }
  }

  /// مرتجع من العميل — مستند بقيد دائن وبضاعة بتدخل العهدة مفصولة
  ///
  /// [conditions] لكل صنف: `good` أو `damaged` — الافتراضي سليم.
  /// [idemKey] بيتولّد مرة واحدة في الشاشة ومابيتغيّرش مع إعادة المحاولة.
  Future<(String?, Map<String, dynamic>?)> createReturn(
    Client c,
    Map<int, int> qtyByProduct, {
    Map<int, String>? units,
    Map<int, String>? conditions,
    // ═══ التقسيم سليم/تالف داخل نفس الصنف (١٥ أغسطس ٢٠٢٦) ═══
    //
    // بلاغ المالك: «لو واحد كرتونة نصها سليم ونصها تالف مش هعرف
    // أعمل كده». الشاشة كانت بتاخد حالة واحدة للسطر كله.
    //
    // [damagedPieces] = كام **قطعة** تالفة من الصنف ده.
    // [totalPieces]   = إجمالي قطع السطر (بعد تحويل الكرتونة/العلبة).
    //
    // ⚠️ **التقسيم بيتبعت بالقطعة إجبارياً** — نص كرتونة مش وحدة.
    // لو بعتنا `unit: case` مع كمية مكسورة السيرفر هيضربها في
    // معامل الكرتونة ويطلع رقم غلط.
    Map<int, int>? damagedPieces,
    Map<int, int>? totalPieces,
    required String policy,
    String? idemKey,
    String? note,
  }) async {
    final items = <Map<String, dynamic>>[];

    for (final e in qtyByProduct.entries) {
      if (e.value <= 0) continue;

      final pid = e.key;
      final dmg = damagedPieces?[pid] ?? 0;
      final tot = totalPieces?[pid] ?? 0;

      // مفيش تقسيم → سطر واحد بوحدته زي ما هي
      if (dmg <= 0 || tot <= 0 || dmg >= tot) {
        items.add({
          'product_id': pid,
          'qty': e.value,
          'unit': units?[pid] ?? 'piece',
          // التالف الكامل بيتبعت `damaged` حتى لو الخريطة ماقالتش
          'condition': dmg > 0 && dmg >= tot
              ? 'damaged'
              : (conditions?[pid] ?? 'good'),
        });

        continue;
      }

      // ⚠️ سطرين بالقطعة — السيرفر بيجمّعهم بـ`$wanted[pid][cond]`
      // فبيطلعوا بندين منفصلين في المستند، وده المطلوب بالظبط.
      items.add({
        'product_id': pid,
        'qty': tot - dmg,
        'unit': 'piece',
        'condition': 'good',
      });
      items.add({
        'product_id': pid,
        'qty': dmg,
        'unit': 'piece',
        'condition': 'damaged',
      });
    }

    if (items.isEmpty) return (L.t('invoice_no_items'), null);

    // نفس قاعدة الفاتورة — المرتجع كمان لازم زيارة مفتوحة
    if (c.visitId == null) return (L.t('invoice_needs_visit'), null);

    try {
      final pos = await Locator.get();

      final res = await Api.I.createReturn(
        clientId: c.id,
        visitId: c.visitId,
        policy: policy,
        lat: pos?.$1,
        lng: pos?.$2,
        items: items,
        idemKey: idemKey,
        note: note,
      );
      final ret = res['return'] as Map<String, dynamic>;
      await refresh();

      return (null, ret);
    } on ApiException catch (e) {
      return (e.message, null);
    } catch (e) {
      return (L.t('error_with', {'e': '$e'}), null);
    }
  }

  Future<String?> arrivePo(PurchaseOrder po) async {
    try {
      final pos = await Locator.get();
      await Api.I.arrivePo(po.id, lat: pos?.$1, lng: pos?.$2);
      await refresh();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  /// إلغاء التسليم بسبب — الأمر بيرجع «مستني» والمندوب يتحرك (١١/٨)
  Future<String?> cancelArrival(PurchaseOrder po, String reason) async {
    try {
      final pos = await Locator.get();
      await Api.I.cancelArrival(po.id, reason, lat: pos?.$1, lng: pos?.$2);
      await refresh();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  /// بترجّع (خطأ، رد السيرفر) — السامري (سلم إيه وإيه الفرق) من السيرفر.
  /// من غير items = تسليم كامل زي فلو السواق القديم بالظبط.
  Future<(String?, Map<String, dynamic>?)> deliverPo(
    PurchaseOrder po, {
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      final pos = await Locator.get();
      final res =
          await Api.I.deliverPo(po.id, items: items, lat: pos?.$1, lng: pos?.$2);
      await refresh();
      return (null, res);
    } on ApiException catch (e) {
      return (e.message, null);
    } catch (e) {
      return (L.t('error_with', {'e': '$e'}), null);
    }
  }

  /// المندوب عدّ البضاعة وأكّد استلامها من المخزن → تنزل عهدته
  Future<String?> receivePick(
    int id,
    List<Map<String, dynamic>> items, {
    String? note,
  }) async {
    if (items.isEmpty) return L.t('pick_order_no_items');

    try {
      await Api.I.receivePick(id, items, note: note);
      await refresh();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return L.t('error_with', {'e': '$e'});
    }
  }

  /// بترجّع (خطأ، اتوافق فوراً؟) — لما **المدير** هو اللي بيسجّل،
  /// السيرفر بيفتح العميل في نفس النداء وبيرجّع `approved: true`
  /// (١١ أغسطس ٢٠٢٦). المندوب بياخد false وبيستنى موافقة المدير.
  /// ⚠️ **بترجّع تلاتة مش اتنين** (١٥ أغسطس ٢٠٢٦): العنصر التالت هو
  /// قايمة العملاء الشبيهين لما السيرفر يطلب تأكيد. الشاشة بتوريهم
  /// في دايالوج وبتبعت تاني بـ`confirmDuplicate: true` لو المندوب
  /// متأكد إنه محل تاني. `null` = مفيش سؤال، الطلب اتبعت (أو فشل).
  Future<(String?, bool, List<Map<String, dynamic>>?)> submitClientRequest({
    required String name,
    String? phone,
    String? address,
    String? addressAr,
    int? zoneId,
    bool hasDocs = false,
    String? photoPath,
    String? docsPath,
    double? lat,
    double? lng,
    bool confirmDuplicate = false,
    // مرساة الليد (بايبلاين ٢٦/٨) — طلب جاي من تاب المحتملين
    int? leadId,
  }) async {
    try {
      final res = await Api.I.createClientRequest(
        name: name,
        phone: phone,
        address: address,
        addressAr: addressAr,
        zoneId: zoneId,
        hasDocs: hasDocs,
        photoPath: photoPath,
        docsPath: docsPath,
        lat: lat,
        lng: lng,
        confirmDuplicate: confirmDuplicate,
        leadId: leadId,
      );

      // ⚠️ **الطلب مااتسجّلش** — ده سؤال مش نجاح. ممنوع `refresh()`
      // هنا ولا رسالة «اتبعت»، لأن مفيش حاجة اتبعتت.
      if (res['needs_confirm'] == true) {
        final raw = res['duplicates'];
        final list = raw is List
            ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
            : <Map<String, dynamic>>[];

        return (null, false, list);
      }

      await refresh();
      // ⚠️ سيرفر قديم من غير المفتاح = false — نفس رسالة زمان
      return (null, res['approved'] == true, null);
    } on ApiException catch (e) {
      return (e.message, false, null);
    } catch (e) {
      return (L.t('error_with', {'e': '$e'}), false, null);
    }
  }

  /// عدد الإشعارات اللي لسه مااتقريتش — ده اللي الشارة بتعرضه.
  ///
  /// ⚠️ **مش `notifications.length`.** الشارة كانت بتعد الإشعارات
  /// كلها (آخر 20)، فالمندوب يفتحها ويقفلها والرقم زي ما هو —
  /// شارة عمرها ما بتفضى بتتحول لديكور ومحدش بيبص لها تاني.
  int get unreadCount => notifications.where((n) => !n.isRead).length;

  /// تعليم الإشعارات كمقروءة.
  ///
  /// ⚠️ **التحديث المحلي الأول والسيرفر بعده** — الشارة بتفضى في
  /// نفس اللحظة اللي المندوب بيفتح فيها القايمة، مش بعد ما الطلب
  /// يروح ويرجع على شبكة موبايل ضعيفة.
  ///
  /// ⚠️ ولو الطلب فشل، مافيش رجوع للحالة القديمة: أسوأ نتيجة إن
  /// الشارة تفضى دلوقتي وترجع في المزامنة الجاية — أهون بكتير من
  /// رسالة خطأ على حاجة المندوب مش طالبها أصلاً.
  Future<void> markNotificationsRead() async {
    if (unreadCount == 0) {
      return;
    }

    for (final n in notifications) {
      n.isRead = true;
    }

    notifyListeners();

    try {
      await Api.I.readNotifications();
    } catch (_) {
      // المزامنة الجاية هتجيب الحالة الصح من السيرفر
    }
  }
}
