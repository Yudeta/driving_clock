import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

ui.Picture buildPicture(Duration timeStamp) {
  final ui.Rect paintBounds =
      ui.Offset.zero & (ui.window.physicalSize / ui.window.devicePixelRatio);
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder, paintBounds);

  TextSpan span = new TextSpan(
      style: new TextStyle(color: Colors.blue[800]),
      text: "timestamp:" + timeStamp.toString());
  TextPainter tp = new TextPainter(
      text: span, textAlign: TextAlign.left, textDirection: TextDirection.ltr);
  tp.layout();
  tp.paint(
      canvas, new Offset(0.0, paintBounds.height / 2.0));

  final ui.Picture picture = recorder.endRecording();
  return picture;
}

void beginFrame(Duration timeStamp) {
  final double devicePixelRatio = ui.window.devicePixelRatio;
  final Float64List deviceTransform = Float64List(16)
    ..[0] = devicePixelRatio
    ..[5] = devicePixelRatio
    ..[10] = 1.0
    ..[15] = 1.0;
  final ui.SceneBuilder sceneBuilder = ui.SceneBuilder()
    ..pushTransform(deviceTransform)
    ..addPicture(ui.Offset.zero, buildPicture(timeStamp))
    ..pop();
  ui.window.render(sceneBuilder.build());

  ui.window.scheduleFrame();
}

void main() {
  // A temporary measure until Platform supports web and TargetPlatform supports
  // macOS.
  if (!kIsWeb && Platform.isMacOS) {
    // TODO(gspencergoog): Update this when TargetPlatform includes macOS.
    // https://github.com/flutter/flutter/issues/31366
    // See https://github.com/flutter/flutter/wiki/Desktop-shells#target-platform-override.
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  }

  ui.window.onBeginFrame = beginFrame;
  ui.window.scheduleFrame();
}
