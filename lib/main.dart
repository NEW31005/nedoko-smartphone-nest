import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nest_state.dart';

void main() {
  runApp(const NedokoApp());
}

enum HomeStage { idle, tucking, sleeping, morning }

class NedokoApp extends StatelessWidget {
  const NedokoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF171512);
    const moss = Color(0xFF4F8D6B);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NEDOKO',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: moss,
          brightness: Brightness.light,
          primary: moss,
          secondary: const Color(0xFFB98258),
          tertiary: const Color(0xFF7B8FA4),
          surface: const Color(0xFFFFFCF6),
          onSurface: ink,
        ),
        fontFamily: 'sans',
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: const Color(0xFFE6D4AF),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: const NedokoShell(),
    );
  }
}

class NedokoShell extends StatefulWidget {
  const NedokoShell({super.key});

  @override
  State<NedokoShell> createState() => _NedokoShellState();
}

class _NedokoShellState extends State<NedokoShell> {
  NestSnapshot _snapshot = NestSnapshot.initial();
  NestReward? _pendingReward;
  HomeStage _stage = HomeStage.idle;
  int _tabIndex = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final lastTuckInMillis = prefs.getInt('lastTuckInAt');
    final snapshot = NestSnapshot(
      isNested: prefs.getBool('isNested') ?? false,
      streak: prefs.getInt('streak') ?? 0,
      lastTuckInAt: lastTuckInMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastTuckInMillis),
      lastRewardDate: prefs.getString('lastRewardDate'),
      souvenirIds: prefs.getStringList('souvenirIds') ?? <String>[],
      faceIds: prefs.getStringList('faceIds') ?? <String>[],
      nestTheme: prefs.getString('nestTheme') ?? 'forest',
      blanketTheme: prefs.getString('blanketTheme') ?? 'linen',
      premiumPreview: prefs.getBool('premiumPreview') ?? false,
    );
    final now = DateTime.now();
    setState(() {
      _snapshot = snapshot;
      if (shouldShowMorningReward(snapshot, now)) {
        _pendingReward = buildReward(snapshot, now);
        _stage = HomeStage.morning;
      } else if (snapshot.isNested) {
        _stage = HomeStage.sleeping;
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isNested', _snapshot.isNested);
    await prefs.setInt('streak', _snapshot.streak);
    final lastTuckInAt = _snapshot.lastTuckInAt;
    if (lastTuckInAt == null) {
      await prefs.remove('lastTuckInAt');
    } else {
      await prefs.setInt('lastTuckInAt', lastTuckInAt.millisecondsSinceEpoch);
    }
    final lastRewardDate = _snapshot.lastRewardDate;
    if (lastRewardDate == null) {
      await prefs.remove('lastRewardDate');
    } else {
      await prefs.setString('lastRewardDate', lastRewardDate);
    }
    await prefs.setStringList('souvenirIds', _snapshot.souvenirIds);
    await prefs.setStringList('faceIds', _snapshot.faceIds);
    await prefs.setString('nestTheme', _snapshot.nestTheme);
    await prefs.setString('blanketTheme', _snapshot.blanketTheme);
    await prefs.setBool('premiumPreview', _snapshot.premiumPreview);
  }

  Future<void> _reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      _snapshot = NestSnapshot.initial();
      _pendingReward = null;
      _stage = HomeStage.idle;
      _tabIndex = 0;
    });
  }

  Future<void> _completeTuckIn() async {
    setState(() {
      _snapshot = tuckIn(_snapshot, DateTime.now());
      _stage = HomeStage.sleeping;
      _pendingReward = null;
    });
    await _save();
  }

  void _beginTuckIn() {
    setState(() => _stage = HomeStage.tucking);
  }

  void _showMorning() {
    setState(() {
      _pendingReward = buildReward(_snapshot, DateTime.now());
      _stage = HomeStage.morning;
    });
  }

  Future<void> _claimReward() async {
    final reward = _pendingReward ?? buildReward(_snapshot, DateTime.now());
    setState(() {
      _snapshot = claimReward(_snapshot, reward, DateTime.now());
      _pendingReward = null;
      _stage = HomeStage.idle;
      _tabIndex = 1;
    });
    await _save();
  }

  Future<void> _setTheme(String value) async {
    setState(() => _snapshot = _snapshot.copyWith(nestTheme: value));
    await _save();
  }

  Future<void> _setBlanket(String value) async {
    setState(() => _snapshot = _snapshot.copyWith(blanketTheme: value));
    await _save();
  }

  Future<void> _setPremiumPreview(bool value) async {
    setState(() => _snapshot = _snapshot.copyWith(premiumPreview: value));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = <Widget>[
      HomeView(
        snapshot: _snapshot,
        stage: _stage,
        pendingReward: _pendingReward,
        onStart: _beginTuckIn,
        onTuckInComplete: _completeTuckIn,
        onMorning: _showMorning,
        onClaimReward: _claimReward,
      ),
      CollectionView(snapshot: _snapshot),
      ThemeView(
        snapshot: _snapshot,
        onNestThemeChanged: _setTheme,
        onBlanketThemeChanged: _setBlanket,
        onPremiumPreviewChanged: _setPremiumPreview,
      ),
      SettingsView(onReset: _reset),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF6),
      body: SafeArea(
        child: IndexedStack(index: _tabIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.nightlight_round_outlined),
            selectedIcon: Icon(Icons.nightlight_round),
            label: 'ねぐら',
          ),
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            selectedIcon: Icon(Icons.collections_bookmark),
            label: '棚',
          ),
          NavigationDestination(
            icon: Icon(Icons.palette_outlined),
            selectedIcon: Icon(Icons.palette),
            label: '装い',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: '設定',
          ),
        ],
      ),
    );
  }
}

class HomeView extends StatelessWidget {
  const HomeView({
    required this.snapshot,
    required this.stage,
    required this.pendingReward,
    required this.onStart,
    required this.onTuckInComplete,
    required this.onMorning,
    required this.onClaimReward,
    super.key,
  });

  final NestSnapshot snapshot;
  final HomeStage stage;
  final NestReward? pendingReward;
  final VoidCallback onStart;
  final VoidCallback onTuckInComplete;
  final VoidCallback onMorning;
  final VoidCallback onClaimReward;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: <Widget>[
        AppHeader(snapshot: snapshot),
        const SizedBox(height: 18),
        NestScene(snapshot: snapshot, stage: stage, onPhoneNested: onStart),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: switch (stage) {
            HomeStage.idle => IdleActions(onStart: onStart),
            HomeStage.tucking => BlanketPull(
              blanketTheme: snapshot.blanketTheme,
              onCompleted: onTuckInComplete,
            ),
            HomeStage.sleeping => SleepingActions(onMorning: onMorning),
            HomeStage.morning => MorningRewardPanel(
              reward: pendingReward ?? buildReward(snapshot, DateTime.now()),
              onClaim: onClaimReward,
            ),
          },
        ),
        const SizedBox(height: 18),
        RetentionStrip(snapshot: snapshot),
      ],
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({required this.snapshot, super.key});

  final NestSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'NEDOKO',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              Text(
                'スマホねぐら',
                style: TextStyle(
                  color: Colors.brown.shade600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        MetricPill(
          icon: Icons.local_fire_department,
          value: '${snapshot.streak}',
        ),
        const SizedBox(width: 8),
        MetricPill(
          icon: Icons.inventory_2_outlined,
          value: '${snapshot.souvenirIds.length}',
        ),
      ],
    );
  }
}

class MetricPill extends StatelessWidget {
  const MetricPill({required this.icon, required this.value, super.key});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2E6D0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0C99F)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: const Color(0xFF6D5638)),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class NestScene extends StatelessWidget {
  const NestScene({
    required this.snapshot,
    required this.stage,
    required this.onPhoneNested,
    super.key,
  });

  final NestSnapshot snapshot;
  final HomeStage stage;
  final VoidCallback onPhoneNested;

  @override
  Widget build(BuildContext context) {
    final tucked = stage == HomeStage.sleeping || stage == HomeStage.morning;
    return AspectRatio(
      aspectRatio: 0.92,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              CustomPaint(
                painter: NestRoomPainter(
                  theme: snapshot.nestTheme,
                  tucked: tucked,
                  premium: snapshot.premiumPreview,
                ),
              ),
              Positioned(
                left: 32,
                right: 32,
                bottom: 58,
                child: DragTarget<String>(
                  onAcceptWithDetails: (_) => onPhoneNested(),
                  builder: (context, candidates, rejected) {
                    return NestBed(
                      blanketTheme: snapshot.blanketTheme,
                      highlighted:
                          candidates.isNotEmpty || stage == HomeStage.tucking,
                      tucked: tucked,
                    );
                  },
                ),
              ),
              if (stage == HomeStage.idle)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 88,
                  child: Center(
                    child: Draggable<String>(
                      data: 'phone',
                      feedback: const Material(
                        color: Colors.transparent,
                        child: PhoneBuddy(scale: 1.08),
                      ),
                      childWhenDragging: const Opacity(
                        opacity: 0.22,
                        child: PhoneBuddy(),
                      ),
                      child: const PhoneBuddy(),
                    ),
                  ),
                ),
              if (stage == HomeStage.sleeping || stage == HomeStage.morning)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 112,
                  child: Center(child: SleepingPhone()),
                ),
              if (stage == HomeStage.tucking)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 94,
                  child: Center(child: PhoneBuddy(scale: 0.94)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class NestRoomPainter extends CustomPainter {
  NestRoomPainter({
    required this.theme,
    required this.tucked,
    required this.premium,
  });

  final String theme;
  final bool tucked;
  final bool premium;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final colors = _themeColors(theme, premium);
    final background = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: tucked
            ? <Color>[colors.$1, colors.$2, const Color(0xFF181715)]
            : <Color>[colors.$1, const Color(0xFF3F4D4A), colors.$2],
      ).createShader(rect);
    canvas.drawRect(rect, background);

    final moonPaint = Paint()..color = const Color(0xFFE9D9A8);
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.16),
      22,
      moonPaint,
    );
    final coverPaint = Paint()..color = colors.$1;
    canvas.drawCircle(
      Offset(size.width * 0.80, size.height * 0.14),
      20,
      coverPaint,
    );

    final starPaint = Paint()
      ..color = const Color(0xFFEADFBF).withValues(alpha: 0.88);
    for (var i = 0; i < 24; i++) {
      final x = (math.sin(i * 7.3) * 0.42 + 0.52) * size.width;
      final y = (math.cos(i * 5.1) * 0.16 + 0.22) * size.height;
      canvas.drawCircle(Offset(x, y), i.isEven ? 1.6 : 1.0, starPaint);
    }

    final windowPaint = Paint()..color = const Color(0x66252A2C);
    final window = RRect.fromRectAndRadius(
      Rect.fromLTWH(28, 42, size.width * 0.28, size.height * 0.26),
      const Radius.circular(22),
    );
    canvas.drawRRect(window, windowPaint);

    final floorPaint = Paint()
      ..shader =
          LinearGradient(
            colors: <Color>[colors.$3, const Color(0xFF2D2923)],
          ).createShader(
            Rect.fromLTWH(
              0,
              size.height * 0.68,
              size.width,
              size.height * 0.32,
            ),
          );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.68, size.width, size.height * 0.32),
      floorPaint,
    );

    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: <Color>[
              const Color(0xFFF4D48F).withValues(alpha: tucked ? 0.20 : 0.32),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width / 2, size.height * 0.62),
              radius: size.width * 0.48,
            ),
          );
    canvas.drawRect(rect, glowPaint);
  }

  (Color, Color, Color) _themeColors(String theme, bool premium) {
    if (theme == 'moon') {
      return (
        const Color(0xFF27313A),
        const Color(0xFF6D7181),
        const Color(0xFF73624C),
      );
    }
    if (theme == 'washitsu') {
      return (
        const Color(0xFF2E3028),
        const Color(0xFF786B4B),
        const Color(0xFF5D5038),
      );
    }
    if (premium) {
      return (
        const Color(0xFF253D38),
        const Color(0xFF815A5A),
        const Color(0xFF5B4A34),
      );
    }
    return (
      const Color(0xFF22352F),
      const Color(0xFF536F58),
      const Color(0xFF4B3E2B),
    );
  }

  @override
  bool shouldRepaint(covariant NestRoomPainter oldDelegate) {
    return oldDelegate.theme != theme ||
        oldDelegate.tucked != tucked ||
        oldDelegate.premium != premium;
  }
}

class PhoneBuddy extends StatelessWidget {
  const PhoneBuddy({this.scale = 1, super.key});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 76,
        height: 122,
        decoration: BoxDecoration(
          color: const Color(0xFF1D211F),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFB7A26E), width: 3),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE7D29C),
              ),
              child: const Icon(Icons.phone_iphone, color: Color(0xFF26332E)),
            ),
            const SizedBox(height: 12),
            const Text(
              'u_u',
              style: TextStyle(
                color: Color(0xFFF8E9B8),
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SleepingPhone extends StatelessWidget {
  const SleepingPhone({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.94, end: 1),
      duration: const Duration(seconds: 2),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: const PhoneBuddy(scale: 0.78),
    );
  }
}

class NestBed extends StatelessWidget {
  const NestBed({
    required this.blanketTheme,
    required this.highlighted,
    required this.tucked,
    super.key,
  });

  final String blanketTheme;
  final bool highlighted;
  final bool tucked;

  @override
  Widget build(BuildContext context) {
    final blanket = blanketColor(blanketTheme);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 118,
      decoration: BoxDecoration(
        color: const Color(0xFFE8D9B9),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: highlighted
              ? const Color(0xFFFFD479)
              : const Color(0xFFB99F68),
          width: highlighted ? 4 : 2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: highlighted
                ? const Color(0x66FFD479)
                : const Color(0x22000000),
            blurRadius: highlighted ? 24 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: blanket.withValues(alpha: tucked ? 0.92 : 0.66),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 16,
            child: Center(
              child: Text(
                'NEST',
                style: TextStyle(
                  color: Color(0xFF7A5E35),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color blanketColor(String blanketTheme) {
  return switch (blanketTheme) {
    'moss' => const Color(0xFF5E8B71),
    'ember' => const Color(0xFFC98462),
    'moon' => const Color(0xFF8B95A8),
    _ => const Color(0xFFD8B66B),
  };
}

class IdleActions extends StatelessWidget {
  const IdleActions({required this.onStart, super.key});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return ActionBand(
      title: '今夜のねぐら',
      body: 'スマホを寝かせる時間です。',
      icon: Icons.bedtime_outlined,
      action: FilledButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.keyboard_arrow_down),
        label: const Text('預ける'),
      ),
    );
  }
}

class BlanketPull extends StatefulWidget {
  const BlanketPull({
    required this.blanketTheme,
    required this.onCompleted,
    super.key,
  });

  final String blanketTheme;
  final VoidCallback onCompleted;

  @override
  State<BlanketPull> createState() => _BlanketPullState();
}

class _BlanketPullState extends State<BlanketPull> {
  double _progress = 0;

  void _update(double delta) {
    setState(() {
      _progress = (_progress - delta / 150).clamp(0, 1);
    });
    if (_progress >= 0.86) {
      widget.onCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('blanket'),
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0xFFF4ECD9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2D0AA)),
      ),
      child: GestureDetector(
        onVerticalDragUpdate: (details) => _update(details.delta.dy),
        onTap: widget.onCompleted,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.vertical_align_top,
                          color: Colors.brown.shade600,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '毛布をかける',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '上へすっと。',
                      style: TextStyle(
                        color: Colors.brown.shade500,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12 + _progress * 58,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: blanketColor(widget.blanketTheme),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 10,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.drag_handle, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SleepingActions extends StatelessWidget {
  const SleepingActions({required this.onMorning, super.key});

  final VoidCallback onMorning;

  @override
  Widget build(BuildContext context) {
    return ActionBand(
      title: 'おやすみ中',
      body: 'ねぐらは静かです。',
      icon: Icons.air,
      action: FilledButton.icon(
        onPressed: onMorning,
        icon: const Icon(Icons.wb_sunny_outlined),
        label: const Text('朝を迎える'),
      ),
    );
  }
}

class MorningRewardPanel extends StatelessWidget {
  const MorningRewardPanel({
    required this.reward,
    required this.onClaim,
    super.key,
  });

  final NestReward reward;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('morning'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF6E7C7),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE4C78E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.inventory_2, color: Color(0xFF73572F)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reward.souvenir.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                reward.souvenir.mark,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(reward.souvenir.description),
          const SizedBox(height: 12),
          Text(
            '${reward.face.name}  ${reward.face.expression}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onClaim,
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('棚へしまう'),
            ),
          ),
        ],
      ),
    );
  }
}

class ActionBand extends StatelessWidget {
  const ActionBand({
    required this.title,
    required this.body,
    required this.icon,
    required this.action,
    super.key,
  });

  final String title;
  final String body;
  final IconData icon;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(title),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EBDD),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2D0AA)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF4F8D6B),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(color: Colors.brown.shade600)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          action,
        ],
      ),
    );
  }
}

class RetentionStrip extends StatelessWidget {
  const RetentionStrip({required this.snapshot, super.key});

  final NestSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: SoftStat(
            label: '連続',
            value: '${snapshot.streak} night',
            icon: Icons.local_fire_department_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SoftStat(
            label: 'おみやげ',
            value: '${snapshot.souvenirIds.length} item',
            icon: Icons.stars_outlined,
          ),
        ),
      ],
    );
  }
}

class SoftStat extends StatelessWidget {
  const SoftStat({
    required this.label,
    required this.value,
    required this.icon,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9DDC7)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: const Color(0xFF9A6B48)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(color: Colors.brown.shade500, fontSize: 12),
              ),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}

class CollectionView extends StatelessWidget {
  const CollectionView({required this.snapshot, super.key});

  final NestSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final souvenirs = snapshot.souvenirIds.map(souvenirById).toList();
    final faces = snapshot.faceIds.map(faceById).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: <Widget>[
        const SectionTitle(title: '棚', subtitle: '朝に届いたもの'),
        const SizedBox(height: 16),
        if (souvenirs.isEmpty)
          const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: '棚は空です',
            body: '今夜のねぐらが待っています。',
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.92,
            ),
            itemCount: souvenirs.length,
            itemBuilder: (context, index) {
              return SouvenirTile(souvenir: souvenirs[index]);
            },
          ),
        const SizedBox(height: 24),
        const SectionTitle(title: '寝顔', subtitle: '休めた夜のしるし'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: faces.isEmpty
              ? <Widget>[const MiniChip(label: 'まだありません')]
              : faces
                    .map(
                      (face) =>
                          MiniChip(label: '${face.name} ${face.expression}'),
                    )
                    .toList(),
        ),
      ],
    );
  }
}

class SouvenirTile extends StatelessWidget {
  const SouvenirTile({required this.souvenir, super.key});

  final NestSouvenir souvenir;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8D9B9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            souvenir.mark,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF4F8D6B),
            ),
          ),
          const Spacer(),
          Text(
            souvenir.name,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            souvenir.description,
            style: TextStyle(color: Colors.brown.shade600, fontSize: 12),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class ThemeView extends StatelessWidget {
  const ThemeView({
    required this.snapshot,
    required this.onNestThemeChanged,
    required this.onBlanketThemeChanged,
    required this.onPremiumPreviewChanged,
    super.key,
  });

  final NestSnapshot snapshot;
  final ValueChanged<String> onNestThemeChanged;
  final ValueChanged<String> onBlanketThemeChanged;
  final ValueChanged<bool> onPremiumPreviewChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: <Widget>[
        const SectionTitle(title: '装い', subtitle: 'ねぐらと毛布'),
        const SizedBox(height: 16),
        OptionGroup(
          title: 'ねぐら',
          options: const <String, String>{
            'forest': '森',
            'moon': '月窓',
            'washitsu': '和室',
          },
          selected: snapshot.nestTheme,
          onSelected: onNestThemeChanged,
        ),
        const SizedBox(height: 16),
        OptionGroup(
          title: '毛布',
          options: const <String, String>{
            'linen': 'リネン',
            'moss': '苔',
            'ember': '灯',
            'moon': '月影',
          },
          selected: snapshot.blanketTheme,
          onSelected: onBlanketThemeChanged,
        ),
        const SizedBox(height: 18),
        SwitchListTile(
          value: snapshot.premiumPreview,
          onChanged: onPremiumPreviewChanged,
          title: const Text('季節のねぐら'),
          subtitle: const Text('プレミアムの見本'),
          secondary: const Icon(Icons.auto_awesome),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          tileColor: const Color(0xFFF3EBDD),
        ),
      ],
    );
  }
}

class OptionGroup extends StatelessWidget {
  const OptionGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String title;
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8D9B9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.entries.map((entry) {
              final active = selected == entry.key;
              return ChoiceChip(
                label: Text(entry.value),
                selected: active,
                onSelected: (_) => onSelected(entry.key),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class SettingsView extends StatelessWidget {
  const SettingsView({required this.onReset, super.key});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: <Widget>[
        const SectionTitle(title: '設定', subtitle: '境界とデータ'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE8D9B9)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('非医療アプリ', style: TextStyle(fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text('薬、服薬量、診断、治療効果は扱いません。強い不安や不眠が続く場合は専門家へ相談してください。'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.restart_alt),
          label: const Text('データをリセット'),
        ),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.brown.shade600,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EBDD),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 42, color: const Color(0xFF8B6A42)),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class MiniChip extends StatelessWidget {
  const MiniChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF0E4CD),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}
