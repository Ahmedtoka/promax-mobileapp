import 'package:flutter/material.dart';
import 'l10n.dart';

import 'models.dart';

// ================= موديلز البروموتر =================

enum BranchVisitStatus { pending, inVisit, done }

/// فرع كي أكاونت بيزوره البروموتر
class Branch {
  final int id;
  final String name;
  final String address;
  final String phone;
  final String? subChannel;
  final BranchVisitStatus status;
  final int? visitId;
  final int movedToday;

  Branch.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'] ?? '',
        address = j['address'] ?? '',
        phone = j['phone'] ?? '',
        subChannel = j['sub_channel']?.toString(),
        visitId = j['visit_id'],
        movedToday = j['moved_today'] ?? 0,
        status = switch (j['visit_status']) {
          'in_visit' => BranchVisitStatus.inVisit,
          'done' => BranchVisitStatus.done,
          _ => BranchVisitStatus.pending,
        };

  (Color, String, IconData) get info => switch (status) {
        BranchVisitStatus.done => (
            const Color(0xFF16A34A),
            L.t('visited'),
            Icons.check_circle
          ),
        BranchVisitStatus.inVisit => (
            const Color(0xFFB86E00),
            L.t('visit_open'),
            Icons.timelapse
          ),
        BranchVisitStatus.pending => (
            Colors.grey,
            L.t('pending'),
            Icons.radio_button_unchecked
          ),
      };
}

/// بند ريفيل — صنف على الرف
class RefillLine {
  final int productId;
  final String name;
  final String unit;
  int shelfBefore;
  int storeQty;
  int movedQty;
  bool outOfStock;

  /// اتشالت علامته من المنتقي المتعدد بعد ما كان متسجل — لازم
  /// يتبعت للسيرفر بأصفاره عشان صفه القديم يتمسح (١٢/٨).
  /// من غيرها فلتر `touched` كان بيسقّطه من الحمولة والصف بيعيش.
  bool removed = false;

  RefillLine({
    required this.productId,
    required this.name,
    required this.unit,
    this.shelfBefore = 0,
    this.storeQty = 0,
    this.movedQty = 0,
    this.outOfStock = false,
  });

  RefillLine.fromJson(Map<String, dynamic> j)
      : productId = j['product_id'],
        name = j['name'] ?? '',
        unit = j['unit'] ?? '',
        shelfBefore = j['shelf_before'] ?? 0,
        storeQty = j['store_qty'] ?? 0,
        movedQty = j['moved_qty'] ?? 0,
        outOfStock = j['out_of_stock'] == true;

  int get shelfAfter => shelfBefore + movedQty;

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'shelf_before': shelfBefore,
        'store_qty': storeQty,
        'moved_qty': movedQty,
        'out_of_stock': outOfStock,
      };

  /// فيه حاجة اتسجلت؟
  bool get touched => movedQty > 0 || outOfStock || shelfBefore > 0 || storeQty > 0;
}

/// زيارة بروموتر مفتوحة
class MerchVisit {
  final int id;
  final int clientId;
  final String client;
  final String address;
  final DateTime? checkedInAt;
  final String? photoBefore;
  final String? photoAfter;
  final bool hasPhotoBefore;
  final bool hasPhotoAfter;
  final int movedTotal;
  final int outOfStock;
  final bool hasRequest;
  final List<RefillLine> refills;

  /// الزيارة اتقفلت بدون تصوير بعلم المنسق (٢١/٩)
  final bool noPhotos;

  /// جرد الرف في الزيارة دي، وآخر جرد اتعمل في نفس الفرع قبلها
  final List<CountLine> counts;
  final List<CountLine> lastCounts;
  final DateTime? lastCountAt;

  /// لوكيشن الفرع مؤكَّد من الداشبورد (١٥/٩) — زرار «تأكيد عنوان الفرع»
  /// بيختفي، والسيرفر بيرفض 409 لو وصله على أي حال
  final bool locationConfirmed;

  MerchVisit.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        clientId = j['client_id'],
        locationConfirmed = j['location_confirmed'] == true,
        client = j['client'] ?? '',
        address = j['address'] ?? '',
        checkedInAt = parseTime(j['checked_in_at']),
        photoBefore = j['photo_before']?.toString(),
        photoAfter = j['photo_after']?.toString(),
        hasPhotoBefore = j['has_photo_before'] == true,
        hasPhotoAfter = j['has_photo_after'] == true,
        movedTotal = j['moved_total'] ?? 0,
        outOfStock = j['out_of_stock'] ?? 0,
        hasRequest = j['has_request'] == true,
        noPhotos = j['no_photos'] == true,
        lastCountAt = parseTime(j['last_count_at']),
        counts = ((j['counts'] ?? []) as List)
            .map((e) => CountLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        lastCounts = ((j['last_counts'] ?? []) as List)
            .map((e) => CountLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        refills = ((j['refills'] ?? []) as List)
            .map((e) => RefillLine.fromJson(e))
            .toList();
}

/// سطر جرد رف: الكمية بوحدتها + تاريخ الإنتاج والانتهاء، بإيد المنسق
class CountLine {
  final int productId;
  final String name;
  double qty;
  String unit;
  DateTime? productionDate;
  DateTime? expiryDate;
  String? note;

  CountLine.blank(this.productId, this.name, this.unit) : qty = 0;

  CountLine.fromJson(Map<String, dynamic> j)
      : productId = j['product_id'],
        name = j['name'] ?? '',
        qty = ((j['qty'] ?? 0) as num).toDouble(),
        unit = j['unit'] ?? 'piece',
        productionDate = _day(j['production_date']),
        expiryDate = _day(j['expiry_date']),
        note = j['note']?.toString();

  static DateTime? _day(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  CountLine copy() => CountLine.blank(productId, name, unit)
    ..qty = qty
    ..productionDate = productionDate
    ..expiryDate = expiryDate
    ..note = note;

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'qty': qty,
        'unit': unit,
        'production_date': productionDate == null ? null : _iso(productionDate!),
        'expiry_date': expiryDate == null ? null : _iso(expiryDate!),
        'note': note,
      };
}

/// صنف في الكتالوج (لاختياره في الريفيل)
class CatalogProduct {
  final int id;
  final String code;
  final String name;

  /// ⚠️ **نَل مسموح** — الصنف اللي مالوش صورة مرفوعة بيرجع `null`
  /// والمنتقي بيوري أيقونة بديلة.
  final String? image;
  final String unit;

  /// وحدات القياس المعرّفة للصنف ومضاعِف كل واحدة بالقطع (٢١/٩) —
  /// سيرفر قديم مابيبعتهاش = قطعة بس
  final Map<String, int> unitFactors;

  CatalogProduct.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        code = j['code'] ?? '',
        name = j['name'] ?? '',
        image = j['image'] as String?,
        unit = j['unit'] ?? '',
        unitFactors = {
          'piece': 1,
          for (final e in ((j['unit_factors'] ?? const {}) as Map).entries)
            e.key.toString(): (e.value as num).toInt(),
        };

  /// بالترتيب الثابت: قطعة ← علبة ← كرتونة
  List<String> get countUnits =>
      ['piece', 'box', 'case'].where(unitFactors.containsKey).toList();

  /// الرف بيتعد بالقطعة — العلبة والكرتونة للمخزن الخلفي
  String get defaultCountUnit => 'piece';
}

/// طلب ريفيل
class ReplenishmentRow {
  final int id;
  final String number;
  final String client;
  final String status;
  final String statusLabel;
  final int qtyTotal;
  final DateTime time;

  ReplenishmentRow.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        number = j['number'] ?? '',
        client = j['client'] ?? '',
        status = j['status'] ?? 'pending',
        statusLabel = j['status_label'] ?? '',
        qtyTotal = j['qty_total'] ?? 0,
        time = parseTime(j['time']) ?? DateTime.now();

  (Color, String) get info => switch (status) {
        'delivered' => (const Color(0xFF16A34A), statusLabel),
        'assigned' => (const Color(0xFF2563EB), statusLabel),
        'cancelled' => (const Color(0xFFB00020), statusLabel),
        _ => (const Color(0xFFB86E00), statusLabel),
      };
}

class PromoterStats {
  final int visits;
  final int visitsDone;
  final int moved;
  final int requests;
  final int branches;

  PromoterStats.fromJson(Map<String, dynamic> j)
      : visits = j['visits'] ?? 0,
        visitsDone = j['visits_done'] ?? 0,
        moved = j['moved'] ?? 0,
        requests = j['requests'] ?? 0,
        branches = j['branches'] ?? 0;

  PromoterStats.empty()
      : visits = 0,
        visitsDone = 0,
        moved = 0,
        requests = 0,
        branches = 0;
}
