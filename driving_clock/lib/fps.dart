import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class Fps {
  Fps._();

  static Fps _instance;

  static Fps get instance {
    if (_instance == null) {
      _instance = Fps._();
    }
    return _instance;
  }

  int _count = 0;
  int _startTime = -1;
  double _fps = 0.0;

  double update() {
    var now = new DateTime.now().millisecondsSinceEpoch;
    if (_startTime < 0) {
      _startTime = now;
    } else {
      _count++;
      if (1000 <= now - _startTime) {
        _fps = _count / ((now - _startTime) / 1000.0);
        _startTime = now;
        _count = 0;
      }
    }
    return _fps;
  }

  void draw(Canvas canvas, Offset offset, Color color) {
//    var fps = Fps.instance.update();
    TextSpan span = new TextSpan(
        style: new TextStyle(color: color), text: "Fps:" + _fps.toString());
    TextPainter tp = new TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: ui.TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, offset);
  }
}
