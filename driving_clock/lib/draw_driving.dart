import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:vector_math/vector_math_64.dart' as vector;

import 'fps.dart';
import 'resource_container.dart';
import 'dart:developer';

class DrawnDriving extends StatelessWidget {
  const DrawnDriving({
    @required this.dateTime,
    @required this.is24HourFormat,
  }) : assert(dateTime != null);

  final DateTime dateTime;
  final bool is24HourFormat;

  @override
  Widget build(BuildContext context) {
//    log("DrawnDriving.build()");
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
/*
  final skylineY = 160.0;

  // draw sky
//  canvas.drawRect(
//      ui.Rect.fromLTRB(
//          -paintBounds.width / 2.0, 0.0, paintBounds.width / 2.0, skylineY),
//      ui.Paint()..color = ui.Color.fromARGB(255, 100, 100, 198));
  if (ResourceContainer.instance.skyImage.isLoaded) {
    Rect srcRect = Rect.fromLTRB(0, 0, 600, 125);
    Rect destRect = Rect.fromLTRB(
        -paintBounds.width / 2.0, 0, paintBounds.width / 2.0, skylineY);
    canvas.drawImageRect(
        ResourceContainer.instance.skyImage.image, srcRect, destRect, Paint());
  }

  // draw green ground
  canvas.drawRect(
      ui.Rect.fromLTRB(-paintBounds.width / 2.0, skylineY,
          paintBounds.width / 2.0, paintBounds.height),
      ui.Paint()..color = ui.Color.fromARGB(255, 70, 198, 49));
*/
  // draw road
  var durationInSec = 4;
  var timeInMilliseconds = dateTime.second * 1000 + dateTime.millisecond;
  var timeOffsetInMillisecones = timeInMilliseconds -
      (dateTime.second / durationInSec).floor() * durationInSec * 1000;
  var per = timeOffsetInMillisecones / (durationInSec * 1000);
  var targetX = math.sin(per * 2.0 * math.pi) * (paintBounds.width / 4.0);

//  var divNum = 60;
/*  for (var i = 0; i < divNum; i++) {
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
  }*/
  // draw road by image
/*  for (var i = 0; i < divNum; i++) {
    double per = i / (divNum - 1);
    var span = paintBounds.height / divNum;
    var y = paintBounds.height * per + skylineY;
    var w = (paintBounds.width / 2.0) * (per * 0.95 + 0.05);
    double perDelay = per * 0.8;
    var centerX = targetX * (1.0 - math.sin(perDelay * math.pi / 2.0));
    Rect srcRect = Rect.fromLTRB(0,124,600,125);
    Rect destRect = Rect.fromLTRB(centerX - w, y, centerX + w, y + span);
    canvas.drawImageRect (ResourceContainer.instance.skyImage.image, srcRect, destRect, Paint());
  }*/
  // draw road with perspective projection
/*
      - cameraY = カメラの高さ
      - 現在地点〜消失点までの距離で以下の処理
          - camera viewのZ位置 = globalでのコース位置 - 自車位置
          - camera viewのコース向き = globalでのコース向き - 自車向き
          - 地面高さ = 0（とりあえず。これを上下してコースの高低差を表現できるか？）
          - 透視投影でX,Y計算
              - X = (道幅 - cameraX) / Z
              - Y = (地面高さ - cameraY) / Z
* */

  var camera = new vector.Vector3(0.0, 100.0, 600.0 * per);
  var cameraRotateX = (-60.0 * math.pi / 180.0) * per; // [radian]

//  // draw cam rotate X
//      {
//    TextSpan span = new TextSpan(
//        style: new TextStyle(
//          color: Colors.red,
//          fontWeight: FontWeight.bold,
//          fontSize: 12,
//        ),
//        text: (cameraRotateX / math.pi * 180).toString());
//    TextPainter tp = new TextPainter(
//        text: span,
//        textAlign: TextAlign.left,
//        textDirection: TextDirection.ltr);
//    tp.layout();
//    tp.paint(canvas, new Offset(0, 0));
//  }

//  var a = vector.Vector3(0,0,0);
//  var b = vector.Vector3.copy(a);
//  b.x = 10;
//  log("a&b:"+a.toString()+", "+b.toString());
  double skylineY = -double.infinity;
  vector.Vector3 timeBoardPosition;
  double timeBoardScale = -double.infinity;

  var zCountMax = 100;
  var prevScreenY = -double.infinity;
  var p = Paint();
//  var skyImage = ResourceContainer.instance.skyImage.image;
  for (var zCount = zCountMax-1; 0 <= zCount; zCount--) {

    if(zCount == zCountMax - 2 && prevScreenY != -double.infinity) {
      skylineY = prevScreenY; // nearly a vanishing point

      // draw sky
      if (ResourceContainer.instance.skyImage.isLoaded) {
        Rect srcRect = Rect.fromLTRB(0, 0, 1130*3/4, 322);
        double imageHeightOnScreen = paintBounds.width *srcRect.bottom /  srcRect.right;
        Rect destRect = Rect.fromLTRB(
            -paintBounds.width / 2.0, skylineY - imageHeightOnScreen, paintBounds.width / 2.0, skylineY);
        canvas.drawImageRect(
            ResourceContainer.instance.skyImage.image, srcRect, destRect,
            Paint());
      }

      // draw green ground
      canvas.drawRect(
          ui.Rect.fromLTRB(-paintBounds.width / 2.0, skylineY,
              paintBounds.width / 2.0, paintBounds.height),
          ui.Paint()
            ..color = ui.Color.fromARGB(255, 70, 198, 49));
    }

    // world coordinate
    final worldRoadZ = (zCount * 10).toDouble();
    final roadWidth = 200.0;
    final worldRoadY = 0.0;
    double worldRoadXCenter;
    if (zCount < zCountMax / 4) {
      worldRoadXCenter = 0.0;
    } else {
      final zPer = (zCount - zCountMax / 4) / (zCountMax * 3 / 4);
      worldRoadXCenter = (-math.cos(zPer * math.pi * 1) + 1.0) * 600;
    }
    final worldRoad0 =
        vector.Vector3(worldRoadXCenter - roadWidth, worldRoadY, worldRoadZ);
    final worldRoad1 =
        vector.Vector3(worldRoadXCenter + roadWidth, worldRoadY, worldRoadZ);
//    if (zCount == 1 || zCount == zCountMax - 1) {
////      log((cameraRotateX / math.pi * 180).toString()+": "+worldRoadY.toString()+", "+worldRoadZ.toString()+" -> cam "+camviewRoadY.toString()+", "+camviewRoadZ.toString()+" -> pers "+persY.toString()+" -> screen "+screenY.toString());
//      log("["+per.toString()+"]");
//      log("  z:"+zCount.toString() +" -> "+ worldRoad0.z.toString());
//      log("  world("+worldRoad0.x.toString() +", "+worldRoad0.y.toString() +", "+worldRoad0.z.toString() +")");
//    }

    // camera view coordinate
    Matrix4 worldToCamview = new vector.Matrix4.rotationX(cameraRotateX)..translate(-camera);
//    final translateMatrix = vector.Matrix4.translation(-camera);
//    final rotateMatrix = vector.Matrix4.rotationX(cameraRotateX);
//    final worldToCamview = rotateMatrix.multiplied(translateMatrix);
    final camviewRoad0 = vector.Vector3.copy(worldRoad0);
    final camviewRoad1 = vector.Vector3.copy(worldRoad1);
    worldToCamview.transform3(camviewRoad0);
    worldToCamview.transform3(camviewRoad1);
//    translateMatrix.transform3(camviewRoad0);
//    translateMatrix.transform3(camviewRoad1);
//    rotateMatrix.transform3(camviewRoad0);
//    rotateMatrix.transform3(camviewRoad1);

//    if (zCount == 1 || zCount == zCountMax - 1) {
////      log((cameraRotateX / math.pi * 180).toString()+": "+worldRoadY.toString()+", "+worldRoadZ.toString()+" -> cam "+camviewRoadY.toString()+", "+camviewRoadZ.toString()+" -> pers "+persY.toString()+" -> screen "+screenY.toString());
//      log("["+per.toString()+"]");
//      log("  z:"+zCount.toString() +" -> "+ camviewRoad0.z.toString());
//      log("  world("+worldRoad0.x.toString() +", "+worldRoad0.y.toString() +", "+worldRoad0.z.toString() +")");
//      //log("  m:"+worldToCamview.toString()+")");
//      log("  cam("+camviewRoad0.x.toString() +", "+camviewRoad0.y.toString() +", "+camviewRoad0.z.toString() +")");
//      log("  paint("+paintBounds.toString());
//    }

    final projectionPlaneDistance = 50.0;
    if (projectionPlaneDistance < camviewRoad0.z) {
//      if(true){
      // perspective coordinate
      var persRoad0 = vector.Vector3(
          camviewRoad0.x / (camviewRoad0.z / projectionPlaneDistance),
          camviewRoad0.y / (camviewRoad0.z / projectionPlaneDistance),
          1.0 / camviewRoad0.z);
      var persRoad1 = vector.Vector3(
          camviewRoad1.x / (camviewRoad1.z / projectionPlaneDistance),
          camviewRoad1.y / (camviewRoad1.z / projectionPlaneDistance),
          1.0 / camviewRoad1.z);
//      var persRoad0 = vector.Vector3.copy(camviewRoad0);
//      var persRoad1 = vector.Vector3.copy(camviewRoad1);
//      if (zCount == 1 || zCount == zCountMax - 1) {
////      log((cameraRotateX / math.pi * 180).toString()+": "+worldRoadY.toString()+", "+worldRoadZ.toString()+" -> cam "+camviewRoadY.toString()+", "+camviewRoadZ.toString()+" -> pers "+persY.toString()+" -> screen "+screenY.toString());
//        log("["+per.toString()+"]");
//        log("  z:"+zCount.toString() +" -> "+ persRoad0.z.toString());
//        log("  pers("+persRoad0.x.toString() +", "+persRoad0.y.toString() +", "+persRoad0.z.toString() +")");
//        log("  paint("+paintBounds.width.toString() +", "+paintBounds.height.toString() +")");
//      }

      // screen coordinate
//      Matrix4 scaleMatrix = vector.Matrix4.diagonal3(vector.Vector3(0.1, 0.1, 0.1));
//      scaleMatrix.transform3(persRoad0);
//      scaleMatrix.transform3(persRoad1);
      // horizontal center is applied by canvas.translate()
//      var screenX0 = persX0;
//      var screenX1 = persX1;
//      var screenY = -persY + paintBounds.height / 2.0;
      var screenRoad0 = vector.Vector3(
          persRoad0.x, -persRoad0.y + paintBounds.height / 2.0, 0.0);
      var screenRoad1 = vector.Vector3(
          persRoad1.x, -persRoad1.y + paintBounds.height / 2.0, 0.0);

      // TODO スクリーンサイズに合わせたスケーリングも必要

//      if (zCount == 1 || zCount == zCountMax - 1) {
//        log("  pers("+persRoad0.x.toString() +", "+persRoad0.y.toString() +", "+persRoad0.z.toString() +")");
//        log("  screen("+screenRoad0.x.toString() +", "+screenRoad0.y.toString() +", "+screenRoad0.z.toString() +")");
//      }

      if(zCount == zCountMax / 4){
        timeBoardPosition = vector.Vector3.copy(screenRoad0);

        var camviewTimeBoard = vector.Vector3(camviewRoad0.x, camviewRoad0.y + 40.0, camviewRoad0.z);
//        worldToCamview.transform3(cam?viewTimeBoard);
        var persTimeBoard = vector.Vector3(
            camviewTimeBoard.x / (camviewTimeBoard.z / projectionPlaneDistance),
            camviewTimeBoard.y / (camviewTimeBoard.z / projectionPlaneDistance),
            1.0 / camviewTimeBoard.z);
        var screenTimeBoard = vector.Vector3(
            persTimeBoard.x, -persTimeBoard.y + paintBounds.height / 2.0, 0.0);

        timeBoardScale = screenRoad0.y - screenTimeBoard.y;
      }

      if (prevScreenY != -double.infinity) {
        var x0, x1, y0, y1;
        if (screenRoad0.x < screenRoad1.x) {
          x0 = screenRoad0.x;
          x1 = screenRoad1.x;
        } else {
          x0 = screenRoad1.x;
          x1 = screenRoad0.x;
        }
        if (prevScreenY < screenRoad0.y) {
          y0 = prevScreenY;
          y1 = screenRoad0.y;
        } else {
          y0 = screenRoad0.y;
          y1 = prevScreenY;
        }
        Rect destRect = Rect.fromLTRB(x0, y0, x1, y1 + 2);

        if (ResourceContainer.instance.roadImage.isLoaded) {
          var textureIndex = zCount % 4;
          var textureY = (textureIndex <= 1) ? 0.0 : 40.0;
          Rect srcRect = Rect.fromLTRB(0, textureY, 400, textureY + 1.0);
          canvas.drawImageRect(
              ResourceContainer.instance.roadImage.image, srcRect, destRect, p);
        }
//        var colorElement = 85;
//        canvas.drawRect(
//            destRect,
//            ui.Paint()
//              ..color =
//              ui.Color.fromARGB(255, colorElement, colorElement, colorElement));
      }
      prevScreenY = screenRoad0.y;
    } else {
      prevScreenY = -double.infinity;
    }
  }

// car
  if (ResourceContainer.instance.carImage.isLoaded) {
    final carImage = ResourceContainer.instance.carImage.image;
    canvas.drawImage(
        carImage,
        Offset(-carImage.width / 2.0, paintBounds.height - carImage.height),
        Paint());
  }

  // time
  final hour = intl.DateFormat(is24HourFormat ? 'HH' : 'hh').format(dateTime);
  final minute = intl.DateFormat('mm').format(dateTime);
  final second = intl.DateFormat('ss').format(dateTime);
  final timeText = hour + ":" + minute + ":" + second;

  // draw time on the road
  if(0.0 < timeBoardScale){
    var textSize = timeBoardScale;
    TextSpan span = new TextSpan(
        style: new TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
          fontSize: textSize,
        ),
        text: timeText);
    TextPainter tp = new TextPainter(
        text: span,
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, new Offset(timeBoardPosition.x, timeBoardPosition.y));

  }
/*
  // draw time temporarily
  if(skylineY != -double.infinity) {
    var timeBoardPer = (timeInMilliseconds - dateTime.second * 1000) / 1000.0;
    timeBoardPer = timeBoardPer * timeBoardPer;

    var timeBoardY = timeBoardPer * (paintBounds.height - skylineY) + skylineY;
    double perDelay = timeBoardPer * 0.8;
    var centerX = targetX * (1.0 - math.sin(perDelay * math.pi / 2.0));
    var textSize = timeBoardPer * 35 + 5;
    TextSpan span = new TextSpan(
        style: new TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.normal,
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
  }*/

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
