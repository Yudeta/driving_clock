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

List generateRoad(int bandNum, double bandLength, double progressInZone) {
  var bandList = List(bandNum);

  double calcVanishingPointX(double progress, double progressMax) {
    if (progress < 2000.0) {
      return 0.0;
    } else if (progress < 4000.0) {
      final progressPer = (progress - 2000.0) / 2000.0;
      return math.sin(0.5 * math.pi * progressPer) * 3000.0;
    } else if (progress < 6000.0) {
      final progressPer = (progress - 4000.0) / 2000.0;
      return math.sin(0.5 * math.pi * (1.0 - progressPer)) * 3000.0;
    }
    return 0.0;
  }

  final progress = progressInZone % 6000.0;
  final vanishingPointX = calcVanishingPointX(progress, 6000.0);

  for (var i = 0; i < bandNum; i++) {
    double calcRoadY(double bandZ) {
      if (bandZ < 2000.0) {
        return math.sin(math.pi * 2.0 * (bandZ / 2000.0)) * 30.0;
      } else {
        return 0.0;
      }
    }

//    double worldRoadY = math.sin(math.pi * 2.0 * ((yPer + i / (bandNum - 1))%1.0)) * 20.0;
    double bandZ = (progress + i * bandLength) % 6000.0;
    double worldRoadY = calcRoadY(bandZ);

    double worldRoadXCenter;
    final zPer = i.toDouble() / (bandNum - 1).toDouble();
    worldRoadXCenter = zPer * zPer * vanishingPointX;
    final worldRoadZ = bandLength * i;
    final worldRoadCenter =
        vector.Vector3(worldRoadXCenter, worldRoadY, worldRoadZ);
    bandList[i] = worldRoadCenter;
  }

  return bandList;
}

vector.Vector3 calcPositionFromWorldToCamera(vector.Vector3 cameraPosition,
    vector.Vector3 cameraRotation, vector.Vector3 positionInWorld) {
  Matrix4 worldToCamview = new vector.Matrix4.rotationX(cameraRotation.x)
    ..rotateY(cameraRotation.y)
    ..translate(-cameraPosition);
  final positionInCameraView = vector.Vector3.copy(positionInWorld);
  worldToCamview.transform3(positionInCameraView);
  return positionInCameraView;
}

vector.Vector3 calcPositionFromCameraToScreen(vector.Vector3 positionInScreen,
    double projectionPlaneDistance, double screenHeight) {
  if (0 < positionInScreen.z) {
    // perspective coordinate
    var persRoadCenter = vector.Vector3(
        positionInScreen.x / (positionInScreen.z / projectionPlaneDistance),
        positionInScreen.y / (positionInScreen.z / projectionPlaneDistance),
        1.0 / positionInScreen.z);

    // screen coordinate
    var screenRoadCenter = vector.Vector3(persRoadCenter.x * screenHeight,
        -persRoadCenter.y * screenHeight, persRoadCenter.z);

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
  var timeInMilliseconds = dateTime.second * 1000 + dateTime.millisecond;

  var progressInZone = timeInMilliseconds.toDouble() * 0.5; //[meter]
  final progressInZoneMax = 60 * 1000;
  /*
  - 基本方針
    - 可視コースの形状をZ方向に16分割、分割したBand毎にpixel単位で描画する。
    - テクスチャスクロールで走行を表現。
    - コース形状の変形と、テクスチャスクロールが独立して動く、擬似3D。これによりスピード感を出す。
      - １つのカーブに対して、現実よりもスクロールが長い（速くても曲がり切ることはない）
  * */
  /*
    - Zone: １つの風景が続く範囲。１分。
      - ゾーン内の進行距離: 60秒 * 1000msec = 60000msec
    - dateTimeを元に、distanceInZonne[dist=独自単位] を計算
      - distanceInZone から、コースの形状決定
  * */

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

  double skylineY = -double.infinity;
  vector.Vector3 timeBoardPosition;
  double timeBoardScale = -double.infinity;

  final projectionPlaneDistance = 1.0;
  final screenHeight = paintBounds.height / 2.0;
  final farRoadDistance = 1600.0;

  var zCountMax = 16;
  var prevScreenY = -double.infinity;
  var prevScreenZ = -double.infinity;
  var prevScreenX0 = -double.infinity;
  var prevScreenX1 = -double.infinity;
  //var p = Paint();

  var bandList =
      generateRoad(zCountMax, farRoadDistance / zCountMax, progressInZone);

  double calcCameraRotateX(double y0, double y1) {
    final yDiff = math.min(math.max(y1 - y0, -20.0), 20.0);
    return yDiff * math.pi / 180.0;
  }

  var camera = vector.Vector3(0.0, 100.0, 200.0 * 0.0);
  var cameraRotateX = calcCameraRotateX(bandList[0].y,
      bandList[1].y); //(-20.0 * math.pi / 180.0)* per; // [radian]
  var rotY = 0.0; //(120.0/2 - 120.0*per) * math.pi / 180.0; // [radian]
  var cameraRotation = vector.Vector3(cameraRotateX, rotY, 0.0);

  // draw BGs
  {
    final worldVanishingPointX = 0.0;
    final worldVanishingPointY = 0.0;
    final worldVanishingPointZ = farRoadDistance;
    final worldVanishingPoint = vector.Vector3(
        worldVanishingPointX, worldVanishingPointY, worldVanishingPointZ);

    // camera view coordinate
    final vanishingPointCameraRotation = vector.Vector3.copy(cameraRotation);
    vanishingPointCameraRotation.y = 0.0;
    final cameraViewVanishingPoint = calcPositionFromWorldToCamera(
        camera, vanishingPointCameraRotation, worldVanishingPoint);

    final screenVanishingPoint = calcPositionFromCameraToScreen(
        cameraViewVanishingPoint, projectionPlaneDistance, screenHeight);

    skylineY = screenVanishingPoint.y;

    // draw sky
    if (ResourceContainer.instance.skyImage.isLoaded) {
      Rect srcRect = Rect.fromLTRB(0, 0, 1130 * 3 / 4, 322);
      double imageHeightOnScreen =
          paintBounds.width * srcRect.bottom / srcRect.right;
      Rect destRect = Rect.fromLTRB(-paintBounds.width / 2.0,
          skylineY - imageHeightOnScreen, paintBounds.width / 2.0, skylineY);
      canvas.drawImageRect(ResourceContainer.instance.skyImage.image, srcRect,
          destRect, Paint());
    }

    // draw green ground
    canvas.drawRect(
        ui.Rect.fromLTRB(-paintBounds.width / 2.0, skylineY,
            paintBounds.width / 2.0, paintBounds.height),
        ui.Paint()..color = ui.Color.fromARGB(255, 70, 198, 49));
  }

  for (var zCount = zCountMax - 1; 0 <= zCount; zCount--) {
    // band毎の処理
    final roadWidth = 200.0;

    // world coordinate
    final worldRoadCenter = bandList[zCount];

    // camera view coordinate
    final camviewRoadCenter =
        calcPositionFromWorldToCamera(camera, cameraRotation, worldRoadCenter);
    final camviewRoadLeftEdge = vector.Vector3(camviewRoadCenter.x - roadWidth,
        camviewRoadCenter.y, camviewRoadCenter.z);

    if (0 < camviewRoadCenter.z) {
      // screen view coordinate
      final screenRoadCenter = calcPositionFromCameraToScreen(
          camviewRoadCenter, projectionPlaneDistance, screenHeight);
      final screenRoadLeftEdge = calcPositionFromCameraToScreen(
          camviewRoadLeftEdge, projectionPlaneDistance, screenHeight);

      // draw road band
      var x0 = screenRoadLeftEdge.x;
      var x1 = screenRoadCenter.x + (screenRoadCenter.x - screenRoadLeftEdge.x);
      var y1;
      var z1;
      if (screenRoadCenter.y <= paintBounds.height / 2.0) {
        y1 = screenRoadCenter.y;
        z1 = screenRoadCenter.z;
      } else {
        y1 = paintBounds.height / 2.0;
        // TODO: z1 calculation is probably not correct..
        z1 = screenRoadCenter.z *
            (paintBounds.height / 2.0) /
            screenRoadCenter.y;
      }
      if (prevScreenY != -double.infinity) {
        var y0 = prevScreenY;
        var z0 = prevScreenZ;
        if (x0 <= x1 &&
            y0 <= y1 &&
            ResourceContainer.instance.roadImage.isLoaded) {
          // Draw trapezoid per band
          final bandProgressPer = (progressInZone % 250.0) / 250.0;
          final intY0 = y0.floor();
          final intY1 = y1.floor();
          if (intY0 <= intY1) {
            final bandHeight = intY1 - intY0 + 1;
            for (var y = 0; y < bandHeight; y++) {
              final bandY0 = y.toDouble() + intY0;
              if (paintBounds.height / 2.0 < bandY0) {
                continue;
              }
              final bandPer = y / (bandHeight - 1);
//              log("prevScreenX0:" + prevScreenX0.toString() + ", x:" + x0.toString());
              final bandX0 = prevScreenX0 * (1.0 - bandPer) +
                  x0 * bandPer; //(x0 - prevScreenX0) * bandPer + prevScreenX0;
              final bandX1 = prevScreenX1 * (1.0 - bandPer) +
                  x1 * bandPer; //(x1 - prevScreenX1) * bandPer + prevScreenX1;

              if (bandX0 < -10000.0 ||
                  10000.0 < bandX0 ||
                  bandY0 < -paintBounds.height / 2.0 ||
                  paintBounds.height / 2.0 < bandY0) {
//                log("outrange:" + bandX0.toString() + "y:" + bandY0.toString());
                continue;
              }
              if (bandX0.isNaN || bandY0.isNaN || bandX1.isNaN) {
                continue;
              }

              Rect destRect = Rect.fromLTRB(
                  bandX0,
                  bandY0,
                  bandX1,
                  bandY0 +
                      2); // TODO: +1だと縞模様になる。何故？destRectのBottomをPixel単位で正確な指定をする方法を調査

              final textureHeight = 64.0; //[pixel]
              // calculate texture Y: linear interpolation by Y
//              var textureY = textureHeight * ((bandPer - bandProgressPer) % 0.99);
              // calculate texture Y: linear interpolation by reciprocal of Z
              final bandZ = bandPer * (z1 - z0) + z0;
              final invZ0 = 1.0 / z0;
              final invZ1 = 1.0 / z1;
              final invBandZ = 1.0 / bandZ;
              final bandPerByZ = invBandZ / (invZ1 - invZ0);
              final textureY =
                  textureHeight * ((bandPerByZ - bandProgressPer) % 0.99);

              Rect srcRect = Rect.fromLTRB(0, textureY, 400, textureY + 0.01);
              canvas.drawImageRect(ResourceContainer.instance.roadImage.image,
                  srcRect, destRect, Paint());
            }
          }
        }
      }
      prevScreenX0 = x0;
      prevScreenX1 = x1;
      prevScreenY = y1;
      prevScreenZ = z1;
    } else {
      prevScreenY = -double.infinity;
      prevScreenZ = -double.infinity;
    }
  }

  // car
  if (ResourceContainer.instance.carImage.isLoaded &&
      ResourceContainer.instance.carImageLeft.isLoaded &&
      ResourceContainer.instance.carImageRight.isLoaded &&
      ResourceContainer.instance.carSlip0.isLoaded &&
      ResourceContainer.instance.carSlip1.isLoaded) {
    int calcCarDirection(double x0, double x1) {
      if (x1 < x0)
        return -1; // left
      else if (x0 < x1)
        return 1; // right
      else
        return 0;
    }

    final carDirection = calcCarDirection(bandList[0].x, bandList[3].x);

    ImageContainer getCarImage(int carDirection) {
      switch (carDirection) {
        case 0:
          return ResourceContainer.instance.carImage;
        case -1:
          return ResourceContainer.instance.carImageLeft;
        case 1:
          return ResourceContainer.instance.carImageRight;
      }
    }

    // TODO: 車とスリップ画像のサイズを画面比で記述して、画面サイズに左右されない表示にする。
    final carImage = getCarImage(carDirection).image;
    canvas.drawImage(
        carImage,
        Offset(
            -carImage.width / 2.0, paintBounds.height / 2.0 - carImage.height),
        Paint());

    if (carDirection != 0) {
      var slipImage;
      if (timeInMilliseconds % 200 < 100) {
        slipImage = ResourceContainer.instance.carSlip0.image;
      } else {
        slipImage = ResourceContainer.instance.carSlip1.image;
      }
      canvas.drawImage(
          slipImage,
          Offset(-slipImage.width / 2.0,
              paintBounds.height / 2.0 - slipImage.height),
          Paint());
    }
  }

  // time
  final hour = intl.DateFormat(is24HourFormat ? 'HH' : 'hh').format(dateTime);
  final minute = intl.DateFormat('mm').format(dateTime);
  final second = intl.DateFormat('ss').format(dateTime);
  final timeText = hour + ":" + minute + ":" + second;
  // fixed position
  var textSize = 12.0;
  TextSpan span = new TextSpan(
      style: new TextStyle(
        color: Colors.red,
        fontWeight: FontWeight.bold,
        fontSize: textSize,
      ),
      text: timeText);
  TextPainter tp = new TextPainter(
      text: span, textAlign: TextAlign.right, textDirection: TextDirection.ltr);
  tp.layout();
  tp.paint(
      canvas, new Offset(-paintBounds.width / 2.0, -paintBounds.height / 4.0));

//  // draw time on the road
//  if(0.0 < timeBoardScale){
//    var textSize = timeBoardScale;
//    TextSpan span = new TextSpan(
//        style: new TextStyle(
//          color: Colors.red,
//          fontWeight: FontWeight.bold,
//          fontSize: textSize,
//        ),
//        text: timeText);
//    TextPainter tp = new TextPainter(
//        text: span,
//        textAlign: TextAlign.right,
//        textDirection: TextDirection.ltr);
//    tp.layout();
//    tp.paint(canvas, new Offset(timeBoardPosition.x, timeBoardPosition.y));
//
//  }
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
