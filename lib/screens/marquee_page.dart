import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../fullscreen/fullscreen_helper.dart';
import '../widgets/marquee_widget.dart';
import '../widgets/font_size_dialog.dart';

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
  double? fontSize;
  bool _networkErrorDialogSuppressed = false;
  bool _networkErrorDialogShowing = false;

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
    _loadFontSize();
    _loadNetworkErrorDialogSuppressed();
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

  Future<void> _loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble('marquee_font_size');
    if (saved != null && saved > 0) {
      setState(() {
        fontSize = saved;
      });
    }
  }

  Future<void> _saveFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('marquee_font_size', size);
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

  Future<void> _showFontSizeDialog() async {
    double? initialFontSize = (fontSize != null && fontSize! > 0) ? fontSize : null;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return FontSizeDialog(
          initialFontSize: initialFontSize,
          onFontSizeChanged: (newSize) {
            setState(() {
              fontSize = newSize;
            });
            _saveFontSize(newSize);
          },
        );
      },
    );
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
      } else {
        await _showNetworkErrorDialog(
          'HTTP 請求錯誤\nHTTP 狀態碼: [${response.statusCode}\nm回應內容: ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      await _showNetworkErrorDialog(
        'HTTP 請求錯誤\n${e.toString()}',
      );
    } catch (e) {
      await _showNetworkErrorDialog(
        '未知錯誤\n${e.toString()}',
      );
    }
  }

  Future<void> _showNetworkErrorDialog(String errorMsg) async {
    if (_networkErrorDialogSuppressed || _networkErrorDialogShowing) return;
    _networkErrorDialogShowing = true;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final dialogTheme = Theme.of(context).copyWith(
      dialogBackgroundColor: isDark ? Colors.grey[900] : Colors.white,
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: isDark ? Colors.white : Colors.black,
            displayColor: isDark ? Colors.white : Colors.black,
          ),
    );
    bool suppress = false;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Theme(
          data: dialogTheme,
          child: StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('網路錯誤'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errorMsg),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: suppress,
                          onChanged: (val) {
                            setState(() {
                              suppress = val ?? false;
                            });
                          },
                        ),
                        const Expanded(child: Text('不再顯示直到重啟')),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      if (suppress) {
                        setState(() {
                          _networkErrorDialogSuppressed = true;
                        });
                      }
                      Navigator.of(context).pop();
                    },
                    child: const Text('確定'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    _networkErrorDialogShowing = false;
  }

  Future<void> _setNetworkErrorDialogSuppressed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('network_error_dialog_suppressed', value);
    setState(() {
      _networkErrorDialogSuppressed = value;
    });
  }

  Future<void> _loadNetworkErrorDialogSuppressed() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _networkErrorDialogSuppressed = prefs.getBool('network_error_dialog_suppressed') ?? false;
    });
  }

  void _onModeChanged(MarqueeMode newMode) {
    setState(() {
      mode = newMode;
    });
    _saveMode(newMode);
    _maybeStartAutoFetch();
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
              } else if (value == 'font_size') {
                _showFontSizeDialog();
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
                value: 'font_size',
                child: Text('調整字體大小'),
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
            final maxFontSize = availableHeight;
            final usedFontSize = (fontSize != null && fontSize! <= maxFontSize)
                ? fontSize!
                : maxFontSize;

            return Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                    child: SizedBox(
                      height: availableHeight,
                      width: availableWidth,
                      child: MarqueeWidget(
                        text: marqueeText,
                        style: TextStyle(
                          fontSize: usedFontSize,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                        velocity: velocity,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      backgroundColor: Colors.black,
    );
  }
}
