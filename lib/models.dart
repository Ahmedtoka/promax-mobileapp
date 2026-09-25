import 'package:flutter/material.dart';
import 'l10n.dart';

// ================= Helpers =================

/// أول عنصر أو null (بدل firstOrNull اللي محتاج package:collection)
T? firstOrNull<T>(Iterable<T> items) {
  for (final e in items) {
    return e;
  }
  return null;
}

String money(num v) {
  final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  final parts = s.split('.');
  final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return '${whole}${parts.length > 1 ? '.${parts[1]}' : ''} ${L.t('currency')}';
}

/// اليوم بس — «آخر زيارة» وما شابه
String fmtDay(DateTime t) {
  final l = t.toLocal();

  return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

/// تاريخ + ساعة — للهيستوري (fmtTime للساعة بس)
String fmtDate(DateTime t) {
  final l = t.toLocal();
  final d =
      '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';

  return '$d ${fmtTime(t)}';
}

String fmtTime(DateTime t) {
  final l = t.toLocal();
  final h12 = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final m = l.minute.toString().padLeft(2, '0');
  // ⚠️ ص/م بتتغيّر مع اللغة — «ص» في واجهة إنجليزي بتبان غلط
  final p = l.hour < 12 ? L.t('am') : L.t('pm');
  return '$h12:$m $p';
}

DateTime? parseTime(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

(Color, String) clientCatInfo(String cat) => switch (cat) {
      'danger' => (const Color(0xFFB00020), L.t('cash_only')),
      'watch' => (const Color(0xFFB86E00), L.t('watch')),
      'grow' => (const Color(0xFF0E7C5A), L.t('grow')),
      'idle' => (Colors.grey, L.t('idle')),
      'credit' => (const Color(0xFF1565C0), L.t('credit_balance')),
      'internal' => (const Color(0xFF6A1B9A), L.t('internal')),
      _ => (const Color(0xFF1565C0), L.t('cat_ok')),
    };

// ================= Models =================

class AppUser {
  final int id;
  final String name;
  final String code;
  final String role; // rep / courier
  final String roleLabel;
  final String? zone;

  /// صورة الموظف (٩/٨) — null لو لسه مارفعهاش، والواجهة بتقع
  /// على دايرة بأول حرف من اسمه
  final String? avatarUrl;

  AppUser.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'] ?? '',
        code = j['code'] ?? '',
        role = j['role'] ?? 'rep',
        roleLabel = j['role_label'] ?? '',
        zone = j['zone']?.toString(),
        avatarUrl = j['avatar_url']?.toString();

  bool get isCourier => role == 'driver';
  bool get isManager => role == 'manager' || role == 'admin';
  bool get isPromoter => role == 'promoter';
  bool get isSalesAgent => role == 'sales_agent';
}

class CustodyItem {
  final int productId;
  final String code;
  final String name;

  /// الاسمين — البحث بيلاقي «برو» عربي أو إنجليزي مهما كانت اللغة
  final String nameAr;
  final String nameEn;

  /// صورة المنتج (رابط كامل) — null لو مفيش
  final String? image;
  final String unit;
  final double price;
  final int assigned;
  final bool taxable;
  final double taxRate;
  int sold;

  /// مرتجع العملاء **السليم** — بضاعة راجعة في العربية، مش للبيع
  final int returnedIn;

  /// مرتجع العملاء **التالف** — بيتسلّم للمخزن لوحده وقت التصفية.
  /// ⚠️ عمود مستقل عن `returnedIn`: السليم بيرجع للبيع والتالف لأ.
  final int damagedIn;

  /// تدريج الوحدات: قطع العلبة وقطع الكرتونة (0 = الوحدة دي مش معرّفة).
  /// ⚠️ عرض واختيار بس — الضرب للقطع بيحصل **في السيرفر** وقت البيع.
  final int boxUnits;
  final int caseUnits;
  final int _remaining;

  /// هوية الباتش (١٩/٨) — الصف الواحد من السيرفر = باتش واحد.
  /// في الصف المدموج (byProduct) بتبقى فاضية — التفاصيل من الصفوف
  /// الخام في شيت الباتشات.
  final String batch;
  final String? expires;
  final int? daysLeft;

  /// العائلة (١٩/٨) — التجميع والترتيب في شاشة العهدة
  final String family;
  final String familyLabel;

  /// هدايا وعينات اتصرفت من الصنف (٢٠/٨) — كارت «أرقام النهاردة»
  final int gifted;

  CustodyItem.fromJson(Map<String, dynamic> j)
      : productId = j['product_id'],
        code = j['code'] ?? '',
        name = j['name'] ?? '',
        nameAr = j['name_ar'] ?? j['name'] ?? '',
        nameEn = j['name_en'] ?? '',
        image = j['image'],
        unit = j['unit'] ?? '',
        price = (j['price'] as num).toDouble(),
        assigned = j['assigned'] ?? 0,
        // ⚠️ الافتراضي true — سيرفر قديم مش راجع الحقل ده يفضل
        // يحسب ضريبة، وده أأمن من إننا نبلّعها في صمت
        taxable = j['taxable'] != false,
        taxRate = ((j['tax_rate'] ?? 0) as num).toDouble(),
        sold = j['sold'] ?? 0,
        returnedIn = j['returned_in'] ?? 0,
        damagedIn = j['damaged_in'] ?? 0,
        boxUnits = j['box_units'] ?? 0,
        caseUnits = j['case_units'] ?? 0,
        batch = j['batch']?.toString() ?? '',
        expires = j['expires']?.toString(),
        daysLeft = (j['days_left'] as num?)?.toInt(),
        family = j['family']?.toString() ?? '',
        familyLabel = j['family_label']?.toString() ?? '',
        gifted = (j['gifted'] as num?)?.toInt() ?? 0,
        _remaining = j['remaining'] ?? 0;

  int get remaining => assigned - sold;
  double get remainingValue => remaining * price;
  int get serverRemaining => _remaining;

  /// وحدات الإدخال المتاحة للصنف ده — القطعة دايماً + علبة/كرتونة لو معرّفين
  Map<String, int> get unitFactors => {
        'piece': 1,
        if (boxUnits > 1) 'box': boxUnits,
        if (caseUnits > 1) 'case': caseUnits,
      };

  /// مضاعِف وحدة بالقطع — 1 لو مش معرّفة (السيرفر هو الحكم النهائي)
  int factorOf(String unit) => unitFactors[unit] ?? 1;

  /// ⚠️ الديفولت الموحّد لوحدة الإدخال (قرار المالك ٩ أغسطس ٢٠٢٦):
  /// **علبة** لو الصنف ليه علبة، وإلا **قطعة** — عمره ما يكون كرتونة.
  String get defaultUnit => boxUnits > 1 ? 'box' : 'piece';

  /// اسم الوحدة المترجم: قطعة / علبة / كرتونة
  static String unitName(String unit) => L.t('unit_$unit');

  /// تجميعة العرض: 245 → «3 كرتونة + 1 علبة + 5 قطعة» — عرض بس
  String? packBd(int pieces) {
    if (pieces <= 0) return null;

    final parts = <String>[];
    var rest = pieces;

    for (final t in [('case', caseUnits), ('box', boxUnits)]) {
      final size = t.$2;
      if (size > 1 && rest >= size) {
        parts.add('${rest ~/ size} ${unitName(t.$1)}');
        rest %= size;
      }
    }

    if (parts.isEmpty) return null;
    if (rest > 0) parts.add('$rest ${unitName('piece')}');

    return parts.join(' + ');
  }

  /// البحث بالاسمين والكود — «برو» بتجيب Promax وبرو ماكس
  bool matches(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return true;

    return name.toLowerCase().contains(s) ||
        nameAr.contains(q.trim()) ||
        nameEn.toLowerCase().contains(s) ||
        code.toLowerCase().contains(s);
  }

  CustodyItem._merged(
      this.productId,
      this.code,
      this.name,
      this.nameAr,
      this.nameEn,
      this.image,
      this.unit,
      this.price,
      this.assigned,
      this.taxable,
      this.taxRate,
      this.sold,
      this.returnedIn,
      // ⚠️ **الكونستراكتور ده مخفي وسهل تنساه.** أي حقل `final`
      // جديد لازم يتضاف هنا كمان وإلا التجميع بيقع بـ«Final field
      // is not initialized by this constructor».
      this.damagedIn,
      this.boxUnits,
      this.caseUnits,
      this.batch,
      this.expires,
      this.daysLeft,
      this.family,
      this.familyLabel,
      this.gifted,
      this._remaining);

  /// دمج صفين لنفس الصنف (باتشات مختلفة أو صف المرتجع)
  CustodyItem merge(CustodyItem o) => CustodyItem._merged(
        productId,
        code.isNotEmpty ? code : o.code,
        name.isNotEmpty ? name : o.name,
        nameAr.isNotEmpty ? nameAr : o.nameAr,
        nameEn.isNotEmpty ? nameEn : o.nameEn,
        image ?? o.image,
        unit.isNotEmpty ? unit : o.unit,
        price > 0 ? price : o.price,
        assigned + o.assigned,
        taxable || o.taxable,
        taxRate > 0 ? taxRate : o.taxRate,
        sold + o.sold,
        returnedIn + o.returnedIn,
        // التالف بيتجمّع زي السليم — صفين لنفس الصنف بيتدمجوا
        damagedIn + o.damagedIn,
        boxUnits > 0 ? boxUnits : o.boxUnits,
        caseUnits > 0 ? caseUnits : o.caseUnits,
        // المدموج مالوش باتش واحد — التفاصيل من الصفوف الخام
        '',
        null,
        null,
        family.isNotEmpty ? family : o.family,
        familyLabel.isNotEmpty ? familyLabel : o.familyLabel,
        gifted + o.gifted,
        _remaining + o._remaining,
      );
}

class Custody {
  final bool exists;
  final int remainingUnits;
  final double remainingValue;
  final double assignedValue;

  /// بضاعة العملاء في العربية — **بره المتاح للبيع**.
  ///
  /// ⚠️ السيرفر بيبعت الرقمين دول من زمان والموديل ماكانش بيقراهم،
  /// فالمندوب مايعرفش كام قطعة هيسلّمها للمحاسب غير لما يعدّها بإيده.
  final int returnedInUnits;
  final int damagedInUnits;

  /// ميتا هيدر «عهدتي» (٢٠/٨) — رقم العربية ووقت التحميل
  final String vehicle;
  final DateTime? loadedAt;

  final List<CustodyItem> items;

  Custody.fromJson(Map<String, dynamic> j)
      : exists = j['exists'] == true,
        remainingUnits = j['remaining_units'] ?? 0,
        remainingValue = ((j['remaining_value'] ?? 0) as num).toDouble(),
        assignedValue = ((j['assigned_value'] ?? 0) as num).toDouble(),
        returnedInUnits = j['returned_in_units'] ?? 0,
        damagedInUnits = j['damaged_in_units'] ?? 0,
        vehicle = j['vehicle']?.toString() ?? '',
        loadedAt = DateTime.tryParse(j['loaded_at']?.toString() ?? ''),
        items = ((j['items'] ?? []) as List)
            .map((e) => CustodyItem.fromJson(e))
            .toList();

  Custody.empty()
      : exists = false,
        remainingUnits = 0,
        remainingValue = 0,
        assignedValue = 0,
        returnedInUnits = 0,
        damagedInUnits = 0,
        vehicle = '',
        loadedAt = null,
        items = [];

  /// ⚠️ **صف واحد لكل صنف.** العهدة بتيجي من السيرفر صف لكل
  /// (صنف، باتش)، والمرتجع بيضيف صف تالت لنفس الصنف — أي شاشة
  /// بتحسب فلوس بالـ`productId` على `items` مباشرةً بتضاعف السعر
  /// والضريبة قد عدد الصفوف. شاشات البيع والمرتجع تستخدم دي.
  List<CustodyItem> get byProduct {
    final map = <int, CustodyItem>{};
    for (final i in items) {
      final prev = map[i.productId];
      map[i.productId] = prev == null ? i : prev.merge(i);
    }
    return map.values.toList();
  }
}

enum VisitStatus { pending, inVisit, done }

class Client {
  final int id;

  /// كود العميل «CL-1043» — هيدر شاشة التشيك إن (موك أب ٢١/٨)
  final String code;

  /// الاسم الكامل من السيرفر — «السلسلة — الفرع»
  final String name;

  /// السلسلة والفرع مفصولين — للشاشات اللي بتعرضهم سطرين
  final String? chain;
  final String branch;

  /// ⚠️ كتلة البحث عابرة اللغات (١١/٨) — السيرفر بيبعت كل الأسماء
  /// (فرع + سلسلة، عربي + إنجليزي) في خانة واحدة lowercase.
  /// الاسم المعروض بلغة الأبلكيشن بس، والمندوب بيكتب بأي لغة —
  /// «رابت» في أبلكيشن إنجليزي و«Rabbit» في أبلكيشن عربي لازم يلاقوا.
  final String searchBlob;
  final String address;

  /// ⚠️ المنطقة والمحافظة بيبانوا على ورقة الفاتورة اللي بتتبعت
  /// للعميل — العنوان لوحده مالوش معنى بره سياق المندوب.
  final String zone;
  final String governorate;
  final String phone;
  final String category;
  final String categoryLabel;

  /// قناة العميل («جملة»، «كي اكاونت»...) — السيرفر بيبعتها من زمان
  /// في بايلود المناطق والأبلكيشن ماكانش بيقراها. كارت أمر التوريد
  /// بيعرضها في سطر «جملة · آجل · ٦.٤ كم» (موك أب ٢١/٨).
  final String channelLabel;
  final double balance;

  /// إجمالي مشترياته التاريخية — لهيدر صفحة العميل
  final double purchases;
  final double discount;
  final bool cashOnly;

  /// كاش ولا آجل — **من تعريف العميل في الـERP، المندوب مابيختارش**
  ///
  /// ⚠️ ممكن تكون `both` كمان — يعني الإدارة سمحت بالطريقتين
  /// و[paymentChoice] بتبقى `true`.
  final String paymentTerms;

  /// ⚠️ **الاستثناء الوحيد لقاعدة «المندوب مابيختارش».** `true` بس
  /// لما الإدارة تختار «الاتنين» على العميل — وساعتها بس شاشة البيع
  /// بتوري سويتش كاش/آجل. غير كده مافيش اختيار على الشاشة خالص.
  final bool paymentChoice;

  /// مدة السداد بالأيام — `null` يعني مفيش مدة متفق عليها
  final int? paymentDays;
  final bool taxable;
  final double taxRate;
  final bool isNew;

  /// آخر زيارة للمحل — من أي مندوب مش منه هو.
  ///
  /// ⚠️ العميل في البول المشترك ممكن يكون زميله زاره امبارح؛ حساب
  /// زياراته هو بس كان هيخلّي الكارت يقول «من ٣٠ يوم» والمحل
  /// اتزار من يومين.
  final DateTime? lastVisitAt;

  /// عدد أيام من آخر زيارة — `null` لو المحل ماتزارش قبل كده
  int? get daysSinceVisit => lastVisitAt == null
      ? null
      : DateTime.now().difference(lastVisitAt!).inDays;

  /// ═══ حالة زيارة النهاردة — لابل ولون ═══
  ///
  /// ⚠️ **في الموديل مش في الشاشة**: كل شاشة كانت بتكتب الـswitch
  /// بتاعها، فلو حالة اتزادت لازم نفتكر نعدّل كذا مكان — والنسيان
  /// بيطلّع لابل فاضي أو لون غلط في شاشة واحدة بس ومحدش ياخد باله.
  String get statusLabel => switch (status) {
        VisitStatus.done => L.t('visit_done'),
        VisitStatus.inVisit => L.t('in_visit'),
        _ => L.t('visit_pending'),
      };

  Color get statusColor => switch (status) {
        VisitStatus.done => const Color(0xFF16A34A),
        VisitStatus.inVisit => const Color(0xFFB86E00),
        _ => const Color(0xFF6B6B7B),
      };

  /// إحداثيات العميل + لينك اللوكيشن المخزّن — لزرار «الاتجاهات».
  /// `null` يعني السيرفر ماعندوش لوكيشن للعميل ده.
  final double? lat;
  final double? lng;
  final String? locationUrl;

  /// اتأكّد من الداشبورد — زرار «عدّل لوكيشن العميل» بيختفي خلاص
  final bool locationConfirmed;

  VisitStatus status;
  int? visitId;
  DateTime? checkInAt;
  DateTime? checkOutAt;

  /// «7 شارع 9، المعادي — القاهرة» — الأجزاء الفاضية بتتشال
  ///
  /// ⚠️ **مصدر واحد للسطر ده.** كل شاشة كانت بتركّبه بطريقتها،
  /// فالفاتورة بتقول «المعادي» والكارت يقول «المعادي - القاهرة».
  String get fullAddress => [address, zone, governorate]
      .where((p) => p.trim().isNotEmpty)
      .join(' — ');

  Client.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        code = j['code']?.toString() ?? '',
        name = j['name'] ?? '',
        chain = j['chain'],
        branch = j['branch'] ?? j['name'] ?? '',
        // سيرفر قديم مش باعت q → فاضية والبحث بالاسم المعروض بس
        searchBlob = j['q'] ?? '',
        address = j['address'] ?? '',
        zone = j['zone'] ?? '',
        governorate = j['governorate'] ?? '',
        phone = j['phone'] ?? '',
        category = j['category'] ?? 'ok',
        categoryLabel = j['category_label'] ?? '',
        channelLabel = j['channel']?.toString() ?? '',
        balance = ((j['balance'] ?? 0) as num).toDouble(),
        purchases = ((j['purchases'] ?? 0) as num).toDouble(),
        discount = ((j['discount'] ?? 0) as num).toDouble(),
        cashOnly = j['cash_only'] == true,
        // سيرفر قديم مش باعت الحقل → من cash_only
        paymentTerms = j['payment_terms'] ?? (j['cash_only'] == true ? 'cash' : 'credit'),
        // ⚠️ الافتراضي `false` — سيرفر قديم مش باعت الحقل معناه
        // مفيش اختيار، مش «وري السويتش على كل العملاء»
        paymentChoice = j['payment_choice'] == true,
        paymentDays = (j['payment_days'] as num?)?.toInt(),
        taxable = j['taxable'] == true,
        taxRate = ((j['tax_rate'] ?? 0) as num).toDouble(),
        isNew = j['is_new'] == true,
        // آخر زيارة **من أي مندوب** — الكارت بيقول «من كام يوم» (١٥/٨)
        lastVisitAt = parseTime(j['last_visit_at']),
        lat = j['lat'] == null ? null : (j['lat'] as num).toDouble(),
        lng = j['lng'] == null ? null : (j['lng'] as num).toDouble(),
        locationUrl = j['location_url'],
        // ⚠️ **الافتراضي `false`** — سيرفر قديم مش باعت الحقل معناه
        // «لسه ماتأكّدش» فالزرار يفضل ظاهر، مش «اتأكّد» فيختفي
        // ويقفل على المندوب طريقه الوحيد لتصحيح نقطة غلط.
        locationConfirmed = j['location_confirmed'] == true,
        visitId = j['visit_id'],
        checkInAt = parseTime(j['checked_in_at']),
        checkOutAt = parseTime(j['checked_out_at']),
        status = switch (j['visit_status']) {
          'in_visit' => VisitStatus.inVisit,
          'done' => VisitStatus.done,
          _ => VisitStatus.pending,
        };

  bool get hasContract => discount > 0;

  /// لينك ملاحة جوجل ماب للعميل — من الإحداثيات لو موجودة، وإلا
  /// اللينك المخزّن في الـERP. `null` = ملوش لوكيشن خالص، والكارت
  /// بيوري «ليس له لوكيشن» بدل زرار بيفتح صفحة فاضية.
  String? get directionsUrl {
    if (lat != null && lng != null) {
      return 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    }
    final u = (locationUrl ?? '').trim();
    return u.isEmpty ? null : u;
  }
}

class Zone {
  final int id;
  final String code;
  final String name;
  final String day;
  final bool isToday;
  final List<Client> clients;

  /// عدد عملاء المنطقة — بادج على الكارت. السيرفر بيبعته صريح
  /// (`client_count` — إضافة ١١/٨)، والفولباك طول قايمة العملاء
  /// نفسها عشان السيرفر القديم ما يكسرش حاجة.
  final int clientCount;

  /// المحافظة — الكود للتجميع واللابل للعرض (١٥/٨).
  ///
  /// ⚠️ الأبلكيشن بقى بيجمّع المناطق تحت محافظاتها بدل ليست مسطّحة
  /// كانت بتخلط المستويين («القاهرة» و«الدقي» جنب بعض وهي جواها).
  /// الفولباك فاضي عشان السيرفر القديم مايكسرش الشاشة.
  final String gov;
  final String govLabel;

  Zone.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        code = j['code'] ?? '',
        name = j['name'] ?? '',
        day = j['day'] ?? '',
        gov = j['gov']?.toString() ?? '',
        govLabel = j['gov_label']?.toString() ?? '',
        isToday = j['is_today'] == true,
        clientCount = (j['client_count'] as num?)?.toInt() ??
            ((j['clients'] ?? []) as List).length,
        clients = ((j['clients'] ?? []) as List)
            .map((e) => Client.fromJson(e))
            .toList();

  int get doneCount =>
      clients.where((c) => c.status == VisitStatus.done).length;

  List<Client> search(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return clients;
    return clients
        .where((c) =>
            c.name.toLowerCase().contains(s) ||
            // كتلة البحث عابرة اللغات — عربي وإنجليزي مهما كانت لغة الأبلكيشن
            c.searchBlob.contains(s) ||
            c.address.toLowerCase().contains(s) ||
            c.phone.contains(s))
        .toList();
  }
}

/// محطة في خط سير النهارده.
///
/// ⚠️ مش نفس `Client` بتاع الزونز. ده عميل **مخطط له النهارده**
/// بترتيب معيّن، ومعاه حالة زيارته. خلطهم بيخلّي شاشة خط السير
/// توري كل عملاء الزون بدل عملاء اليوم.
class JourneyStop {
  final int planId;
  final int clientId;
  final String name;
  final String address;
  final String phone;
  final double? lat;
  final double? lng;
  final String? locationUrl;

  /// اتأكّد من الداشبورد — بيتنقل لـ`Client` في `asClient()`
  final bool locationConfirmed;
  final double balance;
  final bool cashOnly;
  final String paymentTerms;
  final bool paymentChoice;
  final int? paymentDays;

  /// الخصم الفعلي من السيرفر — عشان شاشة البيع من المحطة تسعّر صح
  final double discount;

  /// إجمالي مبيعات العميل التاريخية + آخر مرة اتزار — لكارت المحطة
  final double purchases;
  final DateTime? lastVisitAt;
  final String category;
  final String categoryLabel;

  /// فرع سلسلة ولا عميل فردي — شاشة خط السير بتفصلهم سكشنين (٢٨/٨)
  final bool isChain;
  final bool taxable;
  final double taxRate;
  final int sort;

  /// ═══ أرقام المحطة المتزارة (موك أب خط السير ٢١/٨) ═══
  /// «8:50 ص · 22 دقيقة · 3,120 · حصّل 1,000 · مرتجع 6»
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final double visitSales;
  final double visitCollected;
  final int visitReturnQty;

  /// متوسط فاتورة العميل — شيب «متوسّط 4,100» على كارت الجاي
  final double avgInvoice;

  /// مدة الزيارة بالدقايق — من التشيك إن للتشيك أوت
  int? get visitMinutes => checkedInAt == null || checkedOutAt == null
      ? null
      : checkedOutAt!.difference(checkedInAt!).inMinutes;

  VisitStatus status;
  int? visitId;

  JourneyStop.fromJson(Map<String, dynamic> j)
      : planId = j['plan_id'] ?? 0,
        clientId = j['client_id'],
        name = j['name'] ?? '',
        address = j['address'] ?? '',
        phone = j['phone'] ?? '',
        lat = j['lat'] == null ? null : (j['lat'] as num).toDouble(),
        lng = j['lng'] == null ? null : (j['lng'] as num).toDouble(),
        locationUrl = j['location_url'],
        locationConfirmed = j['location_confirmed'] == true,
        balance = ((j['balance'] ?? 0) as num).toDouble(),
        cashOnly = j['cash_only'] == true,
        paymentTerms = j['payment_terms'] ?? (j['cash_only'] == true ? 'cash' : 'credit'),
        paymentChoice = j['payment_choice'] == true,
        paymentDays = (j['payment_days'] as num?)?.toInt(),
        discount = ((j['discount'] ?? 0) as num).toDouble(),
        purchases = ((j['purchases'] ?? 0) as num).toDouble(),
        lastVisitAt = parseTime(j['last_visit_at']),
        category = j['category'] ?? 'ok',
        categoryLabel = j['category_label'] ?? '',
        isChain = j['is_chain'] == true,
        taxable = j['taxable'] == true,
        taxRate = ((j['tax_rate'] ?? 0) as num).toDouble(),
        sort = j['sort'] ?? 0,
        checkedInAt = parseTime(j['checked_in_at']),
        checkedOutAt = parseTime(j['checked_out_at']),
        visitSales = ((j['visit_sales'] ?? 0) as num).toDouble(),
        visitCollected = ((j['visit_collected'] ?? 0) as num).toDouble(),
        visitReturnQty = (j['visit_return_qty'] as num?)?.toInt() ?? 0,
        avgInvoice = ((j['avg_invoice'] ?? 0) as num).toDouble(),
        visitId = j['visit_id'],
        status = switch (j['status']) {
          'in_visit' => VisitStatus.inVisit,
          'done' => VisitStatus.done,
          _ => VisitStatus.pending,
        };

  bool get hasLocation => lat != null && lng != null;

  /// نفس منطق `Client.directionsUrl` — إحداثيات وإلا اللينك المخزّن
  String? get directionsUrl {
    if (lat != null && lng != null) {
      return 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    }
    final u = (locationUrl ?? '').trim();
    return u.isEmpty ? null : u;
  }

  /// نسخة `Client` من المحطة — شاشة البيع بتاخد `Client`.
  ///
  /// ⚠️ الخصم بصفر عن قصد: السيرفر هو اللي بيحسب الخصم النهائي،
  /// والرقم اللي هنا للعرض بس. تخمين خصم غلط أسوأ من عدم عرضه.
  Client asClient() => Client.fromJson({
        'id': clientId,
        'name': name,
        'address': address,
        'phone': phone,
        'category': category,
        'category_label': categoryLabel,
        // ⚠️ الخصم بقى من السيرفر مع المحطة — الصفر القديم كان بيخلّي
        // المندوب يقول للعميل رقم أعلى من الفاتورة الفعلية
        'balance': balance,
        'purchases': purchases,
        'discount': discount,
        'cash_only': cashOnly,
        'payment_terms': paymentTerms,
        // ⚠️ **لازم يتنقلوا هنا كمان.** الماب دي بتتحوّل لـ`Client`
        // لما المندوب يفتح البيع من محطة في خط السير — ولو الحقلين
        // ناقصين، نفس العميل بيوري السويتش من شاشة والتانية لأ.
        'payment_choice': paymentChoice,
        'payment_days': paymentDays,
        // اللوكيشن كمان — من غيره صفحة العميل المفتوحة من خط السير
        // كانت هتقول «ليس له لوكيشن» وهو ليه إحداثيات فعلاً
        'lat': lat,
        'lng': lng,
        'location_url': locationUrl,
        // ⚠️ **لازم يتنقل هنا كمان** — من غيره نفس العميل بيوري
        // زرار «عدّل اللوكيشن» لما يتفتح من خط السير، ويخبّيه لما
        // يتفتح من الزونز. نفس فخ `payment_choice` المكتوب فوق.
        'location_confirmed': locationConfirmed,
        'taxable': taxable,
        'tax_rate': taxRate,
        'is_new': false,
        'visit_status': status == VisitStatus.done
            ? 'done'
            : (status == VisitStatus.inVisit ? 'in_visit' : 'pending'),
        'visit_id': visitId,
      });
}

/// ملخص يوم المندوب حسب الخطة
class JourneySummary {
  final int planned;
  final int done;
  final int inVisit;
  final int pending;
  final int offPlan;
  final double pct;

  const JourneySummary({
    required this.planned,
    required this.done,
    required this.inVisit,
    required this.pending,
    required this.offPlan,
    required this.pct,
  });

  factory JourneySummary.empty() => const JourneySummary(
      planned: 0, done: 0, inVisit: 0, pending: 0, offPlan: 0, pct: 0);

  factory JourneySummary.fromJson(Map<String, dynamic> j) => JourneySummary(
        planned: j['planned'] ?? 0,
        done: j['done'] ?? 0,
        inVisit: j['in_visit'] ?? 0,
        pending: j['pending'] ?? 0,
        offPlan: j['off_plan'] ?? 0,
        pct: ((j['pct'] ?? 0) as num).toDouble(),
      );

  bool get hasPlan => planned > 0;
}

class PoItem {
  final int productId;
  final String name;
  final String unit;
  final String? image;
  final int qty;

  /// المسلَّم فعلاً — بيتملي بعد إقفال التسليم
  final int deliveredQty;

  /// تدريج الوحدات — عشان تعديل «9 كراتين» وقت التسليم (0 = مش معرّفة)
  final int boxUnits;
  final int caseUnits;

  /// ⚠️ الديفولت الموحّد: علبة لو موجودة وإلا قطعة (٩ أغسطس ٢٠٢٦)
  String get defaultUnit => boxUnits > 1 ? 'box' : 'piece';
  final double price;
  final double total;

  PoItem.fromJson(Map<String, dynamic> j)
      : productId = j['product_id'],
        name = j['name'] ?? '',
        unit = j['unit'] ?? '',
        image = j['image'],
        qty = j['qty'] ?? 0,
        deliveredQty = j['delivered_qty'] ?? 0,
        boxUnits = j['box_units'] ?? 0,
        caseUnits = j['case_units'] ?? 0,
        price = ((j['price'] ?? 0) as num).toDouble(),
        total = ((j['total'] ?? 0) as num).toDouble();

  Map<String, int> get unitFactors => {
        'piece': 1,
        if (boxUnits > 1) 'box': boxUnits,
        if (caseUnits > 1) 'case': caseUnits,
      };

  int factorOf(String unit) => unitFactors[unit] ?? 1;

  /// اسم الوحدة المترجم — نفس `CustodyItem.unitName`
  static String unitName(String unit) => L.t('unit_$unit');

  /// تجميعة العرض «3 كرتونة + 1 علبة» — عرض بس
  String? packBd(int pieces) {
    if (pieces <= 0) return null;

    final parts = <String>[];
    var rest = pieces;

    for (final t in [('case', caseUnits), ('box', boxUnits)]) {
      if (t.$2 > 1 && rest >= t.$2) {
        parts.add('${rest ~/ t.$2} ${CustodyItem.unitName(t.$1)}');
        rest %= t.$2;
      }
    }

    if (parts.isEmpty) return null;
    if (rest > 0) parts.add('$rest ${CustodyItem.unitName('piece')}');

    return parts.join(' + ');
  }
}

class PurchaseOrder {
  final int id;

  /// (٢١/٨) — كارت الأمر بيفتح شاشة العميل للتشيك إن العادي
  final int? clientId;
  final String number;
  final String client;
  final String source;

  /// من طلب ريفيل/بضاعة ولا أمر سلسلة — علم ثابت من السيرفر،
  /// ⚠️ ممنوع استنتاجه من `source` (نص حر مترجم)
  final bool isReplenishment;
  final String address;
  String status; // pending / arrived / delivered
  String statusLabel;

  /// الإجمالي الشامل (`payable()`) — اللي السواق بيحصّله
  final double total;

  /// الصافي قبل الضريبة وضريبة الأمر — لتوزيع الضريبة على المسلَّم
  /// في شاشة المراجعة (السيرفر بيبعتهم من ٨/٨)
  final double netTotal;
  final double taxTotal;
  final int qtyTotal;
  DateTime? arrivedAt;
  DateTime? deliveredAt;

  /// معاد التوريد (يوم وساعة) — لأوامر الكي أكاونت، ومتأخر من السيرفر
  final DateTime? dueAt;
  final bool late;
  final int deliveredQtyTotal;
  final List<PoItem> items;

  /// ═══ إعادة تصميم الكارت (طلب المالك ٨ أغسطس ٢٠٢٦) ═══
  ///
  /// ⚠️ **صورة أمر الشراء الحقيقي بتاع السلسلة.** المندوب بيقف عند
  /// الفرع والفرع بيقارن بورقته هو — من غير الصورة المندوب بيقول
  /// «ده اللي في الأبلكيشن» والفرع بيقول «مش ده اللي طلبناه»،
  /// ومفيش مرجع مشترك بينهم.
  final String? image;

  /// مرجع السلسلة اللي جه في الشيت — الفرع بيعرف الأمر بيه مش برقمنا
  final String? reference;

  final String? clientAddress;
  final String? clientPhone;
  final double? lat;
  final double? lng;

  PurchaseOrder.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        clientId = (j['client_id'] as num?)?.toInt(),
        number = j['number'] ?? '',
        client = j['client'] ?? '',
        source = j['source'] ?? '',
        isReplenishment = j['is_replenishment'] == true,
        address = j['address'] ?? '',
        status = j['status'] ?? 'pending',
        statusLabel = j['status_label'] ?? '',
        total = ((j['total'] ?? 0) as num).toDouble(),
        netTotal = ((j['net_total'] ?? j['total'] ?? 0) as num).toDouble(),
        taxTotal = ((j['tax_total'] ?? 0) as num).toDouble(),
        qtyTotal = j['qty_total'] ?? 0,
        arrivedAt = parseTime(j['arrived_at']),
        deliveredAt = parseTime(j['delivered_at']),
        dueAt = parseTime(j['due_at']),
        late = j['late'] == true,
        deliveredQtyTotal = j['delivered_qty_total'] ?? 0,
        image = j['image'],
        reference = j['reference'],
        clientAddress = j['client_address'],
        clientPhone = j['client_phone'],
        lat = (j['lat'] as num?)?.toDouble(),
        lng = (j['lng'] as num?)?.toDouble(),
        items = ((j['items'] ?? []) as List)
            .map((e) => PoItem.fromJson(e))
            .toList();

  /// الفرق بين المطلوب والمسلَّم — بعد الإقفال
  int get varianceQty => qtyTotal - deliveredQtyTotal;
}

class TrackEvent {
  final String type;
  final String title;
  final String subtitle;
  final double lat;
  final double lng;
  final DateTime time;

  TrackEvent.fromJson(Map<String, dynamic> j)
      : type = j['type'] ?? '',
        title = j['title'] ?? '',
        subtitle = j['subtitle'] ?? '',
        lat = ((j['lat'] ?? 0) as num).toDouble(),
        lng = ((j['lng'] ?? 0) as num).toDouble(),
        time = parseTime(j['time']) ?? DateTime.now();
}

class AppNotification {
  /// معرّف الإشعار على السيرفر.
  ///
  /// ⚠️ **كان بيتـرمى** — السيرفر بيبعته والأبلكيشن مابيقراهوش،
  /// فماكانش فيه طريقة نعرف الإشعار ده اتقرا ولا لأ ولا نمنع تكراره.
  final int id;

  final String title;
  final String body;

  /// وجهة الإشعار: `po:12` · `pick:7` · `request:3` · `custody` …
  ///
  /// ⚠️ **من غيره الإشعار مش قابل للضغط** — لا جوّه الأبلكيشن ولا من
  /// إشعار النظام. المندوب بيقرا «أمر توريد جاهز» وبيدوّر عليه بإيده.
  final String? link;

  final bool isGood;
  final DateTime time;

  /// ⚠️ **الشارة بتعد المش مقروء بس** (2026-08-07). كانت بتعد
  /// الإشعارات كلها، فالمندوب يفتحها ويقفلها والرقم مايقلّش —
  /// وشارة عمرها ما بتفضى بتتحول لضوضاء ومحدش بيبص لها.
  ///
  /// ⚠️ الديفولت `false` مش `true`: سيرفر قديم لسه مابيبعتش المفتاح
  /// يخلّي الإشعار يبان جديد — أأمن من إنه يختفي من غير ما حد يشوفه.
  ///
  /// ⚠️ **مش `final`** — بتتقلب محلياً أول ما المندوب يفتح القايمة،
  /// من غير ما نستنى رد السيرفر. الشارة بتفضى في نفس اللحظة، وده
  /// الفرق بين واجهة بتستجيب وواجهة بتقول «استنى شوية».
  bool isRead;

  AppNotification.fromJson(Map<String, dynamic> j)
      : id = (j['id'] as num?)?.toInt() ?? 0,
        title = j['title'] ?? '',
        body = j['body'] ?? '',
        link = (j['link'] as String?)?.isNotEmpty == true ? j['link'] as String : null,
        isGood = j['is_good'] != false,
        isRead = j['is_read'] == true,
        time = parseTime(j['time']) ?? DateTime.now();
}

class ClientRequestRow {
  final int id;
  final String number;
  final String name;
  final String status;
  final String statusLabel;
  final DateTime time;

  /// العميل اللي اتولد من الاعتماد (١٩/٨) — الطلب المتوافق عليه
  /// بقى كليك أبل: يوديك على العميل تبيع له على طول
  final int? clientId;

  ClientRequestRow.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? 0,
        number = j['number'] ?? '',
        name = j['name'] ?? '',
        status = j['status'] ?? 'pending',
        statusLabel = j['status_label'] ?? '',
        clientId = (j['client_id'] as num?)?.toInt(),
        time = parseTime(j['time']) ?? DateTime.now();

  (Color, String) get info => switch (status) {
        'approved' => (const Color(0xFF0E7C5A), statusLabel),
        'review' => (const Color(0xFFB86E00), statusLabel),
        'rejected' => (const Color(0xFFB00020), statusLabel),
        _ => (Colors.grey, statusLabel),
      };
}

class InvoiceRow {
  final int id;
  final String number;
  final String client;
  final double total;

  /// الإجمالي شامل الضريبة — اللي اتحصّل فعلاً
  final double grandTotal;
  final String payment;

  /// البنود بالصور — بتتعرض لما المندوب يفتح الفاتورة
  final List<InvoiceLine> lines;
  final DateTime time;

  InvoiceRow.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        number = j['number'] ?? '',
        client = j['client'] ?? '',
        total = ((j['total'] ?? 0) as num).toDouble(),
        grandTotal = ((j['grand_total'] ?? j['total'] ?? 0) as num).toDouble(),
        payment = j['payment'] ?? 'cash',
        // بنود الفاتورة بالصور — تفاصيل الفاتورة في «مبيعاتي»
        lines = ((j['lines'] ?? []) as List)
            .map((e) => InvoiceLine.fromJson(e))
            .toList(),
        time = parseTime(j['time']) ?? DateTime.now();

  String get paymentLabel => payment == 'cash' ? L.t('cash') : L.t('credit');
}

/// بند فاتورة — للعرض بالصورة في تفاصيل الفاتورة
class InvoiceLine {
  final String name;
  final String? image;
  final int qty;
  final double price;
  final double total;

  InvoiceLine.fromJson(Map<String, dynamic> j)
      : name = j['name'] ?? '',
        image = j['image'],
        qty = j['qty'] ?? 0,
        price = ((j['price'] ?? 0) as num).toDouble(),
        total = ((j['total'] ?? 0) as num).toDouble();
}

/// مرتجع سجّله المندوب — من قيود العميل المربوطة بزياراته
class ReturnRow {
  final int id;

  /// رقم المرتجع — RET-{id}
  final String number;
  final String client;
  final double total;
  final String memo;
  final DateTime time;

  ReturnRow.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        number = j['number'] ?? 'RET-${j['id']}',
        client = j['client'] ?? '',
        total = ((j['total'] ?? 0) as num).toDouble(),
        memo = j['memo'] ?? '',
        time = parseTime(j['time']) ?? DateTime.now();
}

// ================= رول المدير =================

/// نظرة المدير على مندوب
class RepOverview {
  final int id;
  final String name;
  final String code;
  final String role;
  final String roleLabel;
  final String? zone;
  final double sales;
  final int invoices;
  final int visits;
  final int visitsDone;
  final int pos;
  final int posDone;
  final double posValue;
  final bool hasCustody;
  final int custodyRemaining;
  final double custodyValue;
  final String? activeClient;
  final DateTime? activeSince;
  final DateTime? lastSeen;
  final String? lastAction;

  RepOverview.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'] ?? '',
        code = j['code'] ?? '',
        role = j['role'] ?? 'rep',
        roleLabel = j['role_label'] ?? '',
        zone = j['zone']?.toString(),
        sales = ((j['sales'] ?? 0) as num).toDouble(),
        invoices = j['invoices'] ?? 0,
        visits = j['visits'] ?? 0,
        visitsDone = j['visits_done'] ?? 0,
        pos = j['pos'] ?? 0,
        posDone = j['pos_done'] ?? 0,
        posValue = ((j['pos_value'] ?? 0) as num).toDouble(),
        hasCustody = j['has_custody'] == true,
        custodyRemaining = j['custody_remaining'] ?? 0,
        custodyValue = ((j['custody_value'] ?? 0) as num).toDouble(),
        activeClient = j['active_client']?.toString(),
        activeSince = parseTime(j['active_since']),
        lastSeen = parseTime(j['last_seen']),
        lastAction = j['last_action']?.toString();

  bool get isCourier => role == 'driver';
  bool get isPromoter => role == 'promoter';

  (Color, String) get status {
    if (activeClient != null) {
      return (const Color(0xFFB86E00), isCourier ? L.t('delivering') : L.t('in_visit'));
    }
    if (!hasCustody) return (Colors.grey, L.t('no_custody_short'));
    return (const Color(0xFF16A34A), L.t('working'));
  }
}

/// طلب عميل جديد كما يراه المدير
class PendingRequest {
  final int id;
  final String number;
  final String name;
  final String phone;
  final String address;
  final String? zone;
  final String? rep;
  final bool hasDocs;
  final String? photoUrl;
  final String? docsUrl;
  final String? docsType;
  final String status;
  final String statusLabel;
  final bool isOpen;
  final DateTime time;

  PendingRequest.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        number = j['number'] ?? '',
        name = j['name'] ?? '',
        phone = j['phone'] ?? '',
        address = j['address'] ?? '',
        zone = j['zone']?.toString(),
        rep = j['rep']?.toString(),
        hasDocs = j['has_docs'] == true,
        photoUrl = j['photo_url']?.toString(),
        docsUrl = j['docs_url']?.toString(),
        docsType = j['docs_type']?.toString(),
        status = j['status'] ?? 'pending',
        statusLabel = j['status_label'] ?? '',
        isOpen = j['is_open'] == true,
        time = parseTime(j['time']) ?? DateTime.now();

  (Color, String) get info => switch (status) {
        'approved' => (const Color(0xFF16A34A), statusLabel),
        'review' => (const Color(0xFFB86E00), statusLabel),
        'rejected' => (const Color(0xFFB00020), statusLabel),
        _ => (Colors.grey, statusLabel),
      };
}

/// حدث تراكينج مع اسم صاحبه (لشاشة المدير)
class TeamEvent {
  final String type;
  final String title;
  final String subtitle;
  final String user;
  final DateTime time;

  TeamEvent.fromJson(Map<String, dynamic> j)
      : type = j['type'] ?? '',
        title = j['title'] ?? '',
        subtitle = j['subtitle'] ?? '',
        user = j['user'] ?? '',
        time = parseTime(j['time']) ?? DateTime.now();
}

class ManagerStats {
  final double sales;
  final int invoices;
  final double posValue;
  final int posDone;
  final int visits;
  final int visitsDone;
  final int openRequests;
  final int fieldUsers;

  ManagerStats.fromJson(Map<String, dynamic> j)
      : sales = ((j['sales'] ?? 0) as num).toDouble(),
        invoices = j['invoices'] ?? 0,
        posValue = ((j['pos_value'] ?? 0) as num).toDouble(),
        posDone = j['pos_done'] ?? 0,
        visits = j['visits'] ?? 0,
        visitsDone = j['visits_done'] ?? 0,
        openRequests = j['open_requests'] ?? 0,
        fieldUsers = j['field_users'] ?? 0;

  ManagerStats.empty()
      : sales = 0,
        invoices = 0,
        posValue = 0,
        posDone = 0,
        visits = 0,
        visitsDone = 0,
        openRequests = 0,
        fieldUsers = 0;
}

class TodayStats {
  final double sales;
  final int invoices;
  final int visits;
  final int visitsDone;
  final int posDelivered;
  final double posValue;

  /// متوسط مدة زيارات المندوب بالدقايق (آخر ٣٠ يوم) —
  /// «متوسّط زيارتك 34 دقيقة» في هيدر الزيارة المفتوحة (٢١/٨)
  final int avgVisitMin;

  TodayStats.fromJson(Map<String, dynamic> j)
      : sales = ((j['sales'] ?? 0) as num).toDouble(),
        invoices = j['invoices'] ?? 0,
        visits = j['visits'] ?? 0,
        visitsDone = j['visits_done'] ?? 0,
        posDelivered = j['pos_delivered'] ?? 0,
        posValue = ((j['pos_value'] ?? 0) as num).toDouble(),
        avgVisitMin = (j['avg_visit_min'] as num?)?.toInt() ?? 0;

  TodayStats.empty()
      : sales = 0,
        invoices = 0,
        visits = 0,
        visitsDone = 0,
        posDelivered = 0,
        posValue = 0,
        avgVisitMin = 0;
}

/// ═══ أرقام كارت العميل — شاشة التشيك إن (موك أب ٢١/٨) ═══
///
/// من `GET /clients/{id}/card`: مبيعات الشهر وفواتيره، مرتجعاته
/// ونسبتها، تحصيله وآخره، الباقي عليه وأيام تأخيره، وملخص آخر زيارة.
class ClientCardStats {
  final double monthSales;
  final int monthInvoices;
  final double monthReturns;
  final double returnsPct;
  final double monthCollections;
  final int? lastCollectionDays;
  final double balance;
  final int overdueDays;
  final DateTime? lastVisitAt;
  final double lastVisitSales;
  final double lastVisitCollected;

  int? get lastVisitDays => lastVisitAt == null
      ? null
      : DateTime.now().difference(lastVisitAt!).inDays;

  ClientCardStats.fromJson(Map<String, dynamic> j)
      : monthSales = ((j['month_sales'] ?? 0) as num).toDouble(),
        monthInvoices = (j['month_invoices'] as num?)?.toInt() ?? 0,
        monthReturns = ((j['month_returns'] ?? 0) as num).toDouble(),
        returnsPct = ((j['returns_pct'] ?? 0) as num).toDouble(),
        monthCollections = ((j['month_collections'] ?? 0) as num).toDouble(),
        lastCollectionDays = (j['last_collection_days'] as num?)?.toInt(),
        balance = ((j['balance'] ?? 0) as num).toDouble(),
        overdueDays = (j['overdue_days'] as num?)?.toInt() ?? 0,
        lastVisitAt = parseTime(j['last_visit_at']),
        lastVisitSales = ((j['last_visit_sales'] ?? 0) as num).toDouble(),
        lastVisitCollected =
            ((j['last_visit_collected'] ?? 0) as num).toDouble();
}

// ============ طلبات الريفيل من ناحية المدير ============

/// صنف داخل طلب ريفيل — بسعر قناة العميل
class MgrReplItem {
  final String product;
  final int qty;
  final double price;

  MgrReplItem.fromJson(Map<String, dynamic> j)
      : product = j['product'] ?? '',
        qty = j['qty'] ?? 0,
        price = ((j['price'] ?? 0) as num).toDouble();

  double get total => qty * price;
}

/// طلب ريفيل كامل: البروموتر طلبه، والمدير بيوافق ويوزّعه
class MgrReplenishment {
  final int id;
  final String number;
  final String client;
  final String? address;
  final String? channel;
  final String? promoter;
  final String? assignee;
  final String status;
  final String statusLabel;
  final bool isOpen;
  final bool canDecide;
  final String? note;
  final int qtyTotal;
  final String? photoBefore;
  final String? photoAfter;
  final DateTime time;
  final List<MgrReplItem> items;

  /// مصدر الطلب (2026-08-09): `rep` واقف عند العميل ولا `promoter`
  /// من زيارة رف — وطلب المندوب بيترشّح هو نفسه يستلمه.
  final String origin;
  final String originLabel;
  final int requestedById;

  MgrReplenishment.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        number = j['number'] ?? '',
        client = j['client'] ?? '',
        address = j['address']?.toString(),
        channel = j['channel']?.toString(),
        promoter = j['promoter']?.toString(),
        assignee = j['assignee']?.toString(),
        status = j['status'] ?? 'pending',
        statusLabel = j['status_label'] ?? '',
        isOpen = j['is_open'] == true,
        canDecide = j['can_decide'] == true,
        note = j['note']?.toString(),
        qtyTotal = j['qty_total'] ?? 0,
        photoBefore = j['photo_before']?.toString(),
        photoAfter = j['photo_after']?.toString(),
        time = parseTime(j['time']) ?? DateTime.now(),
        origin = j['origin'] ?? 'promoter',
        originLabel = j['origin_label'] ?? '',
        requestedById = j['requested_by_id'] ?? 0,
        items = ((j['items'] ?? []) as List)
            .map((e) => MgrReplItem.fromJson(e))
            .toList();

  double get value => items.fold(0.0, (s, i) => s + i.total);

  (Color, String) get info => switch (status) {
        'delivered' => (const Color(0xFF16A34A), statusLabel),
        'assigned' => (const Color(0xFF2563EB), statusLabel),
        'cancelled' => (const Color(0xFFB00020), statusLabel),
        _ => (const Color(0xFFB86E00), statusLabel),
      };
}

/// مندوب/سواق متاح ينزّل عليه الطلب
class DriverOption {
  final int id;
  final String name;
  final String code;
  final String roleLabel;

  DriverOption.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'] ?? '',
        code = j['code'] ?? '',
        roleLabel = j['role_label'] ?? '';
}


/// ═══════════════════════════════════════════════════════════════
/// زيارة المخزن — إذن الاستلام (2026-08-08)
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ **دي غير الحضور تماماً.** الحضور بيقول «أنا شغال النهارده»،
/// ودي بتقول «أنا واقف جوه مخزن المعادي دلوقتي». المندوب بيسجّل
/// حضور مرة في اليوم، وبيدخل ويخرج من المخزن براحته.
class WarehouseStop {
  final int id;
  final int warehouseId;
  final String warehouse;
  final DateTime checkedInAt;

  /// الدقايق اللي السيرفر حسبها لحظة الرد — الأبلكيشن بيعدّ من
  /// [checkedInAt] محلياً بعدها
  final int minutes;

  WarehouseStop.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? 0,
        warehouseId = j['warehouse_id'] ?? 0,
        warehouse = j['warehouse'] ?? '',
        checkedInAt = parseTime(j['checked_in_at']) ?? DateTime.now(),
        minutes = (j['minutes'] as num?)?.toInt() ?? 0;

  /// ⚠️ بيتحسب من وقت الدخول مش من عدّاد متراكم — نوم التليفون كان
  /// بيخلّي الرقم يقل عن الحقيقي والفرق يكبر مع اليوم
  int get liveMinutes {
    final m = DateTime.now().difference(checkedInAt).inMinutes;

    return m > 0 ? m : 0;
  }

  /// ⚠️ **بالثواني** (طلب المالك ٨/٨/٢٠٢٦). الرقم بالدقايق بس كان
  /// بيفضل «0:00» أول دقيقة كاملة — والمندوب واقف بيبص على عدّاد
  /// واقف ومش عارف الدخول اتسجّل ولا لأ.
  int get liveSeconds {
    final s = DateTime.now().difference(checkedInAt).inSeconds;

    return s > 0 ? s : 0;
  }

  String get liveLabel {
    final s = liveSeconds;
    final two = (int v) => v.toString().padLeft(2, '0');

    return '${s ~/ 3600}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
  }
}

/// ═══ سامري المخزن النهارده (طلب المالك ٨ أغسطس ٢٠٢٦) ═══
///
/// ⚠️ **زي شاشة الحضور بالظبط.** «انت جوّه مخزن المعادي» لوحدها
/// مابتقولش للمندوب عمل إيه النهارده — استلم كام عهدة وكام أمر
/// توريد وقعد كام دقيقة.
class WarehouseToday {
  final int picks;
  final int pos;
  final int minutes;
  final int visits;

  const WarehouseToday.empty()
      : picks = 0,
        pos = 0,
        minutes = 0,
        visits = 0;

  WarehouseToday.fromJson(Map<String, dynamic> j)
      : picks = (j['picks'] as num?)?.toInt() ?? 0,
        pos = (j['pos'] as num?)?.toInt() ?? 0,
        minutes = (j['minutes'] as num?)?.toInt() ?? 0,
        visits = (j['visits'] as num?)?.toInt() ?? 0;
}

/// مخزن متاح للدخول
class WarehouseOption {
  final int id;
  final String name;
  final String address;

  WarehouseOption.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? 0,
        name = j['name'] ?? '',
        address = j['address'] ?? '';
}

// ═══════════════════════════════════════════════════════════════
// تاريخ العميل  ·  ١٦ أغسطس ٢٠٢٦
// ═══════════════════════════════════════════════════════════════

/// عدّاد مربع واحد في شبكة تاريخ العميل
class HistoryStat {
  final int count;

  /// المعنى بيختلف حسب النوع: **جنيه** للمبيعات والتحصيلات
  /// والمرتجعات، و**قطع** للهدايا، و**صفر** لصور الأرفف.
  final double total;
  final DateTime? lastAt;

  const HistoryStat.empty()
      : count = 0,
        total = 0,
        lastAt = null;

  HistoryStat.fromJson(Map<String, dynamic> j)
      : count = (j['count'] as num?)?.toInt() ?? 0,
        total = (j['total'] as num?)?.toDouble() ?? 0,
        lastAt = j['last_at'] == null
            ? null
            : DateTime.tryParse(j['last_at'])?.toLocal();
}

/// بند جوّه عنصر تاريخ (سطر فاتورة أو مرتجع)
class HistoryLine {
  final String name;
  final String? image;
  final int qty;
  final double total;

  /// سليم/تالف — للمرتجعات بس، `null` في غيرها
  final String? condition;

  HistoryLine.fromJson(Map<String, dynamic> j)
      : name = j['name'] ?? '—',
        image = j['image'] as String?,
        qty = (j['qty'] as num?)?.toInt() ?? 0,
        total = (j['total'] as num?)?.toDouble() ?? 0,
        condition = j['condition'] as String?;
}

/// عنصر واحد في ليستة تاريخ العميل — فاتورة أو تحصيل أو مرتجع
/// أو هدية أو صورة رف.
///
/// ⚠️ **موديل واحد للأنواع الخمسة عن قصد.** الحقول اللي مالهاش
/// معنى في نوع بتيجي `null`، والشاشة بتقرا اللي يخصها. خمس
/// موديلات كانوا هيتحوّلوا لخمس شاشات ليستة متطابقة تقريباً.
class HistoryEntry {
  final int id;
  final String title;
  final double amount;
  final int qty;
  final DateTime? time;

  /// cash/credit — للمبيعات
  final String? payment;

  /// cash/card/cheque/transfer — للتحصيلات
  final String? method;

  /// نص مترجّم من السيرفر — للمرتجعات
  final String? policyLabel;

  /// سبب الهدية — للهدايا
  final String? reason;

  /// before/after — لصور الأرفف
  final String? stage;

  /// صورة الإثبات (تحصيل) أو صورة الرف
  final String? photo;

  /// صورة المنتج — للهدايا
  final String? image;

  final List<HistoryLine> lines;

  HistoryEntry.fromJson(Map<String, dynamic> j)
      : id = (j['id'] as num?)?.toInt() ?? 0,
        title = j['title'] ?? '—',
        amount = (j['amount'] as num?)?.toDouble() ?? 0,
        qty = (j['qty'] as num?)?.toInt() ?? 0,
        time = j['time'] == null ? null : DateTime.tryParse(j['time'])?.toLocal(),
        payment = j['payment'] as String?,
        method = j['method'] as String?,
        policyLabel = j['policy_label'] as String?,
        reason = j['reason'] as String?,
        stage = j['stage'] as String?,
        photo = j['photo'] as String?,
        image = j['image'] as String?,
        lines = ((j['lines'] ?? []) as List)
            .map((e) => HistoryLine.fromJson(e as Map<String, dynamic>))
            .toList();
}
