import 'package:flutter/material.dart';

import '../audio/bgm_service.dart';
import '../audio/sfx_service.dart';
import '../game/models.dart';

class NavalPalette {
  static const Color deepOcean = Color(0xFF061524);
  static const Color steelDark = Color(0xFF102235);
  static const Color steelMid = Color(0xFF1E3750);
  static const Color steelBorder = Color(0xFF4F779B);
  static const Color radarGreen = Color(0xFF28F08D);
  static const Color playerBlue = Color(0xFF2B8DFF);
  static const Color enemyRed = Color(0xFFE83A3A);
  static const Color tacticalAmber = Color(0xFFFFA822);
  static const Color cyanAccent = Color(0xFF3CE3FF);
}

/// Compact AppBar actions for toggling BGM and SFX independently.
class TacticalAudioActions extends StatelessWidget {
  const TacticalAudioActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: BgmService.instance.isMuted,
          builder: (context, muted, _) {
            return IconButton(
              tooltip: muted ? 'Activar música' : 'Silenciar música',
              icon: Icon(
                muted ? Icons.music_off : Icons.music_note,
                color: muted ? Colors.white38 : NavalPalette.radarGreen,
              ),
              onPressed: BgmService.instance.toggleMute,
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: SfxService.instance.isMuted,
          builder: (context, muted, _) {
            return IconButton(
              tooltip: muted ? 'Activar efectos' : 'Silenciar efectos',
              icon: Icon(
                muted ? Icons.volume_off : Icons.volume_up,
                color: muted ? Colors.white38 : NavalPalette.cyanAccent,
              ),
              onPressed: () {
                SfxService.instance.toggleMute();
                if (!SfxService.instance.isMuted.value) {
                  SfxService.instance.play(SfxType.select);
                }
              },
            );
          },
        ),
      ],
    );
  }
}

/// Beveled military-arcade button inspired by classic Gameloft naval UI.
class TacticalButton extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onPressed;
  final bool compact;

  const TacticalButton({
    super.key,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onPressed,
    this.subtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final effectiveAccent = enabled ? accentColor : Colors.white24;

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  SfxService.instance.play(SfxType.select);
                  onPressed!();
                }
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 10 : 14,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF213C56).withValues(alpha: 0.94),
                  const Color(0xFF0E2033).withValues(alpha: 0.96),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: effectiveAccent, width: 1.6),
              boxShadow: [
                if (enabled)
                  BoxShadow(
                    color: effectiveAccent.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 4,
                  height: compact ? 20 : 28,
                  decoration: BoxDecoration(
                    color: effectiveAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: compact ? 8 : 12),
                Icon(icon, color: effectiveAccent, size: compact ? 18 : 24),
                SizedBox(width: compact ? 8 : 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          fontSize: compact ? 12 : 14,
                          color: Colors.white,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gameloft-inspired top dual health bar HUD (ENEMIGO red vs TU FLOTA blue).
class TacticalHealthHud extends StatelessWidget {
  final int myRemainingSegments;
  final int enemyRemainingSegments;
  final int myRemainingShips;
  final int enemyRemainingShips;
  final bool isMyTurn;
  final bool inBattle;

  const TacticalHealthHud({
    super.key,
    required this.myRemainingSegments,
    required this.enemyRemainingSegments,
    required this.myRemainingShips,
    required this.enemyRemainingShips,
    required this.isMyTurn,
    required this.inBattle,
  });

  @override
  Widget build(BuildContext context) {
    final enemyPct = enemyRemainingSegments / kTotalFleetSegments;
    final myPct = myRemainingSegments / kTotalFleetSegments;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A3148), Color(0xFF0A1725)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NavalPalette.steelBorder, width: 1.4),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          // Enemy (Red) bar
          Expanded(
            child: _HudSide(
              title: 'ENEMIGO',
              color: NavalPalette.enemyRed,
              percent: enemyPct,
              remainingShips: enemyRemainingShips,
              alignRight: false,
            ),
          ),
          // Center metallic emblem / turn indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3E5A75), Color(0xFF102030)],
                ),
                border: Border.all(
                  color: !inBattle
                      ? NavalPalette.steelBorder
                      : (isMyTurn
                          ? NavalPalette.radarGreen
                          : NavalPalette.enemyRed),
                  width: 2.2,
                ),
                boxShadow: [
                  if (inBattle)
                    BoxShadow(
                      color: (isMyTurn
                              ? NavalPalette.radarGreen
                              : NavalPalette.enemyRed)
                          .withValues(alpha: 0.45),
                      blurRadius: 8,
                    ),
                ],
              ),
              child: Icon(
                !inBattle
                    ? Icons.anchor
                    : (isMyTurn ? Icons.gps_fixed : Icons.shield),
                size: 22,
                color: !inBattle
                    ? Colors.white70
                    : (isMyTurn
                        ? NavalPalette.radarGreen
                        : NavalPalette.enemyRed),
              ),
            ),
          ),
          // Player (Blue) bar
          Expanded(
            child: _HudSide(
              title: 'TU FLOTA',
              color: NavalPalette.playerBlue,
              percent: myPct,
              remainingShips: myRemainingShips,
              alignRight: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _HudSide extends StatelessWidget {
  final String title;
  final Color color;
  final double percent;
  final int remainingShips;
  final bool alignRight;

  const _HudSide({
    required this.title,
    required this.color,
    required this.percent,
    required this.remainingShips,
    required this.alignRight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Metallic health bar
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: const Color(0xFF07111C),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Align(
              alignment:
                  alignRight ? Alignment.centerRight : Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                widthFactor: percent.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.75),
                        color,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment:
              alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!alignRight) ...[
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
            ],
            // Ship pips
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(kFleetSpecs.length, (i) {
                final alive = i < remainingShips;
                return Container(
                  width: 9,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: alive ? color : Colors.white12,
                    borderRadius: BorderRadius.circular(1.5),
                    border: Border.all(
                      color: alive ? Colors.white54 : Colors.white10,
                      width: 0.6,
                    ),
                  ),
                );
              }),
            ),
            if (alignRight) ...[
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

enum BannerKind {
  hit,
  miss,
  sunk,
  info,
}

/// Dramatic arcade callout banner that pops over the battlefield.
class TacticalEventBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final BannerKind kind;

  const TacticalEventBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    final (Color accent, IconData icon) = switch (kind) {
      BannerKind.hit => (NavalPalette.tacticalAmber, Icons.local_fire_department),
      BannerKind.miss => (NavalPalette.cyanAccent, Icons.water_drop),
      BannerKind.sunk => (NavalPalette.enemyRed, Icons.whatshot),
      BannerKind.info => (NavalPalette.radarGreen, Icons.radar),
    };

    return IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          key: ValueKey('$title-$subtitle'),
          tween: Tween(begin: 0.72, end: 1.0),
          duration: const Duration(milliseconds: 240),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0C1D2E).withValues(alpha: 0.96),
                  const Color(0xFF172D44).withValues(alpha: 0.96),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent, width: 2.4),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.45),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: accent, size: 32),
                const SizedBox(width: 14),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                          color: accent,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 6),
                          ],
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen dramatic Victory / Defeat mission debrief overlay.
class MissionEndOverlay extends StatelessWidget {
  final bool didWin;
  final int myRemainingShips;
  final int enemySunkShips;
  final VoidCallback onRematch;
  final VoidCallback onExit;

  const MissionEndOverlay({
    super.key,
    required this.didWin,
    required this.myRemainingShips,
    required this.enemySunkShips,
    required this.onRematch,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final accent = didWin ? NavalPalette.radarGreen : NavalPalette.enemyRed;
    final title = didWin ? '¡VICTORIA NAVAL!' : 'FLOTA DESTRUIDA';
    final subtitle = didWin
        ? 'Has hundido toda la armada enemiga.'
        : 'El enemigo ha hundido todos tus barcos.';

    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.8, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF172F47), Color(0xFF091522)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  didWin ? Icons.military_tech : Icons.dangerous,
                  size: 64,
                  color: accent,
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatChip(
                        label: 'BARCOS A FLOTE',
                        value: '$myRemainingShips / ${kFleetSpecs.length}',
                        color: NavalPalette.playerBlue,
                      ),
                      _StatChip(
                        label: 'HUNDIDOS',
                        value: '$enemySunkShips / ${kFleetSpecs.length}',
                        color: NavalPalette.tacticalAmber,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TacticalButton(
                  label: 'Revancha',
                  icon: Icons.replay,
                  accentColor: NavalPalette.radarGreen,
                  onPressed: onRematch,
                ),
                const SizedBox(height: 10),
                TacticalButton(
                  label: 'Volver al Menú',
                  icon: Icons.home,
                  accentColor: NavalPalette.steelBorder,
                  onPressed: onExit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}
