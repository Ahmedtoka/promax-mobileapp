/// ═══════════════════════════════════════════════════════════════
/// الحضور والانصراف — موديل الأبلكيشن (2026-08-08)
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ **الحالة جاية من السيرفر مش محسوبة هنا.** الأبلكيشن ممكن يكون
/// أوفلاين أو ساعته غلط، والمدير ممكن يقفل الشيفت من السيستم —
/// فالسيرفر هو اللي بيقول «شغال / في بريك / خلص»، والأبلكيشن بيرسم.
library;

class Punch {
  final String type;
  final String label;
  final String icon;
  final DateTime at;
  final bool auto;
  final double? lat;
  final double? lng;

  Punch.fromJson(Map<String, dynamic> j)
      : type = j['type'] ?? '',
        label = j['label'] ?? '',
        icon = j['icon'] ?? '•',
        at = DateTime.tryParse('${j['at']}')?.toLocal() ?? DateTime.now(),
        auto = j['auto'] == true,
        lat = (j['lat'] as num?)?.toDouble(),
        lng = (j['lng'] as num?)?.toDouble();
}

class Attendance {
  /// working · break · off
  final String state;

  /// open · closed · auto
  final String status;

  final int workedMinutes;
  final int breakMinutes;
  final String workedLabel;
  final String breakLabel;
  final int sessions;
  final DateTime? firstIn;
  final DateTime? lastOut;

  /// ⚠️ **وقت آخر بانش شغل مفتوح** — الأبلكيشن بيعدّ منه محلياً.
  /// من غيره العدّاد بيفضل واقف على الرقم اللي جه من السيرفر لحد
  /// الريكوست الجاي، والموظف بيشتغل ساعة ويشوف نفس الرقم.
  final DateTime? openSince;
  final List<Punch> punches;

  const Attendance._({
    required this.state,
    required this.status,
    required this.workedMinutes,
    required this.breakMinutes,
    required this.workedLabel,
    required this.breakLabel,
    required this.sessions,
    this.firstIn,
    this.lastOut,
    this.openSince,
    this.punches = const [],
  });

  /// ⚠️ الافتراضي `off` — قبل ما السيرفر يرد، الأبلكيشن بيفترض إن
  /// الموظف **مش** حاضر. العكس كان هيوريه أزرار الشغل لثانية ويدوس
  /// عليها وترجع 423.
  factory Attendance.empty() => const Attendance._(
        state: 'off',
        status: 'open',
        workedMinutes: 0,
        breakMinutes: 0,
        workedLabel: '0:00',
        breakLabel: '0:00',
        sessions: 0,
      );

  factory Attendance.fromJson(Map<String, dynamic> j) => Attendance._(
        state: j['state'] ?? 'off',
        status: j['status'] ?? 'open',
        workedMinutes: j['worked_minutes'] ?? 0,
        breakMinutes: j['break_minutes'] ?? 0,
        workedLabel: j['worked_label'] ?? '0:00',
        breakLabel: j['break_label'] ?? '0:00',
        sessions: j['sessions'] ?? 0,
        firstIn: DateTime.tryParse('${j['first_in_at']}')?.toLocal(),
        lastOut: DateTime.tryParse('${j['last_out_at']}')?.toLocal(),
        openSince: DateTime.tryParse('${j['open_since']}')?.toLocal(),
        punches: ((j['punches'] ?? []) as List)
            .map((e) => Punch.fromJson(e))
            .toList(),
      );

  /// الثواني المعروضة **دلوقتي**.
  ///
  /// ⚠️ **`workedMinutes` جه من السيرفر لحظة الريكوست** — والوقت
  /// بيعدّي بعدها. الفرق ده هو اللي بيخلّي العدّاد يمشي من غير ما
  /// نضرب السيرفر كل ثانية.
  ///
  /// ⚠️ **وبيتحسب من `openSince` مش من فرق محلي متراكم** — لو
  /// جمّعنا ثواني على كل تيك، أي تأخير أو نوم للتليفون كان بيخلّي
  /// الرقم يقل عن الحقيقي والفرق يكبر مع اليوم.
  ///
  /// ⚠️ **بالثواني مش بالدقايق** (2026-08-08). المندوب اللي بيدوس
  /// «ابدأ شغل» وبيبص على رقم واقف دقيقة كاملة بيفتكر الأبلكيشن
  /// معلّق ويدوس تاني. الثانية اللي بتتحرك هي الدليل الوحيد إن
  /// الحاجة اشتغلت.
  int get liveWorkedSeconds {
    final base = workedMinutes * 60;

    if (openSince == null) return base;

    final extra = DateTime.now().difference(openSince!).inSeconds;

    return base + (extra > 0 ? extra : 0);
  }

  int get liveWorkedMinutes => liveWorkedSeconds ~/ 60;

  /// «7:45» — للأماكن الضيقة (كارت الرئيسية مثلاً)
  String get liveWorkedLabel {
    final m = liveWorkedMinutes;

    return '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';
  }

  /// «7:45:09» — للعدّاد الكبير في شاشة الحضور
  String get liveWorkedLong {
    final t = liveWorkedSeconds;
    final two = (int v) => v.toString().padLeft(2, '0');

    return '${t ~/ 3600}:${two((t ~/ 60) % 60)}:${two(t % 60)}';
  }

  bool get working => state == 'working';
  bool get onBreak => state == 'break';
  bool get off => state == 'off';

  /// ⚠️ **مسجّلش النهارده خالص** ≠ **خلّص شغله**. الاتنين `off`،
  /// والفرق إن التاني عنده جلسات. البوب أب بيظهر للأول بس — اللي
  /// خلّص شغله عن قصد مايتنقّرش عليه كل ما يفتح الأبلكيشن.
  bool get neverStarted => off && sessions == 0;

  /// الأكشن اللي الزرار الكبير هيعمله دلوقتي
  String get nextAction => switch (state) {
        'working' => 'out',
        'break' => 'back',
        _ => 'in',
      };
}
