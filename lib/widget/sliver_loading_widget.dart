import 'dart:math';
import 'package:flutter/material.dart';

/// A sliver shimmer loader simulating AI response text streaming.
/// Displays 5 animated horizontal lines with staggered shimmer effect.
class SliverAIResponseLoader extends StatefulWidget {
  const SliverAIResponseLoader({
    super.key,
    this.lineCount = 5,
    this.baseColor = const Color(0xFFE0E0E0),
    this.shimmerColor = const Color(0xFFF5F5F5),
    this.borderRadius = 8.0,
  });

  final int lineCount;
  final Color baseColor;
  final Color shimmerColor;
  final double borderRadius;

  @override
  State<SliverAIResponseLoader> createState() => _SliverAIResponseLoaderState();
}

class _SliverAIResponseLoaderState extends State<SliverAIResponseLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  // Randomized line widths to mimic natural text wrapping
  final List<double> _lineWidthFactors = [];

  @override
  void initState() {
    super.initState();
    final rng = Random(42); // fixed seed for consistent layout
    for (int i = 0; i < 5; i++) {
      // Last line is shorter — mimics real AI paragraph endings
      _lineWidthFactors.add(
        i == 4 ? 0.45 + rng.nextDouble() * 0.2 : 0.75 + rng.nextDouble() * 0.25,
      );
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(widget.lineCount, (index) {
              // Stagger shimmer per line by offsetting animation phase
              final staggeredValue = (_animation.value + index * 0.15) % 1.0;
              final shimmerStop = staggeredValue;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final lineWidth =
                        constraints.maxWidth * _lineWidthFactors[index];
                    return ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          widget.baseColor,
                          widget.shimmerColor,
                          widget.baseColor,
                        ],
                        stops: [
                          (shimmerStop - 0.3).clamp(0.0, 1.0),
                          shimmerStop.clamp(0.0, 1.0),
                          (shimmerStop + 0.3).clamp(0.0, 1.0),
                        ],
                      ).createShader(bounds),
                      child: Container(
                        width: lineWidth,
                        height: 14,
                        decoration: BoxDecoration(
                          color: widget.baseColor,
                          borderRadius: BorderRadius.circular(
                            widget.borderRadius,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
