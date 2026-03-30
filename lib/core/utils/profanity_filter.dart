// ============================================================
//  Safe Space — Indian Profanity Filter
//  Dil Se Baat — Safe Raho, Safe Rakho 🫂
// ============================================================

class ProfanityFilter {
  // ── Singleton ──────────────────────────────────────────────
  static final ProfanityFilter _instance = ProfanityFilter._internal();
  factory ProfanityFilter() => _instance;
  ProfanityFilter._internal();

  // ──────────────────────────────────────────────────────────
  //  MASTER WORD LIST (Heavy Duty)
  //  Hindi + Hinglish + Roman variations + leet-speak
  // ──────────────────────────────────────────────────────────
  static const List<String> _badWords = [
    // ── Common Hindi gaaliyan ──
    'madarchod', 'madarchod', 'madar chod', 'maderchod', 'mader chud',
    'behenchod', 'behen chod', 'bc', 'mc', 'mbc', 'b-c', 'm-c',
    'chutiya', 'chutiye', 'chutiyapa', 'chut', 'chutt',
    'bhosda', 'bhosdi', 'bhosdike', 'bhosdiwale', 'bhonsdike',
    'bsdk', 'bhsdwk', 'bsd',
    'randi', 'rande', 'randwa',
    'harami', 'haramzada', 'haramzadi', 'haram',
    'kamina', 'kamine', 'kamini', 'kameena', 'kameeni',
    'sala', 'saali', 'saala', 'saalay',
    'gadha', 'gadhe', 'gadhi',
    'kutta', 'kutte', 'kutti', 'kuttay',
    'suar', 'suwar', 'suwar',
    'ullu', 'ulllu',
    'gaand', 'gand', 'gaandu', 'gandu', 'gaandfat',
    'lund', 'loda', 'lode', 'lauda', 'lavda', 'lodu',
    'chodu', 'chodna', 'chod', 'chud', 'chudai',
    'bkl', 'bklol', 'bklo',
    'mkc', 'mkg', 'mkch',
    'laude', 'lauday', 'lawda',
    'tatti', 'tattu',
    'jhaat', 'jhaatu', 'jhannnt', 'jhant',
    'phuddi', 'choot', 'chootiya',
    'besharam', 'nalayak', 'nikamma',
    'jhant', 'bhadwa', 'chinal', 'gandu', 'kuttiya',
    'muth', 'rakhail', 'tatte', 'choot', 'betichod',
    'lundi', 'bhadwi', 'suar',

    // ── Leet / intentional misspelling variations ──
    'ch0d', 'ch0du', 'chud',
    'madr', 'm@darchod', 'm@der',
    'bh0sda', 'bh0\$da',
    'ch*tiya', 'ch#tiya',
    'rand1', 'r@ndi',
    'g@and', 'g4and', 'gaunnd',
    'lund', 'l*nd', 'l@nd', 'l@uda',
    'b3henchod', 'beh3nchod',

    // ── Partial / creative spellings ──
    'maadar', 'madhar', 'maader',
    'bewda', 'bevda',
    'chinal', 'chinaal',
    'rakhel', 'rakhel',
    'dalaal', 'dalal',
    'haram khor', 'haramkhor',
    'ghanta', 'ghante',
    'maderchud', 'behenchodd',
    'maa ki', 'behen ki', 'teru ma ko',

    // ── English gaaliyan (Heavy) ──
    'fuck', 'f*ck', 'f**k', 'fuk', 'fuq', 'f-u-c-k', 'f.u.c.k',
    'shit', 'sh!t', 'sh*t', 's.h.i.t', 'sh@it',
    'bitch', 'b1tch', 'b!tch', 'b.i.t.c.h', 'b*itch',
    'asshole', 'a**hole', 'a s s h o l e',
    'bastard', 'cunt', 'c*nt', 'dick', 'd!ck',
    'pussy', 'whore', 'nigga', 'nigger', 'motherfucker', 'mf',
    'slut', 'porn', 'xxx',
    'penis', 'vagina', 'boobs', 'milf',
  ];

  // ──────────────────────────────────────────────────────────
  //  NORMALIZE: remove spaces, symbols, leet variations
  // ──────────────────────────────────────────────────────────
  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '') // remove all spaces
        .replaceAll('@', 'a')
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('5', 's')
        .replaceAll('!', 'i')
        .replaceAll('\$', 's')
        .replaceAll('*', '')
        .replaceAll('#', '')
        .replaceAll('.', '')
        .replaceAll('-', '')
        .replaceAll('_', '');
  }

  // ──────────────────────────────────────────────────────────
  //  CHECK: kya text mein gali hai?
  // ──────────────────────────────────────────────────────────
  bool containsProfanity(String text) {
    if (text.isEmpty) return false;

    // Check original text first for multi-word phrases (like "maa ki")
    final lowerText = text.toLowerCase();

    // Also check normalized version
    final normalized = _normalize(text);

    for (final word in _badWords) {
      final normalizedWord = _normalize(word);

      // If the word has spaces (like "madar chod"), we check normalized
      if (normalized.contains(normalizedWord)) {
        return true;
      }

      // Also check if the raw word (if short) exists as a whole word
      if (word.length <= 3) {
        final regex = RegExp(
          '\\b${RegExp.escape(word)}\\b',
          caseSensitive: false,
        );
        if (regex.hasMatch(lowerText)) return true;
      }
    }
    return false;
  }

  // ──────────────────────────────────────────────────────────
  //  VALIDATE: use karo post submit karne se pehle
  //  Returns null if clean, error message if dirty
  // ──────────────────────────────────────────────────────────
  String? validate(String text) {
    if (text.trim().isEmpty) {
      return 'Kuch toh likho 😊';
    }
    if (containsProfanity(text)) {
      return 'Yahan sabka dil safe rehta hai — please respectful raho 🙏';
    }
    return null; // clean!
  }
}
