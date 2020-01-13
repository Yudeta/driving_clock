import 'package:flutter/material.dart';

import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';


class ImageContainer {
  ImageContainer({
    @required this.name,
  }) : assert(name != null);

  final String name;

  ui.Image image;
  bool isLoaded = false;

  void load(){
    rootBundle.load(this.name).then( (bd) {
      Uint8List lst = new Uint8List.view(bd.buffer);
      ui.instantiateImageCodec(lst).then((codec) {
        codec.getNextFrame().then((frameInfo) {
          image = frameInfo.image;
          isLoaded = true;
        });
      });
    });
  }
}

class ResourceContainer {
  ResourceContainer._();

  static ResourceContainer _instance;

  static ResourceContainer get instance {
    if (_instance == null) {
      _instance = ResourceContainer._();
    }
    return _instance;
  }

  ImageContainer skyImage;
  ImageContainer carImage;
  ImageContainer carImageLeft;
  ImageContainer carImageRight;
  ImageContainer carSlip0;
  ImageContainer carSlip1;
  ImageContainer roadImage;

  void load(){
    skyImage = ImageContainer(name:"images/sky.png");
    skyImage.load();
    carImage = ImageContainer(name:"images/car.png");
    carImage.load();
    carImageLeft = ImageContainer(name:"images/img_car1_left.png");
    carImageLeft.load();
    carImageRight = ImageContainer(name:"images/img_car1_right.png");
    carImageRight.load();
    carSlip0 = ImageContainer(name:"images/slip0.png");
    carSlip0.load();
    carSlip1 = ImageContainer(name:"images/slip1.png");
    carSlip1.load();
    roadImage = ImageContainer(name:"images/road0.png");
    roadImage.load();
  }

}
