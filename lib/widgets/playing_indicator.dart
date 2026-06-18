import 'package:flutter/material.dart';

class PlayingIndicator extends StatefulWidget {
  final Color color;

  const PlayingIndicator({super.key, required this.color});

  @override
  State<PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _AnimatedBar(
            controller: _controller,
            delay: 0.0,
            color: widget.color,
          ),
          _AnimatedBar(
            controller: _controller,
            delay: 0.2,
            color: widget.color,
          ),
          _AnimatedBar(
            controller: _controller,
            delay: 0.4,
            color: widget.color,
          ),
        ],
      ),
    );
  }
}

class _AnimatedBar extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final Color color;

  const _AnimatedBar({
    required this.controller,
    required this.delay,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final value = (controller.value - delay) % 1.0;
        final height = 4 + (value * 12);
        return Container(
          width: 3,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      },
    );
  }
}
