import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n.dart';
import '../nav.dart';
import '../session.dart';
import 'attendance.dart' show AttendanceCard;
import 'accountant_collections.dart';
import 'keeper_picks.dart';
import 'shared.dart';

/// ═══════════════════════════════════════════════════════════════
/// شاشات رولز المكتب على الموبايل — المحاسب وأمين المخزن
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ **الرولين دول كانوا بيقعوا على `RepHome`** — زرار «بيع» وعهدة
/// لمحاسب. دلوقتي:
/// - **الأمين**: بورد تجهيز حقيقي (`KeeperPicksBoard`) + هيستوري.
/// - **المحاسب**: تحصيلات الميدان (شيكات وتحويلات بصور إثباتها) —
///   عشان إشعار «تحصيل غير نقدي» يفتح على حاجة مش على لوحة صمّاء.
///
/// ⚠️ **`NavTarget` إجباري هنا** (تدقيق ٩/٨): من غيره لينكات
/// الإشعارات (`replenishment:` للأمين و`collections` للمحاسب) كانت
/// بتتحط في `AppNav.pending` **ومحدش يقراها ولا يصفّرها أبداً**.
/// الشاشة تاب واحد فعلياً، فأي وجهة معروفة بترجع للرئيسية.
class OfficeHome extends StatefulWidget {
  const OfficeHome({super.key});

  @override
  State<OfficeHome> createState() => _OfficeHomeState();
}

class _OfficeHomeState extends State<OfficeHome> with NavTarget<OfficeHome> {
  @override
  int? tabForLink(String kind) => 0;

  @override
  void goToTab(int index) {
    // شاشة بتاب واحد — الوجهة بتتسحب وتتصفّر وخلاص
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final user = Session.I.user;
        final isKeeper = user?.role == 'warehouse_keeper';

        return Scaffold(
          appBar: AppBar(
            title: Text(isKeeper
                ? L.t('role_warehouse_keeper')
                : L.t('role_accountant')),
            actions: [
              // ⚠️ زرار اللغة كان مش موجود خالص للرولين دول —
              // الأمين كان لازم يخرج ويدخل من شاشة اللوجين
              const LangSwitch(),
              IconButton(
                // ⚠️ الشارة كانت ناقصة — الأمين ماكانش يعرف إن فيه
                // أمر تجهيز جديد وصله غير لو فتح الجرس بنفسه
                icon: Badge(
                  isLabelVisible: Session.I.unreadCount > 0,
                  label: Text('${Session.I.unreadCount}'),
                  child: const Icon(Icons.notifications_none),
                ),
                onPressed: () => showNotifications(context),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: L.t('logout'),
                // ⚠️ بتأكيد — زي كل الرولز، مش خروج بدوسة واحدة بالغلط
                onPressed: () => confirmLogout(context),
              ),
            ],
          ),
          // ⚠️ **الأمين بورد تجهيز والمحاسب تحصيلات** (تدقيق ٩/٨):
          // النسخة الأولى للأمين اتشالت عشان `GET /picks` بيرجّع
          // أوامر المندوب — الدرس موثّق هنا وفي `keeper_picks.dart`.
          body: isKeeper
              ? const KeeperPicksBoard()
              : const AccountantCollectionsBoard(),
        );
      },
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// رول مالوش شاشة
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ **الشاشة دي وجودها هو الفايدة.** قبلها كان `_ => RepHome()` —
/// أي رول جديد يتضاف بياخد شاشة السيلز إيجينت في صمت، بزرار «بيع»
/// وعهدة. الخطأ الصامت ده أسوأ من شاشة بتقول «مافيش شاشة»: الأولانية
/// بتخلّي حد يعمل حركة غلط، والتانية بتخلّيه يكلّم الأدمن.
class UnknownRoleScreen extends StatelessWidget {
  const UnknownRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Session.I.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('app_name')),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: L.t('logout'),
            onPressed: () => confirmLogout(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.help_outline, size: 64, color: Color(0xFF9A9A9A)),
              const SizedBox(height: 16),
              Text(
                L.t('no_screen_for_role', {'role': user?.role ?? '—'}),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// كارت الحضور فوق أي بورد مكتب — الأمين والمحاسب بيسجّلوا حضور
/// زي أي موظف، وكان مفيش أي مدخل ليه فالسيستم بيقفل يومهم أوتوماتيك
/// على ساعة غلط (نفس الباج اللي اتصلح للميدان ٨/٨).
class OfficeBoardHeader extends StatelessWidget {
  final Widget child;

  const OfficeBoardHeader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final user = Session.I.user;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Column(
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.name ?? '',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text(user?.roleLabel ?? '',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Brand.forRole(user?.role),
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      Text(user?.code ?? '',
                          style: const TextStyle(
                              fontSize: 11, color: Brand.muted)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const AttendanceCard(),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
