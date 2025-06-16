import 'package:flutter/material.dart';

class FontSizeDialog extends StatefulWidget {
  final double? initialFontSize;
  final ValueChanged<double> onFontSizeChanged;
  const FontSizeDialog({this.initialFontSize, required this.onFontSizeChanged});

  @override
  State<FontSizeDialog> createState() => _FontSizeDialogState();
}

class _FontSizeDialogState extends State<FontSizeDialog> {
  late double tempFontSize;
  double? minFontSize;
  double? maxFontSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final constraints = MediaQuery.of(context).size;
    final verticalPadding = 40.0;
    maxFontSize = constraints.height - verticalPadding * 2;
    minFontSize = 12.0;
    tempFontSize = (widget.initialFontSize ?? maxFontSize!).clamp(minFontSize!, maxFontSize!);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final dialogTheme = Theme.of(context).copyWith(
      dialogBackgroundColor: isDark ? Colors.grey[900] : Colors.white,
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: isDark ? Colors.white : Colors.black,
            displayColor: isDark ? Colors.white : Colors.black,
          ),
    );
    return Theme(
      data: dialogTheme,
      child: AlertDialog(
        title: const Text('調整字體大小'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider(
              value: tempFontSize,
              min: minFontSize!,
              max: maxFontSize!,
              divisions: (maxFontSize! - minFontSize!).clamp(1, 100).toInt(),
              label: tempFontSize.toStringAsFixed(0),
              onChanged: (value) {
                setState(() {
                  tempFontSize = value;
                });
                widget.onFontSizeChanged(tempFontSize);
              },
            ),
            Text('字體大小: [${tempFontSize.toStringAsFixed(0)}m'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              widget.onFontSizeChanged(tempFontSize);
              Navigator.of(context).pop();
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }
}

