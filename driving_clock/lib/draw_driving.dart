import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import 'fps.dart';

class DrawnDriving extends StatelessWidget {
  const DrawnDriving({
    @required this.dateTime,
    @required this.is24HourFormat,
  }) : assert(dateTime != null);

  final DateTime dateTime;
  final bool is24HourFormat;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter:
          _DrivingPainter(dateTime: dateTime, is24HourFormat: is24HourFormat),
    );
    // TODO: Investigate whether SizedBox is needed.
//    return Center(
//      child: SizedBox.expand(
//        child: CustomPaint(
//          painter: _DrivingPainter(count: (dateTime.millisecond * 100 / 1000).toInt()),
//        ),
//      ),
//    );
  }
}

void drawGame(
    Canvas canvas, Size size, DateTime dateTime, bool is24HourFormat) {
  final ui.Rect paintBounds =
      ui.Rect.fromLTWH(0, 0, size.longestSide, size.shortestSide);

  canvas.save();
  canvas.translate(paintBounds.width / 2.0, 0.0);

  final skylineY = 160.0;

  // draw sky
  canvas.drawRect(
      ui.Rect.fromLTRB(
          -paintBounds.width / 2.0, 0.0, paintBounds.width / 2.0, skylineY),
      ui.Paint()..color = ui.Color.fromARGB(255, 100, 100, 198));

  // draw green ground
  canvas.drawRect(
      ui.Rect.fromLTRB(-paintBounds.width / 2.0, skylineY,
          paintBounds.width / 2.0, paintBounds.height),
      ui.Paint()..color = ui.Color.fromARGB(255, 70, 198, 49));

  // draw road
  var durationInSec = 4;
  var timeInMilliseconds = dateTime.second * 1000 + dateTime.millisecond;
  var timeOffsetInMillisecones = timeInMilliseconds -
      (dateTime.second / durationInSec).floor() * durationInSec * 1000;
  var per = timeOffsetInMillisecones / (durationInSec * 1000);
  var targetX = math.sin(per * 2.0 * math.pi) * (paintBounds.width / 4.0);

  var divNum = 30;
  for (var i = 0; i < divNum; i++) {
    double per = i / (divNum - 1);
    var span = paintBounds.height / divNum;
    var y = paintBounds.height * per + skylineY;
    var w = (paintBounds.width / 2.0) * (per * 0.95 + 0.05);
    double perDelay = per * 0.8;
    var centerX = targetX * (1.0 - math.sin(perDelay * math.pi / 2.0));
    var colorElement = 85;
    canvas.drawRect(
        ui.Rect.fromLTRB(centerX - w, y, centerX + w, y + span),
        ui.Paint()
          ..color =
              ui.Color.fromARGB(255, colorElement, colorElement, colorElement));
  }

  // time
  final hour = intl.DateFormat(is24HourFormat ? 'HH' : 'hh').format(dateTime);
  final minute = intl.DateFormat('mm').format(dateTime);
  final second = intl.DateFormat('ss').format(dateTime);
  final timeText = hour + ":" + minute + ":" + second;

  // draw time
  var timeBoardPer = (timeInMilliseconds - dateTime.second * 1000) / 1000.0;
  timeBoardPer = timeBoardPer * timeBoardPer;
  var timeBoardY = timeBoardPer * (paintBounds.height - skylineY) + skylineY;
  double perDelay = timeBoardPer * 0.8;
  var centerX = targetX * (1.0 - math.sin(perDelay * math.pi / 2.0));
  var textSize = timeBoardPer * 35 + 5;
  TextSpan span = new TextSpan(
      style: new TextStyle(
        color: Colors.red,
        fontWeight: FontWeight.bold,
        fontSize: textSize,
      ),
      text: timeText);
  TextPainter tp = new TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr);
  tp.layout();
  centerX -= tp.width / 2.0;
  tp.paint(canvas, new Offset(centerX, timeBoardY));

  canvas.restore();
}

class _DrivingPainter extends CustomPainter {
  _DrivingPainter({
    @required this.dateTime,
    @required this.is24HourFormat,
  }) : assert(dateTime != null);

  DateTime dateTime;
  bool is24HourFormat;

  @override
  void paint(Canvas canvas, Size size) {
//    final center = (Offset.zero & size).center;
//    final rate = dateTime.millisecond / 1000;
//    final position = center + Offset(rate * size.shortestSide * 0.5, 0);
//    final linePaint = Paint()
//      ..color = Color(0xFF4285F4)
//      ..strokeWidth = 4
//      ..strokeCap = StrokeCap.square;
//
//    canvas.drawLine(center, position, linePaint);

    drawGame(canvas, size, dateTime, is24HourFormat);

    Fps.instance.update();
    Fps.instance.draw(canvas, new Offset(0.0, 20.0), Colors.blue[800]);
  }

  @override
  bool shouldRepaint(_DrivingPainter oldDelegate) {
    return true;
  }
}
