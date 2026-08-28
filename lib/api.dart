import 'dart:convert';
import 'l10n.dart';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// عميل الـ API بتاع PROMAX ERP
class Api {
  static final Api I = Api._();
  Api._();

  /// عنوان السيرفر اللايف.
  ///
  /// ⚠️ **كان بيشاور على `10.0.2.2:8000` (إيموليتور أندرويد).**
  /// يعني أي تليفون حقيقي بيتنصّب عليه الأبلكيشن كان بيحاول يتصل
  /// بجهاز مش موجود ويقول «مافيش سيرفر» — والخطوة دي كانت
  /// بتتنسى في كل build.
  ///
  /// ⚠️ للتطوير المحلي: شغّل بـ`flutter run` (وضع الديبج) —
  /// `_defaultBase()` بترجّع `10.0.2.2` لوحدها. زرار «عنوان
  /// السيرفر» اتشال من شاشة الدخول خالص.
  static const String liveBase = 'https://erp.promaxfoods.com/api';

  static String baseUrl = _defaultBase();

  static String _defaultBase() {
    // ⚠️ **اللايف دايماً — حتى في الديبج** (قرار المالك 2026-08-02).
    // التطوير المحلي بقى بـ`--dart-define=API_BASE=http://10.0.2.2:8000/api`
    // بدل ما يبقى الافتراضي — عشان اللي بيجرب على الإيموليتور
    // مايقعدش يحارب «مافيش سيرفر» وهو فاكر المشكلة في الباسورد.
    const override = String.fromEnvironment('API_BASE');

    return override.isNotEmpty ? override : liveBase;
  }

  String? token;

  /// ⚠️ **بوابة الحضور — نقطة واحدة لكل الشاشات** (2026-08-08).
  /// السيرفر بيرد `423` على أي أكشن قبل تسجيل الحضور. بدل ما نمسك
  /// الخطأ ده في 20 شاشة، بنحطه هنا وبيتعرض بوب أب واحد فوق
  /// الأبلكيشن كله (`_AttendanceGate` في `main.dart`).
  static final ValueNotifier<String?> blocked = ValueNotifier(null);

  /// ⚠️ نوع المنع: `attendance_required` ولا `warehouse_required` —
  /// البوابة بتقرر توديه لأنهي شاشة على أساسه
  static final ValueNotifier<String> blockedCode =
      ValueNotifier('attendance_required');

  /// الإدارة وقفت الموظف — شاشة كاملة مالهاش رجوع
  static final ValueNotifier<String?> suspended = ValueNotifier(null);

  /// ⚠️ **لغة الأبلكيشن بتتبعت مع كل ريكوست** (2026-08-08).
  ///
  /// فيه نصوص بتتولد **عند السيرفر** مش في الأبلكيشن — ليبل البانش
  /// («حضور»، «بريك»)، أسماء الحالات، ورسايل الأخطاء. السيرفر كان
  /// بياخد اللغة من `users.locale` بس، والمندوب اللي غيّر لغة
  /// **الأبلكيشن** لعربي كان لسه بياخدها إنجليزي — فحركة اليوم تطلع
  /// عربي في العناوين وإنجليزي في السطور.
  ///
  /// ⚠️ والهيدر ده **اقتراح مش أمر**: السيرفر بيقبل `ar`/`en` بس،
  /// وأي حاجة تانية بيرجع لافتراضيه.
  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-App-Locale': L.locale,
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// ⚠️ **`quiet` = «الريكوست ده مش أكشن من الموظف»** (2026-08-08).
  ///
  /// البوابة اللي بتفتح بوب أب «سجّل حضورك» كانت بتتفتح من **أي**
  /// رد 423 — بما فيه النداءات اللي الأبلكيشن بيعملها لوحده عند
  /// الفتح (البينج، تسجيل توكن الإشعارات، الليدز القريبة، البلس).
  /// النتيجة: البوب أب بيطلع على شاشة اللودينج قبل ما الموظف
  /// يلمس حاجة، وبيرجع كل شوية لوحده.
  ///
  /// دلوقتي الرد 423 على ريكوست `quiet` بيترمي كاستثناء عادي
  /// **من غير** ما يفتح البوابة. الحارس على السيرفر مكانه —
  /// اللي اتغيّر هو **إمتى نزنّ على الموظف**.
  Future<Map<String, dynamic>> _decode(http.Response r, {bool quiet = false}) async {
    final body = r.body.isEmpty ? '{}' : r.body;
    late final Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      // السيرفر رجّع HTML (صفحة خطأ) — نطلّع أول سطر مفيد منها
      final plain = body
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final cut = plain.length > 180 ? plain.substring(0, 180) : plain;
      throw ApiException(
          plain.isEmpty
              ? L.t('bad_response', {'code': '${r.statusCode}'})
              : L.t('server_error', {'code': '${r.statusCode}', 'body': '$cut'}),
          r.statusCode);
    }

    // ⚠️ **403 + `account_blocked` = الإدارة وقفت الموظف** (2026-08-08).
    //
    // كان بيرجع 401 زي أي جلسة منتهية — فالأبلكيشن يمسح التوكن
    // ويرجّعه للوجين، فيدخل بنجاح (اللوجين ماكانش بيفحص) ويتوقف
    // تاني في لفة لا نهائية. والموظف بيقول «الأبلكيشن بايظ» وهو
    // موقوف بقرار إداري.
    if (r.statusCode == 403 && json['code'] == 'account_blocked') {
      suspended.value = json['message']?.toString() ?? '';
      throw ApiException(json['message']?.toString() ?? '', 403);
    }

    // ⚠️ **423 = مش مسجّل حضور أو مش جوه المخزن.** بيتبلّغ قبل أي
    // معالجة تانية عشان الشاشة تعرض البوب أب المناسب بدل رسالة خطأ
    // عامة مالهاش معنى. الـ`code` بيفرّق بين الاتنين.
    if (r.statusCode == 423) {
      if (!quiet) {
        blockedCode.value = json['code']?.toString() ?? 'attendance_required';
        blocked.value = json['message']?.toString() ?? '';
      }
      throw ApiException(json['message']?.toString() ?? '', 423);
    }

    if (r.statusCode >= 400) {
      // رسائل الفاليديشن بتيجي في errors
      final errors = json['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        final msg = first is List && first.isNotEmpty ? first.first : first;
        throw ApiException(msg.toString(), r.statusCode);
      }
      throw ApiException(
          json['message']?.toString() ?? L.t('http_error', {'code': '${r.statusCode}'}),
          r.statusCode);
    }

    return json;
  }

  /// ⚠️ **القراءة عمرها ما بتفتح البوابة.** الدوكترين على السيرفر إن
  /// القراءة مفتوحة قبل الحضور — فأي 423 على `GET` غلط في راوت مش
  /// أكشن من الموظف، ومايستاهلش بوب أب في وشه.
  Future<Map<String, dynamic>> get(String path) async {
    try {
      final r = await http
          .get(_uri(path), headers: _headers)
          .timeout(const Duration(seconds: 20));
      return _decode(r, quiet: true);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(_netError(e), 0);
    }
  }

  /// [quiet] للنداءات اللي الأبلكيشن بيعملها لوحده (بينج، تسجيل
  /// توكن) — دي مالهاش لازمة تزنّ على الموظف لو اترفضت.
  Future<Map<String, dynamic>> post(String path,
      [Map<String, dynamic>? body, bool quiet = false]) async {
    try {
      final r = await http
          .post(_uri(path), headers: _headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 20));
      return _decode(r, quiet: quiet);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(_netError(e), 0);
    }
  }

  /// رسالة مفهومة لأخطاء الشبكة
  String _netError(Object e) {
    final s = e.toString();
    if (s.contains('TimeoutException')) {
      return L.t('server_down');
    }
    if (s.contains('SocketException') ||
        s.contains('Connection refused') ||
        s.contains('Failed host lookup')) {
      return L.t('no_server', {'url': '$baseUrl'});
    }
    return L.t('connection_error', {'e': '$s'});
  }

  // ---------- Endpoints ----------

  Future<Map<String, dynamic>> login(String login, String password) =>
      post('/login', {'login': login, 'password': password});

  Future<Map<String, dynamic>> bootstrap() => get('/bootstrap');

  // ═══ إشعارات فاير بيز (2026-08-07) ═══

  /// تسجيل توكن الجهاز — بيتنادى بعد الدخول وكل ما التوكن يتجدد.
  ///
  /// ⚠️ السيرفر بيربط التوكن باليوزر الحالي وبيشيله من أي يوزر تاني
  /// كان مسجّل بيه — التليفون اللي بيتسلّم لموظف جديد مايفضلش ياخد
  /// إشعارات اللي قبله.
  Future<Map<String, dynamic>> registerDevice(String token,
          {String platform = 'android', String? version}) =>
      post('/device-token', {
        'token': token,
        'platform': platform,
        if (version != null) 'app_version': version,
      }, true);

  /// مسح توكن الجهاز — بيتنادى عند الخروج.
  ///
  /// ⚠️ **POST مش DELETE.** الكلاس ده مافيهوش ميثود عامة للـDELETE،
  /// وإضافة واحدة عشان نداء واحد أكبر من اللزوم — الراوت بيقبل
  /// الاتنين (`Route::match(['post','delete'], ...)`).
  Future<Map<String, dynamic>> forgetDevice(String token) =>
      post('/device-token/forget', {'token': token}, true);

  // ═══ الحوافز والليدز — الأبديت الكبير (2026-08-06) ═══

  /// بينج فتح الأبلكيشن — بيتعد في لوحة الأداء
  Future<Map<String, dynamic>> appOpen({double? lat, double? lng}) =>
      post('/app-open', {
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      }, true);

  /// شاشة التشجيع: تارجتات وتحقيق ونقاط وعمولة ورصيد التصفية
  Future<Map<String, dynamic>> myIncentives() => get('/my-incentives');

  /// العملاء المحتملين في النطاق حوالين المندوب — أليرت نمط أوبر
  Future<Map<String, dynamic>> nearbyLeads(double lat, double lng) =>
      get('/leads/nearby?lat=$lat&lng=$lng');

  /// قرار المندوب: accepted يتسكّن عليه · rejected مش بينوّر تاني
  // ═══ تاب العملاء المحتملين (بايبلاين ٢٦/٨) ═══

  /// ليداتي بالمناطق — المفتوحة + المكسوبة الشهر ده
  Future<Map<String, dynamic>> myLeads() => get('/leads/mine');

  /// تأكيد البيانات من الميدان — multipart عشان صورة المكان
  /// (فلو الليد المطور ٢٦/٨). النقطة الأولى في الحصاد.
  Future<Map<String, dynamic>> confirmLead(
    int id, {
    String? name,
    String? phone,
    String? contact,
    String? address,
    String? governorate,
    int? zoneId,
    String? note,
    double? lat,
    double? lng,
    String? photoPath,
  }) async {
    final req = http.MultipartRequest('POST', _uri('/leads/$id/confirm'))
      ..headers.addAll({
        'Accept': 'application/json',
        'X-App-Locale': L.locale,
        if (token != null) 'Authorization': 'Bearer $token',
      });

    void put(String k, String? v) {
      if (v != null && v.isNotEmpty) req.fields[k] = v;
    }

    put('name', name);
    put('phone', phone);
    put('contact_name', contact);
    put('address', address);
    put('governorate', governorate);
    if (zoneId != null) req.fields['zone_id'] = zoneId.toString();
    put('note', note);
    if (lat != null && lng != null) {
      req.fields['lat'] = lat.toString();
      req.fields['lng'] = lng.toString();
    }
    if (photoPath != null) {
      req.files.add(await http.MultipartFile.fromPath('photo', photoPath));
    }

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    return _decode(await http.Response.fromStream(streamed));
  }

  /// فتح أكاونت فوري بعد التأكيد — بلا موافقة (قرار المالك ٢٦/٨)
  Future<Map<String, dynamic>> openLeadAccount(int id) =>
      post('/leads/$id/open-account');

  /// تحديث حالة الليد — اتكلمنا/بنتفاوض/خسرناه بسبب
  Future<Map<String, dynamic>> leadSetStatus(int id, String status,
          {String? lostReason}) =>
      post('/leads/$id/status', {
        'status': status,
        if (lostReason != null && lostReason.isNotEmpty)
          'lost_reason': lostReason,
      });

  Future<Map<String, dynamic>> leadAction(int leadId, String action) =>
      post('/leads/$leadId/action', {'action': action});

  /// خط سير النهارده لوحده — بيجي مع bootstrap كمان
  Future<Map<String, dynamic>> journey() => get('/journey');

  /// تغيير لغة اليوزر على السيرفر — الشاشة والإشعارات بيتبعوها
  Future<Map<String, dynamic>> setLocale(String locale) =>
      post('/locale', {'locale': locale});

  /// أسعار العميل للأصناف اللي في العهدة.
  ///
  /// ⚠️ **موجودة عشان الرقم اللي المندوب بيقوله للعميل يبقى هو
  /// الرقم اللي هيطلع في الفاتورة.** سعر العهدة سعر قائمة مشتق من
  /// رول المندوب؛ الفاتورة بتتحسب من قايمة العميل وخصمه.
  Future<Map<String, dynamic>> clientPrices(int clientId) =>
      get('/clients/$clientId/prices');

  Future<Map<String, dynamic>> checkIn(int clientId, {double? lat, double? lng}) =>
      post('/visits/check-in', {'client_id': clientId, 'lat': lat, 'lng': lng});

  Future<Map<String, dynamic>> checkOut(int visitId) =>
      post('/visits/$visitId/check-out');

  /// ⚠️ الكاش/الآجل بيتحدد **عند السيرفر** من تعريف العميل — الأبلكيشن
  /// مابيبعتش `payment` إلا للعميل اللي الإدارة عرّفته «الاتنين».
  ///
  /// ⚠️ **والسيرفر مابيثقش في اللي جاي.** حتى لو بعتنا `payment`
  /// لعميل كاش، السيرفر بيرميه ويحط `cash` — فالحقل ده اقتراح مش
  /// أمر، وده اللي بيمنع توكن معدّل يفتح مديونية محدش قررها.
  Future<Map<String, dynamic>> createInvoice({
    required int clientId,
    int? visitId,
    required List<Map<String, dynamic>> items,
    String? payment,
    double? lat,
    double? lng,
    // سيريال الفاتورة الورقية المختومة (١٩/٨) — للمطابقة الدفترية
    String? paperRef,
  }) =>
      post('/invoices', {
        'client_id': clientId,
        'visit_id': visitId,
        'items': items,
        'payment': payment,
        'lat': lat,
        'lng': lng,
        'paper_ref': paperRef,
      });

  /// المتاح للرد + سياسات المرتجع المسموحة للعميل.
  ///
  /// ⚠️ **لازم تتنده قبل ما المندوب يكتب أي كمية.** المرتجع بقى
  /// مقفول على اللي العميل اشتراه فعلاً وبسعر فاتورته، والسياسة
  /// بتتحدد على العميل — فالشاشة من غير النداء ده بتخمّن.
  Future<Map<String, dynamic>> returnable(int clientId) =>
      get('/clients/$clientId/returnable');

  /// مرتجع من العميل — مستند بقيد دائن وبضاعة مفصولة في العهدة
  ///
  /// ⚠️ `idemKey` بيتولّد **مرة واحدة للشاشة** — إعادة الإرسال بعد
  /// انقطاع شبكة بترجّع نفس المستند بدل ما تكتب قيد دائن تاني.
  Future<Map<String, dynamic>> createReturn({
    required int clientId,
    int? visitId,
    required String policy,
    required List<Map<String, dynamic>> items,
    String? idemKey,
    String? note,
    double? lat,
    double? lng,
  }) =>
      post('/returns', {
        'client_id': clientId,
        'visit_id': visitId,
        'policy': policy,
        'items': items,
        'idem_key': idemKey,
        'note': note,
        'lat': lat,
        'lng': lng,
      });

  /// ⚠️ **`lat/lng` في كل حدث** (تدقيق ٨/٨/٢٠٢٦). السيرفر بيستقبلهم
  /// من زمان والأبلكيشن ماكانش بيبعتهم — فالفاتورة والمرتجع وأمر
  /// التوريد وزيارة البروموتر كلهم بيقعوا على الخريطة بلا مكان،
  /// والشاشة اللايف بتوري مسار فيه فجوات.
  Future<Map<String, dynamic>> arrivePo(int poId, {double? lat, double? lng}) =>
      post('/pos/$poId/arrive', {'lat': lat, 'lng': lng});

  /// إلغاء التسليم بعد «وصول» — سبب إجباري والأمر بيرجع «مستني»
  /// (١١/٨ مساءً): المندوب كان بيتحبس «لازم تسلّم» لو المحل قافل.
  Future<Map<String, dynamic>> cancelArrival(int poId, String reason,
          {double? lat, double? lng}) =>
      post('/pos/$poId/cancel-arrival',
          {'reason': reason, 'lat': lat, 'lng': lng});

  // ═══ دخول وخروج المخزن (2026-08-08) ═══
  //
  // ⚠️ **الاتنين بره حارس `in.warehouse`** — دول اللي بيفتحوه أصلاً.
  Future<Map<String, dynamic>> warehouseIn(int warehouseId,
          {double? lat, double? lng}) =>
      post('/warehouse-visits',
          {'warehouse_id': warehouseId, 'lat': lat, 'lng': lng});

  Future<Map<String, dynamic>> warehouseOut({double? lat, double? lng}) =>
      post('/warehouse-visits/out', {'lat': lat, 'lng': lng});

  /// التسليم — من غير items = تسليم كامل (فلو السواق القديم)؛
  /// بـitems = الكميات المسلَّمة فعلاً بوحدتها والسيرفر بيضرب ويقيّد بيها
  Future<Map<String, dynamic>> deliverPo(int poId,
          {List<Map<String, dynamic>>? items, double? lat, double? lng}) =>
      post('/pos/$poId/deliver', {
        if (items != null) 'items': items,
        'lat': lat,
        'lng': lng,
      });

  /// طلب عميل جديد — بيتبعت multipart عشان يشيل صورة المكان وملف الأوراق
  Future<Map<String, dynamic>> createClientRequest({
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
    final req = http.MultipartRequest('POST', _uri('/client-requests'))
      ..headers.addAll({
        'Accept': 'application/json',
        // ⚠️ رفع الملفات بيرجّع رسايل خطأ من السيرفر كمان
        'X-App-Locale': L.locale,
        if (token != null) 'Authorization': 'Bearer $token',
      })
      ..fields['name'] = name
      ..fields['has_docs'] = hasDocs ? '1' : '0'
      // ⚠️ تجاوز واعٍ لحارس التكرار — بيتبعت بعد ما المندوب يشوف
      // الشبيهين ويأكد إنه محل تاني (شوف `_submit` في new_client.dart)
      ..fields['confirm_duplicate'] = confirmDuplicate ? '1' : '0';

    if (phone != null && phone.isNotEmpty) req.fields['phone'] = phone;
    if (address != null && address.isNotEmpty) req.fields['address'] = address;
    // العنوان العربي والمنطقة — من زرار «اسحب اللوكيشن» (٢٠/٨)
    if (addressAr != null && addressAr.isNotEmpty) {
      req.fields['address_ar'] = addressAr;
    }
    if (zoneId != null) req.fields['zone_id'] = zoneId.toString();
    if (leadId != null) req.fields['lead_id'] = leadId.toString();
    // ⚠️ الإحداثيات بتتبعت لو اتلقطت بس — المدير بيكشف العنوان منها
    // في فورم الاعتماد. الاتنين مع بعض أو ولا واحد.
    if (lat != null && lng != null) {
      req.fields['lat'] = lat.toString();
      req.fields['lng'] = lng.toString();
    }

    if (photoPath != null) {
      req.files.add(await http.MultipartFile.fromPath('photo', photoPath));
    }
    if (docsPath != null) {
      req.files.add(await http.MultipartFile.fromPath('docs', docsPath));
    }

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final r = await http.Response.fromStream(streamed);

    // ⚠️ **409 رد مقصود مش خطأ** (١٥ أغسطس ٢٠٢٦): السيرفر لقى عميل
    // شبه ده وبيسأل «تكمّل؟». `_decode` كانت هترميها كـ`ApiException`
    // برسالة بس، والشاشة محتاجة **قايمة** الشبيهين عشان توريهم قبل
    // ما المندوب يقرر. بنرجّع الجسم زي ما هو والشاشة بتقرا
    // `needs_confirm`.
    if (r.statusCode == 409) {
      try {
        final j = jsonDecode(r.body.isEmpty ? '{}' : r.body);
        if (j is Map<String, dynamic>) return j;
      } catch (_) {
        // جسم مش JSON — نسيبها لـ`_decode` تطلّع رسالة مفهومة
      }
    }

    return _decode(r);
  }

  Future<void> readNotifications() => post('/notifications/read');

  /// صورة الموظف من «حسابي» (٩/٨) — بتظهر في التراكينج والحضور
  /// على الداش بورد. بيرجّع `user` كامل بالرابط الجديد.
  Future<Map<String, dynamic>> uploadAvatar(String path) async {
    final req = http.MultipartRequest('POST', _uri('/me/avatar'))
      ..headers.addAll({
        'Accept': 'application/json',
        'X-App-Locale': L.locale,
        if (token != null) 'Authorization': 'Bearer $token',
      });
    req.files.add(await http.MultipartFile.fromPath('avatar', path));

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final r = await http.Response.fromStream(streamed);

    return _decode(r);
  }

  // ═══ أوبشنات الزيارة التلاتة (2026-08-09) ═══

  /// تحصيل من العميل أثناء زيارة مفتوحة — multipart عشان صورة الإثبات.
  ///
  /// ⚠️ **غير الكاش لازم معاه صورة** — السيرفر بيرفض من غيرها،
  /// والشاشة بتمنع الإرسال أصلاً عشان المندوب مايستناش رد فاشل.
  Future<Map<String, dynamic>> collectVisit(
    int visitId, {
    required double amount,
    required String method,
    String? reference,
    String? chequeBank,
    String? chequeDue,
    String? note,
    String? proofPath,
    String? idemKey,
  }) async {
    final req = http.MultipartRequest('POST', _uri('/visits/$visitId/collect'))
      ..headers.addAll({
        'Accept': 'application/json',
        'X-App-Locale': L.locale,
        if (token != null) 'Authorization': 'Bearer $token',
      })
      ..fields['amount'] = '$amount'
      ..fields['method'] = method;

    if (reference != null && reference.isNotEmpty) {
      req.fields['reference'] = reference;
    }
    if (chequeBank != null && chequeBank.isNotEmpty) {
      req.fields['cheque_bank'] = chequeBank;
    }
    if (chequeDue != null && chequeDue.isNotEmpty) {
      req.fields['cheque_due'] = chequeDue;
    }
    if (note != null && note.isNotEmpty) req.fields['note'] = note;
    // ⚠️ نفس درس المرتجعات: المفتاح بيتولّد مرة للشاشة، فإعادة
    // النداء بعد تايم أوت بترجّع نفس القيد بدل قيد تاني
    if (idemKey != null && idemKey.isNotEmpty) {
      req.fields['idem_key'] = idemKey;
    }
    if (proofPath != null) {
      req.files.add(await http.MultipartFile.fromPath('proof', proofPath));
    }

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    return _decode(await http.Response.fromStream(streamed));
  }

  /// صورة رف قبل/بعد على زيارة السيلز — متعددة، كل نداء بيضيف صورة
  Future<Map<String, dynamic>> visitShelfPhoto(
      int visitId, String stage, String photoPath) async {
    final req =
        http.MultipartRequest('POST', _uri('/visits/$visitId/shelf-photo'))
          ..headers.addAll({
            'Accept': 'application/json',
            'X-App-Locale': L.locale,
            if (token != null) 'Authorization': 'Bearer $token',
          })
          ..fields['stage'] = stage
          ..files.add(await http.MultipartFile.fromPath('photo', photoPath));

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    return _decode(await http.Response.fromStream(streamed));
  }

  /// الكتالوج الكامل بأسعار العميل — لشاشة طلب البضاعة
  Future<Map<String, dynamic>> clientCatalog(int clientId) =>
      get('/clients/$clientId/catalog');

  /// سامري تاريخ العميل — عدادات المربعات الخمسة
  Future<Map<String, dynamic>> clientHistory(int clientId) =>
      get('/clients/$clientId/history');

  /// أرقام كارت العميل — شاشة التشيك إن (موك أب ٢١/٨)
  Future<Map<String, dynamic>> clientCard(int clientId) =>
      get('/clients/$clientId/card');

  /// ليستة نوع واحد من تاريخ العميل بتفاصيله
  ///
  /// [type] لازم تكون من: sales · collections · returns · gifts · shelf
  /// (الراوت على السيرفر محصور فيهم بـ`whereIn`).
  Future<Map<String, dynamic>> clientHistoryList(int clientId, String type) =>
      get('/clients/$clientId/history/$type');

  /// طلب بضاعة لعميل من عند العميل — بيدخل فلو الريفيل الموجود
  Future<Map<String, dynamic>> createGoodsRequest(
          int visitId, List<Map<String, dynamic>> items, String? note) =>
      post('/goods-requests',
          {'visit_id': visitId, 'items': items, 'note': note});

  // ═══ لوكيشن العميل من الأبلكيشن (١٤ أغسطس ٢٠٢٦) ═══

  /// اقتراح العنوان والمحافظة والمنطقة من نقطة.
  ///
  /// ⚠️ **بيرجّع 200 حتى لو الخريطة مالقيتش عنوان** — `matched:false`
  /// والخانات فاضية، والمنطقة بتفضل موجودة لأنها محسوبة من داتابيز
  /// السيرفر مش من الإنترنت. الشاشة بتكمّل عادي والمندوب بيكتب بإيده.
  ///
  /// ⚠️ بيرجّع كمان `governorates` و`zones` للدروب داون — مش في
  /// البوت ستراب عشان مايتحمّلوش مع كل مزامنة.
  Future<Map<String, dynamic>> clientGeocode(
          int clientId, double lat, double lng) =>
      post('/clients/$clientId/geocode', {'lat': lat, 'lng': lng});

  /// المحافظات والمناطق **من غير نقطة**.
  ///
  /// ⚠️ الدروب داون كانت بتتملّى من رد الجيوكودينج بس، فلو الـGPS
  /// بره مصر (الإميوليتر لوكيشنه كاليفورنيا) الرد بيبقى 422 والقوايم
  /// ماتوصلش — والمندوب يلاقيهم فاضيين ومالوش أي طريقة يكمّل.
  /// الشاشة بتنده دي أول ما تفتح.
  Future<Map<String, dynamic>> geoOptions() => get('/geo/options');

  /// اقتراح عنوان/محافظة/منطقة من نقطة — لشاشة تسجيل عميل جديد
  /// (٢٠/٨). نفس رد `geocode` بالحرف بس من غير عميل.
  Future<Map<String, dynamic>> geoSuggest(double lat, double lng) =>
      post('/geo/suggest', {'lat': lat, 'lng': lng});

  /// حركة صنف في عهدة المندوب — شاشة تفاصيل الصنف (٢٠/٨).
  /// من غير تواريخ = النهاردة بس.
  Future<Map<String, dynamic>> custodyProductMovements(int productId,
      {String? from, String? to}) {
    final q = <String>[
      if (from != null) 'from=$from',
      if (to != null) 'to=$to',
    ].join('&');

    return get(
        '/custody/products/$productId/movements${q.isEmpty ? '' : '?$q'}');
  }

  /// حفظ لوكيشن العميل — بيتكتب بمصدر `rep_app` ومتأكد على طول،
  /// فالعميل بيخرج من طابور «جاهز للتأكيد» في الداشبورد فوراً.
  ///
  /// ⚠️ الخانة الفاضية معناها «ماتغيّرش» مش «امسح» — السيرفر بيتجاهل
  /// السترنج الفاضية، فمابنبعتش خانة المندوب ماكتبش فيها حاجة.
  Future<Map<String, dynamic>> saveClientLocation(
    int clientId, {
    required double lat,
    required double lng,
    String? address,
    String? addressAr,
    String? governorate,
    int? zoneId,
  }) =>
      post('/clients/$clientId/location', {
        'lat': lat,
        'lng': lng,
        if (address != null && address.isNotEmpty) 'address': address,
        if (addressAr != null && addressAr.isNotEmpty) 'address_ar': addressAr,
        if (governorate != null && governorate.isNotEmpty)
          'governorate': governorate,
        if (zoneId != null) 'zone_id': zoneId,
      });

  // ═══ أمين المخزن — أوامر التجهيز (2026-08-09) ═══

  /// طلبات البضاعة بتاعتي — شاشة «طلباتي» (2026-08-09)
  Future<Map<String, dynamic>> myGoodsRequests() => get('/my-goods-requests');

  /// تحصيلات الميدان للمحاسب — قراءة بس (2026-08-09)
  Future<Map<String, dynamic>> accountantCollections() =>
      get('/accountant/collections');

  Future<Map<String, dynamic>> keeperPicks({bool history = false}) =>
      get('/keeper/picks${history ? '?history=1' : ''}');

  Future<Map<String, dynamic>> keeperPick(int id) => get('/keeper/picks/$id');

  Future<Map<String, dynamic>> keeperStart(int id) =>
      post('/keeper/picks/$id/start');

  Future<Map<String, dynamic>> keeperReady(int id,
          [List<Map<String, dynamic>>? items]) =>
      post('/keeper/picks/$id/ready', {if (items != null) 'items': items});

  // ---------- أوامر التجهيز (استلام من المخزن) ----------

  /// بصمة الحالة — ريكوست رخيص بيتنادى كل 10 ثواني.
  ///
  /// ⚠️ **مايتحطش عليه أي منطق تقيل.** ده اللي بيخلّي الأبلكيشن
  /// لايف: بيرجّع string واحد، ولو اتغيّر بس ساعتها بننده البوت
  /// ستراب الكامل.
  Future<Map<String, dynamic>> pulse() => get('/pulse');
  /// إصدار الأبلكيشن — **من غير توكن**، بيشتغل قبل اللوجين كمان
  Future<Map<String, dynamic>> appVersion() => get('/app-version');

  // ═══ الحضور والانصراف — HR (2026-08-08) ═══

  Future<Map<String, dynamic>> attendance() => get('/attendance');

  /// `type`: in · break · back · out
  Future<Map<String, dynamic>> punch(String type, {double? lat, double? lng}) =>
      post('/attendance/punch', {
        'type': type,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      });

  Future<Map<String, dynamic>> picks() => get('/picks');

  /// مبيعات ومرتجعات المندوب — بفلتر تاريخ اختياري (Y-m-d)
  Future<Map<String, dynamic>> mySales({String? from, String? to}) => get(
      '/invoices${from != null ? '?from=$from${to != null ? '&to=$to' : ''}' : ''}');

  /// كل استلامات العهدة اللي تمّت — بتواريخها وبنودها
  Future<Map<String, dynamic>> picksHistory() => get('/picks?history=1');

  Future<Map<String, dynamic>> pick(int id) => get('/picks/$id');

  /// المندوب عدّ البضاعة وأكّد الاستلام — الكميات بتنزل عهدته
  Future<Map<String, dynamic>> receivePick(
    int id,
    List<Map<String, dynamic>> items, {
    String? note,
  }) =>
      post('/picks/$id/receive', {'items': items, 'note': note});

  // ---------- البروموتر ----------

  Future<Map<String, dynamic>> promoterBootstrap() => get('/promoter/bootstrap');

  Future<Map<String, dynamic>> startMerchVisit(int clientId) =>
      post('/promoter/visits', {'client_id': clientId});

  /// رفع صورة الرف — stage: before / after
  Future<Map<String, dynamic>> uploadShelfPhoto(
      int visitId, String stage, String photoPath) async {
    final req = http.MultipartRequest(
        'POST', _uri('/promoter/visits/$visitId/photo'))
      ..headers.addAll({
        'Accept': 'application/json',
        // ⚠️ رفع الملفات بيرجّع رسايل خطأ من السيرفر كمان
        'X-App-Locale': L.locale,
        if (token != null) 'Authorization': 'Bearer $token',
      })
      ..fields['stage'] = stage
      ..files.add(await http.MultipartFile.fromPath('photo', photoPath));

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    return _decode(await http.Response.fromStream(streamed));
  }

  Future<Map<String, dynamic>> saveRefill(
          int visitId, List<Map<String, dynamic>> lines,
          {double? lat, double? lng}) =>
      post('/promoter/visits/$visitId/refill',
          {'lines': lines, 'lat': lat, 'lng': lng});

  Future<Map<String, dynamic>> requestReplenishment(
          int visitId, List<Map<String, dynamic>> items, String? note) =>
      post('/promoter/visits/$visitId/replenishment', {
        'items': items,
        'note': note,
      });

  Future<Map<String, dynamic>> closeMerchVisit(int visitId) =>
      post('/promoter/visits/$visitId/close');

  // ---------- المدير ----------

  Future<Map<String, dynamic>> managerBootstrap() => get('/manager/bootstrap');

  Future<Map<String, dynamic>> managerRep(int userId) =>
      get('/manager/reps/$userId');

  Future<Map<String, dynamic>> decideRequest(
    int requestId,
    String decision, {
    double? discount,
    String? note,
  }) =>
      post('/manager/requests/$requestId/decide', {
        'decision': decision,
        'discount': discount,
        'note': note,
      });

  /// موافقة على طلب ريفيل وتنزيله على مندوب — بيتحول لأمر توريد
  Future<Map<String, dynamic>> assignReplenishment(
    int requestId,
    int assignedTo, {
    String priceMode = 'channel',
  }) =>
      post('/manager/replenishments/$requestId/assign', {
        'assigned_to': assignedTo,
        'price_mode': priceMode,
      });

  Future<Map<String, dynamic>> cancelReplenishment(int requestId, {String? note}) =>
      post('/manager/replenishments/$requestId/cancel', {'note': note});
}

class ApiException implements Exception {
  final String message;

  /// كود HTTP — أو 0 لو المشكلة شبكة (مفيش رد أصلاً).
  /// بيخلّي الشاشات تفرّق: بيانات غلط (401) ولا ممنوع (403) ولا
  /// السيرفر واقع (5xx) ولا النت/العنوان (0).
  final int status;

  ApiException(this.message, [this.status = -1]);
  @override
  String toString() => message;
}
