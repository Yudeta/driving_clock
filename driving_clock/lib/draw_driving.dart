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

vector.Vector3 generateRoadPosition (int index, int indexMax, double roadZLength, double per) {
  // world coordinate
  final worldRoadZ = roadZLength * index / indexMax;
  final worldRoadY = 0.0;
  double worldRoadXCenter;
  worldRoadXCenter = 0.0;
//  if (index < indexMax / 4) {
//    worldRoadXCenter = 0.0;
//  } else {
//    final zPer = (index - indexMax / 4) / (indexMax * 3 / 4);
//    worldRoadXCenter = (-math.cos(zPer * math.pi * 1) + 1.0) * 600 * per;
//  }
  if (index < indexMax / 8) {
    worldRoadXCenter = 0.0;
  } else {
    final zPer = (index - indexMax / 8) / (indexMax * 7 / 8);
    worldRoadXCenter = (-math.cos(zPer * math.pi * 0.5) + 1.0) * 1800 * per;
  }
//  final zPer = index / indexMax;
//  worldRoadXCenter = (-math.cos(zPer * math.pi * 0.5) + 1.0) * 1800 * per;

  final worldRoadCenter = vector.Vector3(
      worldRoadXCenter, worldRoadY, worldRoadZ);

  return worldRoadCenter;
}

vector.Vector3 calcPositionFromWorldToCamera (
    vector.Vector3 cameraPosition,
    vector.Vector3 cameraRotation,
    vector.Vector3 positionInWorld) {

  Matrix4 worldToCamview = new vector.Matrix4.rotationX(cameraRotation.x)..rotateY(cameraRotation.y)..translate(-cameraPosition);
  final positionInCameraView = vector.Vector3.copy(positionInWorld);
  worldToCamview.transform3(positionInCameraView);
  return positionInCameraView;
}

vector.Vector3 calcPositionFromCameraToScreen (
    vector.Vector3 positionInScreen,
    double projectionPlaneDistance,
    double screenHeight) {

  if (0 < positionInScreen.z) {
    // perspective coordinate
    var persRoadCenter = vector.Vector3(
        positionInScreen.x / (positionInScreen.z / projectionPlaneDistance),
        positionInScreen.y / (positionInScreen.z / projectionPlaneDistance),
        1.0 / positionInScreen.z);

    // screen coordinate
    var screenRoadCenter = vector.Vector3(
        persRoadCenter.x * screenHeight, -persRoadCenter.y * screenHeight, 0.0);

    return screenRoadCenter;
  }

  return vector.Vector3.zero();
}

void drawGame(
    Canvas canvas, Size size, DateTime dateTime, bool is24HourFormat) {
  final ui.Rect paintBounds =
      ui.Rect.fromLTWH(0, 0, size.longestSide, size.shortestSide);

  canvas.save();
  canvas.translate(paintBounds.width / 2.0, paintBounds.height / 2.0);

  // draw road
  var durationInSec = 4;
  var timeInMilliseconds = dateTime.second * 1000 + dateTime.millisecond;
  var timeOffsetInMillisecones = timeInMilliseconds -
      (dateTime.second / durationInSec).floor() * durationInSec * 1000;
  var per = timeOffsetInMillisecones / (durationInSec * 1000);

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

  var camera = vector.Vector3(0.0, 100.0, 200.0 * 0.0);
  var cameraRotateX = 0.0;//(-30.0 * math.pi / 180.0)* per; // [radian]
  var rotY = 0.0;//(120.0/2 - 120.0*per) * math.pi / 180.0; // [radian]
  var cameraRotation = vector.Vector3(cameraRotateX, rotY, 0.0);

  double skylineY = -double.infinity;
  vector.Vector3 timeBoardPosition;
  double timeBoardScale = -double.infinity;

  final projectionPlaneDistance = 1.0;
  final screenHeight = paintBounds.height / 2.0;
  final farRoadDistance = 1000.0;

  // draw BGs
  {
    final worldVanishingPointX = 0.0;
    final worldVanishingPointY = 0.0;
    final worldVanishingPointZ = farRoadDistance;
    final worldVanishingPoint = vector.Vector3(worldVanishingPointX, worldVanishingPointY, worldVanishingPointZ);

    // camera view coordinate
    final vanishingPointCameraRotation = vector.Vector3.copy(cameraRotation);
    vanishingPointCameraRotation.y = 0.0;
    final cameraViewVanishingPoint = calcPositionFromWorldToCamera(camera, vanishingPointCameraRotation, worldVanishingPoint);

    final screenVanishingPoint = calcPositionFromCameraToScreen(
        cameraViewVanishingPoint,
        projectionPlaneDistance,
        screenHeight);

    skylineY = screenVanishingPoint.y;

    // draw sky
    if (ResourceContainer.instance.skyImage.isLoaded) {
      Rect srcRect = Rect.fromLTRB(0, 0, 1130 * 3 / 4, 322);
      double imageHeightOnScreen = paintBounds.width * srcRect.bottom /
          srcRect.right;
      Rect destRect = Rect.fromLTRB(
          -paintBounds.width / 2.0, skylineY - imageHeightOnScreen,
          paintBounds.width / 2.0, skylineY);
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

  var zCountMax = 16;
  var prevScreenY = -double.infinity;
  var prevScreenX0 = -double.infinity;
  var prevScreenX1 = -double.infinity;
  var p = Paint();

  for (var zCount = zCountMax-1; 0 <= zCount; zCount--) {
    // band毎の処理
    final roadWidth = 200.0;

    // world coordinate
    final worldRoadCenter = generateRoadPosition(zCount, zCountMax, farRoadDistance, per);

    // camera view coordinate
    final camviewRoadCenter = calcPositionFromWorldToCamera(camera, cameraRotation, worldRoadCenter);
    final camviewRoadEdge = vector.Vector3(
        camviewRoadCenter.x + roadWidth,
        camviewRoadCenter.y,
        camviewRoadCenter.z);

    if (0 < camviewRoadCenter.z) {
      // screen view coordinate
      final screenRoadCenter = calcPositionFromCameraToScreen(
          camviewRoadCenter,
          projectionPlaneDistance,
          screenHeight);
      final screenRoadEdge = calcPositionFromCameraToScreen(
          camviewRoadEdge,
          projectionPlaneDistance,
          screenHeight);

//      if (zCount == 1 || zCount == zCountMax - 1) {
//        log("["+zCount.toString()+"]");
//        log("  rotY["+(rotY/math.pi*180).toString()+"]");
////        log("  world("+worldRoad0.x.toString() +", "+worldRoad0.y.toString() +", "+worldRoad0.z.toString() +")");
////        log("  camera("+camviewRoad0.x.toString() +", "+camviewRoad0.y.toString() +", "+camviewRoad0.z.toString() +")");
////        log("  persRoad0("+persRoad0.x.toString() +", "+persRoad0.y.toString() +", "+persRoad0.z.toString() +")");
////        log("  persRoad1("+persRoad1.x.toString() +", "+persRoad1.y.toString() +", "+persRoad1.z.toString() +")");
////        log("  world("+worldRoad0.x.toString() +", "+worldRoad0.y.toString() +", "+worldRoad0.z.toString() +")");
////        log("  camera("+camviewRoad0.x.toString() +", "+camviewRoad0.y.toString() +", "+camviewRoad0.z.toString() +")");
////        log("  persRoadCenter("+persRoadCenter.x.toString() +", "+persRoadCenter.y.toString() +", "+persRoadCenter.z.toString() +")");
//        log("  screenRoadCenter("+screenRoadCenter.x.toString() +", "+screenRoadCenter.y.toString() +", "+screenRoadCenter.z.toString() +")");
//        log("  screenRoadEdge("+screenRoadEdge.x.toString() +", "+screenRoadEdge.y.toString() +", "+screenRoadEdge.z.toString() +")");
//      }

/*      if(zCount == zCountMax / 4){
        timeBoardPosition = vector.Vector3.copy(screenRoad0);

        var camviewTimeBoard = vector.Vector3(camviewRoad0.x, camviewRoad0.y + 40.0, camviewRoad0.z);
//        worldToCamview.transform3(cam?viewTimeBoard);
        var persTimeBoard = vector.Vector3(
            camviewTimeBoard.x / (camviewTimeBoard.z / projectionPlaneDistance),
            camviewTimeBoard.y / (camviewTimeBoard.z / projectionPlaneDistance),
            1.0 / camviewTimeBoard.z);
        var screenTimeBoard = vector.Vector3(
            persTimeBoard.x, -persTimeBoard.y, 0.0);

        timeBoardScale = screenRoad0.y - screenTimeBoard.y;
      }*/

      // draw road band
      var x0 = screenRoadEdge.x;
      var x1 = screenRoadCenter.x - (screenRoadEdge.x - screenRoadCenter.x);
      if (prevScreenY != -double.infinity) {
        var y0 = prevScreenY;
        var y1 = screenRoadCenter.y;
        if (x1 < x0) {
          var tmp = x0;
          x0 = x1;
          x1 = tmp;
        }
        if (y1 < y0) {
          var tmp = y0;
          y0 = y1;
          y1 = tmp;
        }
        if (ResourceContainer.instance.roadImage.isLoaded) {
//          // 直方体で描画
//          Rect destRect = Rect.fromLTRB(x0, y0, x1, y1+1);
//          var textureIndex = zCount % 4;
//          var textureY = (textureIndex <= 1) ? 0.0 : 40.0;
//          Rect srcRect = Rect.fromLTRB(0, textureY, 400, textureY + 1.0);
//          canvas.drawImageRect(
//              ResourceContainer.instance.roadImage.image, srcRect, destRect, p);
//
          // 台形描画
          final intY0 = y0.floor();
          final intY1 = y1.floor();
          if(intY0 <= intY1){
            final bandHeight = intY1 - intY0 + 1;
            for (var y = 0; y < bandHeight; y++) {
              final bandY0 = y.toDouble() + intY0;
              if(paintBounds.height / 2.0 < bandY0){
                continue;
              }
              final bandPer = y / (bandHeight - 1);
//              log("prevScreenX0:" + prevScreenX0.toString() + ", x:" + x0.toString());
              final bandX0 = prevScreenX0 * (1.0 - bandPer) + x0 * bandPer;//(x0 - prevScreenX0) * bandPer + prevScreenX0;
              final bandX1 = prevScreenX1 * (1.0 - bandPer) + x1 * bandPer;//(x1 - prevScreenX1) * bandPer + prevScreenX1;

              if(bandX0 < -10000.0 || 10000.0 < bandX0 || bandY0 < -paintBounds.height / 2.0 || paintBounds.height / 2.0 < bandY0){
//                log("outrange:" + bandX0.toString() + "y:" + bandY0.toString());
                continue;
              }

              Rect destRect = Rect.fromLTRB(bandX0, bandY0, bandX1, bandY0+2); // TODO: +1だと縞模様になる。何故？destRectのBottomをPixel単位で正確な指定をする方法を調査

              final textureHeight = 64.0; //[pixel]
              var textureY = textureHeight * bandPer;
              Rect srcRect = Rect.fromLTRB(0, textureY, 400, textureY+0.1);
              canvas.drawImageRect(
                  ResourceContainer.instance.roadImage.image, srcRect, destRect, p);
            }
          }
        }
      }
      prevScreenX0 = x0;
      prevScreenX1 = x1;
      prevScreenY = screenRoadCenter.y;
    } else {
      prevScreenY = -double.infinity;
    }
  }

// car
  if (ResourceContainer.instance.carImage.isLoaded) {
    final carImage = ResourceContainer.instance.carImage.image;
    canvas.drawImage(
        carImage,
        Offset(-carImage.width / 2.0, paintBounds.height/2.0 - carImage.height),
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
