import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n.dart';
import '../updater.dart';
import '../version.dart';

/// ═══════════════════════════════════════════════════════════════
/// شاشة التحديث الإجباري
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ **مفيش زرار رجوع ومفيش تجاهل.** الشاشة دي بتظهر بس لما نسخة
/// المندوب أقدم من `app_min_version` — يعني الأدمن قرر إن النسخة دي
/// **ماينفعش تشتغل** (بتكسّر داتا أو الـAPI اتغيّر). لو سيبناه
/// يتخطاها، هيفضل يشتغل بنسخة بتكتب أرقام غلط.
///
/// اللي بيقلل خطورة القرار ده إن الأدمن هو اللي بيحدد الرقم من
/// شاشة «إصدار الأبلكيشن»، والافتراضي إن الاتنين متساويين — يعني
/// مفيش إجبار غير لما يتعمل بالإيد عن قصد.
class UpdateGate extends StatefulWidget {
  final UpdateInfo info;

  const UpdateGate({super.key, required this.info});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  bool _busy = false;
  String? _error;

  Future<void> _update() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final err = await Updater.install(widget.info.apkUrl);

    if (!mounted) return;

    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.info;

    // ⚠️ `PopScope(canPop: false)` — زرار الرجوع بتاع أندرويد كان
    // بيطلّعه من الشاشة ويرجّعه للأبلكيشن بنسخته القديمة
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Brand.paper,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      gradient: Brand.gradient,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.system_update,
                        color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    L.t('update_required'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    L.t('update_required_hint'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12.5, color: Brand.muted, height: 1.6),
                  ),

                  if (i.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: Brand.blue050,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: Brand.blue200),
                      ),
                      child: Text(
                        i.note,
                        style: const TextStyle(
                            fontSize: 12.5, height: 1.6, color: Brand.text),
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),
                  // نسخته مقابل الجديدة — بيوضّح ليه اتقفل عليه
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: Brand.card,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: Brand.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _v(L.t('update_yours'), appVersion, Brand.red),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Icon(Icons.arrow_forward,
                              size: 17, color: Brand.muted),
                        ),
                        _v(L.t('update_new'), i.latest, Brand.green),
                      ],
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12, color: Brand.red, height: 1.5),
                    ),
                  ],

                  const SizedBox(height: 22),

                  if (!i.canInstall)
                    // ⚠️ إجبار من غير رابط = مصيدة. لو حصل، بنقول
                    // للمندوب يكلم الإدارة بدل ما يفضل يدوس زرار مايشتغلش
                    Text(
                      L.t('update_no_file'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12.5, color: Brand.red, height: 1.6),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _update,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.download),
                        label: Text(
                            _busy ? L.t('update_downloading') : L.t('update_now')),
                      ),
                    ),

                  // ═══ بار التنزيل الحقيقي (2026-08-08) ═══
                  //
                  // ⚠️ **سبينر مبهم كان بيخلّي المندوب يقفل الأبلكيشن.**
                  // الـAPK ~40 ميجا على شبكة الشارع = دقيقة كاملة شاشة
                  // ماتقولش إذا كانت شغالة ولا معلّقة. البار بيقول
                  // النسبة والميجات، وبيتحرك كل 200 كيلو.
                  if (_busy) ...[
                    const SizedBox(height: 14),
                    ValueListenableBuilder<double?>(
                      valueListenable: Updater.progress,
                      builder: (_, pct, __) => Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              // ⚠️ `null` = بار متحرك غير محدّد. السيرفر
                              // اللي مش باعت `Content-Length` مالوش نسبة،
                              // وعرض «0%» ثابت كان بيبان كأنه واقف.
                              value: pct,
                              minHeight: 9,
                              backgroundColor: Brand.border,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ValueListenableBuilder<int>(
                            valueListenable: Updater.received,
                            builder: (_, got, __) => Text(
                              pct == null
                                  ? Updater.mb(got)
                                  : '${(pct * 100).round()}%  ·  ${Updater.mb(got)}',
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  color: Brand.royalBlue),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      L.t('update_wait'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 11.5, color: Brand.muted, height: 1.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _v(String label, String value, Color color) => Column(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: Brand.muted)),
          const SizedBox(height: 2),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: TextStyle(
                fontSize: 14.5, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      );
}
