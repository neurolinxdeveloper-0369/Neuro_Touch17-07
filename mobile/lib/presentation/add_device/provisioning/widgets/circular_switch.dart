import 'package:flutter/material.dart';

const Color _blueOn = Color(0xFF00A3FF); // Clean Blue
const Color _offGrey = Color(0xFF333333); // Dark Grey for OFF state dot

/// A circular power switch matching the physical dial design.
///
/// - **Blue indicator** when [isOn] is `true`
/// - **Grey indicator** when [isOn] is `false`
/// - Tappable: calls [onToggle] with the new state
class CircularSwitch extends StatelessWidget {
  final bool isOn;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onLongPress;
  final double size;
  final String? label;

  const CircularSwitch({
    super.key,
    required this.isOn,
    this.onToggle,
    this.onLongPress,
    this.size = 72,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // The sizes
    final bezelSize = size;
    final innerSize = size * 0.72; // Inner circle size
    final dotSize = size * 0.12; // Indicator dot size
    
    // Center the dot within the outer bezel band
    final topPadding = (bezelSize - innerSize) / 4 - (dotSize / 2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => onToggle?.call(!isOn),
          onLongPress: onLongPress,
          child: SizedBox(
            width: bezelSize,
            height: bezelSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Bezel
                Container(
                  width: bezelSize,
                  height: bezelSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF121212), // Very dark bezel
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.8),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                
                // Inner Circle
                Container(
                  width: innerSize,
                  height: innerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E1E1E), // Lighter inner circle
                    border: Border.all(
                      color: Colors.white.withOpacity(0.06), // Subtle inner highlight
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                ),

                // Center Icon
                _WallSwitchIcon(isOn: isOn),

                // Indicator Dot
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: topPadding > 0 ? topPadding : 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOn ? _blueOn : _offGrey,
                        boxShadow: isOn
                            ? [
                                BoxShadow(
                                  color: _blueOn.withOpacity(0.8),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [
                                // Subtle inset look when off
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.8),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 12),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isOn ? _blueOn : Colors.white.withOpacity(0.6),
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

class _WallSwitchIcon extends StatelessWidget {
  final bool isOn;
  const _WallSwitchIcon({required this.isOn});

  @override
  Widget build(BuildContext context) {
    final color = isOn ? _blueOn : Colors.white.withOpacity(0.3);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 20,
      height: 26,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 10,
          height: 14,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(1),
          ),
          child: Column(
            children: [
              if (!isOn) Expanded(child: Container()),
              Container(
                height: 5,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: isOn ? BorderSide(color: color, width: 1.5) : BorderSide.none,
                    top: !isOn ? BorderSide(color: color, width: 1.5) : BorderSide.none,
                  ),
                ),
              ),
              if (isOn) Expanded(child: Container()),
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
  final Function(int index)? onLongPress;

  const CircularSwitchGrid({
    super.key,
    required this.switchCount,
    required this.switchStates,
    required this.switchNames,
    required this.onToggle,
    this.onLongPress,
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
          onLongPress: onLongPress != null ? () => onLongPress!(switchIndex) : null,
          size: 68,
          label: label,
        );
      },
    );
  }
}
