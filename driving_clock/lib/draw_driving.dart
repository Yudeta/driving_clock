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

class GameParameters {
  static const roadWidth = 200.0;

  double skyOffset;
  int rivalIndex;

  GameParameters(double skyOffset, int rivalIndex){
    this.skyOffset = skyOffset;
    this.rivalIndex = rivalIndex;
  }
}

var gameParameters = GameParameters(0.0, 0);


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
  double calcVanishingPointX2(double progress, double progressMax) {
    if (progress < 2000.0) {
      final progressPer = (progress - 0.0) / 2000.0;
      return -math.sin(0.5 * math.pi * progressPer) * 3000.0;
    } else if (progress < 4000.0) {
      final progressPer = (progress - 2000.0) / 2000.0;
      return -math.sin(0.5 * math.pi * (1.0 - progressPer)) * 3000.0;
    } else if (progress < 5000.0) {
      final progressPer = (progress - 4000.0) / 1000.0;
      return math.sin(math.pi * progressPer) * 1000.0;
    }
    return 0.0;
  }

  final progress = progressInZone % 6000.0;
  final vanishingPointX = calcVanishingPointX2(progress, 6000.0);

  for (var i = 0; i < bandNum; i++) {
    double calcEaseInOutWave(double per) {
        return (math.sin(math.pi * (per - 0.5)) + 1.0) * 0.5;
    }
    double calcRoadY(double baseProgress, int i, int bandNum) {
      if (baseProgress < 3000.0) {
        final hillHeight = 400.0; // [m]
        final hillPer = baseProgress / 3000.0;
        final hillTween = math.sin(math.pi * (2.0 * hillPer - 0.5)) * 0.5 + 0.5;
        if(i < 1) {
          return 0.0;
        }else{
          final zPer = ((i - 1) / (bandNum - 1 - 1));
          // uphill
          return calcEaseInOutWave(zPer) * hillHeight * hillTween;
          // downhill
//          return math.sin(math.pi * (zPer)) * hillHeight * hillTween;
        }
      } else {
        return 0.0;
      }
    }
    double worldRoadY = calcRoadY(progress, i, bandNum);

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

  var timeInMilliseconds = dateTime.second * 1000 + dateTime.millisecond;

  var progressInZone = timeInMilliseconds.toDouble() * 2.0; //[meter]
  final progressInZoneMax = 60 * 1000;

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

  var camera = vector.Vector3(0.0, 100.0, 200.0 * 0.0);
  var cameraRotateX = 0.0; // [radian]
  var rotY = 0.0; //(120.0/2 - 120.0*per) * math.pi / 180.0; // [radian]
  var cameraRotation = vector.Vector3(cameraRotateX, rotY, 0.0);

  // draw BGs
  {
    final worldVanishingPoint = bandList[zCountMax - 1];

    // camera view coordinate
    final vanishingPointCameraRotation = vector.Vector3.copy(cameraRotation);
    vanishingPointCameraRotation.y = 0.0;
    final cameraViewVanishingPoint = calcPositionFromWorldToCamera(
        camera, vanishingPointCameraRotation, worldVanishingPoint);

    final screenVanishingPoint = calcPositionFromCameraToScreen(
        cameraViewVanishingPoint, projectionPlaneDistance, screenHeight);

    double skylineY = screenVanishingPoint.y;

    // draw sky
    if (ResourceContainer.instance.skyImage.isLoaded) {
      final skyImage = ResourceContainer.instance.skyImage.image;
      //Rect srcRect = Rect.fromLTRB(0, 0, 1130 * 3 / 4, 322);
      //gameParameters.skyOffset // -paintBounds.width .. 0.0

      Rect skyArea = Rect.fromLTRB(
          -paintBounds.width * 0.5, -paintBounds.height * 0.5,
          paintBounds.width * 0.5, skylineY);
      // Base ratio -> skyImage.height * 0.75 : paintBounds.height * 0.5

      // skyArea.height : paintBounds.height * 0.5 = y : skyImage.height * 0.75
      // y = skyArea.height * skyImage.height * 0.75 / (paintBounds.height * 0.5)
      final heightOnImage = skyArea.height * (skyImage.height * 0.75) / (paintBounds.height * 0.5);
      // w : skyImage.height * 0.75 = paintBounds.width : paintBounds.height * 0.5
      final widthOnImage = (skyImage.height * 0.75) * paintBounds.width / (paintBounds.height * 0.5);
      // w : paintBounds.height * 0.5 = skyImage.width : heightOnImage
      final widthOnScreen = (paintBounds.height * 0.5) * skyImage.width / (skyImage.height * 0.75);

      if(gameParameters.skyOffset < -widthOnScreen){
        gameParameters.skyOffset += widthOnScreen;
      }else if(0.0 < gameParameters.skyOffset){
        gameParameters.skyOffset -= widthOnScreen;
      }

      Rect srcRect = Rect.fromLTRB(
          0,
          skyImage.height - heightOnImage,
          skyImage.width.toDouble(),
          skyImage.height.toDouble());
      for(var i=0;i<2;i++) {
        final screenX = gameParameters.skyOffset - paintBounds.width * 0.5 + widthOnScreen * i;
        if(screenX < paintBounds.width * 0.5) {
          Rect destRect = Rect.fromLTRB(
              screenX, -paintBounds.height * 0.5,
              screenX + widthOnScreen, skylineY);
          canvas.drawImageRect(skyImage, srcRect, destRect, Paint());
        }
      }

//      Rect srcRect = Rect.fromLTRB(
//          0,
//          skyImage.height - imageHeight,
//          imageWidth,
//          skyImage.height.toDouble());
//
//      Rect destRect = Rect.fromLTRB(
//          gameParameters.skyOffset - paintBounds.width * 0.5, -paintBounds.height * 0.5,
//          gameParameters.skyOffset + paintBounds.width * 0.5, skylineY);

//      canvas.drawImageRect(skyImage, srcRect, destRect, Paint());
    }
  }

  // Draw each band
  final roadWidth = GameParameters.roadWidth;
  final fieldColor = ui.Color.fromARGB(255, 171, 112, 73);
  final bandLengthZ = farRoadDistance / zCountMax; // [m]
  final driveTimeInBand = 250.0; // [msec]

  for (var zCount = zCountMax - 1; 0 <= zCount; zCount--) {
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
          final bandProgressPer = (progressInZone % driveTimeInBand) / driveTimeInBand;
          final intY0 = y0.floor();
          final intY1 = y1.ceil();

          // field
          canvas.drawRect(
              ui.Rect.fromLTRB(-paintBounds.width / 2.0, intY0.toDouble(),
                  paintBounds.width / 2.0, intY1.toDouble()),
              ui.Paint()..color = fieldColor);

          // road
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
                  bandY0 + 1);

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


  // Object utility
  void _drawSprite(ui.Image image, Offset positionLeftTop, Size size, Paint paint) {
    Rect destRect = Rect.fromLTRB(
        positionLeftTop.dx,
        positionLeftTop.dy,
        positionLeftTop.dx + size.width,
        positionLeftTop.dy + size.height);
    Rect srcRect = Rect.fromLTRB(0, 0, image.width.toDouble(), image.height.toDouble());
    canvas.drawImageRect(image, srcRect, destRect, paint);
  }

  vector.Vector3 calcObjectPositionOnRoad(double targetZ) {
    int findBand(double z){
      for (var i = 1; i < zCountMax; i++) {
        if(z <= bandList[i].z){
          return i;
        }
      }
      return -1;
    }
    final bandIndex = findBand(targetZ);
    if(0 <= bandIndex){
      final roadPosition1 = bandList[bandIndex - 1];
      final roadPosition2 = bandList[bandIndex];
      final per = (targetZ - roadPosition1.z) / (roadPosition2.z - roadPosition1.z);
      final roadPosition = roadPosition2 * per + roadPosition1 * (1.0 - per);
      return roadPosition;
    }
    return vector.Vector3.zero();
  }

  // time
  final hour = intl.DateFormat(is24HourFormat ? 'HH' : 'hh').format(dateTime);
  final minute = intl.DateFormat('mm').format(dateTime);
  final timeText = hour + ":" + minute;

  // Rival car
  if (ResourceContainer.instance.rivalCarImage.isLoaded) {
    final rivalCarSpeedScale = 0.5;
    final rivalCarTime = 5000.0;
    gameParameters.rivalIndex = (((progressInZone * rivalCarSpeedScale) / rivalCarTime).floor()) % 2;
    vector.Vector3 generateRivalCar(double progressInZone) {
      final rivalCarZPer = ((progressInZone * rivalCarSpeedScale) % rivalCarTime) / rivalCarTime;
      final rivalCarZ = farRoadDistance * (1.0 - rivalCarZPer);
      return calcObjectPositionOnRoad(rivalCarZ);
    }
    final worldRivalCarPositionCenter = generateRivalCar(progressInZone);
    final rivalCarOffsetX = (gameParameters.rivalIndex * 2 - 1) * GameParameters.roadWidth * 0.6;
    final worldRivalCarPosition = vector.Vector3(
        worldRivalCarPositionCenter.x + rivalCarOffsetX,
        worldRivalCarPositionCenter.y,
        worldRivalCarPositionCenter.z
    );

    // camera view coordinate
//    final camviewRoadLeftEdge = vector.Vector3(camviewRoadCenter.x - roadWidth,
//        camviewRoadCenter.y, camviewRoadCenter.z);
    final camviewRivalCarPosition =
    calcPositionFromWorldToCamera(camera, cameraRotation, worldRivalCarPosition);
    if (0 < camviewRivalCarPosition.z) {
      // screen view coordinate
      final screenRivalCarPosition = calcPositionFromCameraToScreen(
          camviewRivalCarPosition, projectionPlaneDistance, screenHeight);

      final carImage = ResourceContainer.instance.rivalCarImage.image;

      final carImageScaleOnScreen = 20.0 / camviewRivalCarPosition.z;
      final carImageSize = Size(
          paintBounds.width * carImageScaleOnScreen,
          carImage.height * (paintBounds.width * carImageScaleOnScreen) / carImage.width );
      final carImagePosition = Offset(
          screenRivalCarPosition.x - carImageSize.width * 0.5,
          screenRivalCarPosition.y - carImageSize.height * 0.8);
      _drawSprite(carImage, carImagePosition, carImageSize, Paint());

      // Time
      var textSize = carImageSize.height * 0.8;
      final fontColor = ui.Color.fromARGB(255, 231, 213, 212);
      final outlineColor = ui.Color.fromARGB(255, 58, 41, 31);
      TextSpan span = new TextSpan(
          style: new TextStyle(
            color: fontColor,
            fontWeight: FontWeight.bold,
            fontSize: textSize,
            shadows: [
              Shadow(
                blurRadius: 2.0,
                color: outlineColor,
                offset: Offset(-1.0, 0.0),
              ),
              Shadow(
                blurRadius: 2.0,
                color: outlineColor,
                offset: Offset(1.0, 0.0),
              ),
              Shadow(
                blurRadius: 2.0,
                color: outlineColor,
                offset: Offset(0.0, 1.0),
              ),
            ],
          ),
          text: timeText);
      TextPainter tp = new TextPainter(
          text: span, textAlign: TextAlign.right, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, new Offset(screenRivalCarPosition.x - tp.width * 0.5, carImagePosition.dy - tp.height * 1.1));
    }
  }

  // My car
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

    final carImage = getCarImage(carDirection).image;

    final worldMyCarPositionZPer = 0.9;
    final worldMyCarPosition = bandList[1] * worldMyCarPositionZPer + bandList[2] * (1.0 - worldMyCarPositionZPer);

    // camera view coordinate
    final camviewMyCarPosition =
    calcPositionFromWorldToCamera(camera, cameraRotation, worldMyCarPosition);
    if (0 < camviewMyCarPosition.z) {
      // screen view coordinate
      final screenMyCarPosition = calcPositionFromCameraToScreen(
          camviewMyCarPosition, projectionPlaneDistance, screenHeight);

      final carImageScaleOnScreen = 20.0 / camviewMyCarPosition.z;
      final carImageSize = Size(
          paintBounds.width * carImageScaleOnScreen,
          carImage.height * (paintBounds.width * carImageScaleOnScreen) / carImage.width );
      final carImagePosition = Offset(
          screenMyCarPosition.x - carImageSize.width * 0.5,
          screenMyCarPosition.y - carImageSize.height * 0.8);
      _drawSprite(carImage, carImagePosition, carImageSize, Paint());

      if (carDirection != 0) {
        // Update sky offset
        if(carDirection < 0.0) {
          gameParameters.skyOffset += 2.0;
        } else{
          gameParameters.skyOffset -= 2.0;
        }

        // Draw Slip
        var slipImage;
        if (timeInMilliseconds % 200 < 100) {
          slipImage = ResourceContainer.instance.carSlip0.image;
        } else {
          slipImage = ResourceContainer.instance.carSlip1.image;
        }
        final slipImageSize = Size(
            paintBounds.width * carImageScaleOnScreen,
            slipImage.height * (paintBounds.width * carImageScaleOnScreen) / slipImage.width );
        final slipImagePosition = Offset(
            screenMyCarPosition.x - slipImageSize.width * 0.5,
            carImagePosition.dy + carImageSize.height - slipImageSize.height);
        _drawSprite(slipImage, slipImagePosition, slipImageSize, Paint());
      }
    }
  }

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
