import 'package:flutter/material.dart';

/// A circular power switch with a glowing center dot.
///
/// - **Blue glow** when [isOn] is `true`
/// - **White glow** when [isOn] is `false`
/// - Smooth animated transition between states
/// - Tappable: calls [onToggle] with the new state
class CircularSwitch extends StatelessWidget {
  final bool isOn;
  final ValueChanged<bool>? onToggle;
  final double size;
  final String? label;

  const CircularSwitch({
    super.key,
    required this.isOn,
    this.onToggle,
    this.size = 72,
    this.label,
  });

  static const Color _blueOn = Color(0xFF2979FF);
  static const Color _offRing = Color(0xFF3A3A4A);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => onToggle?.call(!isOn),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Outer ring gradient
              gradient: RadialGradient(
                colors: isOn
                    ? [
                        _blueOn.withOpacity(0.25),
                        _blueOn.withOpacity(0.06),
                        Colors.transparent,
                      ]
                    : [
                        Colors.white.withOpacity(0.12),
                        Colors.white.withOpacity(0.03),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.6, 1.0],
              ),
              // Glow box shadow
              boxShadow: isOn
                  ? [
                      BoxShadow(
                        color: _blueOn.withOpacity(0.6),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: _blueOn.withOpacity(0.25),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.25),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
              border: Border.all(
                color: isOn ? _blueOn : _offRing,
                width: 2,
              ),
            ),
            child: Center(
              child: _SwitchInner(isOn: isOn, size: size),
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isOn ? _blueOn : Colors.white60,
              letterSpacing: 0.3,
            ),
            child: Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

class _SwitchInner extends StatelessWidget {
  final bool isOn;
  final double size;

  const _SwitchInner({required this.isOn, required this.size});

  @override
  Widget build(BuildContext context) {
    final innerSize = size * 0.52;
    final dotSize = size * 0.16;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: innerSize,
      height: innerSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOn ? const Color(0xFF1A237E) : const Color(0xFF1C1C2E),
        boxShadow: isOn
            ? [
                BoxShadow(
                  color: const Color(0xFF2979FF).withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOn ? const Color(0xFF2979FF) : Colors.white54,
            boxShadow: isOn
                ? [
                    BoxShadow(
                      color: const Color(0xFF2979FF).withOpacity(0.9),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}

/// Grid of [CircularSwitch] widgets — count matches the panel number.
class CircularSwitchGrid extends StatelessWidget {
  final int switchCount; // 6, 7, or 8
  final Map<int, bool> switchStates; // index → isOn
  final Map<int, String> switchNames;
  final Function(int index, bool newState) onToggle;

  const CircularSwitchGrid({
    super.key,
    required this.switchCount,
    required this.switchStates,
    required this.switchNames,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = switchCount <= 6 ? 3 : 4;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 20,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: switchCount,
      itemBuilder: (context, index) {
        final switchIndex = index + 1;
        final isOn = switchStates[switchIndex] ?? false;
        final label = switchNames[switchIndex] ?? 'Switch $switchIndex';
        return CircularSwitch(
          isOn: isOn,
          onToggle: (v) => onToggle(switchIndex, v),
          size: 68,
          label: label,
        );
      },
    );
  }
}
