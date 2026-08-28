import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════
/// PROMAX — طبقة الهوية
/// الألوان والخطوط مأخوذة حرفياً من Brand Guidelines 2024.
/// ممنوع تخترع لون هنا — لو محتاج درجة جديدة راجع الجايد لاين.
/// ═══════════════════════════════════════════════════════════
class Brand {
  Brand._();

  // ---------- 2.1 Main palette ----------
  static const royalBlue = Color(0xFF12399B); // primary
  static const purpleHeart = Color(0xFF602D90); // primary
  static const razzmatazz = Color(0xFFD74297); // secondary pink
  static const yellow = Color(0xFFFFF927); // secondary

  // تدرجات الأزرق
  static const blue600 = Color(0xFF194FBD);
  static const blue500 = Color(0xFF2470E3);
  static const blue400 = Color(0xFF389CFF);
  static const blue200 = Color(0xFF82C7FF);
  static const blue050 = Color(0xFFE8F1FF);

  // تدرجات البنفسجي
  static const purple600 = Color(0xFF6E38AD);
  static const purple500 = Color(0xFF7D40D6);
  static const purple400 = Color(0xFF914FFC);
  static const purple200 = Color(0xFFC4A6FF);
  static const purple050 = Color(0xFFF2ECFF);

  // ---------- محايدات ----------
  static const ink = Color(0xFF0A0A0F);
  static const paper = Color(0xFFF5F5F5);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE4E4EA);
  static const text = Color(0xFF12121A);
  static const muted = Color(0xFF6B6B7B);

  // ---------- دلالات ----------
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFB00020);
  static const orange = Color(0xFFB86E00);

  /// التدرج الرسمي — أزرق ملكي لبنفسجي
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [royalBlue, purpleHeart],
  );

  /// لون كل رول — كلها من الباليت، مفيش لون بره الهوية
  static Color forRole(String? role) => switch (role) {
        'driver' => blue500,
        'promoter' => purple500,
        'manager' || 'admin' => purpleHeart,
        // رولز المكتب — لون مختلف عشان اللي ماسك الموبايل يعرف
        // إنه مش على شاشة ميدان بمجرد ما يبصّ
        'accountant' => razzmatazz,
        'warehouse_keeper' => blue500,
        _ => royalBlue,
      };

  /// اسم الخط حسب اللغة — Cairo للعربي و Poppins للإنجليزي.
  ///
  /// ⚠️ **قرار 2026-07-31:** العربي بقى Cairo بدل Zagma. Zagma خط
  /// عناوين (Display) — حلو في اللوجو، بس المندوب بيقرا شاشة فيها
  /// أسماء عملاء وأرقام صغيرة تحت الشمس، وCairo مصمّم للواجهات
  /// وبيقرا أوضح في المقاسات الصغيرة.
  ///
  /// ⚠️ Zagma **لسه مسجّل في `pubspec.yaml`** — أي شاشة بتناديه
  /// بالاسم مباشرة مش هتقع. متاح للعناوين البراندية.
  static const fontEn = 'Poppins';
  static const fontAr = 'Cairo';

  /// خط العناوين البراندي — للسبلاش والعناوين الكبيرة بس
  static const fontDisplay = 'Zagma';
}

/// ═══ الصاعقة ⚡ — عنصر البراند الأساسي (4.1) ═══
/// مرسومة كـ Path عشان تتلون وتتحجّم من غير أصول إضافية.
class BoltPainter extends CustomPainter {
  final Color color;
  final double opacity;

  const BoltPainter({this.color = Brand.royalBlue, this.opacity = 1});

  // نفس مسار الـ SVG الرسمي، على viewBox 225×416
  static const _w = 225.0;
  static const _h = 416.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _w;
    final p = Path()
      ..moveTo(221.25, 161.02)
      ..cubicTo(159.33, 243.85, 97.33, 326.59, 35.66, 409.61)
      ..cubicTo(31.24, 415.61, 21.08, 411.89, 23.38, 404.03)
      ..cubicTo(40.72, 345.81, 59.16, 287.99, 76.49, 229.77)
      ..lineTo(13.3, 229.77)
      ..cubicTo(5.96, 229.77, 0.0, 223.80, 0.0, 216.43)
      ..lineTo(64.19, 10.22)
      ..cubicTo(65.80, 5.04, 70.56, 1.48, 75.99, 1.41)
      ..lineTo(170.47, 0.13)
      ..lineTo(170.47, 0.16)
      ..cubicTo(175.26, 0.0, 177.90, 4.27, 176.28, 10.18)
      ..cubicTo(171.79, 26.13, 141.0, 118.53, 132.32, 144.82)
      ..cubicTo(131.44, 147.46, 132.22, 148.23, 135.09, 148.26)
      ..cubicTo(161.96, 148.29, 188.88, 148.45, 215.73, 149.13)
      ..cubicTo(222.34, 148.49, 225.38, 156.07, 221.25, 161.02)
      ..close();

    canvas.save();
    canvas.scale(s);
    canvas.drawPath(p, Paint()..color = color.withValues(alpha: opacity));
    canvas.restore();
  }

  @override
  bool shouldRepaint(BoltPainter old) =>
      old.color != color || old.opacity != opacity;
}

/// الصاعقة كويدجت جاهز
class Bolt extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const Bolt({
    super.key,
    this.size = 24,
    this.color = Brand.royalBlue,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size * (BoltPainter._h / BoltPainter._w),
        child: CustomPaint(
          painter: BoltPainter(color: color, opacity: opacity),
        ),
      );
}

/// خلفية بالتدرج + صاعقة علامة مائية — بتتستخدم في السبلاش واللوجين
class BrandBackdrop extends StatelessWidget {
  final Widget child;
  final double boltOpacity;

  const BrandBackdrop({
    super.key,
    required this.child,
    this.boltOpacity = .10,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    return Container(
      decoration: const BoxDecoration(gradient: Brand.gradient),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // العلامة المائية — مقلوبة شوية زي الجايد لاين
          Transform.rotate(
            angle: -0.16,
            child: Bolt(
              size: w * .82,
              color: Colors.white,
              opacity: boltOpacity,
            ),
          ),
          child,
        ],
      ),
    );
  }
}
