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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
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
      _maybeStartAutoFetch(); // 確保mode載入後正確啟動
    });
    _loadFetchUrl();
    _loadFetchInterval();
    _initFullscreenListener();
  }

  void _initFullscreenListener() {
    // 只在Web平台監聽
    if (kIsWeb) {
      // ignore: undefined_prefixed_name
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
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('自訂訊息內容'),
          content: TextField(
            controller: controller,
            autofocus: true,
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
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('調整滾動速度'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
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
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('自訂伺服器網址'),
          content: TextField(
            controller: controller,
            autofocus: true,
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
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('自訂爬取間隔（秒）'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('跑馬燈'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Web專用全螢幕按鈕
          if (kIsWeb)
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
            final fontSize = constraints.maxWidth * 0.25;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              child: MarqueeWidget(
                text: marqueeText,
                style: TextStyle(
                  fontSize: fontSize,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                velocity: velocity,
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
    if (oldWidget.text != widget.text || oldWidget.style != widget.style || oldWidget.velocity != widget.velocity) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startMarquee());
    }
  }

  void _startMarquee() {
    final style = widget.style ?? const TextStyle();
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text + '\u00A0', style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    _textWidth = textPainter.width;

    if (_textWidth == 0) return;

    final distance = _textWidth + _gap;
    final duration = Duration(milliseconds: (distance / widget.velocity * 1000).toInt());

    _controller.stop();
    _controller.reset();
    _controller.duration = duration;
    _controller.repeat();
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
        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              if (_textWidth <= _containerWidth) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: _containerWidth,
                    child: Text(widget.text, style: widget.style),
                  ),
                );
              }
              final offset = -(_controller.value * (_textWidth + _gap));
              return Stack(
                children: [
                  Positioned(
                    left: offset,
                    child: Row(
                      children: [
                        SizedBox(
                          width: _textWidth,
                          child: Text(widget.text, style: widget.style),
                        ),
                        SizedBox(width: _gap),
                        SizedBox(
                          width: _textWidth,
                          child: Text(widget.text, style: widget.style),
                        ),
                        SizedBox(width: _gap),
                        SizedBox(
                          width: _textWidth,
                          child: Text(widget.text, style: widget.style),
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