import 'dart:html' as html;
import 'dart:js_util' as js_util;

void enterFullscreen() {
  final elem = html.document.documentElement;
  if (elem != null) {
    if (js_util.hasProperty(elem, 'requestFullscreen')) {
      js_util.callMethod(elem, 'requestFullscreen', []);
    } else if (js_util.hasProperty(elem, 'webkitRequestFullscreen')) {
      js_util.callMethod(elem, 'webkitRequestFullscreen', []);
    }
  }
}

void exitFullscreen() {
  final doc = html.document;
  if (js_util.hasProperty(doc, 'exitFullscreen')) {
    js_util.callMethod(doc, 'exitFullscreen', []);
  } else if (js_util.hasProperty(doc, 'webkitExitFullscreen')) {
    js_util.callMethod(doc, 'webkitExitFullscreen', []);
  }
}

bool isCurrentlyFullscreen() {
  final doc = html.document;
  return js_util.getProperty(doc, 'fullscreenElement') != null ||
      js_util.getProperty(doc, 'webkitFullscreenElement') != null;
}

void addFullscreenChangeListener(void Function() cb) {
  html.document.addEventListener('fullscreenchange', (_) => cb());
  html.document.addEventListener('webkitfullscreenchange', (_) => cb());
}
