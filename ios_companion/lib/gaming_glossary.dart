class GamingGlossary {
  static final List<MapEntry<RegExp, String>> _phrases = [
    MapEntry(RegExp(r'\bnew quest available\b', caseSensitive: false), 'مهمة جديدة متاحة'),
    MapEntry(RegExp(r'\bquest (?:is )?complete[d]?\b', caseSensitive: false), 'اكتملت المهمة'),
    MapEntry(RegExp(r'\bquest failed\b', caseSensitive: false), 'فشلت المهمة'),
    MapEntry(RegExp(r'\bquest updated\b', caseSensitive: false), 'تم تحديث المهمة'),
    MapEntry(RegExp(r'\bmain quest\b', caseSensitive: false), 'المهمة الرئيسية'),
    MapEntry(RegExp(r'\bside quest\b', caseSensitive: false), 'مهمة جانبية'),
    MapEntry(RegExp(r'\bcheckpoint reached\b', caseSensitive: false), 'وصلت إلى نقطة الحفظ'),
    MapEntry(RegExp(r'\breached (?:the )?checkpoint\b', caseSensitive: false), 'وصلت إلى نقطة الحفظ'),
    MapEntry(RegExp(r'\blast checkpoint\b', caseSensitive: false), 'آخر نقطة حفظ'),
    MapEntry(RegExp(r'\bboss fight\b', caseSensitive: false), 'قتال الزعيم'),
    MapEntry(RegExp(r'\bboss battle\b', caseSensitive: false), 'معركة الزعيم'),
    MapEntry(RegExp(r'\bboss defeated\b', caseSensitive: false), 'هُزم الزعيم'),
    MapEntry(RegExp(r'\bfinal boss\b', caseSensitive: false), 'الزعيم الأخير'),
    MapEntry(RegExp(r'\bopen (?:the |your )?inventory\b', caseSensitive: false), 'افتح المخزون'),
    MapEntry(RegExp(r'\binventory full\b', caseSensitive: false), 'المخزون ممتلئ'),
    MapEntry(RegExp(r'\blow health\b', caseSensitive: false), 'صحتك منخفضة'),
    MapEntry(RegExp(r'\bhealth restored\b', caseSensitive: false), 'استعدت صحتك'),
    MapEntry(RegExp(r'\bout of ammo\b', caseSensitive: false), 'نفدت الذخيرة'),
    MapEntry(RegExp(r'\blevel up\b', caseSensitive: false), 'ارتقيت في المستوى'),
    MapEntry(RegExp(r'\bgame over\b', caseSensitive: false), 'انتهت اللعبة'),
    MapEntry(RegExp(r'\bmission complete[d]?\b', caseSensitive: false), 'اكتملت المهمة'),
    MapEntry(RegExp(r'\bmission failed\b', caseSensitive: false), 'فشلت المهمة'),
    MapEntry(RegExp(r'\bobjective complete[d]?\b', caseSensitive: false), 'اكتمل الهدف'),
    MapEntry(RegExp(r'\bnew objective\b', caseSensitive: false), 'هدف جديد'),
    MapEntry(RegExp(r'\bsave game\b', caseSensitive: false), 'احفظ اللعبة'),
    MapEntry(RegExp(r'\bpress (?:the )?options button\b', caseSensitive: false), 'اضغط زر الخيارات'),
    MapEntry(RegExp(r'\bhold (?:to )?interact\b', caseSensitive: false), 'اضغط مطولاً للتفاعل'),
  ];

  static const Map<String, String> _terms = {
    'checkpoint': 'نقطة الحفظ',
    'checkpoints': 'نقاط الحفظ',
    'inventory': 'المخزون',
    'quest': 'مهمة',
    'quests': 'مهام',
    'sidequest': 'مهمة جانبية',
    'boss': 'الزعيم',
    'miniboss': 'زعيم صغير',
    'mini-boss': 'زعيم صغير',
    'health': 'الصحة',
    'hp': 'الصحة',
    'mana': 'الطاقة',
    'stamina': 'القدرة',
    'ammo': 'الذخيرة',
    'ammunition': 'الذخيرة',
    'weapon': 'السلاح',
    'weapons': 'الأسلحة',
    'armor': 'الدرع',
    'armour': 'الدرع',
    'shield': 'الترس',
    'potion': 'جرعة',
    'item': 'عنصر',
    'items': 'عناصر',
    'loot': 'الغنائم',
    'skill': 'مهارة',
    'skills': 'المهارات',
    'ability': 'قدرة',
    'abilities': 'القدرات',
    'level': 'المستوى',
    'xp': 'الخبرة',
    'experience': 'الخبرة',
    'map': 'الخريطة',
    'minimap': 'الخريطة المصغرة',
    'waypoint': 'نقطة الطريق',
    'objective': 'الهدف',
    'objectives': 'الأهداف',
    'mission': 'المهمة',
    'missions': 'المهام',
    'dialogue': 'الحوار',
    'dialog': 'الحوار',
    'cutscene': 'مشهد قصصي',
    'save': 'حفظ',
    'load': 'تحميل',
    'settings': 'الإعدادات',
    'options': 'الخيارات',
    'pause': 'إيقاف مؤقت',
    'resume': 'استئناف',
    'retry': 'إعادة المحاولة',
    'continue': 'متابعة',
    'start': 'ابدأ',
    'skip': 'تخطي',
    'craft': 'اصنع',
    'crafting': 'الصناعة',
    'upgrade': 'ترقية',
    'equip': 'جهّز',
    'unequip': 'انزع',
    'attack': 'هجوم',
    'defend': 'دفاع',
    'dodge': 'تفادٍ',
    'parry': 'صد',
    'reload': 'إعادة تعبئة',
    'heal': 'عالج',
    'respawn': 'العودة للحياة',
    'player': 'اللاعب',
    'enemy': 'العدو',
    'enemies': 'الأعداء',
    'ally': 'الحليف',
    'team': 'الفريق',
    'score': 'النتيجة',
    'rank': 'الرتبة',
    'match': 'المباراة',
    'round': 'الجولة',
    'victory': 'النصر',
    'defeat': 'الهزيمة',
    'winner': 'الفائز',
    'loser': 'الخاسر',
    'critical': 'ضربة حرجة',
    'headshot': 'إصابة في الرأس',
    'stealth': 'التسلل',
    'cover': 'الاحتماء',
    'grenade': 'قنبلة',
    'medkit': 'حقيبة إسعاف',
    'key': 'مفتاح',
    'door': 'الباب',
    'locked': 'مغلق',
    'unlocked': 'مفتوح',
    'treasure': 'كنز',
    'chest': 'صندوق',
    'gold': 'ذهب',
    'coins': 'عملات',
    'currency': 'عملة',
    'shop': 'المتجر',
    'vendor': 'البائع',
    'buy': 'اشترِ',
    'sell': 'بِع',
    'fast travel': 'سفر سريع',
    'safe zone': 'منطقة آمنة',
    'danger zone': 'منطقة خطر',
    'tutorial': 'التعليم',
    'hint': 'تلميح',
    'warning': 'تحذير',
    'loading': 'جارٍ التحميل',
    'connecting': 'جارٍ الاتصال',
    'disconnected': 'انقطع الاتصال',
    'controller': 'يد التحكم',
    'playstation': 'بلايستيشن',
  };

  static const Map<String, String> _words = {
    'a': '',
    'an': '',
    'the': '',
    'to': 'إلى',
    'at': 'عند',
    'in': 'في',
    'on': 'على',
    'of': 'من',
    'for': 'لأجل',
    'from': 'من',
    'with': 'مع',
    'and': 'و',
    'or': 'أو',
    'before': 'قبل',
    'after': 'بعد',
    'near': 'قرب',
    'inside': 'داخل',
    'outside': 'خارج',
    'go': 'اذهب',
    'goes': 'يذهب',
    'going': 'ذاهب',
    'move': 'تحرّك',
    'run': 'اركض',
    'walk': 'امشِ',
    'enter': 'ادخل',
    'exit': 'اخرج',
    'open': 'افتح',
    'close': 'أغلق',
    'take': 'خذ',
    'pick': 'التقط',
    'use': 'استخدم',
    'press': 'اضغط',
    'hold': 'اضغط مطولاً',
    'reach': 'تصل',
    'reached': 'وصلت إلى',
    'find': 'اعثر على',
    'found': 'عثرت على',
    'defeat': 'اهزم',
    'defeated': 'هُزم',
    'kill': 'اقضِ على',
    'protect': 'احمِ',
    'follow': 'اتبع',
    'talk': 'تحدّث',
    'speak': 'تكلّم',
    'return': 'عُد',
    'back': 'رجوع',
    'next': 'التالي',
    'previous': 'السابق',
    'new': 'جديد',
    'old': 'قديم',
    'low': 'منخفض',
    'high': 'مرتفع',
    'full': 'ممتلئ',
    'empty': 'فارغ',
    'you': 'أنت',
    'your': '',
    'is': '',
    'are': '',
    'was': '',
    'were': '',
    'be': '',
    'this': 'هذا',
    'that': 'ذلك',
    'now': 'الآن',
    'here': 'هنا',
    'there': 'هناك',
    'please': 'من فضلك',
    'welcome': 'أهلاً',
    'warning': 'تحذير',
    'caution': 'انتبه',
  };

  static String translate(String input) {
    final trimmed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return '';
    if (_arabicRatio(trimmed) >= 0.45) return trimmed;

    var text = trimmed;
    for (final phrase in _phrases) {
      text = text.replaceAll(phrase.key, phrase.value);
    }

    final terms = _terms.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final term in terms) {
      text = text.replaceAll(
        RegExp('\\b${RegExp.escape(term)}\\b', caseSensitive: false),
        _terms[term]!,
      );
    }

    final rendered = <String>[];
    for (final raw in text.split(' ')) {
      if (raw.isEmpty) continue;
      final match = RegExp(r'^([^\p{L}\p{N}]*)(.*?)([^\p{L}\p{N}]*)$', unicode: true).firstMatch(raw);
      final lead = match?.group(1) ?? '';
      final core = match?.group(2) ?? raw;
      final tail = match?.group(3) ?? '';
      if (core.isEmpty) continue;
      if (_arabicRatio(core) > 0) {
        rendered.add('$lead$core$tail');
        continue;
      }
      final lookup = core.toLowerCase();
      if (_words.containsKey(lookup)) {
        final word = _words[lookup]!;
        if (word.isEmpty) continue;
        rendered.add('$lead$word$tail');
        continue;
      }
      rendered.add(raw);
    }
    return rendered.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static double _arabicRatio(String value) {
    if (value.isEmpty) return 0;
    final arabic = RegExp(r'[\u0600-\u06FF]').allMatches(value).length;
    final letters = RegExp(r'[A-Za-z\u0600-\u06FF]').allMatches(value).length;
    if (letters == 0) return 0;
    return arabic / letters;
  }
}
