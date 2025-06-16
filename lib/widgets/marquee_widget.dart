import 'package:flutter/material.dart';

class MarqueeWidget extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double velocity;

  const MarqueeWidget({
    super.key,
    required this.text,
    this.style,
    this.velocity = 50,
  });

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _textWidth = 0;
  double _containerWidth = 0;
  final double _gap = 40;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMarquee());
  }

  @override
  void didUpdateWidget(covariant MarqueeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMarquee());
  }

  void _startMarquee() {
    final style = widget.style ?? const TextStyle();
    final mediaQuery = MediaQuery.maybeOf(context);
    final textScale = mediaQuery?.textScaleFactor ?? 1.0;
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text + '\u00A0', style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
      maxLines: 1,
      textScaleFactor: textScale,
    )..layout(
        minWidth: 0,
        maxWidth: double.infinity,
      );

    final newTextWidth = textPainter.width;
    final shouldAnimate = newTextWidth > 0 && _containerWidth > 0 && newTextWidth > _containerWidth;

    if (_textWidth != newTextWidth) {
      _textWidth = newTextWidth;
    }

    if (shouldAnimate) {
      final distance = _textWidth + _gap;
      final duration = Duration(milliseconds: (distance / widget.velocity * 1000).toInt());
      _controller.stop();
      _controller.reset();
      _controller.duration = duration;
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.reset();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_containerWidth != constraints.maxWidth) {
          _containerWidth = constraints.maxWidth;
          WidgetsBinding.instance.addPostFrameCallback((_) => _startMarquee());
        }
        final fontSize = widget.style?.fontSize ?? constraints.maxHeight;
        if (constraints.maxHeight == 0 || fontSize == 0) {
          return const SizedBox.shrink();
        }
        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              if (_textWidth <= _containerWidth) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: _containerWidth,
                    height: constraints.maxHeight,
                    child: Text(
                      widget.text,
                      style: widget.style,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                );
              }
              final offset = -(_controller.value * (_textWidth + _gap));
              return Stack(
                children: [
                  Positioned(
                    left: offset,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: _textWidth,
                          height: constraints.maxHeight,
                          child: Text(
                            widget.text,
                            style: widget.style,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                        ),
                        SizedBox(width: _gap),
                        SizedBox(
                          width: _textWidth,
                          height: constraints.maxHeight,
                          child: Text(
                            widget.text,
                            style: widget.style,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

