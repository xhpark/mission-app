class ThaiSentenceContent {
  const ThaiSentenceContent({
    required this.id,
    required this.category,
    required this.orderNo,
    required this.koreanText,
    required this.thaiText,
    required this.phonetic,
    required this.hangulPronunciation,
    required this.englishText,
    required this.hint,
    required this.related,
    required this.cultureNote,
    this.audioPath = '',
    this.audioUrl = '',
  });

  final String id;
  final String category;
  final int orderNo;
  final String koreanText;
  final String thaiText;
  final String phonetic;
  final String hangulPronunciation;
  final String englishText;
  final String hint;
  final String related;
  final String cultureNote;
  final String audioPath;
  final String audioUrl;
}

class ThaiWordContent {
  const ThaiWordContent({
    required this.id,
    required this.category,
    required this.orderNo,
    required this.koreanMeaning,
    required this.thaiWord,
    required this.phonetic,
    required this.hangulPronunciation,
    required this.englishMeaning,
    required this.wordType,
    required this.linkedSentenceIds,
    required this.note,
    this.audioPath = '',
    this.audioUrl = '',
  });

  final String id;
  final String category;
  final int orderNo;
  final String koreanMeaning;
  final String thaiWord;
  final String phonetic;
  final String hangulPronunciation;
  final String englishMeaning;
  final String wordType;
  final String linkedSentenceIds;
  final String note;
  final String audioPath;
  final String audioUrl;
}

const thaiSentenceContents = <ThaiSentenceContent>[
  ThaiSentenceContent(
    id: 'THS_D001',
    category: 'daily',
    orderNo: 1,
    koreanText: '\uc548\ub155\ud558\uc138\uc694',
    thaiText:
        '\u0e2a\u0e27\u0e31\u0e2a\u0e14\u0e35 (\u0e04\u0e23\u0e31\u0e1a/\u0e04\u0e48\u0e30)',
    phonetic: 'sa-w\u00e0t-dee (khr\u00e1p/kh\u00e2)',
    hangulPronunciation: '\uc0ac\uc640\ub514 \ud06c\ub78d/\uce74',
    englishText: 'Hello / Hi',
    hint:
        '\u0e2a\u0e27\u0e31\u0e2a\u0e14\u0e35\ub294 \ud0dc\uad6d\uc5b4\uc758 \ub300\ud45c \uc778\uc0ac\ub9d0\uc774\ub2e4. \ub0a8\uc131\uc740 \u0e04\u0e23\u0e31\u0e1a, \uc5ec\uc131\uc740 \u0e04\u0e48\u0e30\ub97c \ubd99\uc774\uba74 \ub354 \uacf5\uc190\ud558\ub2e4.',
    related:
        '\u0e2a\u0e27\u0e31\u0e2a\u0e14\u0e35\u0e04\u0e23\u0e31\u0e1a / \u0e2a\u0e27\u0e31\u0e2a\u0e14\u0e35\u0e04\u0e48\u0e30',
    cultureNote:
        '\ud0dc\uad6d\uc5d0\uc11c\ub294 \ubbf8\uc18c\uc640 \ud568\uaed8 \ub9d0\ud558\uba74 \ub354 \uc790\uc5f0\uc2a4\ub7fd\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_D002',
    category: 'daily',
    orderNo: 2,
    koreanText: '\uc88b\uc740 \uc544\uce68/\uc624\ud6c4/\uc800\ub141',
    thaiText:
        '\u0e2a\u0e27\u0e31\u0e2a\u0e14\u0e35 (\u0e04\u0e23\u0e31\u0e1a/\u0e04\u0e48\u0e30)',
    phonetic: 'sa-w\u00e0t-dee (khr\u00e1p/kh\u00e2)',
    hangulPronunciation: '\uc0ac\uc640\ub514 \ud06c\ub78d/\uce74',
    englishText: 'Good morning / afternoon / evening',
    hint:
        '\ud0dc\uad6d\uc5d0\uc11c\ub294 \uc544\uce68/\uc624\ud6c4/\uc800\ub141\uc744 \uad6c\ubd84\ud574 \ub2e4\ub978 \uc778\uc0ac\ub97c \uc4f0\uae30\ubcf4\ub2e4 \u0e2a\u0e27\u0e31\u0e2a\u0e14\u0e35\ub97c \ud3ed\ub113\uac8c \uc0ac\uc6a9\ud55c\ub2e4.',
    related: '\u0e2a\u0e27\u0e31\u0e2a\u0e14\u0e35',
    cultureNote:
        '\uc601\uc5b4\uc2dd \uc2dc\uac04\ub300 \uc778\uc0ac\ubcf4\ub2e4 \ud604\uc9c0 \uc2b5\uad00\uc744 \uc775\ud788\ub294 \uac83\uc774 \uc911\uc694\ud558\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_D003',
    category: 'daily',
    orderNo: 3,
    koreanText: '\uc815\ub9d0 \uace0\ub9c8\uc6cc!',
    thaiText: '\u0e02\u0e2d\u0e1a\u0e04\u0e38\u0e13\u0e21\u0e32\u0e01',
    phonetic: 'kh\u00f2p-khun m\u00e2ak',
    hangulPronunciation: '\ucf65\ucfe4 \ub9c9',
    englishText: 'Thanks a lot',
    hint:
        '\u0e02\u0e2d\u0e1a\u0e04\u0e38\u0e13 + \u0e21\u0e32\u0e01 \uad6c\uc870\ub85c \'\uc815\ub9d0 \uac10\uc0ac\ud569\ub2c8\ub2e4\'\uc758 \ub290\ub08c\uc744 \uc900\ub2e4.',
    related:
        '\u0e02\u0e2d\u0e1a\u0e04\u0e38\u0e13 / \u0e02\u0e2d\u0e1a\u0e04\u0e38\u0e13\u0e21\u0e32\u0e01',
    cultureNote:
        '\uac10\uc0ac \ud45c\ud604\uc740 \uad00\uacc4 \ud615\uc131\uc5d0 \ub9e4\uc6b0 \uc911\uc694\ud558\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_D004',
    category: 'daily',
    orderNo: 4,
    koreanText: '\ucc9c\ub9cc\uc5d0\uc694',
    thaiText: '\u0e44\u0e21\u0e48\u0e40\u0e1b\u0e47\u0e19\u0e44\u0e23',
    phonetic: 'm\u00e2i pen rai',
    hangulPronunciation: '\ub9c8\uc774 \ud39c \ub77c\uc774',
    englishText: 'You are welcome',
    hint:
        '\u0e44\u0e21\u0e48\u0e40\u0e1b\u0e47\u0e19\u0e44\u0e23\ub294 \'\ucc9c\ub9cc\uc5d0\uc694\', \'\uad1c\ucc2e\uc544\uc694\', \'\uc2e0\uacbd \uc4f0\uc9c0 \ub9c8\uc138\uc694\'\ub97c \ub113\uac8c \ud3ec\uad04\ud55c\ub2e4.',
    related: '\u0e44\u0e21\u0e48\u0e40\u0e1b\u0e47\u0e19\u0e44\u0e23',
    cultureNote:
        '\uc9e7\uace0 \uc790\uc8fc \uc4f0\uc5ec \uc6b0\uc120 \uc554\uae30 \uac00\uce58\uac00 \ub192\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_D005',
    category: 'daily',
    orderNo: 5,
    koreanText: '\uc608',
    thaiText: '\u0e43\u0e0a\u0e48',
    phonetic: 'ch\u00e2i',
    hangulPronunciation: '\ucc28\uc774',
    englishText: 'Yes',
    hint:
        '\u0e43\u0e0a\u0e48\ub294 \'\uc608, \ub9de\uc544\uc694\'\uc758 \ub73b\uc73c\ub85c \uc0ac\uc6a9\ub41c\ub2e4.',
    related:
        '\u0e43\u0e0a\u0e48\u0e04\u0e23\u0e31\u0e1a / \u0e43\u0e0a\u0e48\u0e04\u0e48\u0e30',
    cultureNote:
        '\ub2e8\ub2f5\ud615 \ub300\ub2f5\uc5d0\ub3c4 \uacf5\uc190 \ud45c\ud604\uc744 \ubd99\uc774\uba74 \ub354 \uc790\uc5f0\uc2a4\ub7fd\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_D006',
    category: 'daily',
    orderNo: 6,
    koreanText: '\uc544\ub2c8\uc624',
    thaiText:
        '\u0e44\u0e21\u0e48\u0e43\u0e0a\u0e48 (\u0e04\u0e23\u0e31\u0e1a/\u0e04\u0e48\u0e30)',
    phonetic: 'm\u00e2i ch\u00e2i (khr\u00e1p/kh\u00e2)',
    hangulPronunciation: '\ub9c8\uc774\ucc28\uc774 \ud06c\ub78d/\uce74',
    englishText: 'No',
    hint:
        '\u0e44\u0e21\u0e48\u0e43\u0e0a\u0e48\ub294 \'\uc544\ub2c8\uc624/\uc544\ub2c8\uc5d0\uc694\'\uc5d0 \uac00\uae5d\ub2e4.',
    related:
        '\u0e44\u0e21\u0e48\u0e43\u0e0a\u0e48\u0e04\u0e23\u0e31\u0e1a / \u0e44\u0e21\u0e48\u0e43\u0e0a\u0e48\u0e04\u0e48\u0e30',
    cultureNote:
        '\ubd80\uc815 \ub300\ub2f5\uc740 \ubd80\ub4dc\ub7ec\uc6b4 \ud45c\uc815\u00b7\uc5b5\uc591\uc774 \uc911\uc694\ud558\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_D007',
    category: 'daily',
    orderNo: 7,
    koreanText: '\uc2e4\ub840(\uc8c4\uc1a1)\ud569\ub2c8\ub2e4',
    thaiText: '\u0e02\u0e2d\u0e42\u0e17\u0e29',
    phonetic: 'kh\u01d2r-th\u00f4at',
    hangulPronunciation: '\ucee4\ud1b3',
    englishText: 'Excuse me / Sorry',
    hint:
        '\u0e02\u0e2d\u0e42\u0e17\u0e29\ub294 \uc2e4\ub840/\uc8c4\uc1a1\ud569\ub2c8\ub2e4\uc5d0 \ud574\ub2f9\ud558\ub294 \ud575\uc2ec \ud45c\ud604\uc774\ub2e4.',
    related:
        '\u0e02\u0e2d\u0e42\u0e17\u0e29\u0e04\u0e23\u0e31\u0e1a / \u0e02\u0e2d\u0e42\u0e17\u0e29\u0e04\u0e48\u0e30',
    cultureNote:
        '\uae38\uc744 \ubb3c\uc744 \ub54c\ub098 \uc0ac\ub78c\uc744 \uc9c0\ub098\uce60 \ub54c\ub3c4 \uc720\uc6a9\ud558\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_D008',
    category: 'daily',
    orderNo: 8,
    koreanText: '\uad1c\ucc2e\uc544\uc694',
    thaiText: '\u0e44\u0e21\u0e48\u0e40\u0e1b\u0e47\u0e19\u0e44\u0e23',
    phonetic: 'm\u00e2i pen rai',
    hangulPronunciation: '\ub9c8\uc774 \ud39c \ub77c\uc774',
    englishText: 'It\'s okay',
    hint:
        '\u0e44\u0e21\u0e48\u0e40\u0e1b\u0e47\u0e19\u0e44\u0e23\ub294 \uc0c1\ub300\ub97c \uc548\uc2ec\uc2dc\ud0a4\ub294 \ud45c\ud604\uc73c\ub85c \uc790\uc8fc \uc4f0\uc778\ub2e4.',
    related: '\u0e44\u0e21\u0e48\u0e40\u0e1b\u0e47\u0e19\u0e44\u0e23',
    cultureNote:
        '\uac10\uc0ac \uc751\ub2f5\uacfc \uc0ac\uacfc \uc751\ub2f5 \ub458 \ub2e4 \uac00\ub2a5\ud558\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_D009',
    category: 'daily',
    orderNo: 9,
    koreanText: '\uc798 \uac00\uc694',
    thaiText: '\u0e25\u0e32\u0e01\u0e48\u0e2d\u0e19',
    phonetic: 'laa-k\u00f2rn',
    hangulPronunciation: '\ub77c\uaec0',
    englishText: 'Goodbye',
    hint:
        '\u0e25\u0e32\u0e01\u0e48\u0e2d\u0e19\uc740 \ud5e4\uc5b4\uc9c8 \ub54c \uc4f0\ub294 \uae30\ubcf8 \uc791\ubcc4 \uc778\uc0ac\ub2e4.',
    related: '\u0e25\u0e32\u0e01\u0e48\u0e2d\u0e19',
    cultureNote:
        '\ub2e4\uc2dc \ubcfc \uac00\ub2a5\uc131\uc774 \ub192\uc73c\uba74 \'\u0e41\u0e25\u0e49\u0e27\u0e1e\u0e1a\u0e01\u0e31\u0e19\u0e43\u0e2b\u0e21\u0e48\'\uac00 \ub354 \ub530\ub73b\ud558\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_D010',
    category: 'daily',
    orderNo: 10,
    koreanText: '\ub2e4\uc2dc \ub9cc\ub098\uc694',
    thaiText:
        '\u0e41\u0e25\u0e49\u0e27\u0e1e\u0e1a\u0e01\u0e31\u0e19\u0e43\u0e2b\u0e21\u0e48',
    phonetic: 'l\u00e1ew-ph\u00f3p-kan-m\u00e0i',
    hangulPronunciation: '\ub798\uc6b0 \ud3fd \uae50 \ub9c8\uc774',
    englishText: 'See you again',
    hint:
        '\u0e41\u0e25\u0e49\u0e27\u0e1e\u0e1a\u0e01\u0e31\u0e19\u0e43\u0e2b\u0e21\u0e48\ub294 \'\ub2e4\uc2dc \ub9cc\ub098\uc694\'\uc5d0 \ud574\ub2f9\ud55c\ub2e4.',
    related:
        '\u0e41\u0e25\u0e49\u0e27\u0e1e\u0e1a\u0e01\u0e31\u0e19\u0e43\u0e2b\u0e21\u0e48',
    cultureNote:
        '\uae0d\uc815\uc801\uc73c\ub85c \ub300\ud654\ub97c \ub9c8\ubb34\ub9ac\ud558\ub294 \ud45c\ud604\uc774\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_D011',
    category: 'daily',
    orderNo: 11,
    koreanText: '\uc774\ub984\uc774 \ubb34\uc5c7\uc778\uac00\uc694?',
    thaiText:
        '\u0e04\u0e38\u0e13\u0e0a\u0e37\u0e48\u0e2d\u0e2d\u0e30\u0e44\u0e23?',
    phonetic: 'khun chue-a-rai?',
    hangulPronunciation: '\ucfe4 \uce20 \uc544\ub77c\uc774',
    englishText: 'What\'s your name?',
    hint:
        '\u0e04\u0e38\u0e13\u0e0a\u0e37\u0e48\u0e2d\u0e2d\u0e30\u0e44\u0e23?\ub294 \uac00\uc7a5 \uae30\ubcf8\uc801\uc778 \uc790\uae30\uc18c\uac1c \uc9c8\ubb38\uc774\ub2e4.',
    related:
        '\u0e09\u0e31\u0e19\u0e0a\u0e37\u0e48\u0e2d... / \u0e1c\u0e21\u0e0a\u0e37\u0e48\u0e2d...',
    cultureNote:
        '\ucc98\uc74c \ub9cc\ub0a8\uc5d0\uc11c \uc720\uc6a9\ud558\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_D012',
    category: 'daily',
    orderNo: 12,
    koreanText: '\uba87 \uc0b4\uc785\ub2c8\uae4c?',
    thaiText:
        '\u0e04\u0e38\u0e13\u0e2d\u0e32\u0e22\u0e38\u0e40\u0e17\u0e48\u0e32\u0e44\u0e2b\u0e23\u0e48?',
    phonetic: 'khun aa-y\u00fa th\u00e2o-r\u00e0i?',
    hangulPronunciation: '\ucfe4 \uc544\uc720 \ud0c0\uc624\ub77c\uc774',
    englishText: 'How old are you?',
    hint:
        '\u0e04\u0e38\u0e13\u0e2d\u0e32\u0e22\u0e38\u0e40\u0e17\u0e48\u0e32\u0e44\u0e2b\u0e23\u0e48?\ub294 \uc9c1\uc5ed\ud558\uba74 \'\uba87 \uc0b4\uc785\ub2c8\uae4c?\'\uc774\ub2e4.',
    related: '\u0e2d\u0e32\u0e22\u0e38',
    cultureNote:
        '\uc0c1\ub300\uc5d0 \ub530\ub77c \ub098\uc774\ub97c \uc9c1\uc811 \ubb3b\ub294 \uac83\uc774 \uc870\uc2ec\uc2a4\ub7ec\uc6b8 \uc218 \uc788\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_D013',
    category: 'daily',
    orderNo: 13,
    koreanText: '\ub9db\uc788\uac8c \ub4dc\uc138\uc694',
    thaiText:
        '\u0e17\u0e32\u0e19\u0e43\u0e2b\u0e49\u0e2d\u0e23\u0e48\u0e2d\u0e22\u0e19\u0e30',
    phonetic: 'thaan-h\u00e2i-a-r\u00f2y-n\u00e1',
    hangulPronunciation: '\ud0c4 \ud558\uc774 \uc544\ub7ec\uc774 \ub098',
    englishText: 'Enjoy your meal',
    hint:
        '\u0e17\u0e32\u0e19\u0e43\u0e2b\u0e49\u0e2d\u0e23\u0e48\u0e2d\u0e22\u0e19\u0e30\ub294 \'\ub9db\uc788\uac8c \ub4dc\uc138\uc694\'\uc5d0 \ud574\ub2f9\ud55c\ub2e4.',
    related: '\u0e2d\u0e23\u0e48\u0e2d\u0e22 / \u0e17\u0e32\u0e19',
    cultureNote:
        '\uc2dd\uc0ac \uc790\ub9ac\uc5d0\uc11c \uce5c\uadfc\ud558\uac8c \uc4f0\ub294 \ud45c\ud604\uc774\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_D014',
    category: 'daily',
    orderNo: 14,
    koreanText: '\uc815\ub9d0 \ub9db\uc788\uc5b4\uc694',
    thaiText:
        '\u0e2d\u0e23\u0e48\u0e2d\u0e22\u0e21\u0e32\u0e01\u0e08\u0e23\u0e34\u0e07\u0e46',
    phonetic: 'a-r\u00f2y-m\u00e2ak-jing-jing',
    hangulPronunciation: '\uc544\ub7ec\uc774 \ub9c9 \ucc21\ucc21',
    englishText: 'It\'s really delicious',
    hint:
        '\u0e2d\u0e23\u0e48\u0e2d\u0e22\u0e21\u0e32\u0e01\u0e08\u0e23\u0e34\u0e07\u0e46\ub294 \'\uc815\ub9d0 \ub9db\uc788\uc5b4\uc694\'\ub77c\ub294 \uac15\ud55c \uce6d\ucc2c\uc774\ub2e4.',
    related: '\u0e2d\u0e23\u0e48\u0e2d\u0e22\u0e21\u0e32\u0e01',
    cultureNote:
        '\uc74c\uc2dd\uc744 \ub300\uc811\ubc1b\uc558\uc744 \ub54c \ud638\uac10 \ud615\uc131\uc5d0 \uc88b\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_D015',
    category: 'daily',
    orderNo: 15,
    koreanText: '\ub2f9\uc2e0\uc774 \ucd5c\uace0\uc785\ub2c8\ub2e4',
    thaiText:
        '\u0e04\u0e38\u0e13\u0e22\u0e2d\u0e14\u0e40\u0e22\u0e35\u0e48\u0e22\u0e21\u0e17\u0e35\u0e48\u0e2a\u0e38\u0e14',
    phonetic: 'khun y\u00f4at-y\u00eeam th\u00eei-s\u00f9t',
    hangulPronunciation: '\ucfe4 \uc694\uc5ff \uc774\uc554 \ud2f0\uc22b',
    englishText: 'You are the best',
    hint:
        '\u0e04\u0e38\u0e13\u0e22\u0e2d\u0e14\u0e40\u0e22\u0e35\u0e48\u0e22\u0e21\u0e17\u0e35\u0e48\u0e2a\u0e38\u0e14\ub294 \'\ub2f9\uc2e0\uc774 \ucd5c\uace0\uc785\ub2c8\ub2e4\'\ub77c\ub294 \uac15\ud55c \uce6d\ucc2c\uc774\ub2e4.',
    related: '\u0e22\u0e2d\u0e14\u0e40\u0e22\u0e35\u0e48\u0e22\u0e21',
    cultureNote:
        '\uaca9\ub824 \ud45c\ud604\uc73c\ub85c \ud65c\uc6a9 \uac00\ub2a5\ud558\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_M001',
    category: 'mission',
    orderNo: 1,
    koreanText:
        '\uc608\uc218\ub2d8\uc774 \ub2f9\uc2e0\uc744 \uc0ac\ub791\ud574\uc694',
    thaiText:
        '\u0e1e\u0e23\u0e30\u0e40\u0e22\u0e0b\u0e39\u0e23\u0e31\u0e01\u0e04\u0e38\u0e13',
    phonetic: 'phr\u00e1-y\u00ea-soo r\u00e1k khun',
    hangulPronunciation: '\ud504\ub77c \uc608\uc218 \ub77d \ucfe4',
    englishText: 'Jesus loves you',
    hint:
        '\uc608\uc218\ub2d8\uc758 \uc0ac\ub791\uc744 \uc9c1\uc811 \uc804\ub2ec\ud558\ub294 \uac00\uc7a5 \uae30\ubcf8\uc801\uc778 \uc120\uad50 \ubb38\uc7a5\uc774\ub2e4.',
    related:
        '\u0e1e\u0e23\u0e30\u0e40\u0e22\u0e0b\u0e39\u0e23\u0e31\u0e01\u0e04\u0e38\u0e13',
    cultureNote:
        '\ucc98\uc74c \uc778\uc0ac \ud6c4 \uc790\uc5f0\uc2a4\ub7fd\uac8c \uc5f0\uacb0\ud558\uae30 \uc88b\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_M002',
    category: 'mission',
    orderNo: 2,
    koreanText:
        '\ud558\ub098\ub2d8\uc774 \ub2f9\uc2e0\uc744 \uc0ac\ub791\ud574\uc694',
    thaiText:
        '\u0e1e\u0e23\u0e30\u0e40\u0e08\u0e49\u0e32\u0e17\u0e23\u0e07\u0e23\u0e31\u0e01\u0e04\u0e38\u0e13',
    phonetic: 'phr\u00e1-ch\u00e2o song r\u00e1k khun',
    hangulPronunciation: '\ud504\ub77c\uc9dc\uc624 \uc1a1 \ub77d \ucfe4',
    englishText: 'God loves you',
    hint:
        '\u0e1e\u0e23\u0e30\u0e40\u0e08\u0e49\u0e32\ub294 \ud558\ub098\ub2d8\uc744 \uc758\ubbf8\ud558\ub294 \uacf5\uc2dd \ud45c\ud604\uc774\ub2e4.',
    related:
        '\u0e1e\u0e23\u0e30\u0e40\u0e08\u0e49\u0e32\u0e17\u0e23\u0e07\u0e23\u0e31\u0e01\u0e04\u0e38\u0e13',
    cultureNote:
        '\ubd88\uad50 \ubb38\ud654\uad8c\uc5d0\uc11c\ub294 \uc2e0 \uac1c\ub150 \uc124\uba85\uc774 \ud544\uc694\ud560 \uc218 \uc788\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_M003',
    category: 'mission',
    orderNo: 3,
    koreanText: '\ud558\ub098\ub2d8\uc758 \ucd95\ubcf5\uc744!',
    thaiText:
        '\u0e02\u0e2d\u0e1e\u0e23\u0e30\u0e40\u0e08\u0e49\u0e32\u0e2d\u0e27\u0e22\u0e1e\u0e23',
    phonetic: 'kh\u01d2r phr\u00e1-ch\u00e2o uay-phorn',
    hangulPronunciation:
        '\ucee4 \ud504\ub77c\uc9dc\uc624 \uc6b0\uc544\uc774\ud3f0',
    englishText: 'God bless you',
    hint:
        '\uc9e7\uace0 \uac15\ud55c \ucd95\ubcf5 \ubb38\uc7a5\uc73c\ub85c \uaca9\ub824\uc640 \ub9c8\ubb34\ub9ac\uc5d0 \uc88b\ub2e4.',
    related:
        '\u0e02\u0e2d\u0e1e\u0e23\u0e30\u0e40\u0e08\u0e49\u0e32\u0e2d\u0e27\u0e22\u0e1e\u0e23',
    cultureNote:
        '\uae30\ub3c4 \ud6c4 \ub9c8\ubb34\ub9ac \ud45c\ud604\uc73c\ub85c \uc88b\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_M004',
    category: 'mission',
    orderNo: 4,
    koreanText: '\ud558\ub098\ub2d8\uc740 \uc0ac\ub791\uc774\uc2ed\ub2c8\ub2e4',
    thaiText:
        '\u0e1e\u0e23\u0e30\u0e40\u0e08\u0e49\u0e32\u0e04\u0e37\u0e2d\u0e04\u0e27\u0e32\u0e21\u0e23\u0e31\u0e01',
    phonetic: 'phr\u00e1-ch\u00e2o khue kwaam-r\u00e1k',
    hangulPronunciation: '\ud504\ub77c\uc9dc\uc624 \ud06c \ucf70\uc554\ub77d',
    englishText: 'God is love',
    hint:
        '\ubcf5\uc74c\uc758 \ud575\uc2ec \uac1c\ub150\uc744 \ub9e4\uc6b0 \uac04\ub2e8\ud558\uac8c \uc804\ub2ec\ud558\ub294 \ubb38\uc7a5\uc774\ub2e4.',
    related:
        '\u0e1e\u0e23\u0e30\u0e40\u0e08\u0e49\u0e32\u0e04\u0e37\u0e2d\u0e04\u0e27\u0e32\u0e21\u0e23\u0e31\u0e01',
    cultureNote:
        '\uc124\uba85\ud615 \ubcf5\uc74c \ubb38\uc7a5\uc73c\ub85c \uc801\ud569\ud558\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_M005',
    category: 'mission',
    orderNo: 5,
    koreanText: '\uc608\uc218\ub2d8 \ubbff\uc73c\uc138\uc694',
    thaiText:
        '\u0e40\u0e0a\u0e37\u0e48\u0e2d\u0e43\u0e19\u0e1e\u0e23\u0e30\u0e40\u0e22\u0e0b\u0e39\u0e40\u0e16\u0e2d\u0e30',
    phonetic: 'chuea nai phr\u00e1-y\u00ea-soo thuh',
    hangulPronunciation:
        '\uce20\uc544 \ub098\uc774 \ud504\ub77c \uc608\uc218 \ud130',
    englishText: 'Believe in Jesus',
    hint:
        '\ubd80\ub4dc\ub7ec\uc6b4 \uad8c\uc720\ud615 \uc120\uad50 \ubb38\uc7a5\uc774\ub2e4.',
    related:
        '\u0e40\u0e0a\u0e37\u0e48\u0e2d\u0e43\u0e19\u0e1e\u0e23\u0e30\u0e40\u0e22\u0e0b\u0e39\u0e40\u0e16\u0e2d\u0e30',
    cultureNote:
        '\uac15\uc694\ubcf4\ub2e4 \ucd08\uccad\uc758 \ud1a4\uc73c\ub85c \uc0ac\uc6a9\ud55c\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_M006',
    category: 'mission',
    orderNo: 6,
    koreanText:
        '\uc6b0\ub9ac\ub294 \ub2f9\uc2e0\ub4e4\uc744 \uc0ac\ub791\ud574\uc694',
    thaiText:
        '\u0e1e\u0e27\u0e01\u0e40\u0e23\u0e32\u0e23\u0e31\u0e01\u0e04\u0e38\u0e13',
    phonetic: 'phuak-rao r\u00e1k khun',
    hangulPronunciation: '\ud478\uc545\ub77c\uc624 \ub77d \ucfe4',
    englishText: 'We love you',
    hint:
        '\uad00\uacc4 \ud615\uc131\uacfc \ud300\uc758 \ub530\ub73b\ud568\uc744 \uc804\ud558\ub294 \ubb38\uc7a5\uc774\ub2e4.',
    related:
        '\u0e1e\u0e27\u0e01\u0e40\u0e23\u0e32\u0e23\u0e31\u0e01\u0e04\u0e38\u0e13',
    cultureNote:
        '\ubcf5\uc74c \uc804 \ub300\ud654 \ubd84\uc704\uae30\ub97c \ubd80\ub4dc\ub7fd\uac8c \ub9cc\ub4e0\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_M007',
    category: 'mission',
    orderNo: 7,
    koreanText: '\uc608\uc218\ub2d8 \uc544\uc138\uc694?',
    thaiText:
        '\u0e04\u0e38\u0e13\u0e23\u0e39\u0e49\u0e08\u0e31\u0e01\u0e1e\u0e23\u0e30\u0e40\u0e22\u0e0b\u0e39\u0e44\u0e2b\u0e21',
    phonetic: 'khun r\u00fau-j\u00e0k phr\u00e1-y\u00ea-soo m\u00e1i',
    hangulPronunciation:
        '\ucfe4 \ub8e8\uc9dd \ud504\ub77c \uc608\uc218 \ub9c8\uc774',
    englishText: 'Do you know Jesus?',
    hint:
        '\ubcf5\uc74c\uc744 \uc804\ud558\uae30 \uc804\uc5d0 \uc790\uc5f0\uc2a4\ub7fd\uac8c \ub300\ud654\ub97c \uc2dc\uc791\ud558\ub294 \uc9c8\ubb38\uc774\ub2e4.',
    related:
        '\u0e04\u0e38\u0e13\u0e23\u0e39\u0e49\u0e08\u0e31\u0e01\u0e1e\u0e23\u0e30\u0e40\u0e22\u0e0b\u0e39\u0e44\u0e2b\u0e21',
    cultureNote:
        '\uc9c1\uc811\uc801\uc778 \uc9c8\ubb38\uc774\uc9c0\ub9cc \ubd80\ub4dc\ub7ec\uc6b4 \ud1a4\uc774 \uc911\uc694\ud558\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_M008',
    category: 'mission',
    orderNo: 8,
    koreanText: '\uad50\ud68c \uac00\ubcf4\uc168\uc5b4\uc694?',
    thaiText:
        '\u0e04\u0e38\u0e13\u0e40\u0e04\u0e22\u0e44\u0e1b\u0e42\u0e1a\u0e2a\u0e16\u0e4c\u0e44\u0e2b\u0e21',
    phonetic: 'khun khoei bpai b\u00f2ht m\u00e1i',
    hangulPronunciation:
        '\ucfe4 \ucee4\uc774 \ube60\uc774 \ubcf4\ud2b8 \ub9c8\uc774',
    englishText: 'Have you been to church?',
    hint:
        '\uc0c1\ub300\uc758 \uc2e0\uc559 \uacbd\ud5d8\uc744 \ud655\uc778\ud558\ub294 \uc9c8\ubb38\uc774\ub2e4.',
    related:
        '\u0e04\u0e38\u0e13\u0e40\u0e04\u0e22\u0e44\u0e1b\u0e42\u0e1a\u0e2a\u0e16\u0e4c\u0e44\u0e2b\u0e21',
    cultureNote:
        '\uac15\uc694 \ub290\ub08c \uc5c6\uc774 \uc790\uc5f0\uc2a4\ub7fd\uac8c \uc0ac\uc6a9\ud55c\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_M009',
    category: 'mission',
    orderNo: 9,
    koreanText: '\uae30\ub3c4\ud574 \ub4dc\ub9b4\uac8c\uc694',
    thaiText:
        '\u0e1c\u0e21\u0e08\u0e30\u0e2d\u0e18\u0e34\u0e29\u0e10\u0e32\u0e19\u0e43\u0e2b\u0e49\u0e04\u0e38\u0e13',
    phonetic: 'ph\u01d2m j\u00e0 \u00e0-th\u00edt-thaan h\u00e2i khun',
    hangulPronunciation: '\ud3fc \uc9dc \uc544\ud303\ud0c4 \ud558\uc774 \ucfe4',
    englishText: 'I will pray for you',
    hint:
        '\uc120\uad50 \ud604\uc7a5\uc5d0\uc11c \ub9e4\uc6b0 \ud6a8\uacfc\uc801\uc778 \uc811\uadfc \ubb38\uc7a5\uc774\ub2e4.',
    related:
        '\u0e1c\u0e21\u0e08\u0e30\u0e2d\u0e18\u0e34\u0e29\u0e10\u0e32\u0e19\u0e43\u0e2b\u0e49\u0e04\u0e38\u0e13',
    cultureNote:
        '\uc2e4\uc81c \uc0c1\ud669\uc5d0\uc11c \uad00\uacc4 \ud615\uc131\uc5d0 \uac15\ud55c \ubb38\uc7a5\uc774\ub2e4.',
  ),
  ThaiSentenceContent(
    id: 'THS_M010',
    category: 'mission',
    orderNo: 10,
    koreanText: '\ud568\uaed8 \ucc2c\uc591\ud569\uc2dc\ub2e4',
    thaiText:
        '\u0e21\u0e32\u0e23\u0e49\u0e2d\u0e07\u0e40\u0e1e\u0e25\u0e07\u0e01\u0e31\u0e19',
    phonetic: 'maa-r\u0254\u0301\u0254ng-phleeng-kan',
    hangulPronunciation: '\ub9c8 \ub871 \ud50c\ub81d \uae50',
    englishText: 'Let\'s sing together / Let\'s praise together',
    hint:
        '\uc9e7\uace0 \uc678\uc6b0\uae30 \uc26c\uc6b4 \ud604\uc7a5\ud615 \ucc2c\uc591 \ucd08\uccad \ubb38\uc7a5\uc774\ub2e4.',
    related:
        '\u0e21\u0e32\u0e23\u0e49\u0e2d\u0e07\u0e40\u0e1e\u0e25\u0e07\u0e01\u0e31\u0e19',
    cultureNote:
        '\uc608\ubc30 \uc804\ud658\uc774\ub098 \ubd84\uc704\uae30 \uc804\ud658\uc5d0 \uc720\uc6a9\ud558\ub2e4.',
  ),
];

const thaiWordContents = <ThaiWordContent>[
  ThaiWordContent(
    id: 'THW_D001',
    category: 'daily',
    orderNo: 1,
    koreanMeaning: '(\ub0a8\uc131 \ud654\uc790) \uacf5\uc190 \ud45c\ud604',
    thaiWord: '\u0e04\u0e23\u0e31\u0e1a',
    phonetic: 'khr\xe1p',
    hangulPronunciation: '\ud06c\ub78d',
    englishMeaning: 'male polite particle',
    wordType: 'particle',
    linkedSentenceIds: 'THS_D001, THS_D002, THS_D006',
    note: '\uacf5\uc190 \ud45c\ud604',
  ),
  ThaiWordContent(
    id: 'THW_D002',
    category: 'daily',
    orderNo: 2,
    koreanMeaning: '(\uc5ec\uc131 \ud654\uc790) \uacf5\uc190 \ud45c\ud604',
    thaiWord: '\u0e04\u0e48\u0e30',
    phonetic: 'kh\xe2',
    hangulPronunciation: '\uce74',
    englishMeaning: 'female polite particle',
    wordType: 'particle',
    linkedSentenceIds: 'THS_D001, THS_D002, THS_D006',
    note: '\uacf5\uc190 \ud45c\ud604',
  ),
  ThaiWordContent(
    id: 'THW_D003',
    category: 'daily',
    orderNo: 3,
    koreanMeaning: '\ub9e4\uc6b0, \ub9ce\uc774',
    thaiWord: '\u0e21\u0e32\u0e01',
    phonetic: 'm\xe2ak',
    hangulPronunciation: '\ub9c9',
    englishMeaning: 'very, much',
    wordType: 'word',
    linkedSentenceIds: 'THS_D003, THS_D014',
    note: '\uac15\uc870 \ud45c\ud604',
  ),
  ThaiWordContent(
    id: 'THW_D004',
    category: 'daily',
    orderNo: 4,
    koreanMeaning: '\ubb34\uc5c7',
    thaiWord: '\u0e44\u0e23',
    phonetic: 'rai',
    hangulPronunciation: '\ub77c\uc774',
    englishMeaning: '',
    wordType: 'word',
    linkedSentenceIds: 'THS_D004, THS_D008',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_D005',
    category: 'daily',
    orderNo: 5,
    koreanMeaning: '\uc608, \ub9de\uc544\uc694',
    thaiWord: '\u0e43\u0e0a\u0e48',
    phonetic: 'ch\xe2i',
    hangulPronunciation: '\ucc28\uc774',
    englishMeaning: 'yes',
    wordType: 'word',
    linkedSentenceIds: 'THS_D005',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_D006',
    category: 'daily',
    orderNo: 6,
    koreanMeaning: '\uc544\ub2c8\uc624, \uc544\ub2c8\uc5d0\uc694',
    thaiWord: '\u0e44\u0e21\u0e48\u0e43\u0e0a\u0e48',
    phonetic: 'm\xe2i ch\xe2i',
    hangulPronunciation: '\ub9c8\uc774 \ucc28\uc774',
    englishMeaning: 'no / not',
    wordType: 'expression',
    linkedSentenceIds: 'THS_D006',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_D007',
    category: 'daily',
    orderNo: 7,
    koreanMeaning: '\uc8c4\uc1a1\ud569\ub2c8\ub2e4, \uc2e4\ub840\ud569\ub2c8\ub2e4',
    thaiWord: '\u0e02\u0e2d\u0e42\u0e17\u0e29',
    phonetic: 'kh\u01d2r-th\xf4at',
    hangulPronunciation: '\ucee4\ud1b3',
    englishMeaning: 'sorry / excuse me',
    wordType: 'word',
    linkedSentenceIds: 'THS_D007',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_D008',
    category: 'daily',
    orderNo: 8,
    koreanMeaning: '\uc798 \uac00\uc694',
    thaiWord: '\u0e25\u0e32\u0e01\u0e48\u0e2d\u0e19',
    phonetic: 'laa-k\xf2rn',
    hangulPronunciation: '\ub77c\uaec0',
    englishMeaning: 'goodbye',
    wordType: 'word',
    linkedSentenceIds: 'THS_D009',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_D009',
    category: 'daily',
    orderNo: 9,
    koreanMeaning: '\uadf8\ub7fc',
    thaiWord: '\u0e41\u0e25\u0e49\u0e27',
    phonetic: 'l\xe1ew',
    hangulPronunciation: '\ub798\uc6b0',
    englishMeaning: 'see you again',
    wordType: 'expression',
    linkedSentenceIds: 'THS_D010',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_D010',
    category: 'daily',
    orderNo: 10,
    koreanMeaning: '\ub2f9\uc2e0',
    thaiWord: '\u0e04\u0e38\u0e13',
    phonetic: 'khun',
    hangulPronunciation: '\ucfe4',
    englishMeaning: 'you',
    wordType: 'word',
    linkedSentenceIds: 'THS_D011, THS_D012, THS_D015',
    note: '\ub192\uc784 \ud638\uce6d',
  ),
  ThaiWordContent(
    id: 'THW_D011',
    category: 'daily',
    orderNo: 11,
    koreanMeaning: '\uc774\ub984',
    thaiWord: '\u0e0a\u0e37\u0e48\u0e2d',
    phonetic: 'ch\u0289\u0302\u0289',
    hangulPronunciation: '\uce20',
    englishMeaning: 'name',
    wordType: 'word',
    linkedSentenceIds: 'THS_D011',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_D012',
    category: 'daily',
    orderNo: 12,
    koreanMeaning: '\ubb34\uc5c7',
    thaiWord: '\u0e2d\u0e30\u0e44\u0e23',
    phonetic: 'a-rai',
    hangulPronunciation: '\uc544\ub77c\uc774',
    englishMeaning: 'what',
    wordType: 'word',
    linkedSentenceIds: 'THS_D011',
    note: '\uc758\ubb38\uc0ac',
  ),
  ThaiWordContent(
    id: 'THW_D013',
    category: 'daily',
    orderNo: 13,
    koreanMeaning: '\ub098\uc774',
    thaiWord: '\u0e2d\u0e32\u0e22\u0e38',
    phonetic: 'aa-y\xfa',
    hangulPronunciation: '\uc544\uc720',
    englishMeaning: 'age',
    wordType: 'word',
    linkedSentenceIds: 'THS_D012',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_D014',
    category: 'daily',
    orderNo: 14,
    koreanMeaning: '\uc5bc\ub9c8, \uba87',
    thaiWord: '\u0e40\u0e17\u0e48\u0e32\u0e44\u0e2b\u0e23\u0e48',
    phonetic: 'th\xe2o-r\xe0i',
    hangulPronunciation: '\ud0c0\uc624\ub77c\uc774',
    englishMeaning: 'how much / how many',
    wordType: 'word',
    linkedSentenceIds: 'THS_D012',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_D015',
    category: 'daily',
    orderNo: 15,
    koreanMeaning: '\uba39\ub2e4, \ub4dc\uc2dc\ub2e4',
    thaiWord: '\u0e17\u0e32\u0e19',
    phonetic: 'thaan',
    hangulPronunciation: '\ud0c4',
    englishMeaning: 'eat',
    wordType: 'word',
    linkedSentenceIds: 'THS_D013',
    note: '\uacf5\uc190\ud55c \uc2dd\uc0ac \ud45c\ud604',
  ),
  ThaiWordContent(
    id: 'THW_D016',
    category: 'daily',
    orderNo: 16,
    koreanMeaning: '\ub9db\uc788\ub2e4',
    thaiWord: '\u0e2d\u0e23\u0e48\u0e2d\u0e22',
    phonetic: 'a-r\xf2i',
    hangulPronunciation: '\uc544\ub7ec\uc774',
    englishMeaning: 'delicious',
    wordType: 'word',
    linkedSentenceIds: 'THS_D013, THS_D014',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_D017',
    category: 'daily',
    orderNo: 17,
    koreanMeaning: '\ubd80\ub4dc\ub7ec\uc6b4 \uad8c\uc720/\uc644\ud654 \uc5b4\ubbf8',
    thaiWord: '\u0e19\u0e30',
    phonetic: 'n\xe1',
    hangulPronunciation: '\ub098',
    englishMeaning: 'softening particle',
    wordType: 'particle',
    linkedSentenceIds: 'THS_D013',
    note: '\uce5c\uadfc\ud55c \uc5b4\uc870',
  ),
  ThaiWordContent(
    id: 'THW_D018',
    category: 'daily',
    orderNo: 18,
    koreanMeaning: '\uc815\ub9d0, \uc9c4\uc9dc',
    thaiWord: '\u0e08\u0e23\u0e34\u0e07\u0e46',
    phonetic: 'jing-jing',
    hangulPronunciation: '\ucc21\ucc21',
    englishMeaning: 'really',
    wordType: 'word',
    linkedSentenceIds: 'THS_D014',
    note: '\uac15\uc870 \ud45c\ud604',
  ),
  ThaiWordContent(
    id: 'THW_D019',
    category: 'daily',
    orderNo: 19,
    koreanMeaning: '\uc815\uc810, \ucd5c\uace0',
    thaiWord: '\u0e22\u0e2d\u0e14',
    phonetic: 'y\xf4at',
    hangulPronunciation: '\uc694\uc5ff',
    englishMeaning: 'excellent',
    wordType: 'word',
    linkedSentenceIds: 'THS_D015',
    note: '\uce6d\ucc2c',
  ),
  ThaiWordContent(
    id: 'THW_D020',
    category: 'daily',
    orderNo: 20,
    koreanMeaning: '\uac00\uc7a5, \ucd5c\uace0\ub85c',
    thaiWord: '\u0e17\u0e35\u0e48\u0e2a\u0e38\u0e14',
    phonetic: 'th\xeei-s\xf9t',
    hangulPronunciation: '\ud2f0\uc22b',
    englishMeaning: 'the most / best',
    wordType: 'word',
    linkedSentenceIds: 'THS_D015',
    note: '\ucd5c\uc0c1\uae09',
  ),
  ThaiWordContent(
    id: 'THW_D021',
    category: 'daily',
    orderNo: 21,
    koreanMeaning: '\uc544\ub2c8\ub2e4',
    thaiWord: '\u0e44\u0e21\u0e48',
    phonetic: 'm\xe2i',
    hangulPronunciation: '\ub9c8\uc774',
    englishMeaning: '',
    wordType: 'word',
    linkedSentenceIds: '',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_D022',
    category: 'daily',
    orderNo: 22,
    koreanMeaning: '\uc774\ub2e4',
    thaiWord: '\u0e40\u0e1b\u0e47\u0e19',
    phonetic: 'pen',
    hangulPronunciation: '\ud39c',
    englishMeaning: '',
    wordType: 'word',
    linkedSentenceIds: '',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_D023',
    category: 'daily',
    orderNo: 23,
    koreanMeaning: '\ubb34\uc5c7',
    thaiWord: '\u0e44\u0e23',
    phonetic: 'rai',
    hangulPronunciation: '',
    englishMeaning: '',
    wordType: 'word',
    linkedSentenceIds: '',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_D024',
    category: 'daily',
    orderNo: 24,
    koreanMeaning: '\ub9cc\ub098\ub2e4',
    thaiWord: '\u0e1e\u0e1a',
    phonetic: 'ph\xf3p',
    hangulPronunciation: '\ud3fd',
    englishMeaning: '',
    wordType: 'word',
    linkedSentenceIds: '',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_D025',
    category: 'daily',
    orderNo: 25,
    koreanMeaning: '\uc11c\ub85c',
    thaiWord: '\u0e01\u0e31\u0e19',
    phonetic: 'kan',
    hangulPronunciation: '\uae50',
    englishMeaning: '',
    wordType: 'word',
    linkedSentenceIds: '',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_D026',
    category: 'daily',
    orderNo: 26,
    koreanMeaning: '\ub2e4\uc2dc, \uc0c8\ub85c\uc6b4',
    thaiWord: '\u0e43\u0e2b\u0e21\u0e48',
    phonetic: 'm\xe0i',
    hangulPronunciation: '\ub9c8\uc774',
    englishMeaning: '',
    wordType: 'word',
    linkedSentenceIds: '',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_D027',
    category: 'daily',
    orderNo: 27,
    koreanMeaning: '\ud6cc\ub96d\ud558\ub2e4',
    thaiWord: '\u0e40\u0e22\u0e35\u0e48\u0e22\u0e21',
    phonetic: 'y\xeeam',
    hangulPronunciation: '\uc774\uc554',
    englishMeaning: '',
    wordType: 'word',
    linkedSentenceIds: '',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_D028',
    category: 'daily',
    orderNo: 28,
    koreanMeaning: '\uba85\uc0ac\ud654 \uc811\ub450\uc5b4',
    thaiWord: '\u0e04\u0e27\u0e32\u0e21',
    phonetic: 'kwaam',
    hangulPronunciation: '\ucf70\uc554',
    englishMeaning: '',
    wordType: 'word',
    linkedSentenceIds: '',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_D029',
    category: 'daily',
    orderNo: 29,
    koreanMeaning: '\ubcf5\uc218\uc811\ub450\uc0ac, ~\ub4e4',
    thaiWord: '\u0e1e\u0e27\u0e01',
    phonetic: 'phuak',
    hangulPronunciation: '\ud478\uc545',
    englishMeaning: '',
    wordType: 'word',
    linkedSentenceIds: '',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_D030',
    category: 'daily',
    orderNo: 30,
    koreanMeaning: '\uc678\uce58\ub2e4',
    thaiWord: '\u0e23\u0e49\u0e2d\u0e07',
    phonetic: 'r\u0254\u0301\u0254ng',
    hangulPronunciation: '\ub871',
    englishMeaning: '',
    wordType: 'word',
    linkedSentenceIds: '',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_M001',
    category: 'mission',
    orderNo: 1,
    koreanMeaning: '\uc608\uc218\ub2d8',
    thaiWord: '\u0e1e\u0e23\u0e30\u0e40\u0e22\u0e0b\u0e39',
    phonetic: 'phr\xe1-y\xea-soo',
    hangulPronunciation: '\ud504\ub77c \uc608\uc218',
    englishMeaning: 'Jesus',
    wordType: 'word',
    linkedSentenceIds: 'THS_M001, THS_M005, THS_M007',
    note: '\uc120\uad50 \ud575\uc2ec \ub2e8\uc5b4',
  ),
  ThaiWordContent(
    id: 'THW_M002',
    category: 'mission',
    orderNo: 2,
    koreanMeaning: '\uc0ac\ub791\ud558\ub2e4',
    thaiWord: '\u0e23\u0e31\u0e01',
    phonetic: 'r\xe1k',
    hangulPronunciation: '\ub77d',
    englishMeaning: 'love',
    wordType: 'word',
    linkedSentenceIds: 'THS_M001, THS_M006',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_M003',
    category: 'mission',
    orderNo: 3,
    koreanMeaning: '\ud558\ub098\ub2d8',
    thaiWord: '\u0e1e\u0e23\u0e30\u0e40\u0e08\u0e49\u0e32',
    phonetic: 'phr\xe1-ch\xe2o',
    hangulPronunciation: '\ud504\ub77c\uc9dc\uc624',
    englishMeaning: 'God',
    wordType: 'word',
    linkedSentenceIds: 'THS_M002, THS_M003, THS_M004',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_M004',
    category: 'mission',
    orderNo: 4,
    koreanMeaning: '(\uc2e0\uc801 \uc874\uce6d \ubcf4\uc870)',
    thaiWord: '\u0e17\u0e23\u0e07',
    phonetic: 'song',
    hangulPronunciation: '\uc1a1',
    englishMeaning: 'honorific helper',
    wordType: 'particle',
    linkedSentenceIds: 'THS_M002',
    note: '\u0e1e\u0e23\u0e30\u0e40\u0e08\u0e49\u0e32\u0e17\u0e23\u0e07... \uad6c\uc870',
  ),
  ThaiWordContent(
    id: 'THW_M005',
    category: 'mission',
    orderNo: 5,
    koreanMeaning: '~\ud574 \uc8fc\uc138\uc694 / \ubc14\ub77c\ub2e4',
    thaiWord: '\u0e02\u0e2d',
    phonetic: 'kh\u01d2r',
    hangulPronunciation: '\ucee4',
    englishMeaning: 'request / may',
    wordType: 'word',
    linkedSentenceIds: 'THS_M003',
    note: '\uae30\ub3c4/\ucd95\ubcf5 \ubb38\uc7a5\uc5d0 \uc790\uc8fc \uc4f0\uc784',
  ),
  ThaiWordContent(
    id: 'THW_M006',
    category: 'mission',
    orderNo: 6,
    koreanMeaning: '\ucd95\ubcf5',
    thaiWord: '\u0e2d\u0e27\u0e22\u0e1e\u0e23',
    phonetic: 'uay-phorn',
    hangulPronunciation: '\uc6b0\uc544\uc774\ud3f0',
    englishMeaning: 'blessing',
    wordType: 'word',
    linkedSentenceIds: 'THS_M003',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_M007',
    category: 'mission',
    orderNo: 7,
    koreanMeaning: '\uc0ac\ub791 (\uba85\uc0ac)',
    thaiWord: '\u0e04\u0e27\u0e32\u0e21\u0e23\u0e31\u0e01',
    phonetic: 'kwaam-r\xe1k',
    hangulPronunciation: '\ucf70\uc554\ub77d',
    englishMeaning: 'love (noun)',
    wordType: 'word',
    linkedSentenceIds: 'THS_M004',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_M008',
    category: 'mission',
    orderNo: 8,
    koreanMeaning: '\ubbff\ub2e4',
    thaiWord: '\u0e40\u0e0a\u0e37\u0e48\u0e2d',
    phonetic: 'chuea',
    hangulPronunciation: '\uce20\uc544',
    englishMeaning: 'believe',
    wordType: 'word',
    linkedSentenceIds: 'THS_M005',
    note: '\uad8c\uc720 \ubb38\uc7a5\uc5d0 \ud575\uc2ec',
  ),
  ThaiWordContent(
    id: 'THW_M009',
    category: 'mission',
    orderNo: 9,
    koreanMeaning: '\uc6b0\ub9ac',
    thaiWord: '\u0e1e\u0e27\u0e01\u0e40\u0e23\u0e32',
    phonetic: 'phuak-rao',
    hangulPronunciation: '\ud478\uc545\ub77c\uc624',
    englishMeaning: 'we',
    wordType: 'word',
    linkedSentenceIds: 'THS_M006',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_M010',
    category: 'mission',
    orderNo: 10,
    koreanMeaning: '\uc54c\ub2e4, \uc54c\uac8c \ub418\ub2e4',
    thaiWord: '\u0e23\u0e39\u0e49\u0e08\u0e31\u0e01',
    phonetic: 'r\xfau-j\xe0k',
    hangulPronunciation: '\ub8e8\uc9dd',
    englishMeaning: 'know',
    wordType: 'word',
    linkedSentenceIds: 'THS_M007',
    note: '\uc608\uc218\ub2d8 \uc544\uc138\uc694? \ud575\uc2ec \ub3d9\uc0ac',
  ),
  ThaiWordContent(
    id: 'THW_M011',
    category: 'mission',
    orderNo: 11,
    koreanMeaning: '\uacbd\ud5d8\ud558\ub2e4, ~\ud574\ubcf8 \uc801 \uc788\ub2e4',
    thaiWord: '\u0e40\u0e04\u0e22',
    phonetic: 'khoei',
    hangulPronunciation: '\ucee4\uc774',
    englishMeaning: 'have ever',
    wordType: 'word',
    linkedSentenceIds: 'THS_M008',
    note: '\uacbd\ud5d8 \uc9c8\ubb38',
  ),
  ThaiWordContent(
    id: 'THW_M012',
    category: 'mission',
    orderNo: 12,
    koreanMeaning: '\uad50\ud68c',
    thaiWord: '\u0e42\u0e1a\u0e2a\u0e16\u0e4c',
    phonetic: 'b\xf2ht',
    hangulPronunciation: '\ubcf4\ud2b8',
    englishMeaning: 'church',
    wordType: 'word',
    linkedSentenceIds: 'THS_M008',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_M013',
    category: 'mission',
    orderNo: 13,
    koreanMeaning: '\uae30\ub3c4\ud558\ub2e4',
    thaiWord: '\u0e2d\u0e18\u0e34\u0e29\u0e10\u0e32\u0e19',
    phonetic: '\xe0-th\xedt-thaan',
    hangulPronunciation: '\uc544\ud303\ud0c4',
    englishMeaning: 'pray',
    wordType: 'word',
    linkedSentenceIds: 'THS_M009',
    note: '',
  ),
  ThaiWordContent(
    id: 'THW_M014',
    category: 'mission',
    orderNo: 14,
    koreanMeaning: '~\ud560 \uac83\uc774\ub2e4',
    thaiWord: '\u0e08\u0e30',
    phonetic: 'j\xe0',
    hangulPronunciation: '\uc9dc',
    englishMeaning: 'will / future',
    wordType: 'word',
    linkedSentenceIds: 'THS_M009',
    note: '\ubbf8\ub798 \uc870\ub3d9\uc0ac',
  ),
  ThaiWordContent(
    id: 'THW_M015',
    category: 'mission',
    orderNo: 15,
    koreanMeaning: '\uc624\uc138\uc694, \ud568\uaed8 \ud558\uc790',
    thaiWord: '\u0e21\u0e32',
    phonetic: 'maa',
    hangulPronunciation: '\ub9c8',
    englishMeaning: 'come / let\'s',
    wordType: 'word',
    linkedSentenceIds: 'THS_M010',
    note: '\uad8c\uc720 \uc2dc\uc791 \ud45c\ud604',
  ),
  ThaiWordContent(
    id: 'THW_M016',
    category: 'mission',
    orderNo: 16,
    koreanMeaning: '\ub178\ub798\ud558\ub2e4',
    thaiWord: '\u0e40\u0e1e\u0e25\u0e07',
    phonetic: 'phleeng',
    hangulPronunciation: '\ud50c\ub81d',
    englishMeaning: 'sing',
    wordType: 'expression',
    linkedSentenceIds: 'THS_M010',
    note: '\uc9e7\uc740 \ud604\uc7a5\ud615 \ud45c\ud604',
  ),
];

List<ThaiSentenceContent> sentencesByCategory(String category) {
  return thaiSentenceContents
      .where((item) => item.category == category)
      .map(_hydrateSentenceAudio)
      .toList()
    ..sort((a, b) => a.orderNo.compareTo(b.orderNo));
}

List<ThaiWordContent> wordsByCategory(String category) {
  return thaiWordContents
      .where((item) => item.category == category)
      .map(_hydrateWordAudio)
      .toList()
    ..sort((a, b) => a.orderNo.compareTo(b.orderNo));
}

ThaiSentenceContent sentenceAt(String category, int zeroBasedIndex) {
  final list = sentencesByCategory(category);
  if (list.isEmpty) {
    return thaiSentenceContents.first;
  }

  final index = zeroBasedIndex.clamp(0, list.length - 1);
  return list[index];
}

ThaiSentenceContent _hydrateSentenceAudio(ThaiSentenceContent item) {
  final path = item.audioPath.isNotEmpty
      ? _normalizeAudioAssetPath(item.audioPath)
      : 'assets/audio/sentence/${item.id}.mp3';
  return ThaiSentenceContent(
    id: item.id,
    category: item.category,
    orderNo: item.orderNo,
    koreanText: item.koreanText,
    thaiText: item.thaiText,
    phonetic: item.phonetic,
    hangulPronunciation: item.hangulPronunciation,
    englishText: item.englishText,
    hint: item.hint,
    related: item.related,
    cultureNote: item.cultureNote,
    audioPath: path,
    audioUrl: '',
  );
}

ThaiWordContent _hydrateWordAudio(ThaiWordContent item) {
  final path = item.audioPath.isNotEmpty
      ? _normalizeAudioAssetPath(item.audioPath)
      : 'assets/audio/word/${item.id}.mp3';
  return ThaiWordContent(
    id: item.id,
    category: item.category,
    orderNo: item.orderNo,
    koreanMeaning: item.koreanMeaning,
    thaiWord: item.thaiWord,
    phonetic: item.phonetic,
    hangulPronunciation: item.hangulPronunciation,
    englishMeaning: item.englishMeaning,
    wordType: item.wordType,
    linkedSentenceIds: item.linkedSentenceIds,
    note: item.note,
    audioPath: path,
    audioUrl: '',
  );
}

String _normalizeAudioAssetPath(String path) {
  var normalized = path.trim();
  if (normalized.startsWith('assets/')) {
    normalized = normalized.substring('assets/'.length);
  }
  if (normalized.startsWith('audio/sentences/')) {
    normalized = normalized.replaceFirst('audio/sentences/', 'audio/sentence/');
  }
  if (normalized.startsWith('audio/words/')) {
    normalized = normalized.replaceFirst('audio/words/', 'audio/word/');
  }
  return 'assets/$normalized';
}

ThaiWordContent wordAt(String category, int zeroBasedIndex) {
  final list = wordsByCategory(category);
  if (list.isEmpty) {
    return thaiWordContents.first;
  }

  final index = zeroBasedIndex.clamp(0, list.length - 1);
  return list[index];
}

List<String> sentenceThaiOptions({
  required String category,
  required int correctIndex,
}) {
  final sentences = sentencesByCategory(category);
  if (sentences.isEmpty) {
    return const ['No options'];
  }

  final target = sentenceAt(category, correctIndex);
  final options = <String>[];
  final seen = <String>{};
  _appendUniqueOption(
    options: options,
    seen: seen,
    value: target.thaiText,
    normalizer: _normalizeOptionText,
  );

  for (final candidate in sentences) {
    if (candidate.id == target.id) {
      continue;
    }
    _appendUniqueOption(
      options: options,
      seen: seen,
      value: candidate.thaiText,
      normalizer: _normalizeOptionText,
    );
    if (options.length == 4) {
      break;
    }
  }

  return options;
}

List<String> wordEnglishOptions({
  required String category,
  required int correctIndex,
}) {
  final words = wordsByCategory(category);
  if (words.isEmpty) {
    return const ['No options'];
  }

  final target = wordAt(category, correctIndex);
  final options = <String>[];
  final seen = <String>{};
  _appendUniqueOption(
    options: options,
    seen: seen,
    value: _wordMeaningForChoice(target),
    normalizer: _normalizeOptionText,
  );

  for (final candidate in words) {
    if (candidate.id == target.id) {
      continue;
    }
    _appendUniqueOption(
      options: options,
      seen: seen,
      value: _wordMeaningForChoice(candidate),
      normalizer: _normalizeOptionText,
    );
    if (options.length == 4) {
      break;
    }
  }

  return options;
}

void _appendUniqueOption({
  required List<String> options,
  required Set<String> seen,
  required String value,
  required String Function(String input) normalizer,
}) {
  final normalized = normalizer(value);
  if (normalized.isEmpty || seen.contains(normalized)) {
    return;
  }
  seen.add(normalized);
  options.add(value);
}

String _normalizeOptionText(String input) {
  return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String _wordMeaningForChoice(ThaiWordContent word) {
  final english = word.englishMeaning.trim();
  if (english.isNotEmpty) {
    return english;
  }
  return word.koreanMeaning.trim();
}
