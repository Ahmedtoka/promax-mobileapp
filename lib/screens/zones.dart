import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
// ⚠️ لـ`SystemUiOverlayStyle` بس — شاشة العميل بقت من غير أب بار،
// وشريط الحالة بيورّث ستايل الشاشة اللي قبلها. على هيدر بنفسجي
// غامق ده معناه أيقونات سودا مش بتتشاف. مكتبة أساسية مش باكدچ.
import 'package:flutter/services.dart';

import '../api.dart';
import '../brand.dart';
import '../l10n.dart';
import '../locator.dart';

import '../models.dart';
import '../session.dart';
import 'shared.dart';
import 'sale.dart';
import 'client_return.dart';
import 'gifts.dart';
import 'new_client.dart';
import 'collect.dart';
import 'shelf_photos.dart';
import 'goods_request.dart';
import 'client_location.dart';
import 'client_history.dart';
import 'supply_orders.dart';


// ═══════════ مساعدات شاشات المناطق (إعادة تصميم ٢٠/٨) ═══════════

/// مسافة بالكيلومتر من نقطة المندوب — null لو مفيش نقطة أو إحداثيات
double? kmTo((double, double)? pos, double? lat, double? lng) {
  if (pos == null || lat == null || lng == null) return null;

  double rad(double d) => d * pi / 180;
  final dLat = rad(lat - pos.$1);
  final dLng = rad(lng - pos.$2);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(rad(pos.$1)) * cos(rad(lat)) * sin(dLng / 2) * sin(dLng / 2);
  final km = 2 * 6371.0 * atan2(sqrt(a), sqrt(1 - a));

  return km > 300 ? null : km;
}

String kmLabel(double km) => L.t('km_n',
    {'k': km < 10 ? km.toStringAsFixed(1) : km.round().toString()});

/// الهيدر المتدرج الموحد — عنوان + سطر معلومات + بحث جوه الهيدر
class _ZonesHeader extends StatelessWidget {
  final String title;
  final String sub;
  final bool showBack;
  final Widget? action;
  final TextEditingController? search;
  final String? hint;
  final VoidCallback? onChanged;

  const _ZonesHeader({
    required this.title,
    required this.sub,
    this.showBack = false,
    this.action,
    this.search,
    this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // ⚠️ **بقى كارت متدرج جوه SafeArea مش بلوك مليان الشاشة** (طلب
    // المالك ٢١/٨): نفس ستايل هيدر الرئيسية والتوريد — الخلفية ورا
    // شريط الحالة فاتحة وأيقونات الساعة والشبكة غامقة ثابتة في كل
    // التابات، ومفيش تقلب ألوان مع التنقل.
    return SafeArea(
      bottom: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        decoration: BoxDecoration(
          gradient: Brand.gradient,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(children: [
          Row(children: [
            if (showBack)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.of(context).maybePop(),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child:
                      Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            if (action != null) action!,
          ]),
          if (search != null) ...[
            const SizedBox(height: 11),
            TextField(
              controller: search,
              textInputAction: TextInputAction.search,
              onChanged: (_) => onChanged?.call(),
              decoration: InputDecoration(
                isDense: true,
                hintText: hint ?? L.t('search_everything'),
                hintStyle: TextStyle(fontSize: 12.5, color: Brand.muted),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: (search!.text.isEmpty)
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          search!.clear();
                          onChanged?.call();
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// شيبة فلتر — متعلمة بالأزرق الملكي، وإلا بيضا بحد
class _FChip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;

  const _FChip({required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? Brand.royalBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: on ? Brand.royalBlue : const Color(0xFFE0DDD4)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: on ? Colors.white : Brand.muted)),
      ),
    );
  }
}

// ================= قايمة الزونز =================

class ZonesScreen extends StatefulWidget {
  const ZonesScreen({super.key});

  @override
  State<ZonesScreen> createState() => _ZonesScreenState();
}

/// ═══════════════════════════════════════════════════════════════
/// المناطق — محافظات ثم مناطق، وبحث شامل  ·  ١٥ أغسطس ٢٠٢٦
/// ═══════════════════════════════════════════════════════════════
///
/// طلبات المالك: «نزود فيها بحث فوق — باسم العميل ماشي، برقم موبايل
/// ماشي، بالمنطقة ماشي، بالسلسلة ماشي … ولما أدخل على القاهرة يطلعلي
/// الـZones اللي جواها».
///
/// ⚠️ **الليست القديمة كانت بتخلط مستويين**: «القاهرة» و«الدقي» جنب
/// بعض وهي جواها. بقت محافظات، وجوه كل واحدة مناطقها.
///
/// ⚠️ **البحث بيقفز فوق التدرّج كله.** المندوب اللي بيدوّر على محل
/// مش عايز يفكّر هو في أنهي محافظة — بيكتب أي حاجة (اسم · موبايل ·
/// منطقة · سلسلة) وبتطلعله كروت العملاء على طول. التدرّج للتصفّح،
/// والبحث للوصول المباشر.
class _ZonesScreenState extends State<ZonesScreen> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ ListenableBuilder إجبارية — الشاشة const جوه التابات، ومن
    // غيرها بتفضل بيضا لحد ما المستخدم يقلّب تاب ويرجع.
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) => _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final s = Session.I;
    final query = _q.text.trim();

    final live = s.zones.where((z) => z.clients.isNotEmpty).toList();
    final govsN =
        live.map((z) => z.gov.isEmpty ? '_' : z.gov).toSet().length;
    final clientsN = live.fold<int>(0, (t, z) => t + z.clientCount);

    return Scaffold(
      // SafeArea تحت — المحتوى كان واصل لآخر الشاشة تحت بار النظام
      body: SafeArea(
        top: false,
        child: Column(
        children: [
          // ═══ الهيدر المتدرج (٢٠/٨) — الأرقام الكبيرة + عميل جديد ═══
          _ZonesHeader(
            title: L.t('zones_clients'),
            sub: L.t('govs_zones_clients', {
              'g': '$govsN',
              'z': '${live.length}',
              'c': '$clientsN',
            }),
            action: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const NewClientScreen())),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  border: Border.all(color: Colors.white38),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.person_add_alt,
                      size: 15, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(L.t('new_client'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900)),
                ]),
              ),
            ),
            search: _q,
            hint: L.t('search_everything'),
            onChanged: () => setState(() {}),
          ),
          Expanded(
            child: query.isNotEmpty
                ? _results(context, s, query)
                : _governorates(context, s),
          ),
        ],
        ),
      ),
    );
  }

  /// نتايج البحث — كروت عملاء من كل المناطق
  Widget _results(BuildContext context, Session s, String query) {
    final hits = <Client>[];

    for (final z in s.zones) {
      hits.addAll(z.search(query));
    }

    if (hits.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.search_off, size: 52, color: Brand.muted),
          const SizedBox(height: 12),
          Text(L.t('no_results'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(L.t('search_everything_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Brand.muted)),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
      itemCount: hits.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(L.t('n_results', {'n': '${hits.length}'}),
                style: TextStyle(fontSize: 12, color: Brand.muted)),
          );
        }

        return ClientTile(client: hits[i - 1]);
      },
    );
  }

  /// التصفّح — محافظات، وجوه كل واحدة مناطقها
  Widget _governorates(BuildContext context, Session s) {
    final live = s.zones.where((z) => z.clients.isNotEmpty).toList();

    if (live.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.map_outlined, size: 56, color: Brand.muted),
          const SizedBox(height: 14),
          Text(L.t('no_zones_yet'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(L.t('no_zones_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Brand.muted)),
        ],
      );
    }

    // تجميع بالمحافظة — الكود مفتاح، واللابل للعرض
    final groups = <String, List<Zone>>{};
    final labels = <String, String>{};

    for (final z in live) {
      final key = z.gov.isEmpty ? '_' : z.gov;
      (groups[key] ??= []).add(z);
      labels[key] = z.govLabel.isEmpty ? L.t('gov_unknown') : z.govLabel;
    }

    int clientsOf(String k) =>
        groups[k]!.fold<int>(0, (t, z) => t + z.clientCount);

    // ⚠️ **الأكتر عملاء الأول** (٢٠/٨) — المندوب شغله في المحافظات
    // التقيلة، مش بالأبجدية
    final keys = groups.keys.toList()
      ..sort((a, b) => clientsOf(b).compareTo(clientsOf(a)));

    // مناطقي — أسرع وصول: زونات النهاردة الأول وبعدين الأتقل عملاء
    final quick = <Zone>[
      ...live.where((z) => z.isToday),
      ...(live.where((z) => !z.isToday).toList()
        ..sort((a, b) => b.clientCount.compareTo(a.clientCount))),
    ].take(4).toList();

    return RefreshIndicator(
      onRefresh: s.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
        children: [
          if (quick.isNotEmpty) ...[
            Text(L.t('my_zones_quick'),
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Brand.muted)),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: quick.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final z = quick[i];
                  final pend = z.clientCount - z.doneCount;

                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => ZoneScreen(zone: z))),
                    child: Container(
                      width: 158,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: z.isToday
                                ? Brand.royalBlue
                                : const Color(0xFFE0DDD4),
                            width: z.isToday ? 1.4 : 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(z.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text(
                              z.isToday
                                  ? '${L.t('today_zone')} · ${L.t('n_clients', {'n': '$pend'})}'
                                  : L.t('n_clients',
                                      {'n': '${z.clientCount}'}),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: z.isToday
                                      ? FontWeight.w800
                                      : FontWeight.w400,
                                  color: z.isToday
                                      ? Brand.royalBlue
                                      : Brand.muted)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(children: [
            Text(L.t('all_govs'),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900)),
            const Spacer(),
            Text(L.t('most_clients'),
                style: TextStyle(fontSize: 10.5, color: Brand.muted)),
          ]),
          const SizedBox(height: 8),
          for (final k in keys)
            Builder(builder: (context) {
              final zs = groups[k]!;
              final clients = clientsOf(k);
              final done = zs.fold<int>(0, (t, z) => t + z.doneCount);
              final pend = clients - done;
              final mine = zs.any((z) => z.isToday);

              return Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          GovScreen(title: labels[k] ?? '—', zones: zs))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    child: Row(children: [
                      // عداد العملاء الكبير — أول حاجة العين تشوفها
                      Container(
                        width: 52,
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: Brand.royalBlue.withValues(alpha: .07),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Column(children: [
                          Text('$clients',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Brand.royalBlue)),
                          Text(L.t('client_word'),
                              style: TextStyle(
                                  fontSize: 9, color: Brand.muted)),
                        ]),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(
                                child: Text(labels[k] ?? '—',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w900)),
                              ),
                              if (mine) ...[
                                const SizedBox(width: 6),
                                Chip2(
                                    text: L.t('your_zone'),
                                    color: Brand.green),
                              ],
                            ]),
                            const SizedBox(height: 2),
                            Text(
                                '${L.t('n_zones', {'n': '${zs.length}'})}'
                                '${mine && pend > 0 ? ' · ${L.t('still_visits_n', {'n': '$pend'})}' : ''}',
                                style: TextStyle(
                                    fontSize: 10.5, color: Brand.muted)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          size: 15, color: Colors.grey),
                    ]),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// المحافظة — المناطق اللي جواها  ·  إعادة تصميم ٢٠/٨
/// ═══════════════════════════════════════════════════════════════
///
/// هيدر متدرج + بحث بيلقط المناطق **والعملاء** جوه المحافظة،
/// وفلاتر: «فيها عملاء لسه» (الافتراضي — دي شغلانة المندوب)،
/// «قريب مني» بالمسافة، و«الكل». كل صف بيقول: كام عميل، لسه كام،
/// وبُعدها كام كيلو.
class GovScreen extends StatefulWidget {
  final String title;
  final List<Zone> zones;

  const GovScreen({super.key, required this.title, required this.zones});

  @override
  State<GovScreen> createState() => _GovScreenState();
}

class _GovScreenState extends State<GovScreen> {
  final _q = TextEditingController();
  String _filter = 'pending';
  (double, double)? _pos;

  @override
  void initState() {
    super.initState();
    Locator.get().then((p) {
      if (mounted && p != null) setState(() => _pos = p);
    });
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  /// بُعد المنطقة = أقرب عميل ليها عنده إحداثيات
  double? _zoneKm(Zone z) {
    double? best;
    for (final c in z.clients) {
      final km = kmTo(_pos, c.lat, c.lng);
      if (km != null && (best == null || km < best)) best = km;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        // نسخة محدّثة بعد أي ريفريش — بنفس ترتيب الآيديهات
        final ids = widget.zones.map((z) => z.id).toSet();
        final zones = Session.I.zones
            .where((z) => ids.contains(z.id))
            .toList()
          ..sort((a, b) => b.clientCount.compareTo(a.clientCount));
        final all = zones.isEmpty ? widget.zones : zones;

        final query = _q.text.trim();
        final clientsN = all.fold<int>(0, (t, z) => t + z.clientCount);
        final pendingZones = all
            .where((z) => z.clientCount - z.doneCount > 0)
            .toList();

        var list = switch (_filter) {
          'pending' => pendingZones,
          'near' => (all.toList()
            ..sort((a, b) => (_zoneKm(a) ?? 9999)
                .compareTo(_zoneKm(b) ?? 9999))),
          _ => all,
        };

        // البحث بيلقط أسماء المناطق — ولو لقى عملاء بيعرضهم كروت
        final clientHits = <Client>[];
        if (query.isNotEmpty) {
          list = list
              .where((z) =>
                  z.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
          for (final z in all) {
            clientHits.addAll(z.search(query));
          }
        }

        return Scaffold(
          body: SafeArea(
            top: false,
            child: Column(children: [
            _ZonesHeader(
              title: widget.title,
              sub:
                  '${L.t('n_zones', {'n': '${all.length}'})} · ${L.t('n_clients', {'n': '$clientsN'})}',
              showBack: true,
              search: _q,
              hint: L.t('gov_search_hint', {'g': widget.title}),
              onChanged: () => setState(() {}),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _FChip(
                      label:
                          '${L.t('gov_has_pending')} · ${pendingZones.length}',
                      on: _filter == 'pending',
                      onTap: () => setState(() => _filter = 'pending')),
                  const SizedBox(width: 7),
                  _FChip(
                      label: L.t('near_me'),
                      on: _filter == 'near',
                      onTap: () => setState(() => _filter = 'near')),
                  const SizedBox(width: 7),
                  _FChip(
                      label: '${L.t('all')} · ${all.length}',
                      on: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all')),
                ]),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: Session.I.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                  children: [
                    for (final z in list) _zoneRow(context, z),
                    if (list.isEmpty && clientHits.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(30),
                        child: Center(
                          child: Text(L.t('no_results'),
                              style: TextStyle(color: Brand.muted)),
                        ),
                      ),
                    // عملاء طلعوا في البحث — وصول مباشر من غير تنقّل
                    if (clientHits.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(L.t('n_results', {'n': '${clientHits.length}'}),
                          style:
                              TextStyle(fontSize: 11.5, color: Brand.muted)),
                      const SizedBox(height: 6),
                      for (final c in clientHits.take(30))
                        ClientTile(client: c, pos: _pos),
                    ],
                  ],
                ),
              ),
            ),
            ]),
          ),
        );
      },
    );
  }

  Widget _zoneRow(BuildContext context, Zone z) {
    final pend = z.clientCount - z.doneCount;
    final km = _zoneKm(z);

    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => ZoneScreen(zone: z))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Column(children: [
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Brand.royalBlue.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.location_on_outlined,
                    size: 19, color: Brand.royalBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(z.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900)),
                      ),
                      if (z.isToday) ...[
                        const SizedBox(width: 6),
                        Chip2(
                            text: L.t('today_zone'),
                            color: Brand.royalBlue),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(
                        [
                          L.t('n_clients', {'n': '${z.clientCount}'}),
                          if (pend > 0) L.t('still_n', {'n': '$pend'}),
                          if (z.doneCount > 0)
                            '${L.t('done_f')} ${z.doneCount}',
                          if (km != null) kmLabel(km),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10.5, color: Brand.muted)),
                  ],
                ),
              ),
              // لسه كام — الرقم اللي بيحدد «أروح ولا خلاص»
              Text(pend > 0 ? '$pend' : '✓',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: pend > 0 ? Brand.royalBlue : Brand.green)),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios,
                  size: 14, color: Colors.grey),
            ]),
            // بروجريس خفيف للي اتزار جزئياً
            if (z.doneCount > 0 && pend > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: z.clientCount == 0
                        ? 0
                        : z.doneCount / z.clientCount,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFEFEDE6),
                    color: Brand.green,
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ================= عملاء الزون — بحث واختيار =================

class ZoneScreen extends StatefulWidget {
  final Zone zone;
  const ZoneScreen({super.key, required this.zone});

  @override
  State<ZoneScreen> createState() => _ZoneScreenState();
}

class _ZoneScreenState extends State<ZoneScreen> {
  final _q = TextEditingController();

  /// pending (الافتراضي — دي الشغلانة) · done · debt
  String _filter = 'pending';

  /// ترتيب بالأقرب — أول ما النقطة توصل
  bool _near = true;
  (double, double)? _pos;

  @override
  void initState() {
    super.initState();
    Locator.get().then((p) {
      if (mounted && p != null) setState(() => _pos = p);
    });
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        // نجيب نسخة محدّثة من الزون بعد أي refresh
        final zone =
            firstOrNull(Session.I.zones.where((z) => z.id == widget.zone.id)) ??
                widget.zone;

        final allClients = zone.clients;
        final pendN =
            allClients.where((c) => c.status != VisitStatus.done).length;
        final doneN = allClients.length - pendN;
        final debtN = allClients.where((c) => c.balance > 0).length;

        var list = zone.search(_q.text);
        list = switch (_filter) {
          'pending' =>
            list.where((c) => c.status != VisitStatus.done).toList(),
          'done' => list.where((c) => c.status == VisitStatus.done).toList(),
          'debt' => list.where((c) => c.balance > 0).toList(),
          _ => list,
        };

        if (_near && _pos != null) {
          list = list.toList()
            ..sort((a, b) => (kmTo(_pos, a.lat, a.lng) ?? 9999)
                .compareTo(kmTo(_pos, b.lat, b.lng) ?? 9999));
        }

        return Scaffold(
          body: SafeArea(
            top: false,
            child: Column(
            children: [
              _ZonesHeader(
                title: zone.name,
                sub:
                    '${zone.govLabel.isEmpty ? '' : '${zone.govLabel} · '}${L.t('n_clients', {'n': '${allClients.length}'})}',
                showBack: true,
                search: _q,
                hint: L.t('zone_search_hint'),
                onChanged: () => setState(() {}),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                child: Row(children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _FChip(
                            label: '${L.t('still_word')} · $pendN',
                            on: _filter == 'pending',
                            onTap: () =>
                                setState(() => _filter = 'pending')),
                        const SizedBox(width: 7),
                        _FChip(
                            label: '${L.t('done_f')} · $doneN',
                            on: _filter == 'done',
                            onTap: () => setState(() => _filter = 'done')),
                        const SizedBox(width: 7),
                        _FChip(
                            label: '${L.t('has_debt')} · $debtN',
                            on: _filter == 'debt',
                            onTap: () => setState(() => _filter = 'debt')),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // ترتيب بالأقرب — بيشتغل أول ما الـGPS يلقط
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _near = !_near),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.near_me_outlined,
                            size: 14,
                            color: _near && _pos != null
                                ? Brand.royalBlue
                                : Brand.muted),
                        const SizedBox(width: 3),
                        Text(L.t('near_sort'),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _near && _pos != null
                                    ? Brand.royalBlue
                                    : Brand.muted)),
                      ]),
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text(L.t('no_client_found'),
                            style: TextStyle(color: Colors.grey.shade600)))
                    : RefreshIndicator(
                        onRefresh: Session.I.refresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                          itemCount: list.length,
                          itemBuilder: (context, i) =>
                              ClientTile(client: list[i], pos: _pos),
                        ),
                      ),
              ),
            ],
            ),
          ),
        );
      },
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// كارت العميل — إعادة تصميم ٢٠/٨ (زي الموك أب)
/// ═══════════════════════════════════════════════════════════════
///
/// سطر واحد سريع: الاسم + العنوان والمسافة، والمديونية رقم واضح
/// على الجنب. تحته الشيبس اللي بتفرق (كاش/آجل · خصم · عميل جديد ·
/// ماتزارش)، وصف الأكشن: «ابدأ الزيارة ›» بيدخل على شاشة العميل
/// (والتشيك إن أول حاجة فيها) + تليفون + لوكيشن + التاريخ.
/// العميل اللي خلص بياخد صف مختصر أخضر «تمت ✓».
class ClientTile extends StatelessWidget {
  final Client client;

  /// نقطة المندوب — للمسافة على الكارت (اختيارية)
  final (double, double)? pos;

  const ClientTile({super.key, required this.client, this.pos});

  @override
  Widget build(BuildContext context) {
    final c = client;
    final days = c.daysSinceVisit;
    final done = c.status == VisitStatus.done;
    final km = kmTo(pos, c.lat, c.lng);

    void open() => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ClientScreen(client: c)));

    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (done ? Brand.green : Brand.royalBlue)
                          .withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                        done ? Icons.check_circle : Icons.storefront,
                        size: 19,
                        color: done ? Brand.green : Brand.royalBlue),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (c.chain != null &&
                            c.chain!.trim().isNotEmpty &&
                            c.chain != c.branch)
                          Text(c.chain!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Brand.muted)),
                        Text(c.branch,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: done ? Brand.muted : null)),
                        const SizedBox(height: 2),
                        Text(
                            [
                              if (c.address.isNotEmpty) c.address,
                              if (km != null) kmLabel(km),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10.5, color: Brand.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // المديونية — رقم واضح، مش شارة مستخبية
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(L.t('debt_word'),
                          style:
                              TextStyle(fontSize: 9, color: Brand.muted)),
                      Text(
                          c.balance > 0
                              ? money(c.balance)
                              : '0',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: c.balance > 0
                                  ? const Color(0xFFB86E00)
                                  : Brand.muted)),
                    ],
                  ),
                ],
              ),

              if (done)
                // ═══ اتزارت — صف مختصر من غير أزرار ═══
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Row(children: [
                    Chip2(text: L.t('done_f'), color: Brand.green),
                    const SizedBox(width: 8),
                    if (c.lastVisitAt != null)
                      Text(
                          L.t('visited_at',
                              {'t': fmtTime(c.lastVisitAt!)}),
                          style: TextStyle(
                              fontSize: 10.5, color: Brand.muted)),
                  ]),
                )
              else ...[
                const SizedBox(height: 8),
                // الشيبس اللي بتفرق للمندوب وهو بيقرر
                Wrap(spacing: 6, runSpacing: 5, children: [
                  _Tag(
                    icon: Icons.payments_outlined,
                    text: c.paymentChoice
                        ? L.t('payment_both')
                        : (c.paymentTerms == 'cash'
                            ? L.t('cash')
                            : L.t('credit')),
                    color: Brand.royalBlue,
                  ),
                  if (c.discount > 0)
                    _Tag(
                      icon: Icons.sell_outlined,
                      text: L.t('discount_n',
                          {'n': '${(c.discount * 100).round()}'}),
                      color: Brand.purpleHeart,
                    ),
                  if (c.isNew)
                    _Tag(
                      icon: Icons.fiber_new_outlined,
                      text: L.t('new_client'),
                      color: Brand.green,
                    ),
                  if (days == null)
                    _Tag(
                      icon: Icons.history,
                      text: L.t('never_visited'),
                      color: Brand.orange,
                    )
                  else if (days >= 7)
                    _Tag(
                      icon: Icons.history,
                      text: L.t('last_visit_days', {'n': '$days'}),
                      color: days >= 14 ? Brand.red : Brand.orange,
                    ),
                ]),
                const SizedBox(height: 8),

                // ═══ صف الأكشن: ابدأ الزيارة + تليفون + لوكيشن + التاريخ ═══
                Row(children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: open,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 5),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(L.t('start_visit'),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Brand.royalBlue)),
                        const Icon(Icons.chevron_left,
                            size: 18, color: Brand.royalBlue),
                      ]),
                    ),
                  ),
                  const Spacer(),
                  _CardIconBtn(
                    icon: Icons.history_toggle_off,
                    tooltip: L.t('client_history'),
                    color: Brand.royalBlue,
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => ClientHistoryScreen(
                                clientId: c.id, clientName: c.name))),
                  ),
                  if (c.phone.trim().isNotEmpty) ...[
                    const SizedBox(width: 7),
                    _CardIconBtn(
                      icon: Icons.phone_outlined,
                      tooltip: L.t('call'),
                      color: Brand.royalBlue,
                      onTap: () =>
                          Locator.openUrl('tel:${c.phone.trim()}'),
                    ),
                  ],
                  if (c.directionsUrl != null) ...[
                    const SizedBox(width: 7),
                    _CardIconBtn(
                      icon: Icons.place_outlined,
                      tooltip: L.t('get_directions'),
                      color: Brand.green,
                      onTap: () => Locator.openUrl(c.directionsUrl!),
                    ),
                  ],
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// تاج صغير بأيقونة — للكارت والشاشات اللي محتاجة معلومة مختصرة
class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Tag({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

// ================= كارت الزيارة =================

class ClientScreen extends StatefulWidget {
  final Client client;
  const ClientScreen({super.key, required this.client});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  bool _busy = false;

  /// أرقام الكارت من `/clients/{id}/card` (موك أب ٢١/٨) — بتتحمّل
  /// في الخلفية، والشاشة شغّالة من غيرها لو الشبكة وقعت: المربعات
  /// بتفضل «—» والتشيك إن نفسه مش بيتأثر.
  ClientCardStats? _card;

  /// نقطة المندوب — لسطر «إنت على بعد :n متر من العميل»
  (double, double)? _pos;

  /// تكّة التايمر الحي «12:47» — بتعيد الرسم بس والزيارة مفتوحة
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _loadCard();
    _locate();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final c = Session.I.clientById(widget.client.id) ?? widget.client;
      if (mounted && c.status == VisitStatus.inVisit) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _loadCard() async {
    try {
      final res = await Api.I.clientCard(widget.client.id);
      if (mounted) setState(() => _card = ClientCardStats.fromJson(res));
    } catch (_) {
      // مفيش شبكة؟ الفلو شغّال عادي — الأرقام مش شرط للزيارة
    }
  }

  Future<void> _locate() async {
    final p = await Locator.get();
    if (mounted && p != null) setState(() => _pos = p);
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    final err = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }

  /// الانتقال للزيارة المفتوحة على عميل تاني.
  ///
  /// ⚠️⚠️ **مابنبنيش عميل مؤقت من `open_visit`.** العميل المؤقت
  /// خصمه صفر ورصيده صفر، وشاشة البيع بتحسب المعروض من
  /// `client.discount` — نفس فخ «رقم على اللسان ورقم في الفاتورة».
  /// فالترتيب: نلاقيه في المحمَّل → وإلا نحدّث من السيرفر → وإلا
  /// نقول للمندوب يقفلها من مكانها.
  Future<void> _goToOpenVisit(int openId) async {
    var other = Session.I.clientById(openId);

    if (other == null) {
      setState(() => _busy = true);
      await Session.I.refresh();
      if (!mounted) return;
      setState(() => _busy = false);
      other = Session.I.clientById(openId);
    }

    if (!mounted) return;

    if (other == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.t('open_visit_not_loaded'))));

      return;
    }

    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ClientScreen(client: other!)));
  }

  /// رقم بفواصل الآلاف من غير عملة — الأرقام الكبيرة في المربعات
  static String _n(num v) {
    final s =
        v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    final parts = s.split('.');
    final whole = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

    return whole + (parts.length > 1 ? '.${parts[1]}' : '');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final c = Session.I.clientById(widget.client.id) ?? widget.client;

        // ⚠️ **أيقونات شريط الحالة بيضا بالإجبار** — من غير أب بار
        // الشاشة بتورّث ستايل الشاشة اللي قبلها.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            bottomNavigationBar: _footer(c),
            body: ListView(
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                _header(c),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_busy) const LinearProgressIndicator(),
                      if (c.status == VisitStatus.pending)
                        ..._pendingBody(c),
                      if (c.status == VisitStatus.inVisit)
                        ..._visitBody(c),
                      if (c.status == VisitStatus.done) ..._doneBody(c),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // الفوتر الثابت — تشيك إن متدرج + سطر المسافة · تشيك أوت أحمر
  // ═══════════════════════════════════════════════════════════
  //
  // ⚠️ viewPadding صريح (٢١/٨) — SafeArea ماكانتش بتزق الأزرار فوق
  // بار النظام على الجهاز.
  Widget? _footer(Client c) {
    final pad = EdgeInsets.fromLTRB(
        16, 0, 16, 12 + MediaQuery.viewPaddingOf(context).bottom);

    if (c.status == VisitStatus.pending) {
      final openId = Session.I.openVisitClientId;
      // زيارة تانية مفتوحة → الكارت في البودي بيشرح، مفيش زرار بيفشل
      if (openId != null && openId != c.id) return null;

      // «إنت على بعد 40 متر من العميل» — من آخر نقطة GPS
      final km = kmTo(_pos, c.lat, c.lng);
      String? away;
      if (km != null) {
        final m = (km * 1000).round();
        away = m < 950
            ? L.t('cc_away_m', {'n': '$m'})
            : L.t('cc_away_km', {'k': km.toStringAsFixed(1)});
      }

      return Padding(
        padding: pad,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _gradientBtn(
            icon: Icons.login,
            label: L.t('check_in'),
            onTap: _busy ? null : () => _run(() => Session.I.checkIn(c)),
          ),
          if (away != null)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(away,
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Brand.royalBlue)),
            ),
        ]),
      );
    }

    if (c.status != VisitStatus.inVisit) return null;

    return Padding(
      padding: pad,
      child: FilledButton.icon(
        icon: const Icon(Icons.logout, size: 20),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: Brand.red.withValues(alpha: .10),
          foregroundColor: Brand.red,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Brand.red.withValues(alpha: .35))),
        ),
        label: Text(L.t('check_out'),
            style: const TextStyle(
                fontSize: 15.5, fontWeight: FontWeight.w800)),
        onPressed: _busy ? null : () => _run(() => Session.I.checkOut(c)),
      ),
    );
  }

  /// زرار متدرج عريض — التشيك إن و«ابدأ التسليم»
  ///
  /// ⚠️ **Container مش Ink** (بلاغ ٢١/٨ مساءً): Ink بيرسم على
  /// الـMaterial الأبعد، فجوه كارت أبيض التدرج كان بيترسم **تحت**
  /// خلفية الكارت — زرار أبيض بنص أبيض غير مرئي. Container بيرسم
  /// في مكانه الصح، والـInkWell جوه Material شفاف عشان الريبل.
  Widget _gradientBtn(
          {IconData? icon, required String label, VoidCallback? onTap}) =>
      Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: Brand.gradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 19, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ]),
          ),
        ),
      );

  // ═══════════════════════════════════════════════════════════
  // الهيدر المتدرج (موك أب ٢١/٨)
  // ═══════════════════════════════════════════════════════════
  //
  // قبل الزيارة: الاسم + «جملة · كود CL-1043» + شيبس الدفع/الخصم/
  // التصنيف + بوكس العنوان + الطريق واتصل.
  // جوه الزيارة: الاسم + أيقونات اتصال/اتجاهات + كارت التايمر الحي.
  Widget _header(Client c) {
    final inVisit = c.status == VisitStatus.inVisit;

    final subParts = <String>[
      if (c.channelLabel.isNotEmpty) c.channelLabel,
      if (c.code.isNotEmpty) L.t('cc_code', {'c': c.code}),
    ];

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: Brand.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                IconButton(
                  tooltip: L.t('back'),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 22),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900)),
                      if (subParts.isNotEmpty)
                        Text(subParts.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                // جوه الزيارة: اتصال واتجاهات فوق (موك أب ٢)
                if (inVisit) ...[
                  if (c.phone.trim().isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _HeaderIconBtn(
                      icon: Icons.call,
                      tooltip: L.t('call'),
                      onTap: () =>
                          Locator.openUrl('tel:${c.phone.trim()}'),
                    ),
                  ],
                  if (c.directionsUrl != null) ...[
                    const SizedBox(width: 6),
                    _HeaderIconBtn(
                      icon: Icons.near_me_outlined,
                      tooltip: L.t('get_directions'),
                      onTap: () => Locator.openUrl(c.directionsUrl!),
                    ),
                  ],
                ],
              ]),

              if (inVisit) ...[
                const SizedBox(height: 10),
                _visitTimerCard(c),
              ] else ...[
                const SizedBox(height: 10),

                // ═══ شيبس شروط البيع (موك أب ١) ═══
                //
                // ⚠️ `both` بتطلع «كاش وآجل» — المقارنة النصية كانت
                // بتحط أي حاجة مش `cash` في خانة الآجل (درس ٨/٨).
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _HeroLabel(
                    icon: Icons.payments_outlined,
                    text: c.paymentChoice
                        ? L.t('payment_both')
                        : c.paymentTerms == 'cash'
                            ? L.t('cash')
                            : (c.paymentDays != null && c.paymentDays! > 0
                                ? L.t('cc_credit_days',
                                    {'n': '${c.paymentDays}'})
                                : L.t('credit')),
                  ),
                  if (c.discount > 0)
                    _HeroLabel(
                      icon: Icons.sell_outlined,
                      text: L.t('discount_n',
                          {'n': '${(c.discount * 100).round()}'}),
                      strong: true,
                    ),
                  // التصنيف التجاري بالأصفر البراندي — «عميل مهم»
                  if (c.category != 'ok' && c.categoryLabel.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Brand.yellow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(c.categoryLabel,
                          style: const TextStyle(
                              color: Brand.ink,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900)),
                    ),
                ]),

                // ═══ بوكس العنوان — أغمق شوية جوه التدرج ═══
                if (c.fullAddress.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.place_outlined,
                            size: 15, color: Colors.white70),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(c.fullAddress,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  height: 1.5,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],

                // ═══ الطريق (أبيض مليان) + اتصل (شفاف) ═══
                if (c.directionsUrl != null ||
                    c.phone.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    if (c.directionsUrl != null)
                      Expanded(
                        child: _hdrBtn(
                          icon: Icons.near_me_outlined,
                          label: L.t('cc_route'),
                          filled: true,
                          onTap: () => Locator.openUrl(c.directionsUrl!),
                        ),
                      ),
                    if (c.directionsUrl != null &&
                        c.phone.trim().isNotEmpty)
                      const SizedBox(width: 10),
                    if (c.phone.trim().isNotEmpty)
                      Expanded(
                        child: _hdrBtn(
                          icon: Icons.call_outlined,
                          label: L.t('call'),
                          filled: false,
                          onTap: () =>
                              Locator.openUrl('tel:${c.phone.trim()}'),
                        ),
                      ),
                  ]),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// زرار الهيدر: «الطريق» أبيض مليان و«اتصل» شفاف بحدود
  Widget _hdrBtn(
          {required IconData icon,
          required String label,
          required bool filled,
          required VoidCallback onTap}) =>
      InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color:
                filled ? Colors.white : Colors.white.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(13),
            border: filled
                ? null
                : Border.all(color: Colors.white.withValues(alpha: .4)),
          ),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 17, color: filled ? Brand.royalBlue : Colors.white),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: filled ? Brand.royalBlue : Colors.white)),
          ]),
        ),
      );

  /// ═══ كارت التايمر الحي «12:47» (موك أب ٢) ═══
  ///
  /// أقل من ساعة: دقيقة:ثانية · ساعة فأكتر: ساعة:دقيقة — عشان الرقم
  /// الكبير يفضل ليه معنى من غير ما يبقى ٣ خانات.
  Widget _visitTimerCard(Client c) {
    final at = c.checkInAt;
    final el = at == null ? Duration.zero : DateTime.now().difference(at);
    final hours = el.inHours;
    final big = hours > 0
        ? '$hours:${(el.inMinutes % 60).toString().padLeft(2, '0')}'
        : '${el.inMinutes}:${(el.inSeconds % 60).toString().padLeft(2, '0')}';
    final unit = hours > 0 ? L.t('cc_hr_min') : L.t('cc_min_sec');
    final avg = Session.I.today.avgVisitMin;

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                      at == null
                          ? L.t('in_visit')
                          : L.t('cc_visit_on', {'t': fmtTime(at)}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800)),
                ),
              ]),
              if (avg > 0) ...[
                const SizedBox(height: 4),
                Text(L.t('cc_avg_visit', {'n': '$avg'}),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 10.5)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(big,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1.05,
                    fontWeight: FontWeight.w900)),
            Text(unit,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 9.5)),
          ],
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // بودي «قبل التشيك إن» (موك أب ١): شبكة الأرقام + الـPO المستني
  // + كارت آخر زيارة
  // ═══════════════════════════════════════════════════════════
  List<Widget> _pendingBody(Client c) {
    final out = <Widget>[];

    if (c.directionsUrl == null) {
      out.addAll([
        _MiniFlag(
            icon: Icons.location_off_outlined,
            text: L.t('no_location_checkin_first')),
        const SizedBox(height: 12),
      ]);
    }

    // ⚠️ زيارة مفتوحة على عميل تاني؟ بنقولها **قبل** ما يدوس —
    // المصدر `openVisitClientId` من السيرفر (درس «هيد باديل» ١١/٨)
    final openId = Session.I.openVisitClientId;
    if (openId != null && openId != c.id) {
      final openName = Session.I.openVisitName ?? '—';
      out.addAll([
        Card(
          color: const Color(0xFFFFF4E5),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(L.t('close_visit_first', {'c': openName}),
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: const Color(0xFFB45309),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.arrow_forward, size: 19),
                  label: Text(L.t('open_visit_go'),
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w800)),
                  onPressed:
                      _busy ? null : () => _goToOpenVisit(openId),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ]);
    }

    // ═══ شبكة الأرقام ٢×٢ ═══
    final s = _card;
    final retPct = s == null
        ? ''
        : (s.returnsPct % 1 == 0
            ? s.returnsPct.toStringAsFixed(0)
            : s.returnsPct.toStringAsFixed(1));

    out.addAll([
      // ⚠️ **ممنوع stretch هنا** (بلاغ ٢١/٨ مساءً): الصف جوه عمود
      // بارتفاع مفتوح (ListView)، وstretch كانت بتمطّط الخلايا لما
      // لا نهاية — الصف الأول بياخد الشاشة كلها والباقي بيختفي تحت.
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: _statCard(
            dot: Brand.royalBlue,
            title: L.t('cc_month_sales'),
            value: s == null ? '—' : _n(s.monthSales),
            sub: s == null
                ? ''
                : '${L.t('currency')} · ${L.t('cc_invoices_n', {
                        'n': '${s.monthInvoices}'
                      })}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            dot: Brand.orange,
            title: L.t('cc_returns'),
            value: s == null ? '—' : _n(s.monthReturns),
            valueColor: Brand.orange,
            sub: s == null
                ? ''
                : '${L.t('currency')} · ${L.t('cc_of_sales', {
                        'n': retPct
                      })}',
          ),
        ),
      ]),
      const SizedBox(height: 10),
      // ⚠️ **ممنوع stretch هنا** (بلاغ ٢١/٨ مساءً): الصف جوه عمود
      // بارتفاع مفتوح (ListView)، وstretch كانت بتمطّط الخلايا لما
      // لا نهاية — الصف الأول بياخد الشاشة كلها والباقي بيختفي تحت.
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: _statCard(
            dot: Brand.green,
            title: L.t('cc_collected'),
            value: s == null ? '—' : _n(s.monthCollections),
            sub: s == null
                ? ''
                : '${L.t('currency')}${s.lastCollectionDays == null ? '' : ' · ${L.t('cc_last_n_days', {
                          'n': '${s.lastCollectionDays}'
                        })}'}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: c.balance > 0
              ? _statCard(
                  badge: L.t('cc_due'),
                  title: '',
                  value: _n(c.balance),
                  valueColor: Brand.red,
                  bg: const Color(0xFFFFF5F4),
                  borderColor: const Color(0xFFF3CBC7),
                  sub:
                      '${L.t('currency')}${s != null && s.overdueDays > 0 ? ' · ${L.t('cc_late_n', {
                              'n': '${s.overdueDays}'
                            })}' : ''}',
                  subColor:
                      s != null && s.overdueDays > 0 ? Brand.red : null,
                )
              : _statCard(
                  dot: Brand.green,
                  title: L.t('cc_due'),
                  value: _n(c.balance),
                  valueColor: Brand.green,
                  sub: L.t('currency'),
                ),
        ),
      ]),
    ]);

    // ═══ أمر توريد مستني ═══
    final po = firstOrNull(Session.I.pos
        .where((p) => p.clientId == c.id && p.status != 'delivered'));
    if (po != null) {
      out.addAll([const SizedBox(height: 12), _poWaitingCard(po)]);
    }

    out.addAll([const SizedBox(height: 12), _lastVisitCard(c)]);

    return out;
  }

  Widget _statCard({
    required String title,
    required String value,
    required String sub,
    Color? dot,
    String? badge,
    Color? valueColor,
    Color? bg,
    Color? borderColor,
    Color? subColor,
  }) =>
      Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: bg ?? Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor ?? Brand.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Brand.muted)),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Brand.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(badge,
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                )
              else if (dot != null)
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
            ]),
            const SizedBox(height: 7),
            Text(value,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: valueColor ?? Brand.text)),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(sub,
                  style: TextStyle(
                      fontSize: 9.5, color: subColor ?? Brand.muted)),
            ],
          ],
        ),
      );

  /// «متأخر من امبارح 3:02 م» — نفس صياغة كارت أوامر التوريد
  String _lateLabel(DateTime d) {
    final now = DateTime.now();
    bool same(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    final t = fmtTime(d);

    if (same(d, now.subtract(const Duration(days: 1)))) {
      return L.t('po_late_since_y', {'t': t});
    }
    if (same(d, now)) return L.t('po_late_since', {'d': t});

    return L.t('po_late_since', {'d': '${fmtDate(d).split(' ').first} $t'});
  }

  /// ═══ كارت «أمر توريد مستني» بصور الأصناف (موك أب ١) ═══
  Widget _poWaitingCard(PurchaseOrder po) {
    final images =
        po.items.map((i) => i.image).whereType<String>().take(4).toList();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PoDeliveryScreen(poId: po.id))),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Brand.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDEBEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_shipping_outlined,
                        size: 20, color: Brand.razzmatazz),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${L.t('cc_po_waiting')} · ${po.number}',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900)),
                        if (po.late && po.dueAt != null)
                          Text(_lateLabel(po.dueAt!),
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Brand.red)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_n(po.total),
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900)),
                      Text(
                          '${L.t('currency')} · ${L.t('total_units', {
                                'n': '${po.qtyTotal}'
                              })}',
                          style: TextStyle(
                              fontSize: 9.5, color: Brand.muted)),
                    ],
                  ),
                ],
              ),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(children: [
                  for (final u in images)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 7),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Brand.border),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        clipBehavior: Clip.antiAlias,
                        padding: const EdgeInsets.all(3),
                        child: Image.network(u,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink()),
                      ),
                    ),
                ]),
              ],
              const SizedBox(height: 8),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(L.t('cc_view_po'),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Brand.royalBlue)),
                const Icon(Icons.chevron_left,
                    size: 17, color: Brand.royalBlue),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  /// ═══ كارت «آخر زيارة قبل :n أيام» + زرار الزيارات (موك أب ١) ═══
  Widget _lastVisitCard(Client c) {
    final s = _card;
    final days = s?.lastVisitDays;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ClientHistoryScreen(
                clientId: c.id, clientName: c.name))),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Brand.border),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Brand.blue050,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.event_note_outlined,
                  size: 20, color: Brand.royalBlue),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      s == null
                          ? L.t('last_visit')
                          : days == null
                              ? L.t('cc_first_visit')
                              : days == 0
                                  ? L.t('cc_last_visit_today')
                                  : L.t('cc_last_visit_n',
                                      {'n': '$days'}),
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w900)),
                  if (s != null && s.lastVisitAt != null)
                    Text(
                        L.t('cc_lv_line', {
                          'i': _n(s.lastVisitSales),
                          'c': _n(s.lastVisitCollected),
                        }),
                        style: TextStyle(
                            fontSize: 10.5, color: Brand.muted)),
                ],
              ),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(L.t('cc_visits_btn'),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Brand.royalBlue)),
              const Icon(Icons.chevron_left,
                  size: 17, color: Brand.royalBlue),
            ]),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // بودي الزيارة المفتوحة (موك أب ٢): كارت التسليم + شبكة ٢×٣
  // + ضيف لوكيشن
  // ═══════════════════════════════════════════════════════════
  List<Widget> _visitBody(Client c) {
    final out = <Widget>[];

    // ═══ سلّم أمر التوريد — أول حاجة في الزيارة (فلو ٢١/٨) ═══
    final po = firstOrNull(Session.I.pos
        .where((p) => p.clientId == c.id && p.status != 'delivered'));

    if (po != null) {
      out.addAll([
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Brand.royalBlue, width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Brand.blue050,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_shipping_outlined,
                      size: 21, color: Brand.royalBlue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(L.t('cc_deliver_po'),
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900)),
                      Text(
                          '${po.number} · ${L.t('items_n', {
                                'n': '${po.items.length}'
                              })} · ${L.t('total_units', {
                                'n': '${po.qtyTotal}'
                              })}',
                          style: TextStyle(
                              fontSize: 10.5, color: Brand.muted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_n(po.total),
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                    Text(L.t('currency'),
                        style: TextStyle(
                            fontSize: 9.5, color: Brand.muted)),
                  ],
                ),
              ]),
              const SizedBox(height: 11),
              _gradientBtn(
                label: L.t('cc_start_delivery'),
                onTap: _busy
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PoDeliveryScreen(poId: po.id))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ]);
    }

    // ═══ شبكة الأكشنات ٢×٣ ═══
    //
    // ⚠️ (١١/٨ مساءً) المدير بيشوف كل الأكشنات الستة زي المندوب —
    // قرار المالك: «الشركة لسه صغيرة، المدير هيبيع ويتصفّى».
    out.addAll([
      // ⚠️ **ممنوع stretch هنا** (بلاغ ٢١/٨ مساءً): الصف جوه عمود
      // بارتفاع مفتوح (ListView)، وstretch كانت بتمطّط الخلايا لما
      // لا نهاية — الصف الأول بياخد الشاشة كلها والباقي بيختفي تحت.
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _actionCell(
          icon: Icons.shopping_cart_outlined,
          color: Brand.royalBlue,
          label: L.t('sale'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SaleScreen(client: c))),
        ),
        const SizedBox(width: 10),
        _actionCell(
          icon: Icons.payments_outlined,
          color: Brand.green,
          label: L.t('collect_btn'),
          sub: c.balance > 0
              ? L.t('cc_on_him_n', {'n': _n(c.balance)})
              : null,
          subColor: Brand.orange,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CollectScreen(client: c))),
        ),
      ]),
      const SizedBox(height: 10),
      // ⚠️ **ممنوع stretch هنا** (بلاغ ٢١/٨ مساءً): الصف جوه عمود
      // بارتفاع مفتوح (ListView)، وstretch كانت بتمطّط الخلايا لما
      // لا نهاية — الصف الأول بياخد الشاشة كلها والباقي بيختفي تحت.
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _actionCell(
          icon: Icons.u_turn_left,
          color: Brand.orange,
          label: L.t('return_doc'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ClientReturnScreen(client: c))),
        ),
        const SizedBox(width: 10),
        _actionCell(
          icon: Icons.photo_camera_outlined,
          color: Brand.blue500,
          label: L.t('shelf_btn'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ShelfPhotosScreen(client: c))),
        ),
      ]),
      const SizedBox(height: 10),
      // ⚠️ **ممنوع stretch هنا** (بلاغ ٢١/٨ مساءً): الصف جوه عمود
      // بارتفاع مفتوح (ListView)، وstretch كانت بتمطّط الخلايا لما
      // لا نهاية — الصف الأول بياخد الشاشة كلها والباقي بيختفي تحت.
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _actionCell(
          icon: Icons.card_giftcard_outlined,
          color: Brand.purpleHeart,
          label: L.t('gift_btn'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => GiftsScreen(
                  presetClientId: c.id,
                  presetClientName: c.name,
                  visitId: c.visitId))),
        ),
        const SizedBox(width: 10),
        _actionCell(
          icon: Icons.add_shopping_cart,
          color: const Color(0xFF00695C),
          label: L.t('goods_btn'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => GoodsRequestScreen(client: c))),
        ),
      ]),
    ]);

    // ═══ ضيف/عدّل لوكيشن العميل ═══
    //
    // ⚠️ **الشرط `locationConfirmed` مش `lat != null`** — وجود
    // إحداثيات مش معناه إن بني آدم راجعها وأكّدها.
    if (!c.locationConfirmed) {
      final has = c.lat != null && c.lng != null;

      out.addAll([
        const SizedBox(height: 12),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _busy
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ClientLocationScreen(client: c))),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 13, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Brand.border),
              ),
              child: Row(children: [
                Icon(
                    has
                        ? Icons.edit_location_alt_outlined
                        : Icons.add_location_alt_outlined,
                    size: 18,
                    color: has ? Brand.muted : Brand.red),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                      has
                          ? L.t('edit_client_location')
                          : L.t('add_client_location'),
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: has ? Brand.text : Brand.red)),
                ),
                const Icon(Icons.chevron_left,
                    size: 18, color: Brand.muted),
              ]),
            ),
          ),
        ),
      ]);
    }

    return out;
  }

  /// خلية أكشن في شبكة الزيارة — أيقونة في مربع ملوّن + لابل
  /// (+ «عليه :n» تحت التحصيل)
  Widget _actionCell({
    required IconData icon,
    required Color color,
    required String label,
    String? sub,
    Color? subColor,
    required VoidCallback onTap,
  }) =>
      Expanded(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _busy ? null : onTap,
            child: Container(
              // ارتفاع ثابت — الخليتين في الصف يبقوا قد بعض من غير
              // stretch (اللي كان بيكسر الرندر في الارتفاع المفتوح)
              height: 118,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Brand.border),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, size: 21, color: color),
                ),
                const SizedBox(height: 9),
                Text(label,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w800)),
                if (sub != null)
                  Text(sub,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: subColor ?? Brand.muted)),
              ]),
            ),
          ),
        ),
      );

  // ═══════════════════════════════════════════════════════════
  // بودي «الزيارة اتقفلت» — زي ما كان
  // ═══════════════════════════════════════════════════════════
  List<Widget> _doneBody(Client c) {
    return [
      // «آخر زيارة» بتاريخها — «اتقفلت» لوحدها ماكانتش بتقول حاجة
      Builder(builder: (context) {
        final at = c.checkOutAt ?? c.checkInAt;

        return Card(
          color: const Color(0xFFE7F7EE),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    size: 19, color: Color(0xFF16A34A)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(L.t('last_visit_was'),
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800)),
                      if (at != null)
                        Text('${fmtDate(at)} · ${fmtTime(at)}',
                            style: TextStyle(
                                fontSize: 11.5, color: Brand.muted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Brand.green.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(L.t('visit_closed_f'),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F7A38))),
                ),
              ],
            ),
          ),
        );
      }),
      const SizedBox(height: 8),
      // ⚠️ الزيارة المقفولة مش نهاية اليوم — يقدر يفتح زيارة جديدة،
      // والمصدر `openVisitClientId` مش البحث في القوايم المحمّلة.
      Builder(builder: (context) {
        final openId = Session.I.openVisitClientId;

        if (openId != null && openId != c.id) {
          final openName = Session.I.openVisitName ?? '—';

          return Card(
            color: const Color(0xFFFFF4E5),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _busy ? null : () => _goToOpenVisit(openId),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 19, color: Color(0xFFB45309)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          L.t('close_visit_tap', {'c': openName}),
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB45309))),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 20, color: Color(0xFFB45309)),
                  ],
                ),
              ),
            ),
          );
        }

        return OutlinedButton.icon(
          icon: const Icon(Icons.login),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          label: Text(L.t('check_in_again'),
              style: const TextStyle(fontSize: 15)),
          onPressed:
              _busy ? null : () => _run(() => Session.I.checkIn(c)),
        );
      }),
    ];
  }
}

/// ═══════════════════════════════════════════════════════════════
/// لابل شرط بيع في هيدر العميل  ·  ١٥ أغسطس ٢٠٢٦
/// ═══════════════════════════════════════════════════════════════
///
/// طلب المالك: «حط طرق البيع بتاعته والخصم بتاعه في Labels كده شيك».
///
/// حلّ محل الشيبس القديمة (كبر التعامل · عميل جديد · الدفع · الخصم)
/// اللي كانت أربعة بنفس الوزن — فالمندوب مابيفرقش بين تصنيف إداري
/// مالوش لازمة وشرط بيع بيحدد إزاي هيتحاسب.
///
/// ⚠️ **أيقونة + نص، مش لون بس** — الخصم `strong` بخلفية أوضح لأنه
/// الرقم اللي بيغيّر السعر، بس التمييز مش باللون وحده.
/// أيقونة مربعة على كارت العميل في الليستة.
///
/// ⚠️ **٤٦×٤٤ على الأقل** — قاعدة مساحة اللمس. الكارت مزحوم
/// والإغراء إنها تبقى ٣٢؛ المندوب بيدوس بإبهامه وهو ماشي.
class _CardIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _CardIconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 46,
        height: 44,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: .5)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onTap,
          child: Tooltip(message: tooltip, child: Icon(icon, size: 20)),
        ),
      );
}

/// أيقونة دايرية على الهيدر المتدرّج — اتصال / اتجاهات.
///
/// ⚠️ **٤٠×٤٠ مش أقل.** الأيقونة نفسها ١٧ بكسل، بس مساحة اللمس
/// لازم تفضل قريبة من ٤٤ — المندوب بيدوس بإبهامه وهو ماشي.
class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white.withValues(alpha: .18),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, size: 18, color: Colors.white),
            ),
          ),
        ),
      );
}

/// شارة تحذير صغيرة — بديل الكارت الأحمر بعرض الشاشة
class _MiniFlag extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniFlag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Brand.red.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Brand.red.withValues(alpha: .28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Brand.red),
            const SizedBox(width: 5),
            Text(text,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Brand.red)),
          ],
        ),
      );
}

class _HeroLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool strong;

  const _HeroLabel({
    required this.icon,
    required this.text,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: strong ? .26 : .14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: Colors.white.withValues(alpha: strong ? .45 : .20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: strong ? FontWeight.w900 : FontWeight.w700)),
        ],
      ),
    );
  }
}
