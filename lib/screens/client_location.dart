import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n.dart';
import '../locator.dart';
import '../models.dart';
import '../session.dart';
import 'shared.dart';

/// ═══════════════════════════════════════════════════════════════
/// ضيف لوكيشن العميل (١٤ أغسطس ٢٠٢٦)
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **بلاغ المالك اللي بنى الشاشة دي**: «كنت عامل حسابي إن
/// التشيك إن بتاع المندوب بيكون قدام المحل فيبقى ده لوكيشن المكان —
/// لكن المندوب بيعمل تشيك إن وهو في الطريق وبيدخل يجهّز الفاتورة».
///
/// يعني نقطة الزيارة **تخمين**. الشاشة دي بتخلّي المندوب يسحب نقطة
/// **بقصد** وهو واقف قدام المحل، والسيرفر بيكتبها متأكدة على طول
/// (`location_source = rep_app`) فالعميل بيخرج من طابور «جاهز
/// للتأكيد» في الداشبورد.
///
/// ⚠️ **الحفظ مقفول لحد ما النقطة تتسحب** (طلب المالك صراحةً: «لازم
/// أدوس زرار هات اللوكيشن عشان الإحداثيات لازم تتسحب»). من غير
/// القفل ده الشاشة كانت هتبقى فورم عنوان عادي، والعنوان بلا نقطة
/// مابيحلش المشكلة اللي اتعملت عشانها.
///
/// ⚠️ **`Locator.get(fresh: true)`** — الكاش بتاع الـ١٠ دقايق ممنوع
/// هنا. نقطة عمرها ١٠ دقايق هي بالظبط «نقطة الطريق» اللي بنهرب منها.
///
/// ⚠️ **كل خانة قابلة للتعديل بعد الديتكت.** جوجل/OSM بترجّع أقرب
/// معلَم مش عنوان المحل — المندوب هو اللي بيصحّح. وفشل الجيوكودينج
/// **مابيمنعش الحفظ**: النقطة اتسحبت وهي الأهم.
class ClientLocationScreen extends StatefulWidget {
  final Client client;

  const ClientLocationScreen({super.key, required this.client});

  @override
  State<ClientLocationScreen> createState() => _ClientLocationScreenState();
}

class _ClientLocationScreenState extends State<ClientLocationScreen> {
  final _addrEn = TextEditingController();
  final _addrAr = TextEditingController();

  /// النقطة المسحوبة — `null` معناه **الحفظ مقفول**
  (double, double)? _point;

  String? _gov;
  int? _zone;

  /// دروب داون المحافظات والمناطق — بتيجي مع رد الجيوكود مش مع
  /// البوت ستراب (ليستة ثابتة مالهاش لازمة تتحمّل مع كل مزامنة)
  List<_Option<String>> _govs = const [];
  List<_ZoneOption> _zones = const [];

  bool _capturing = false;
  bool _geocoding = false;
  bool _saving = false;

  /// رسالة تحت زرار الديتكت — «بنجيب العنوان…» / «مالقيناش عنوان»
  String? _geoMsg;

  bool get _busy => _capturing || _geocoding || _saving;

  @override
  void initState() {
    super.initState();

    // ⚠️ خانة الإنجليزي بتتملّى من `clients.address` — **نفس العمود**
    // اللي هيتكتب فيه. سيبانها فاضية كان بيخلّي المندوب يفتكر إن
    // العميل مالوش عنوان أصلاً ويكتب واحد جديد من الصفر.
    _addrEn.text = widget.client.address;

    // ⚠️ **القوايم بتتحمّل مع فتح الشاشة، مش مع سحب الـGPS**
    // (إصلاح ١٥/٨). قبل كده كانت بتتملّى من رد الجيوكودينج بس —
    // فلو السحب فشل أو النقطة بره مصر، المندوب يلاقي المحافظة
    // والمنطقة فاضيين ومقفولين ومالوش أي طريقة يكمّل. القوايم دي
    // داتا مرجعية ثابتة ومالهاش علاقة بالنقطة أصلاً.
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    // ⚠️ من `Session` مش `Api` مباشرة — الشاشة كلها ماشية على
    // `Session`، وهي اللي بتلقف الأخطاء وترجّع خريطة فاضية بدل
    // ما ترمي استثناء يمنع الشاشة من الفتح وهو أوفلاين.
    final res = await Session.I.geoOptions();

    if (!mounted || res.isEmpty) return;

    setState(() {
      _govs = _parseGovs(res);
      _zones = _parseZones(res);
    });
  }

  List<_Option<String>> _parseGovs(Map<String, dynamic> res) {
    final out = <_Option<String>>[];

    for (final g in (res['governorates'] as List? ?? const [])) {
      final m = Map<String, dynamic>.from(g as Map);
      out.add(_Option(m['key']?.toString() ?? '', m['label']?.toString() ?? ''));
    }

    return out;
  }

  List<_ZoneOption> _parseZones(Map<String, dynamic> res) {
    final out = <_ZoneOption>[];

    for (final z in (res['zones'] as List? ?? const [])) {
      final m = Map<String, dynamic>.from(z as Map);
      out.add(_ZoneOption(
        (m['id'] as num).toInt(),
        m['name']?.toString() ?? '',
        m['governorate']?.toString(),
      ));
    }

    return out;
  }

  @override
  void dispose() {
    _addrEn.dispose();
    _addrAr.dispose();
    super.dispose();
  }

  // ═══════════════ سحب النقطة ═══════════════

  Future<void> _capture() async {
    setState(() {
      _capturing = true;
      _geoMsg = null;
    });

    final pos = await Locator.get(fresh: true);

    if (!mounted) return;

    if (pos == null) {
      setState(() => _capturing = false);
      snack(context, L.t('loc_capture_failed'), bad: true);

      return;
    }

    setState(() {
      _point = pos;
      _capturing = false;
    });

    // الديتكت بيمشي لوحده بعد السحب — المندوب مايدوسش مرتين
    await _geocode();
  }

  /// ⚠️ **بيملا ومابيحفظش.** الرد اقتراح، والخانات بتفضل مفتوحة
  /// للتعديل. الفشل بيسيب الخانات زي ما هي والحفظ شغّال.
  Future<void> _geocode() async {
    final p = _point;
    if (p == null) return;

    setState(() {
      _geocoding = true;
      _geoMsg = L.t('loc_fetching');
    });

    final (err, res) =
        await Session.I.geocodeClientPoint(widget.client, p.$1, p.$2);

    if (!mounted) return;

    if (err != null || res == null) {
      // ⚠️ فشل **الاتصال** (نت/سيرفر) — غير «الخريطة مالقتش عنوان».
      // الاتنين بيسيبوا الخانات مفتوحة والحفظ شغّال، بس الرسالة لازم
      // تفرّق: واحدة بتقول «جرّب تاني» والتانية «اكتب بإيدك».
      setState(() {
        _geocoding = false;
        _geoMsg = err ?? L.t('loc_geo_offline');
      });

      return;
    }

    // ── الدروب داون الأول: من غيرها الاقتراح مالوش خانة يقع فيها ──
    // (بتتحمّل كمان في `initState` — دي تحديث لو السيرفر رجّع قوايم أحدث)
    final govs = _parseGovs(res);
    final zones = _parseZones(res);

    final addrEn = res['address_en']?.toString();
    final addrAr = res['address_ar']?.toString();
    final gov = res['governorate']?.toString();
    final zoneId = (res['zone_id'] as num?)?.toInt();
    final matched = res['matched'] == true;

    final filled = <String>[];

    setState(() {
      _geocoding = false;
      if (govs.isNotEmpty) _govs = govs;
      if (zones.isNotEmpty) _zones = zones;

      // العنوان بيتكتب فوق — الديتكت أكشن صريح من المندوب
      if (addrEn != null && addrEn.isNotEmpty) _addrEn.text = addrEn;
      if (addrAr != null && addrAr.isNotEmpty) _addrAr.text = addrAr;
      if ((addrEn != null && addrEn.isNotEmpty) ||
          (addrAr != null && addrAr.isNotEmpty)) {
        filled.add(L.t('loc_address'));
      }

      // ⚠️ المحافظة والمنطقة بيتحطوا **لو الخانة فاضية بس** — المندوب
      // ممكن يكون عارف الصح، والخريطة مش دايماً بتصيبها
      //
      // ⚠️⚠️ **والاقتراح لازم يكون موجود في الليستة.** `DropdownButton`
      // بترمي أسيرشن لو الـ`value` مالهاش عنصر مطابق — فاقتراح لمنطقة
      // مش في القايمة (سيرفر أقدم/أحدث، أو منطقة اتعطّلت بين النداءين)
      // كان هيكسّر الشاشة كلها بدل ما يتجاهل الاقتراح وخلاص.
      if (gov != null &&
          gov.isNotEmpty &&
          _gov == null &&
          _govs.any((g) => g.value == gov)) {
        _gov = gov;
        filled.add(L.t('loc_governorate'));
      }
      if (zoneId != null && _zone == null && _zones.any((z) => z.id == zoneId)) {
        _zone = zoneId;
        filled.add(L.t('loc_zone'));
      }

      // ⚠️ الرسالة بتقول **إيه اللي اتملى فعلاً** — «تمام» لوحدها
      // مابتقولش إذا كانت المنطقة اتحطت ولا لأ، والمندوب بيمشي
      // فاكر إنها اتظبطت. و`matched: false` معناها الخريطة مالقتش
      // عنوان — المنطقة ممكن تكون اتملت برضه (محسوبة عندنا).
      if (filled.isEmpty || !matched) {
        _geoMsg = filled.isEmpty
            ? L.t('loc_geo_failed')
            : '${L.t('loc_geo_failed')} · ✔ ${filled.join(' · ')}';
      } else {
        _geoMsg = '✔ ${filled.join(' · ')}';
      }
    });
  }

  // ═══════════════ الحفظ ═══════════════

  Future<void> _save() async {
    final p = _point;

    // ⚠️ حارس تاني ورا الزرار المعطّل — الزرار بيتفعّل بالحالة،
    // والحالة ممكن تتغيّر بين الرسمة والضغطة
    if (p == null) {
      snack(context, L.t('loc_need_point_first'), bad: true);

      return;
    }

    // ⚠️ **تأكيد قبل الكتابة فوق لوكيشن موجود.** المندوب ممكن يكون
    // فاتح الشاشة بالغلط وهو بعيد عن المحل — والكتابة فوق نقطة
    // متأكدة بتضيع شغل مراجعة اتعمل.
    if (widget.client.lat != null && widget.client.lng != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(L.t('loc_overwrite_title')),
          content: Text(L.t('loc_overwrite_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(L.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(L.t('loc_overwrite_yes')),
            ),
          ],
        ),
      );

      if (ok != true || !mounted) return;
    }

    setState(() => _saving = true);

    final err = await Session.I.saveClientLocation(
      widget.client,
      lat: p.$1,
      lng: p.$2,
      address: _addrEn.text.trim(),
      addressAr: _addrAr.text.trim(),
      governorate: _gov,
      zoneId: _zone,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (err != null) {
      snack(context, err, bad: true);

      return;
    }

    // ⚠️ امسك الـNavigator والـMessenger **قبل** الـpop — بعد الـpop
    // الشاشة بتتعمل لها dispose و`mounted` بترجع false، والرسالة
    // بتضيع (فخ موثّق في المشروع).
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(SnackBar(content: Text(L.t('loc_saved'))));
    nav.pop();
  }

  // ═══════════════ الدروب داون ═══════════════

  /// مناطق المحافظة المختارة — **زائد** المنطقة المختارة لو بره
  /// الفلتر.
  ///
  /// ⚠️ الإضافة دي مش تجميل: `DropdownButton` بترمي أسيرشن لو الـ
  /// `value` مش موجودة في `items`. المندوب يغيّر المحافظة بعد ما
  /// الاقتراح حط منطقة من محافظة تانية = كراش من غير الحارس ده.
  List<_ZoneOption> _visibleZones() {
    final gov = _gov;

    if (gov == null || gov.isEmpty) return _zones;

    final out = _zones
        .where((z) => z.governorate == null || z.governorate == gov)
        .toList();

    if (_zone != null && !out.any((z) => z.id == _zone)) {
      final picked = firstOrNull(_zones.where((z) => z.id == _zone));
      if (picked != null) out.insert(0, picked);
    }

    return out;
  }

  Widget _dropLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      );

  Widget _dropBox(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    final p = _point;
    final hasPoint = p != null;
    final hadLocation = c.lat != null && c.lng != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(hadLocation ? L.t('loc_edit_title') : L.t('loc_add_title')),
      ),
      body: ListView(
        // viewPadding صريح (مسح ٢١/٨)
        padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + MediaQuery.viewPaddingOf(context).bottom),
        children: [
          // ═══ العميل + لوكيشنه الحالي ═══
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(c.fullAddress.isEmpty ? '—' : c.fullAddress,
                      style: TextStyle(fontSize: 12, color: Brand.muted)),
                  const SizedBox(height: 10),
                  if (hadLocation)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(L.t('loc_current'),
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFB45309))),
                          const SizedBox(height: 3),
                          Text('${c.lat}, ${c.lng}',
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                  fontSize: 12, color: Brand.muted)),
                          const SizedBox(height: 3),
                          Text(L.t('loc_overwrite_hint'),
                              style: TextStyle(
                                  fontSize: 11, color: Brand.muted)),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEC),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(L.t('no_location'),
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB00020))),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ═══ الزرار الأساسي: اسحب اللوكيشن ═══
          FilledButton.icon(
            icon: const Icon(Icons.my_location, size: 22),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              backgroundColor: hasPoint ? const Color(0xFF16A34A) : null,
            ),
            label: Text(
                hasPoint ? L.t('loc_recapture') : L.t('loc_capture'),
                style: const TextStyle(
                    fontSize: 16.5, fontWeight: FontWeight.w900)),
            onPressed: _busy ? null : _capture,
          ),
          if (_capturing) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
            const SizedBox(height: 4),
            Text(L.t('loc_capturing'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: Brand.muted)),
          ],

          const SizedBox(height: 10),

          // ═══ النقطة المسحوبة ═══
          if (hasPoint)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: .09),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF16A34A).withValues(alpha: .3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.place, size: 18, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(L.t('loc_captured'),
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F7A38))),
                        Text(
                            '${p.$1.toStringAsFixed(6)}, ${p.$2.toStringAsFixed(6)}',
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F1EA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Brand.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(L.t('loc_need_point_first'),
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Brand.muted)),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 14),

          // ═══ إعادة الديتكت + رسالة الحالة ═══
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46)),
                  label: Text(L.t('loc_redetect'),
                      style: const TextStyle(fontSize: 13)),
                  onPressed: (!hasPoint || _busy) ? null : _geocode,
                ),
              ),
            ],
          ),
          if (_geoMsg != null) ...[
            const SizedBox(height: 6),
            Text(_geoMsg!,
                style: TextStyle(fontSize: 11.5, color: Brand.muted)),
          ],
          if (_geocoding) ...[
            const SizedBox(height: 6),
            const LinearProgressIndicator(),
          ],

          const SizedBox(height: 16),
          Text(L.t('loc_fields_hint'),
              style: TextStyle(fontSize: 11.5, color: Brand.muted)),
          const SizedBox(height: 10),

          // ═══ الخانات — كلها قابلة للتعديل ═══
          TextField(
            controller: _addrAr,
            maxLength: 190,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              labelText: L.t('loc_address_ar'),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addrEn,
            maxLength: 190,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: L.t('loc_address_en'),
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),

          // ⚠️ **`DropdownButton` عادي مش `FormField`** — نفس قرار شاشة
          // طلبات الريفيل: بيشتغل على أي إصدار فلاتر، والـFormField
          // غيّر اسم باراميتر القيمة بين الإصدارات.
          _dropLabel(L.t('loc_governorate')),
          _dropBox(DropdownButton<String>(
            value: _gov,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            hint: Text(L.t('loc_pick'),
                style: const TextStyle(fontSize: 13)),
            items: [
              DropdownMenuItem<String>(
                  value: null,
                  child: Text(L.t('loc_pick'),
                      style: const TextStyle(fontSize: 13))),
              for (final g in _govs)
                DropdownMenuItem<String>(
                    value: g.value,
                    child: Text(g.label,
                        style: const TextStyle(fontSize: 13))),
            ],
            onChanged: _busy ? null : (v) => setState(() => _gov = v),
          )),
          const SizedBox(height: 12),

          _dropLabel(L.t('loc_zone')),
          _dropBox(DropdownButton<int>(
            value: _zone,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            hint: Text(L.t('loc_pick'),
                style: const TextStyle(fontSize: 13)),
            items: [
              DropdownMenuItem<int>(
                  value: null,
                  child: Text(L.t('loc_pick'),
                      style: const TextStyle(fontSize: 13))),
              for (final z in _visibleZones())
                DropdownMenuItem<int>(
                    value: z.id,
                    child: Text(z.name,
                        style: const TextStyle(fontSize: 13))),
            ],
            onChanged: _busy ? null : (v) => setState(() => _zone = v),
          )),

          if (_govs.isEmpty) ...[
            const SizedBox(height: 6),
            Text(L.t('loc_lists_need_detect'),
                style: TextStyle(fontSize: 11, color: Brand.muted)),
          ],

          const SizedBox(height: 22),
          if (_saving) const LinearProgressIndicator(),
          const SizedBox(height: 6),

          // ═══ الحفظ — مقفول لحد ما النقطة تتسحب (طلب المالك) ═══
          FilledButton.icon(
            icon: const Icon(Icons.save_outlined),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            label: Text(L.t('loc_save'),
                style: const TextStyle(fontSize: 16)),
            onPressed: (!hasPoint || _busy) ? null : _save,
          ),
          if (!hasPoint) ...[
            const SizedBox(height: 6),
            Text(L.t('loc_need_point_first'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB00020))),
          ],
        ],
      ),
    );
  }
}

/// خيار دروب داون بسيط — قيمة ومسمى
class _Option<T> {
  final T value;
  final String label;

  const _Option(this.value, this.label);
}

/// المنطقة بمحافظتها — عشان الفلترة بالمحافظة المختارة
class _ZoneOption {
  final int id;
  final String name;
  final String? governorate;

  const _ZoneOption(this.id, this.name, this.governorate);
}
