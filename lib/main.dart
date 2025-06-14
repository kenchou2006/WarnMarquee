import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'fullscreen_helper.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marquee',
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.grey,
          foregroundColor: Colors.black,
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Colors.white,
          textStyle: TextStyle(color: Colors.black),
        ),
        dialogBackgroundColor: Colors.white,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.grey,
          foregroundColor: Colors.white,
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.grey[900],
          textStyle: const TextStyle(color: Colors.white),
        ),
        dialogBackgroundColor: Colors.grey[900],
      ),
      themeMode: ThemeMode.system,
      home: const MarqueePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MarqueePage extends StatefulWidget {
  const MarqueePage({super.key});

  @override
  State<MarqueePage> createState() => _MarqueePageState();
}

enum MarqueeMode { manual, auto }

class _MarqueePageState extends State<MarqueePage> {
  String marqueeText = '智慧定點式道路警示牌即時跑馬燈系統';
  double velocity = 400;
  MarqueeMode mode = MarqueeMode.manual;
  Timer? _timer;
  String _lastFetchedMessage = '';
  String fetchUrl = 'https://warningsign.pp.ua/marquee/message_json/';
  int fetchInterval = 3;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _loadMarqueeText();
    _loadVelocity();
    _loadMode().then((_) {
      _maybeStartAutoFetch();
    });
    _loadFetchUrl();
    _loadFetchInterval();
    _initFullscreenListener();
  }

  void _initFullscreenListener() {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
      addFullscreenChangeListener(() {
        setState(() {
          _isFullscreen = isCurrentlyFullscreen();
        });
      });
      _isFullscreen = isCurrentlyFullscreen();
    }
  }

  Future<void> _loadMarqueeText() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('marquee_text');
    if (saved != null && saved.isNotEmpty) {
      setState(() {
        marqueeText = saved;
      });
    }
  }

  Future<void> _saveMarqueeText(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('marquee_text', text);
  }

  Future<void> _loadVelocity() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble('marquee_velocity');
    if (saved != null && saved > 0) {
      setState(() {
        velocity = saved;
      });
    }
  }

  Future<void> _saveVelocity(double v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('marquee_velocity', v);
  }

  Future<void> _loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('marquee_mode');
    if (saved == 'auto') {
      setState(() {
        mode = MarqueeMode.auto;
      });
    }
  }

  Future<void> _saveMode(MarqueeMode m) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('marquee_mode', m == MarqueeMode.auto ? 'auto' : 'manual');
  }

  Future<void> _loadFetchUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('marquee_fetch_url');
    if (saved != null && saved.isNotEmpty) {
      setState(() {
        fetchUrl = saved;
      });
    }
  }

  Future<void> _saveFetchUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('marquee_fetch_url', url);
  }

  Future<void> _loadFetchInterval() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('marquee_fetch_interval');
    if (saved != null && saved > 0) {
      setState(() {
        fetchInterval = saved;
      });
    }
  }

  Future<void> _saveFetchInterval(int interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('marquee_fetch_interval', interval);
  }

  Future<void> _showEditDialog() async {
    final controller = TextEditingController(text: marqueeText);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final dialogTheme = Theme.of(context).copyWith(
      dialogBackgroundColor: isDark ? Colors.grey[900] : Colors.white,
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: isDark ? Colors.white : Colors.black,
            displayColor: isDark ? Colors.white : Colors.black,
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.black : Colors.grey[200],
        hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
      ),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return Theme(
          data: dialogTheme,
          child: AlertDialog(
            title: const Text('自訂訊息內容'),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: const InputDecoration(
                hintText: '請輸入跑馬燈訊息',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('確定'),
              ),
            ],
          ),
        );
      },
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        marqueeText = result.trim();
      });
      _saveMarqueeText(result.trim());
    }
  }

  Future<void> _showVelocityDialog() async {
    final controller = TextEditingController(text: velocity.toStringAsFixed(0));
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final dialogTheme = Theme.of(context).copyWith(
      dialogBackgroundColor: isDark ? Colors.grey[900] : Colors.white,
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: isDark ? Colors.white : Colors.black,
            displayColor: isDark ? Colors.white : Colors.black,
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.black : Colors.grey[200],
        hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
      ),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return Theme(
          data: dialogTheme,
          child: AlertDialog(
            title: const Text('調整滾動速度'),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: const InputDecoration(
                hintText: '請輸入速度（像素/秒，建議20~200）',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('確定'),
              ),
            ],
          ),
        );
      },
    );
    if (result != null) {
      final v = double.tryParse(result.trim());
      if (v != null && v > 0) {
        setState(() {
          velocity = v;
        });
        _saveVelocity(v);
      }
    }
  }

  Future<void> _showFetchUrlDialog() async {
    final controller = TextEditingController(text: fetchUrl);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final dialogTheme = Theme.of(context).copyWith(
      dialogBackgroundColor: isDark ? Colors.grey[900] : Colors.white,
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: isDark ? Colors.white : Colors.black,
            displayColor: isDark ? Colors.white : Colors.black,
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.black : Colors.grey[200],
        hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
      ),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return Theme(
          data: dialogTheme,
          child: AlertDialog(
            title: const Text('自訂伺服器網址'),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: const InputDecoration(
                hintText: '請輸入API網址',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('確定'),
              ),
            ],
          ),
        );
      },
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        fetchUrl = result.trim();
      });
      _saveFetchUrl(result.trim());
      if (mode == MarqueeMode.auto) {
        _maybeStartAutoFetch();
      }
    }
  }

  Future<void> _showFetchIntervalDialog() async {
    final controller = TextEditingController(text: fetchInterval.toString());
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final dialogTheme = Theme.of(context).copyWith(
      dialogBackgroundColor: isDark ? Colors.grey[900] : Colors.white,
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: isDark ? Colors.white : Colors.black,
            displayColor: isDark ? Colors.white : Colors.black,
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.black : Colors.grey[200],
        hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
      ),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return Theme(
          data: dialogTheme,
          child: AlertDialog(
            title: const Text('自訂爬取間隔（秒）'),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: const InputDecoration(
                hintText: '請輸入間隔秒數（>=1）',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('確定'),
              ),
            ],
          ),
        );
      },
    );
    if (result != null) {
      final v = int.tryParse(result.trim());
      if (v != null && v > 0) {
        setState(() {
          fetchInterval = v;
        });
        _saveFetchInterval(v);
        if (mode == MarqueeMode.auto) {
          _maybeStartAutoFetch();
        }
      }
    }
  }

  void _maybeStartAutoFetch() {
    _timer?.cancel();
    if (mode == MarqueeMode.auto) {
      _fetchMessage();
      _timer = Timer.periodic(Duration(seconds: fetchInterval), (_) => _fetchMessage());
    }
  }

  Future<void> _fetchMessage() async {
    try {
      final response = await http.get(Uri.parse(fetchUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final msg = data['message']?.toString() ?? '';
        if (msg.isNotEmpty && msg != _lastFetchedMessage) {
          setState(() {
            marqueeText = msg;
            _lastFetchedMessage = msg;
          });
        }
      }
    } catch (_) {}
  }

  void _onModeChanged(MarqueeMode newMode) {
    if (mode != newMode) {
      setState(() {
        mode = newMode;
      });
      _saveMode(newMode);
      _maybeStartAutoFetch();
      if (newMode == MarqueeMode.manual) {
        _timer?.cancel();
        _loadMarqueeText();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;
    final popupMenuColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final popupMenuTextColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text('智慧跑馬燈'),
        actions: [
          if (kIsWeb || defaultTargetPlatform == TargetPlatform.android)
            IconButton(
              icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
              tooltip: _isFullscreen ? '退出全螢幕' : '全螢幕',
              onPressed: () {
                if (_isFullscreen) {
                  exitFullscreen();
                } else {
                  enterFullscreen();
                }
              },
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showEditDialog();
              } else if (value == 'velocity') {
                _showVelocityDialog();
              } else if (value == 'fetch_url') {
                _showFetchUrlDialog();
              } else if (value == 'fetch_interval') {
                _showFetchIntervalDialog();
              } else if (value == 'mode_manual') {
                _onModeChanged(MarqueeMode.manual);
              } else if (value == 'mode_auto') {
                _onModeChanged(MarqueeMode.auto);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('自訂訊息內容'),
              ),
              const PopupMenuItem(
                value: 'velocity',
                child: Text('調整滾動速度'),
              ),
              const PopupMenuItem(
                value: 'fetch_url',
                child: Text('自訂伺服器網址'),
              ),
              const PopupMenuItem(
                value: 'fetch_interval',
                child: Text('自訂爬取間隔'),
              ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(
                value: 'mode_manual',
                checked: mode == MarqueeMode.manual,
                child: const Text('手動訊息模式'),
              ),
              CheckedPopupMenuItem(
                value: 'mode_auto',
                checked: mode == MarqueeMode.auto,
                child: const Text('自動爬取訊息'),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxHeight > constraints.maxWidth) {
              return const Center(
                child: Text(
                  '請將裝置切換為橫向以顯示跑馬燈',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }
            final verticalPadding = 40.0;
            final horizontalPadding = 16.0;
            final availableHeight = constraints.maxHeight - verticalPadding * 2;
            final availableWidth = constraints.maxWidth - horizontalPadding * 2;
            final fontSize = availableHeight;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              child: SizedBox(
                height: availableHeight,
                width: availableWidth,
                child: MarqueeWidget(
                  text: marqueeText,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                  velocity: velocity,
                ),
              ),
            );
          },
        ),
      ),
      backgroundColor: Colors.black,
    );
  }
}

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
