import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n.dart';

/// ═══════════════════════════════════════════════════════════════
/// المنتقي المتعدد — «علّم على كل اللي عايزه ودوس إضافة»
/// ═══════════════════════════════════════════════════════════════
///
/// طلب المالك (١٢ أغسطس ٢٠٢٦): البيع كان وجع — المندوب بيكتب اسم
/// كل صنف بالإيد صنف ورا صنف. دلوقتي دوسة واحدة على خانة البحث
/// بتفتح **كل** الأصناف بتشيك بوكس: يعلّم على اللي عايزه، يدوس
/// «إضافة (X)»، وكلهم ينزلوا سطور — بعدين يظبط كمية ووحدة كل سطر.
///
/// ودجت عامة: بتاخد `PickEntry` مش موديل معيّن — عشان تشتغل مع
/// عهدة البيع والمرتجع (`CustodyItem`)، وكتالوج طلب البضاعة،
/// وكتالوج البروموتر بنفس الشكل في كل حتة.
///
/// اللي كان متعلّم عليه قبل كده بيفتح متعلّم — وشيل العلامة بيشيل
/// السطر من الشاشة الأم (رحلة ذهاب وعودة بديهية).
class PickEntry {
  final int id;
  final String name;

  /// كود / باركود — بيتعرض تحت الاسم لو موجود
  final String code;
  final String? image;

  /// سطر معلومات (سعر / وحدة) — بيتعرض زي ما هو
  final String subtitle;

  /// شارة جانبية (مثلاً «متاح ١٢») بألوانها — اختيارية
  final String? badge;
  final Color? badgeBg;
  final Color? badgeFg;

  /// نص بحث إضافي (الاسم العربي + الإنجليزي) — «برو» بتلاقي
  /// Promax وبرو ماكس مهما كانت لغة الواجهة، نفس فكرة
  /// `CustodyItem.matches`
  final String searchText;

  const PickEntry({
    required this.id,
    required this.name,
    this.code = '',
    this.image,
    this.subtitle = '',
    this.badge,
    this.badgeBg,
    this.badgeFg,
    this.searchText = '',
  });

  bool matches(String q) {
    final t = q.trim();
    if (t.isEmpty) return true;
    final s = t.toLowerCase();

    return name.toLowerCase().contains(s) ||
        code.toLowerCase().contains(s) ||
        searchText.toLowerCase().contains(s) ||
        searchText.contains(t);
  }
}

/// بيفتح شاشة الاختيار وبيرجع مجموعة الأصناف المعلّم عليها —
/// `null` لو رجع بزرار الجهاز من غير ما يدوس «إضافة».
Future<Set<int>?> showMultiItemPicker(
  BuildContext context, {
  required List<PickEntry> entries,
  Set<int> preSelected = const {},
  Color? accent,
  String? title,
}) {
  return Navigator.of(context).push<Set<int>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => MultiItemPickerScreen(
        entries: entries,
        preSelected: preSelected,
        accent: accent,
        title: title,
      ),
    ),
  );
}

/// خانة «البحث» اللي بتفتح المنتقي — شكلها خانة بحث عشان الإيد
/// تروحلها لوحدها، بس دوسة واحدة عليها بتفتح الليستة كلها.
class PickerBox extends StatelessWidget {
  final VoidCallback onTap;
  final String? label;
  final Color? accent;

  const PickerBox({super.key, required this.onTap, this.label, this.accent});

  @override
  Widget build(BuildContext context) {
    final c = accent ?? Theme.of(context).colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7E3DA)),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 20, color: Brand.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label ?? L.t('tap_pick_products'),
                style: TextStyle(fontSize: 13, color: Brand.muted),
              ),
            ),
            Icon(Icons.checklist_rounded, size: 21, color: c),
          ],
        ),
      ),
    );
  }
}

class MultiItemPickerScreen extends StatefulWidget {
  final List<PickEntry> entries;
  final Set<int> preSelected;
  final Color? accent;
  final String? title;

  const MultiItemPickerScreen({
    super.key,
    required this.entries,
    this.preSelected = const {},
    this.accent,
    this.title,
  });

  @override
  State<MultiItemPickerScreen> createState() => _MultiItemPickerScreenState();
}

class _MultiItemPickerScreenState extends State<MultiItemPickerScreen> {
  final _search = TextEditingController();

  /// بنقاطع مع الموجود فعلاً — id مش في الليستة (صنف اتشال من
  /// الكتالوج مثلاً) مايعدّش في «إضافة (X)» ولا يترجع للشاشة الأم
  late final Set<int> _sel = {
    for (final e in widget.entries)
      if (widget.preSelected.contains(e.id)) e.id,
  };

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PickEntry> get _filtered {
    final q = _search.text;
    if (q.trim().isEmpty) return widget.entries;
    return widget.entries.where((e) => e.matches(q)).toList();
  }

  void _toggle(PickEntry e) {
    setState(() {
      if (!_sel.remove(e.id)) _sel.add(e.id);
    });
  }

  /// «اختيار الكل» بيشتغل على النتايج الظاهرة — لو في بحث مكتوب
  /// بيعلّم على نتايجه بس، ولو الخانة فاضية بيعلّم على الكل.
  void _toggleAll(List<PickEntry> visible) {
    final all = visible.isNotEmpty && visible.every((e) => _sel.contains(e.id));
    setState(() {
      if (all) {
        for (final e in visible) {
          _sel.remove(e.id);
        }
      } else {
        for (final e in visible) {
          _sel.add(e.id);
        }
      }
    });
  }

  // الصورة أكبر شوية (٢٠/٨) — contain عشان الصنف يبان كله
  Widget _thumb(PickEntry e) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 62,
          height: 62,
          color: Colors.white,
          child: e.image == null
              ? _thumbFallback()
              : Image.network(e.image!, cacheWidth: 800,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _thumbFallback(),
                ),
        ),
      );

  Widget _thumbFallback() => Container(
        color: const Color(0xFFF0EEE8),
        child: Icon(Icons.inventory_2_outlined, size: 28, color: Brand.muted),
      );

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? Theme.of(context).colorScheme.primary;
    final visible = _filtered;
    final allPicked =
        visible.isNotEmpty && visible.every((e) => _sel.contains(e.id));
    final searching = _search.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? L.t('pick_products_title')),
        actions: [
          TextButton(
            onPressed: visible.isEmpty ? null : () => _toggleAll(visible),
            child: Text(
              allPicked ? L.t('unselect_all') : L.t('select_all'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: L.t('search_products'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searching
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(_search.clear),
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE7E3DA)),
                ),
              ),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? Center(child: Text(L.t('no_results')))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: visible.length,
                    itemBuilder: (context, idx) {
                      final e = visible[idx];
                      final on = _sel.contains(e.id);

                      return Card(
                        // الصف المتعلّم عليه بيتلوّن — يتشاف من بعيد
                        color: on
                            ? accent.withValues(alpha: .07)
                            : null,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _toggle(e),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            child: Row(
                              children: [
                                _thumb(e),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(e.name,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 5),
                                      // ═══ السعر والمتاح شارات (٢٠/٨) ═══
                                      // الكود والوزن اتشالوا من الصف —
                                      // الكود لسه بيتلقط في البحث عادي
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (e.subtitle.isNotEmpty)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Brand.royalBlue
                                                    .withValues(alpha: .08),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                e.subtitle,
                                                textDirection:
                                                    TextDirection.ltr,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: Brand.royalBlue,
                                                ),
                                              ),
                                            ),
                                          if (e.badge != null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: e.badgeBg ??
                                                    const Color(0xFFF1F1F4),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                e.badge!,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: e.badgeFg ??
                                                      Brand.muted,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Checkbox(
                                  value: on,
                                  activeColor: accent,
                                  onChanged: (_) => _toggle(e),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        // viewPadding صريح (مسح ٢١/٨) — بار «التالي» كان تحت بار النظام
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.viewPaddingOf(context).bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  L.t('n_selected', {'n': '${_sel.length}'}),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  minimumSize: const Size(150, 50),
                ),
                icon: const Icon(Icons.check),
                label: Text(L.t('add_n', {'n': '${_sel.length}'})),
                // مفعول دايماً — «إضافة (0)» بعد شيل كل العلامات
                // معناها امسح كل السطور (رحلة ذهاب وعودة كاملة)
                onPressed: () => Navigator.of(context).pop(Set<int>.of(_sel)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
