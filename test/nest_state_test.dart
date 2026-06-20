import 'package:flutter_test/flutter_test.dart';
import 'package:nedoko_smartphone_nest/nest_state.dart';

void main() {
  test('dayKey formats dates consistently', () {
    expect(dayKey(DateTime(2026, 6, 5)), '2026-06-05');
  });

  test('nextStreak starts, keeps same-day, and increments yesterday', () {
    final now = DateTime(2026, 6, 20, 22);
    expect(nextStreak(null, now, 0), 1);
    expect(nextStreak(DateTime(2026, 6, 20, 2), now, 4), 4);
    expect(nextStreak(DateTime(2026, 6, 19, 23), now, 4), 5);
    expect(nextStreak(DateTime(2026, 6, 15, 23), now, 4), 1);
  });

  test('reward is due only after a nested night crosses a day boundary', () {
    final snapshot = NestSnapshot.initial().copyWith(
      isNested: true,
      lastTuckInAt: DateTime(2026, 6, 19, 23),
    );
    expect(shouldShowMorningReward(snapshot, DateTime(2026, 6, 20, 8)), isTrue);
    expect(
      shouldShowMorningReward(snapshot, DateTime(2026, 6, 19, 23, 30)),
      isFalse,
    );
  });

  test('claimReward stores souvenir and face without keeping user text', () {
    final snapshot = tuckIn(NestSnapshot.initial(), DateTime(2026, 6, 19, 23));
    final reward = buildReward(snapshot, DateTime(2026, 6, 20, 7));
    final claimed = claimReward(snapshot, reward, DateTime(2026, 6, 20, 7));

    expect(claimed.isNested, isFalse);
    expect(claimed.lastRewardDate, '2026-06-20');
    expect(claimed.souvenirIds, contains(reward.souvenir.id));
    expect(claimed.faceIds, contains(reward.face.id));
  });
}
