class NestSouvenir {
  const NestSouvenir({
    required this.id,
    required this.name,
    required this.mark,
    required this.description,
  });

  final String id;
  final String name;
  final String mark;
  final String description;
}

class SleepFace {
  const SleepFace({
    required this.id,
    required this.name,
    required this.expression,
  });

  final String id;
  final String name;
  final String expression;
}

class NestReward {
  const NestReward({
    required this.souvenir,
    required this.face,
    required this.message,
  });

  final NestSouvenir souvenir;
  final SleepFace face;
  final String message;
}

class NestSnapshot {
  const NestSnapshot({
    required this.isNested,
    required this.streak,
    required this.souvenirIds,
    required this.faceIds,
    required this.nestTheme,
    required this.blanketTheme,
    required this.premiumPreview,
    this.lastTuckInAt,
    this.lastRewardDate,
  });

  factory NestSnapshot.initial() {
    return const NestSnapshot(
      isNested: false,
      streak: 0,
      souvenirIds: <String>[],
      faceIds: <String>[],
      nestTheme: 'forest',
      blanketTheme: 'linen',
      premiumPreview: false,
    );
  }

  final bool isNested;
  final int streak;
  final DateTime? lastTuckInAt;
  final String? lastRewardDate;
  final List<String> souvenirIds;
  final List<String> faceIds;
  final String nestTheme;
  final String blanketTheme;
  final bool premiumPreview;

  NestSnapshot copyWith({
    bool? isNested,
    int? streak,
    DateTime? lastTuckInAt,
    String? lastRewardDate,
    List<String>? souvenirIds,
    List<String>? faceIds,
    String? nestTheme,
    String? blanketTheme,
    bool? premiumPreview,
  }) {
    return NestSnapshot(
      isNested: isNested ?? this.isNested,
      streak: streak ?? this.streak,
      lastTuckInAt: lastTuckInAt ?? this.lastTuckInAt,
      lastRewardDate: lastRewardDate ?? this.lastRewardDate,
      souvenirIds: souvenirIds ?? this.souvenirIds,
      faceIds: faceIds ?? this.faceIds,
      nestTheme: nestTheme ?? this.nestTheme,
      blanketTheme: blanketTheme ?? this.blanketTheme,
      premiumPreview: premiumPreview ?? this.premiumPreview,
    );
  }
}

const List<NestSouvenir> souvenirCatalog = <NestSouvenir>[
  NestSouvenir(
    id: 'moon_shard',
    name: '月のかけら',
    mark: 'MOON',
    description: '静かな夜にだけ届く淡い石。',
  ),
  NestSouvenir(
    id: 'star_sand',
    name: '星砂',
    mark: 'STAR',
    description: 'ねぐらの隅で小さく光る砂。',
  ),
  NestSouvenir(
    id: 'cedar_leaf',
    name: '眠り杉の葉',
    mark: 'LEAF',
    description: '森のねぐらから落ちてきた葉。',
  ),
  NestSouvenir(
    id: 'warm_pebble',
    name: 'ぬくい小石',
    mark: 'STONE',
    description: '毛布の下で温まっていた小石。',
  ),
  NestSouvenir(
    id: 'window_feather',
    name: '月窓の羽根',
    mark: 'WING',
    description: '朝の光に透ける柔らかい羽根。',
  ),
  NestSouvenir(
    id: 'night_button',
    name: '夜のボタン',
    mark: 'DOT',
    description: 'どこかの毛布から外れた小さな飾り。',
  ),
];

const List<SleepFace> sleepFaceCatalog = <SleepFace>[
  SleepFace(id: 'soft_smile', name: 'ほっとした寝顔', expression: 'u_u'),
  SleepFace(id: 'deep_sleep', name: '深く眠る寝顔', expression: '-_-'),
  SleepFace(id: 'tiny_yawn', name: '小さなあくび', expression: 'o_o'),
  SleepFace(id: 'blanket_peek', name: '毛布からちらり', expression: '^_^'),
  SleepFace(id: 'moon_dream', name: '月を見た夢', expression: '*_*'),
];

const List<String> morningMessages = <String>[
  'ちゃんと休めたみたい。',
  'ねぐらの朝は静かです。',
  '小さなおみやげが届きました。',
  '今夜もこの場所で待っています。',
  '毛布の跡が少し残っています。',
];

String dayKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

int nextStreak(DateTime? previousTuckIn, DateTime now, int currentStreak) {
  if (previousTuckIn == null) {
    return 1;
  }
  if (isSameDay(previousTuckIn, now)) {
    return currentStreak == 0 ? 1 : currentStreak;
  }
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  if (isSameDay(previousTuckIn, yesterday)) {
    return currentStreak + 1;
  }
  return 1;
}

bool shouldShowMorningReward(NestSnapshot snapshot, DateTime now) {
  final tuckedAt = snapshot.lastTuckInAt;
  if (!snapshot.isNested || tuckedAt == null) {
    return false;
  }
  if (snapshot.lastRewardDate == dayKey(now)) {
    return false;
  }
  return !isSameDay(tuckedAt, now);
}

NestSnapshot tuckIn(NestSnapshot snapshot, DateTime now) {
  return snapshot.copyWith(
    isNested: true,
    lastTuckInAt: now,
    streak: nextStreak(snapshot.lastTuckInAt, now, snapshot.streak),
  );
}

NestReward buildReward(NestSnapshot snapshot, DateTime now) {
  final seed =
      now.year * 10000 +
      now.month * 100 +
      now.day +
      snapshot.streak * 17 +
      snapshot.souvenirIds.length * 7;
  final souvenir = souvenirCatalog[seed.abs() % souvenirCatalog.length];
  final face = sleepFaceCatalog[(seed ~/ 3).abs() % sleepFaceCatalog.length];
  final message = morningMessages[(seed ~/ 5).abs() % morningMessages.length];
  return NestReward(souvenir: souvenir, face: face, message: message);
}

NestSnapshot claimReward(
  NestSnapshot snapshot,
  NestReward reward,
  DateTime now,
) {
  final souvenirs = List<String>.of(snapshot.souvenirIds)
    ..add(reward.souvenir.id);
  final faces = List<String>.of(snapshot.faceIds)..add(reward.face.id);
  return snapshot.copyWith(
    isNested: false,
    lastRewardDate: dayKey(now),
    souvenirIds: souvenirs,
    faceIds: faces,
  );
}

NestSouvenir souvenirById(String id) {
  return souvenirCatalog.firstWhere(
    (souvenir) => souvenir.id == id,
    orElse: () => souvenirCatalog.first,
  );
}

SleepFace faceById(String id) {
  return sleepFaceCatalog.firstWhere(
    (face) => face.id == id,
    orElse: () => sleepFaceCatalog.first,
  );
}
