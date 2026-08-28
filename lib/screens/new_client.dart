import 'dart:io';
import '../l10n.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../doc_picker.dart';
import '../locator.dart';
import '../session.dart';

/// تسجيل محل / جيم جديد — بيروح كطلب للـ Channel Manager
class NewClientScreen extends StatefulWidget {
  const NewClientScreen({
    super.key,
    // ═══ فتح أكاونت من ليد (بايبلاين ٢٦/٨): الفورم بييجي متملي
    // ببيانات المحتمل، والطلب بيتربط بيه — الاعتماد بيقفله «كسبناه»
    this.leadId,
    this.initName,
    this.initPhone,
    this.initAddress,
  });

  final int? leadId;
  final String? initName;
  final String? initPhone;
  final String? initAddress;

  @override
  State<NewClientScreen> createState() => _NewClientScreenState();
}

class _NewClientScreenState extends State<NewClientScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();

  bool hasDocs = false;
  bool _busy = false;
  String? _error;

  // ═══ اللوكيشن والتسكين (٢٠/٨) ═══
  //
  // المندوب واقف قدام المحل — زرار واحد بيسحب النقطة، يكتب العنوان
  // بالعربي، ويقترح المحافظة والمنطقة. الطلب بيوصل للمدير متسكّن
  // جاهز: يدوب يظبط التسعير ويعتمد.
  double? _lat, _lng;
  bool _locBusy = false;
  bool _locOk = false;
  String? _locMsg;
  String _addrEn = '';

  /// (key, label) — المحافظات · (id, name, gov) — المناطق
  List<(String, String)> _govs = const [];
  List<(int, String, String?)> _zones = const [];
  String? _gov;
  int? _zoneId;

  @override
  void initState() {
    super.initState();
    // فتح أكاونت من ليد (٢٦/٨) — الفورم بييجي متملي ببياناته
    if (widget.initName != null) _name.text = widget.initName!;
    if (widget.initPhone != null) _phone.text = widget.initPhone!;
    if (widget.initAddress != null) _address.text = widget.initAddress!;
    // القوايم داتا مرجعية ثابتة — بتتحمّل أول ما الشاشة تفتح عشان
    // المندوب يقدر يختار يدوي حتى لو مسحبش نقطة (نفس درس شاشة
    // لوكيشن العميل)
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final res = await Api.I.geoOptions();
      if (!mounted) return;
      setState(() {
        _govs = _parseGovs(res);
        _zones = _parseZones(res);
      });
    } catch (_) {
      // القوايم بترجع مع السحب برضه — مش مشكلة
    }
  }

  List<(String, String)> _parseGovs(Map<String, dynamic> res) => [
        for (final g in (res['governorates'] as List? ?? const []))
          if (g is Map) (g['key'].toString(), g['label'].toString()),
      ];

  List<(int, String, String?)> _parseZones(Map<String, dynamic> res) => [
        for (final z in (res['zones'] as List? ?? const []))
          if (z is Map)
            (
              (z['id'] as num).toInt(),
              z['name'].toString(),
              z['governorate']?.toString(),
            ),
      ];

  /// ⚠️ نفس حارس شاشة اللوكيشن: `DropdownButton` بترمي أسيرشن لو
  /// القيمة المختارة مش في الليستة المعروضة
  List<(int, String, String?)> _zonesFor(String? gov) {
    if (gov == null || gov.isEmpty) return _zones;
    final out =
        _zones.where((z) => z.$3 == null || z.$3 == '' || z.$3 == gov).toList();

    return out.isEmpty ? _zones : out;
  }

  Future<void> _grabLocation() async {
    setState(() {
      _locBusy = true;
      _locMsg = null;
    });

    final p = await Locator.get();

    if (p == null) {
      if (!mounted) return;
      setState(() {
        _locBusy = false;
        _locMsg = L.t('nc_gps_failed');
      });

      return;
    }

    _lat = p.$1;
    _lng = p.$2;

    try {
      final res = await Api.I.geoSuggest(p.$1, p.$2);
      if (!mounted) return;

      setState(() {
        _locBusy = false;
        _locOk = true;

        final govs = _parseGovs(res);
        final zones = _parseZones(res);
        if (govs.isNotEmpty) _govs = govs;
        if (zones.isNotEmpty) _zones = zones;

        // العنوان العربي — بيتكتب لو المندوب ماكتبش حاجة بإيده
        final ar = res['address_ar']?.toString() ?? '';
        _addrEn = res['address_en']?.toString() ?? '';
        if (ar.isNotEmpty && _address.text.trim().isEmpty) _address.text = ar;

        final gov = res['governorate']?.toString();
        if (gov != null && gov.isNotEmpty && _govs.any((g) => g.$1 == gov)) {
          _gov ??= gov;
        }
        final z = (res['zone_id'] as num?)?.toInt();
        if (z != null && _zonesFor(_gov).any((x) => x.$1 == z)) {
          _zoneId ??= z;
        }

        _locMsg = ar.isNotEmpty || z != null
            ? L.t('nc_loc_grabbed')
            : L.t('nc_addr_failed');
      });
    } on ApiException catch (e) {
      // النقطة اتسحبت ✔ — الاقتراح بس اللي فشل
      if (!mounted) return;
      setState(() {
        _locBusy = false;
        _locOk = true;
        _locMsg = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locBusy = false;
        _locOk = true;
        _locMsg = L.t('nc_addr_failed');
      });
    }
  }

  /// صورة المكان
  File? _photo;

  /// ملف الأوراق الرسمية (صورة من الكاميرا أو PDF)
  File? _docs;
  String? _docsName;
  bool _docsIsPdf = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty && _phone.text.trim().isNotEmpty;

  // ---------- اختيار الملفات ----------

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final x = await ImagePicker()
          .pickImage(source: source, imageQuality: 70, maxWidth: 1600);
      if (x != null && mounted) setState(() => _photo = File(x.path));
    } catch (e) {
      _snack(L.t('camera_failed', {'e': '$e'}));
    }
  }

  Future<void> _scanDocs() async {
    try {
      final x = await ImagePicker().pickImage(
          source: ImageSource.camera, imageQuality: 80, maxWidth: 2000);
      if (x != null && mounted) {
        setState(() {
          _docs = File(x.path);
          _docsName = L.t('docs_photo');
          _docsIsPdf = false;
        });
      }
    } catch (e) {
      _snack(L.t('camera_failed', {'e': '$e'}));
    }
  }

  Future<void> _pickPdf() async {
    try {
      final doc = await DocPicker.pick();
      if (doc != null) {
        setState(() {
          _docs = File(doc.path);
          _docsName = doc.name;
          _docsIsPdf = doc.isPdf;
        });
      }
    } on DocPickerException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(L.t('files_failed', {'e': '$e'}));
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  void _photoSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(L.t('take_photo')),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(L.t('pick_gallery')),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (_photo != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(L.t('remove_photo'),
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _photo = null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------- الإرسال ----------

  /// دايالوج «فيه عميل شبه ده» — بيرجّع true لو المندوب أكّد.
  ///
  /// ⚠️ **بيوري الشبيهين بالاسم والكود والسبب**، مش سؤال مجرّد.
  /// «فيه عميل بنفس الاسم، تكمّل؟» من غير ما يقول مين بيخلّي
  /// المندوب يضغط «كمّل» كل مرة — والحارس يبقى شكل.
  Future<bool> _confirmDuplicates(List<Map<String, dynamic>> dupes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L.t('dup_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(L.t('dup_body'), style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            ...dupes.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• ${d['name'] ?? ''} (${d['code'] ?? ''}) — ${d['by_label'] ?? ''}',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L.t('dup_cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L.t('dup_continue')),
          ),
        ],
      ),
    );

    return ok == true;
  }

  Future<void> _submit({bool confirmDuplicate = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    // ⚠️ النقطة المسحوبة بزرار «اسحب اللوكيشن» ليها الأولوية —
    // اتسحبت والمندوب واقف قدام المحل فعلاً. لو ماسحبش بنلتقط
    // واحدة الآن كفولباك (null بصمت لو الـGPS مقفول).
    final pos = _lat != null ? (_lat!, _lng!) : await Locator.get();

    final (err, approved, dupes) = await Session.I.submitClientRequest(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      // ⚠️ خانة العنوان في الشاشة **عربي** (٢٠/٨) — بتتبعت في
      // `address_ar` زي عمود العميل بالظبط. الإنجليزي من الاقتراح
      // لو جه، والمدير بيكمّله وقت الاعتماد.
      address: _addrEn.trim(),
      addressAr: _address.text.trim(),
      zoneId: _zoneId,
      hasDocs: hasDocs,
      photoPath: _photo?.path,
      docsPath: hasDocs ? _docs?.path : null,
      lat: pos?.$1,
      lng: pos?.$2,
      confirmDuplicate: confirmDuplicate,
      leadId: widget.leadId,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (err != null) {
      setState(() => _error = err);
      return;
    }

    // ⚠️ **الطلب مااتسجّلش لسه** — السيرفر بيسأل. لو المندوب أكّد
    // بنبعت تاني بعلم التأكيد، ولو لأ بنسيبه في الفورم يصلّح الاسم.
    if (dupes != null && dupes.isNotEmpty) {
      final go = await _confirmDuplicates(dupes);
      if (!mounted) return;
      if (go) await _submit(confirmDuplicate: true);

      return;
    }

    // ⚠️ الرسالة كانت بتتبعت على روت ميت بعد الـpop — فالمندوب
    // عمره ما شاف «الطلب اتبعت» (تدقيق ٩/٨)
    // ⚠️ المدير بيفتح العميل فوراً (١١/٨) — رسالته «اتفعّل» مش
    // «مستني موافقة»، وإلا هيفضل مستني رد على حاجة خلصت.
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    nav.pop();
    messenger.showSnackBar(SnackBar(
        content: Text(approved
            ? L.t('client_auto_approved')
            : L.t('request_sent_notify'))));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: Text(L.t('register_client'))),
      body: ListView(
        // viewPadding صريح (مسح ٢١/٨)
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
        children: [
          Card(
            color: const Color(0xFFE8EFFD),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF2563EB)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        L.t('request_flow_hint'),
                        style: TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            ),
          ),

          if (_error != null)
            Card(
              color: const Color(0xFFFDECEC),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFB00020)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFFB00020),
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),

          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: L.t('place_name'),
              prefixIcon: Icon(Icons.storefront_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: L.t('phone_number'),
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // ═══ اسحب اللوكيشن الحالي (٢٠/٨) ═══
          // زرار واحد: نقطة GPS + عنوان عربي + محافظة ومنطقة —
          // المندوب يراجع ويكمّل بدل ما يكتب كل حاجة بإيده.
          FilledButton.tonalIcon(
            icon: _locBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_locOk ? Icons.where_to_vote : Icons.my_location),
            label: Text(
                _locOk ? L.t('nc_loc_done') : L.t('nc_grab_location'),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800)),
            onPressed: _locBusy ? null : _grabLocation,
          ),
          if (_locMsg != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_locMsg!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _locOk
                          ? const Color(0xFF0E7C5A)
                          : const Color(0xFFB00020))),
            ),
          const SizedBox(height: 12),

          TextField(
            controller: _address,
            decoration: InputDecoration(
              labelText: L.t('nc_address_ar'),
              prefixIcon: Icon(Icons.place_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // ⚠️ **`DropdownButton` عادي مش `FormField`** — نفس قرار
          // شاشة لوكيشن العميل: بيشتغل على أي إصدار فلاتر،
          // والـFormField غيّر اسم باراميتر القيمة بين الإصدارات.
          _dropLabel(L.t('loc_governorate')),
          _dropBox(DropdownButton<String>(
            value: _govs.any((g) => g.$1 == _gov) ? _gov : null,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            hint: Text(L.t('loc_pick'), style: const TextStyle(fontSize: 13)),
            items: [
              DropdownMenuItem<String>(
                  value: null,
                  child: Text(L.t('loc_pick'),
                      style: const TextStyle(fontSize: 13))),
              for (final g in _govs)
                DropdownMenuItem<String>(
                    value: g.$1,
                    child:
                        Text(g.$2, style: const TextStyle(fontSize: 13))),
            ],
            onChanged: (v) => setState(() {
              _gov = v;
              // المنطقة المختارة لازم تفضل جوه ليستة المحافظة الجديدة
              if (_zoneId != null &&
                  !_zonesFor(v).any((z) => z.$1 == _zoneId)) {
                _zoneId = null;
              }
            }),
          )),
          const SizedBox(height: 12),

          _dropLabel(L.t('loc_zone')),
          _dropBox(DropdownButton<int>(
            value:
                _zonesFor(_gov).any((z) => z.$1 == _zoneId) ? _zoneId : null,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            hint: Text(L.t('loc_pick'), style: const TextStyle(fontSize: 13)),
            items: [
              DropdownMenuItem<int>(
                  value: null,
                  child: Text(L.t('loc_pick'),
                      style: const TextStyle(fontSize: 13))),
              for (final z in _zonesFor(_gov))
                DropdownMenuItem<int>(
                    value: z.$1,
                    child:
                        Text(z.$2, style: const TextStyle(fontSize: 13))),
            ],
            onChanged: (v) => setState(() => _zoneId = v),
          )),
          const SizedBox(height: 14),

          // ---------- صورة المكان ----------
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _photoSheet,
            child: Container(
              height: _photo == null ? 108 : 170,
              decoration: BoxDecoration(
                color: _photo == null ? Colors.white : const Color(0xFFE7F7EE),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _photo == null ? Colors.grey.shade400 : primary),
              ),
              clipBehavior: Clip.antiAlias,
              child: _photo == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_camera_outlined,
                              size: 30, color: Colors.grey.shade600),
                          const SizedBox(height: 8),
                          Text(L.t('tap_photo_place'),
                              style: TextStyle(
                                  fontSize: 12.5, color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(_photo!, fit: BoxFit.cover),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black54,
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 10),
                            child: Text(L.t('photo_attached'),
                                style: TextStyle(
                                    color: Colors.white, fontSize: 11.5)),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),

          // ---------- أوراق رسمية ----------
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: hasDocs,
                  onChanged: (v) => setState(() {
                    hasDocs = v;
                    if (!v) {
                      _docs = null;
                      _docsName = null;
                    }
                  }),
                  title: Text(L.t('has_official_docs'),
                      style: TextStyle(fontSize: 14)),
                  subtitle: Text(L.t('commercial_record'),
                      style: TextStyle(fontSize: 11.5)),
                  secondary: const Icon(Icons.description_outlined),
                ),

                // الخيارين بيظهروا بس لما يفتح السويتش
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: hasDocs
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      children: [
                        const Divider(height: 8),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _DocOption(
                                icon: Icons.document_scanner_outlined,
                                title: L.t('photograph_docs'),
                                subtitle: L.t('with_camera'),
                                selected: _docs != null && !_docsIsPdf,
                                color: primary,
                                onTap: _scanDocs,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DocOption(
                                icon: Icons.picture_as_pdf_outlined,
                                title: L.t('upload_file'),
                                subtitle: L.t('pdf_or_image'),
                                selected: _docs != null && _docsIsPdf,
                                color: primary,
                                onTap: _pickPdf,
                              ),
                            ),
                          ],
                        ),
                        if (_docs != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7F7EE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                    _docsIsPdf
                                        ? Icons.picture_as_pdf
                                        : Icons.image,
                                    color: primary,
                                    size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_docsName ?? L.t('file_attached'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600)),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setState(() {
                                    _docs = null;
                                    _docsName = null;
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  secondChild: const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 6),
          FilledButton.icon(
            icon: const Icon(Icons.send),
            label:
                Text(L.t('submit_to_manager'), style: TextStyle(fontSize: 16)),
            onPressed: (!_valid || _busy) ? null : _submit,
          ),
          const SizedBox(height: 10),
          Text(
              L.t('attachments_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _DocOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _DocOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 1.6 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 26, color: selected ? color : Colors.grey.shade700),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? color : Colors.black87)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
