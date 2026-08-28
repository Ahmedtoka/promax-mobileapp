import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../brand.dart';
import '../l10n.dart';
import '../models.dart';
import '../session.dart';
import '../version.dart';
import 'client_requests.dart';
import 'sales_history.dart';
import 'my_requests.dart';
import 'shared.dart';

/// ═══════════════════════════════════════════════════════════════
/// حسابي — بيانات المندوب وإعداداته
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ الخروج واللغة اتنقلوا هنا من أبار الرئيسية — مكانهم الطبيعي
/// مع بيانات الحساب، والأبار فضيت للإشعارات اللي بتتغير طول اليوم.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Session.I;
    final u = s.user;
    final color = Theme.of(context).colorScheme.primary;

    // ⚠️ **الأب بار اتشال (طلب المالك ٢١/٨)** — كارت الهوية المتدرج
    // هو الهيدر، بنفس ستايل الرئيسية والتوريد. SafeArea من فوق عشان
    // شريط الحالة، والأيقونات ثابتة غامقة من AnnotatedRegion الهوم.
    return Scaffold(
      body: SafeArea(
      child: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          children: [
            // ═══ هيدر الهوية بالتدرج الرسمي (تطوير ١٩/٨) ═══
            // بدل الكارت الأبيض الساكت: تدرج البراند + شارة الرول +
            // أرقام يومه قدامه — نفس لغة كارت سامري العهدة.
            Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              decoration: BoxDecoration(
                gradient: Brand.gradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: .28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // صورة الموظف (٩/٨) — اضغط عليها تغيّرها.
                      // بإطار أبيض عشان تبان على التدرج.
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: _AvatarButton(color: color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u?.name ?? '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white)),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _chip(u?.roleLabel ?? ''),
                                _chip(u?.code ?? ''),
                                if (u?.zone != null) _chip('📍 ${u!.zone}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // ═══ يومه بالأرقام — مش للمدير (إحصائياته مختلفة) ═══
                  if (!(u?.isManager ?? false)) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        children: [
                          _stat(L.t('today_sales_stat'), money(s.today.sales)),
                          _statDivider(),
                          _stat(L.t('today_invoices_stat'),
                              '${s.today.invoices}'),
                          _statDivider(),
                          _stat(L.t('today_visits_stat'),
                              '${s.today.visitsDone} / ${s.today.visits}'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ═══ العهدة باختصار — والضغط بيفتح التفاصيل كاملة ═══
            if (s.custody.exists)
              Card(
                child: ListTile(
                  leading: Icon(Icons.inventory_2_outlined, color: color),
                  title: Text(L.t('custody'),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                      '${L.t('remaining')}: ${s.custody.remainingUnits}',
                      style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CustodyScreen()),
                  ),
                ),
              ),

            // ═══ طلباتي — طلبات البضاعة وحالتها (2026-08-09) ═══
            // للسيلز والمدير (١١/٨ مساءً): الاتنين بيطلبوا بضاعة من
            // عند العميل من شاشة الزيارة. البروموتر ليه تاب الريفيل.
            if ((s.user?.isSalesAgent ?? false) || (s.user?.isManager ?? false))
              Card(
                child: ListTile(
                  leading: Icon(Icons.add_shopping_cart, color: color),
                  title: Text(L.t('my_requests_title'),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(L.t('my_requests_sub'),
                      style: const TextStyle(fontSize: 11.5)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
                  ),
                ),
              ),

            // ═══ طلبات العملاء الجدد — اللي سجلتهم وحالتهم ═══
            // ⚠️ للسيلز بس (تدقيق ٩/٨): البروموتر والمدير الليستة
            // عندهم فاضية دايماً — الريفريش بتاعهم مش بيملاها أصلاً
            if (s.user?.isSalesAgent ?? false)
            Card(
              child: ListTile(
                leading: Badge(
                  isLabelVisible:
                      s.requests.any((r) => r.status == 'pending'),
                  label: Text(
                      '${s.requests.where((r) => r.status == 'pending').length}'),
                  child: Icon(Icons.person_add_alt, color: color),
                ),
                title: Text(L.t('new_client_requests'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ClientRequestsScreen()),
                ),
              ),
            ),

            // ═══ مبيعاتي ومرتجعاتي ═══
            Card(
              child: ListTile(
                leading: Icon(Icons.receipt_long_outlined, color: color),
                title: Text(L.t('my_sales'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SalesHistoryScreen()),
                ),
              ),
            ),

            // ═══ الإشعارات ═══
            Card(
              child: ListTile(
                leading: Badge(
                  isLabelVisible: s.unreadCount > 0,
                  label: Text('${s.unreadCount}'),
                  child: Icon(Icons.notifications_outlined, color: color),
                ),
                title: Text(L.t('notifications'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => showNotifications(context),
              ),
            ),

            // ═══ التتبع — سجل تحركات اليوم ═══
            // ⚠️ مش للمدير (تدقيق ٩/٨): ريفريشه مش بيملى `events`
            // فالكارت كان بيفتح «مفيش تحركات» دايماً ويبان بايظ
            if (!(s.user?.isManager ?? false))
            Card(
              child: ListTile(
                leading: Icon(Icons.route_outlined, color: color),
                title: Text(L.t('tracking'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TrackingScreen()),
                ),
              ),
            ),

            // ═══ اللغة ═══
            Card(
              child: ListTile(
                leading: Icon(Icons.language, color: color),
                title: Text(L.t('language'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                // ⚠️ **اللون إجباري** (تدقيق ٩/٨): الديفولت أبيض للأب-بارات
            // الملونة — على كارت أبيض كان زرار اللغة **غير مرئي**، وده
            // المدخل الوحيد للغة عند السواق والبروموتر والمدير.
            trailing: const LangSwitch(color: Brand.muted),
              ),
            ),

            const SizedBox(height: 18),

            // ═══ الخروج ═══
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB00020),
                side: const BorderSide(color: Color(0xFFB00020)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: () => confirmLogout(context),
              icon: const Icon(Icons.logout, size: 18),
              label: Text(L.t('logout')),
            ),

            // إصدار الأبلكيشن — أول سؤال في أي بلاغ دعم
            const SizedBox(height: 12),
            Center(
              child: Text('PROMAX v$appVersion',
                  style: TextStyle(fontSize: 11, color: Brand.muted)),
            ),
          ],
        ),
      ),
      ),
    );
  }

  /// شارة بيضا شفافة على التدرج — رول/كود/منطقة
  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      );

  Widget _stat(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.white.withValues(alpha: .85))),
          ],
        ),
      );

  Widget _statDivider() => Container(
        width: 1,
        height: 30,
        color: Colors.white.withValues(alpha: .25),
      );
}

/// دايرة صورة الموظف + تغييرها (كاميرا/معرض) — ٩ أغسطس ٢٠٢٦
class _AvatarButton extends StatefulWidget {
  final Color color;

  const _AvatarButton({required this.color});

  @override
  State<_AvatarButton> createState() => _AvatarButtonState();
}

class _AvatarButtonState extends State<_AvatarButton> {
  bool _busy = false;

  Future<void> _change(ImageSource source) async {
    // ⚠️ امسك الماسنجر قبل أي await — النافيجيتور بيتقفل قبل ما
    // الرفع يخلص (نفس درس new_client الموثّق)
    final messenger = ScaffoldMessenger.of(context);

    try {
      final x = await ImagePicker()
          .pickImage(source: source, imageQuality: 82, maxWidth: 900);
      if (x == null) return;

      setState(() => _busy = true);
      final err = await Session.I.uploadAvatar(x.path);
      if (!mounted) return;
      setState(() => _busy = false);

      messenger.showSnackBar(SnackBar(
          content: Text(err ?? L.t('avatar_saved')),
          backgroundColor: err == null ? null : const Color(0xFFB00020)));
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger
          .showSnackBar(SnackBar(content: Text(L.t('camera_failed', {'e': '$e'}))));
    }
  }

  void _pickSource() {
    showModalBottomSheet(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(L.t('with_camera')),
              onTap: () {
                Navigator.of(sheet).pop();
                _change(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(L.t('pick_gallery')),
              onTap: () {
                Navigator.of(sheet).pop();
                _change(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = Session.I.user;
    final url = u?.avatarUrl;

    return InkWell(
      onTap: _busy ? null : _pickSource,
      borderRadius: BorderRadius.circular(30),
      child: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: widget.color.withValues(alpha: .12),
            backgroundImage: url != null ? NetworkImage(url) : null,
            child: url == null
                ? Text(
                    (u?.name ?? L.t('initial_unknown')).characters.first,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: widget.color),
                  )
                : null,
          ),
          if (_busy)
            const Positioned.fill(
              child: Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5))),
            )
          else
            PositionedDirectional(
              bottom: 0,
              end: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                    color: widget.color, shape: BoxShape.circle),
                child: const Icon(Icons.photo_camera,
                    size: 11, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
