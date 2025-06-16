import 'package:flutter/services.dart';

bool _isFullscreen = false;
final List<void Function()> _listeners = [];

void enterFullscreen() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  _isFullscreen = true;
  for (final cb in _listeners) {
    cb();
  }
}

void exitFullscreen() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  _isFullscreen = false;
  for (final cb in _listeners) {
    cb();
  }
}

bool isCurrentlyFullscreen() => _isFullscreen;

void addFullscreenChangeListener(void Function() cb) {
  if (!_listeners.contains(cb)) {
    _listeners.add(cb);
  }
}

