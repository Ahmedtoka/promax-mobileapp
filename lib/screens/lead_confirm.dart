import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../l10n.dart';
import '../locator.dart';
import '../session.dart';
import 'shared.dart';
import 'zones.dart';

/// ═══════════════════════════════════════════════════════════════
/// «تأكيد بيانات عميل محتمل» (فلو الليد المطور ٢٦/٨)
/// ═══════════════════════════════════════════════════════════════
///
/// شاشة زي تسجيل العميل الجديد بالظبط بس متملية ببيانات الليد:
/// اسم المكان · التليفون · العنوان العربي · المحافظة · المنطقة ·
/// صورة المكان · وزرار «اسحب اللوكيشن» في الآخر — لو البيانات مش
/// مظبوطة النقطة والاقتراح بيملوا الإنبتس على طول.
///
/// وضعين:
///   openAccount=false → تأكيد بس (النقطة الأولى) ورجوع.
///   openAccount=true  → تأكيد + فتح أكاونت فوري بلا موافقة (كاش
///     وآجل) ودخول على شاشة العميل يبيع له على طول.
class LeadConfirmScreen extends StatefulWidget {
  const LeadConfirmScreen({
    super.key,
    required this.lead,
    this.openAccount = false,
  });

  final Map<String, dynamic> lead;
  final bool openAccount;

  @override
  State<LeadConfirmScreen> createState() => _LeadConfirmScreenState();
}

class _LeadConfirmScreenState extends State<LeadConfirmScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;

  File? _photo;
  bool _busy = false;
  String? _error;

  double? _lat, _lng;
  bool _locBusy = false;
  bool _locOk = false;
  String? _locMsg;

  List<(String, String)> _govs = const [];
  List<(int, String, String?)> _zones = const [];
  String? _gov;
  int? _zoneId;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: '${widget.lead['name'] ?? ''}');
    _phone = TextEditingController(text: '${widget.lead['phone'] ?? ''}');
    _address = TextEditingController(text: '${widget.lead['address'] ?? ''}');
    _loadOptions();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
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
      // القوايم اختيارية — الشاشة شغالة من غيرها
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

  List<(int, String, String?)> _zonesFor(String? gov) {
    if (gov == null || gov.isEmpty) return _zones;
    final out =
        _zones.where((z) => z.$3 == null || z.$3 == '' || z.$3 == gov).toList();

    return out.isEmpty ? _zones : out;
  }

  /// اسحب اللوكيشن — نفس تجربة تسجيل العميل: نقطة + عنوان + اقتراح
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

        // ⚠️ هنا بنكتب فوق الموجود — المندوب ضغط الزرار عشان
        // «البيانات مش صحيحة»، فالاقتراح بيدوس على القديم
        final ar = res['address_ar']?.toString() ?? '';
        if (ar.isNotEmpty) _address.text = ar;

        final gov = res['governorate']?.toString();
        if (gov != null && gov.isNotEmpty && _govs.any((g) => g.$1 == gov)) {
          _gov = gov;
        }
        final z = (res['zone_id'] as num?)?.toInt();
        if (z != null && _zonesFor(_gov).any((x) => x.$1 == z)) {
          _zoneId = z;
        }

        _locMsg = L.t('nc_loc_done');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locBusy = false;
        _locOk = true;   // النقطة اتسجلت حتى لو الاقتراح فشل
        _locMsg = L.t('nc_loc_done');
      });
    }
  }

  void _photoSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(L.t('take_photo')),
            onTap: () async {
              Navigator.of(ctx).pop();
              final x = await ImagePicker()
                  .pickImage(source: ImageSource.camera, imageQuality: 78);
              if (x != null && mounted) setState(() => _photo = File(x.path));
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(L.t('pick_gallery')),
            onTap: () async {
              Navigator.of(ctx).pop();
              final x = await ImagePicker()
                  .pickImage(source: ImageSource.gallery, imageQuality: 78);
              if (x != null && mounted) setState(() => _photo = File(x.path));
            },
          ),
          if (_photo != null)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(L.t('remove_photo')),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() => _photo = null);
              },
            ),
        ]),
      ),
    );
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final leadId = (widget.lead['id'] as num).toInt();
    // فولباك لحظة الإرسال لو مسحبش نقطة بالزرار
    final pos = _lat != null ? (_lat!, _lng!) : await Locator.get();

    try {
      await Api.I.confirmLead(
        leadId,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        governorate: _gov,
        zoneId: _zoneId,
        lat: pos?.$1,
        lng: pos?.$2,
        photoPath: _photo?.path,
      );

      if (!widget.openAccount) {
        if (!mounted) return;
        final nav = Navigator.of(context);
        nav.maybePop();
        snack(context, L.t('lead_confirm_done'));

        return;
      }

      // ═══ تأكيد + فتح: أكاونت فوري وبيع على طول ═══
      final res = await Api.I.openLeadAccount(leadId);
      final clientId =
          ((res['client'] as Map?)?['id'] as num?)?.toInt();

      // العميل الجديد لازم ينزل في المناطق قبل ما نفتح شاشته
      await Session.I.refresh();
      if (!mounted) return;

      final nav = Navigator.of(context);
      final msgCtx = context;

      // دوّر عليه في مناطق الجلسة — Coverage ضمنت ظهوره
      dynamic found;
      for (final z in Session.I.zones) {
        for (final c in z.clients) {
          if (c.id == clientId) found = c;
        }
      }

      nav.maybePop();
      snack(msgCtx, L.t('lead_opened_done'));

      if (found != null) {
        nav.push(MaterialPageRoute(
            builder: (_) => ClientScreen(client: found)));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.openAccount
              ? L.t('lead_confirm_open_title')
              : L.t('lead_confirm_title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(_error!,
                  style: const TextStyle(color: Color(0xFFB00020))),
            ),

          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: L.t('place_name'),
              prefixIcon: const Icon(Icons.storefront_outlined),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: L.t('phone'),
              prefixIcon: const Icon(Icons.call_outlined),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _address,
            decoration: InputDecoration(
              labelText: L.t('nc_address_ar'),
              prefixIcon: const Icon(Icons.place_outlined),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // المحافظة والمنطقة — DropdownButton عادي (قرار موثق)
          Text(L.t('loc_governorate'),
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          _dropBox(DropdownButton<String>(
            value: _govs.any((g) => g.$1 == _gov) ? _gov : null,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            hint: Text(L.t('loc_pick'), style: const TextStyle(fontSize: 13)),
            items: [
              for (final g in _govs)
                DropdownMenuItem<String>(
                    value: g.$1,
                    child:
                        Text(g.$2, style: const TextStyle(fontSize: 13))),
            ],
            onChanged: (v) => setState(() {
              _gov = v;
              if (_zoneId != null &&
                  !_zonesFor(v).any((z) => z.$1 == _zoneId)) {
                _zoneId = null;
              }
            }),
          )),
          const SizedBox(height: 12),

          Text(L.t('loc_zone'),
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          _dropBox(DropdownButton<int>(
            value: _zonesFor(_gov).any((z) => z.$1 == _zoneId) ? _zoneId : null,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            hint: Text(L.t('loc_pick'), style: const TextStyle(fontSize: 13)),
            items: [
              for (final z in _zonesFor(_gov))
                DropdownMenuItem<int>(
                    value: z.$1,
                    child:
                        Text(z.$2, style: const TextStyle(fontSize: 13))),
            ],
            onChanged: (v) => setState(() => _zoneId = v),
          )),
          const SizedBox(height: 14),

          // ═══ صورة المكان ═══
          OutlinedButton.icon(
            icon: Icon(_photo == null
                ? Icons.photo_camera_outlined
                : Icons.check_circle,
                color: _photo == null ? null : const Color(0xFF0F7A38)),
            label: Text(
                _photo == null ? L.t('place_photo') : L.t('photo_attached')),
            onPressed: _photoSheet,
          ),
          if (_photo != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child:
                    Image.file(_photo!, height: 140, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 14),

          // ═══ اسحب اللوكيشن — آخر حاجة: لو البيانات مش صح ═══
          FilledButton.tonalIcon(
            icon: _locBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_locOk ? Icons.where_to_vote : Icons.my_location),
            label: Text(L.t('nc_grab_location'),
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
          const SizedBox(height: 20),

          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text(
                _busy
                    ? '...'
                    : (widget.openAccount
                        ? L.t('lead_confirm_open_btn')
                        : L.t('lead_confirm_save_btn')),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _dropBox(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(6),
        ),
        child: child,
      );
}
