import 'package:flutter/material.dart';

import 'models.dart';

// ============ أوامر التجهيز — المندوب بيستلم عهدته من المخزن ============

/// صنف جوّه أمر تجهيز — بالباتش والصلاحية ومكانه على الرف
class PickItem {
  final int id;
  final int productId;
  final String name;
  final String code;
  final String unit;

  /// صورة المنتج — ريفرنس بصري وهو بيعدّ
  final String? image;
  final String batchNo;
  final String? expiresOn;
  final String location;
  final int qtyRequested;
  final int qtyPicked;
  final int? qtyReceived;

  /// كام من الكمية دي هدايا — مش للبيع.
  ///
  /// ⚠️ **لازم تبان للمندوب قبل ما يستلم.** لو مابانتش، بيستلم
  /// الكمية كلها وهو فاكرها كلها للبيع، وبعدين بيلاقي في عهدته
  /// كمية «مجانية» مش عارف مصدرها ولا مصيرها.
  final int giftQty;

  /// الكمية اللي المندوب بيأكدها وهو بيعدّ — بتبدأ باللي المخزن جهّزه
  int qtyToReceive;

  PickItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        productId = j['product_id'] ?? 0,
        name = j['name'] ?? '',
        code = j['code'] ?? '',
        unit = j['unit'] ?? '',
        image = j['image'],
        batchNo = j['batch_no']?.toString() ?? '—',
        expiresOn = j['expires_on']?.toString(),
        location = j['location']?.toString() ?? '—',
        qtyRequested = j['qty_requested'] ?? 0,
        qtyPicked = j['qty_picked'] ?? 0,
        giftQty = j['gift_qty'] ?? 0,
        qtyReceived =
            j['qty_received'] == null ? null : (j['qty_received'] as num).toInt(),
        qtyToReceive = j['qty_picked'] ?? 0;

  /// المندوب عدّ رقم مختلف عن اللي المخزن جهّزه؟
  bool get hasVariance => qtyToReceive != qtyPicked;

  /// المخزن جهّز أقل من المطلوب؟
  bool get shortPicked => qtyPicked < qtyRequested;

  /// فيه هدايا في السطر ده؟
  bool get hasGift => giftQty > 0;

  /// اللي للبيع فعلاً
  int get saleQty => (qtyPicked - giftQty).clamp(0, qtyPicked);

  /// تاريخ الصلاحية بشكل مقروء
  String get expiryLabel {
    final d = expiresOn == null ? null : DateTime.tryParse(expiresOn!);
    if (d == null) return '—';
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$day/$m/${d.year}';
  }

  Map<String, dynamic> toReceiveJson() => {'id': id, 'qty': qtyToReceive};
}

/// أمر تجهيز: المخزن بيجهّز البضاعة والمندوب بيستلمها وتنزل عهدته
class PickOrder {
  final int id;
  final String number;
  final String warehouse;
  final String status; // requested / picking / ready / handed / cancelled
  final String statusLabel;
  final String purpose;
  final String purposeLabel;
  final int qtyRequested;
  final int qtyPicked;
  final int qtyReceived;

  /// إجمالي الهدايا في الأمر — بتبان في الكارت قبل ما يفتحه.
  final int giftTotal;

  final bool canReceive;
  final bool hasVariance;
  final DateTime? neededOn;
  final DateTime? readyAt;
  final DateTime? handedAt;
  final DateTime time;
  final String? notes;
  final List<PickItem> items;

  PickOrder.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        number = j['number'] ?? '',
        warehouse = j['warehouse']?.toString() ?? '',
        status = j['status'] ?? 'requested',
        statusLabel = j['status_label'] ?? '',
        purpose = j['purpose'] ?? '',
        purposeLabel = j['purpose_label'] ?? '',
        qtyRequested = j['qty_requested'] ?? 0,
        qtyPicked = j['qty_picked'] ?? 0,
        qtyReceived = j['qty_received'] ?? 0,
        giftTotal = j['gift_total'] ?? 0,
        canReceive = j['can_receive'] == true,
        hasVariance = j['has_variance'] == true,
        neededOn = parseTime(j['needed_on']),
        readyAt = parseTime(j['ready_at']),
        handedAt = parseTime(j['handed_at']),
        time = parseTime(j['time']) ?? DateTime.now(),
        notes = j['notes']?.toString(),
        items = ((j['items'] ?? []) as List)
            .map((e) => PickItem.fromJson(e))
            .toList();

  bool get isReady => status == 'ready';
  bool get isHanded => status == 'handed';

  /// إجمالي اللي المندوب بيأكده دلوقتي في شاشة الاستلام
  int get qtyToReceive => items.fold(0, (s, i) => s + i.qtyToReceive);

  /// فيه بند اتعدّل عن اللي المخزن جهّزه؟
  bool get touched => items.any((i) => i.hasVariance);

  (Color, String) get info => switch (status) {
        'ready' => (const Color(0xFF2563EB), statusLabel),
        'handed' => (const Color(0xFF16A34A), statusLabel),
        'cancelled' => (const Color(0xFFB00020), statusLabel),
        'picking' => (const Color(0xFFB86E00), statusLabel),
        _ => (Colors.grey, statusLabel),
      };
}
