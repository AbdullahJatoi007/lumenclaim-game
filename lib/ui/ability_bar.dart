import 'package:flutter/material.dart';
import '../game/lumenclaim_game.dart';

/// Fixed-position ability buttons: shield (bottom-left) and return-fire
/// (bottom-right). Positions/sizes here are mirrored in
/// [FloatingJoystick.reservedButtonZones] so the floating joystick knows
/// to ignore touches that start on top of these buttons — otherwise a tap
/// here would simultaneously plant a joystick origin underneath it.
class AbilityBar extends StatelessWidget {
  final GameStats stats;
  final VoidCallback onShield;
  final VoidCallback onFire;

  static const double buttonSize = 74;
  static const double margin = 12;

  const AbilityBar({
    super.key,
    required this.stats,
    required this.onShield,
    required this.onFire,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: margin,
          bottom: margin,
          child: _ShieldButton(stats: stats, onPressed: onShield),
        ),
        Positioned(
          right: margin,
          bottom: margin,
          child: _FireButton(stats: stats, onPressed: onFire),
        ),
      ],
    );
  }
}

class _ShieldButton extends StatelessWidget {
  final GameStats stats;
  final VoidCallback onPressed;

  const _ShieldButton({required this.stats, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final onCooldown = stats.shieldCooldownLeft > 0 && !stats.shieldActive;
    final cooldownFraction =
        (stats.shieldCooldownLeft / GameStats.shieldCooldownDuration)
            .clamp(0.0, 1.0);
    final ready = !stats.shieldActive && !onCooldown;

    return _AbilityButton(
      onPressed: ready ? onPressed : null,
      color: const Color(0xFF4DE3FF),
      active: stats.shieldActive,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (onCooldown)
            SizedBox(
              width: AbilityBar.buttonSize - 10,
              height: AbilityBar.buttonSize - 10,
              child: CircularProgressIndicator(
                value: 1 - cooldownFraction,
                strokeWidth: 3,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF4DE3FF)),
              ),
            ),
          Icon(
            Icons.shield_rounded,
            color: ready ? const Color(0xFF4DE3FF) : Colors.white38,
            size: 28,
          ),
          if (stats.shieldActive)
            Positioned(
              bottom: 6,
              child: Text(
                stats.shieldTimeLeft.toStringAsFixed(1),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}

class _FireButton extends StatelessWidget {
  final GameStats stats;
  final VoidCallback onPressed;

  const _FireButton({required this.stats, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final hasAmmo = stats.ammo > 0;
    final capped = stats.killsThisLevel >= GameStats.maxKillableEnemiesPerLevel;

    return _AbilityButton(
      onPressed: hasAmmo ? onPressed : null,
      color: const Color(0xFFEAFBFF),
      active: false,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.gps_fixed_rounded,
            color: hasAmmo ? const Color(0xFFEAFBFF) : Colors.white24,
            size: 26,
          ),
          Positioned(
            bottom: 6,
            child: Text(
              capped ? '0' : '${stats.ammo}',
              style: TextStyle(
                color: hasAmmo ? Colors.white : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AbilityButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color color;
  final bool active;
  final Widget child;

  const _AbilityButton({
    required this.onPressed,
    required this.color,
    required this.active,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width: AbilityBar.buttonSize,
        height: AbilityBar.buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? color.withOpacity(0.28) : const Color(0xAA0B1220),
          border: Border.all(
            color: enabled ? color.withOpacity(0.6) : Colors.white24,
            width: 1.5,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 16,
                      spreadRadius: 1)
                ]
              : null,
        ),
        child: child,
      ),
    );
  }
}
