import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
// ⚠️ **`GlobalKey` من `widgets` مش من `rendering`.** `rendering.dart`
// فيها `RenderRepaintBoundary` بس — والمفتاح نفسه حاجة في شجرة
// الويدجتس. الاستيراد ناقص كان بيكسّر البيلد بـ«Type 'GlobalKey'
// not found».
import 'package:flutter/widgets.dart';

/// ═══════════════════════════════════════════════════════════════
/// تصوير ودّي جزء من الشاشة ومشاركته (2026-08-08)
/// ═══════════════════════════════════════════════════════════════
///
/// المندوب بيخلّص أمر التوريد وعايز يبعت الورقة للعميل واتساب. بدل
/// ما يعمل سكرين شوت فيها البار والساعة والشبكة، بنصوّر **الكارت
/// نفسه** ونبعته.
///
/// ⚠️ **مفيش `share_plus` ولا `path_provider`** — نفس سياسة باقي
/// القنوات في المشروع (`doc_picker` / `locator` / `updater`).
/// الباكدجات دي بتجرّ تبعيات وبتكسر البيلد مع كل ترقية.
class Sharer {
  static const _channel = MethodChannel('promax/share');

  /// بيصوّر الودجت اللي جوه [key] وبيفتح شيت المشاركة.
  ///
  /// بترجّع `false` لو الصورة ماتعملتش أو المستخدم لغى.
  ///
  /// ⚠️ **`pixelRatio: 2.5` مش 1.** الصورة بتتبعت لعميل هيفتحها على
  /// تليفونه ويكبّرها — وبـ1 الأرقام بتطلع مهروسة ومش مقروءة، وهي
  /// كل الغرض من الورقة.
  static Future<bool> shareBoundary(
    GlobalKey key, {
    required String name,
    String? text,
  }) async {
    try {
      final ctx = key.currentContext;
      if (ctx == null) return false;

      final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return false;

      final image = await boundary.toImage(pixelRatio: 2.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return false;

      final bytes = data.buffer.asUint8List();

      final ok = await _channel.invokeMethod<bool>('shareImage', {
        'bytes': Uint8List.fromList(bytes),
        // ⚠️ اسم فيه رقم الأمر — المندوب اللي بيبعت 20 فاتورة في اليوم
        // مايلاقيش 20 ملف اسمهم `invoice.png` في المشاركات الأخيرة
        'name': name,
        'text': text,
      });

      return ok == true;
    } catch (_) {
      // ⚠️ **بيبلع الخطأ.** المشاركة كماليات — الفاتورة اتحفظت على
      // السيرفر خلاص، ورمي إكسبشن هنا كان بيوري المندوب شاشة حمرا
      // على حاجة نجحت فعلاً.
      return false;
    }
  }
}
