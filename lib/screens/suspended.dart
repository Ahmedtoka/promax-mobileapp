import 'package:flutter/material.dart';

import '../api.dart';
import '../brand.dart';
import '../l10n.dart';
import '../session.dart';

/// ═══════════════════════════════════════════════════════════════
/// الأبلكيشن موقوف على الموظف ده (2026-08-08)
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ **شاشة نهاية مش رسالة خطأ.** لما الإدارة توقف موظف، السيرفر
/// كان بيرد 401 زي أي جلسة منتهية — فالأبلكيشن يمسح التوكن ويرجّعه
/// للوجين، وهو يدخل ويتوقف تاني في لفة لا نهائية. وكان بيتصل يقول
/// «الأبلكيشن بايظ» وهو موقوف بقرار.
///
/// ⚠️ **مفيش زرار «حاول تاني».** الوقف قرار إداري مش عطل شبكة —
/// وزرار إعادة المحاولة كان بيوحي إن فيه حاجة تتصلح من هنا.
/// الزرار الوحيد بيمسح الجلسة عشان اللي بعده يقدر يسجّل دخول على
/// نفس التليفون.
class SuspendedScreen extends StatelessWidget {
  final String message;

  const SuspendedScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.paper,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Brand.red.withValues(alpha: .10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline,
                      size: 42, color: Brand.red),
                ),
                const SizedBox(height: 22),

                Text(
                  L.t('suspended_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: Brand.red),
                ),
                const SizedBox(height: 12),

                // ⚠️ **رسالة السيرفر زي ما هي.** الإدارة ممكن تغيّر
                // النص (تحط رقم تليفون مثلاً) من غير إصدار جديد،
                // ونص مكتوب في الأبلكيشن كان بيمنع ده.
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13.5, height: 1.8, color: Brand.muted),
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: Brand.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      // ⚠️ الترتيب مهم: الخروج بيمسح التوكن الأول،
                      // وبعدين بنفضّي الإشارة — لو عكسنا، الشاشة
                      // بترجع للوجين والتوكن الموقوف لسه متخزن،
                      // فأول ريكوست بيرجّع نفس الشاشة.
                      await Session.I.logout();
                      Api.suspended.value = null;
                    },
                    icon: const Icon(Icons.logout, size: 19),
                    label: Text(L.t('logout'),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
