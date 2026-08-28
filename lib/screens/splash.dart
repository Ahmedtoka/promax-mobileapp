import 'package:flutter/material.dart';

import '../brand.dart';

/// شاشة البداية — اللوجو على تدرج الهوية والصاعقة علامة مائية.
/// بتفضل ظاهرة لحد ما الجلسة تتحمّل، وبتتحرك حركة بسيطة (150–300ms
/// زي ما الجايد لاين بيحب: الحركة تعبّر عن الطاقة مش تتفلسف).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, .6, curve: Curves.easeOut),
  );

  late final Animation<double> _rise = Tween(begin: 18.0, end: 0.0).animate(
    CurvedAnimation(parent: _c, curve: const Interval(0, .6, curve: Curves.easeOutCubic)),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BrandBackdrop(
        boltOpacity: .13,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Opacity(
            opacity: _fade.value,
            child: Transform.translate(
              offset: Offset(0, _rise.value),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  // اللوجو الرسمي — النسخة البيضا على التدرج
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 52),
                    child: Image.asset(
                      'assets/brand/logo/logo-h-white.png',
                      fit: BoxFit.contain,
                      // لو الأصل مش موجود لأي سبب، الاسم بيظهر نص
                      errorBuilder: (_, __, ___) => const Text(
                        'PROMAX',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'FOOD INDUSTRIES',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .7),
                      fontSize: 10.5,
                      letterSpacing: 3.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(Brand.yellow),
                    ),
                  ),
                  const SizedBox(height: 54),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
