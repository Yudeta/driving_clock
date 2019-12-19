import 'dart:io';

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_clock_helper/customizer.dart';
import 'package:flutter_clock_helper/model.dart';
import 'package:intl/intl.dart';
import 'package:flutter/scheduler.dart';



class Fps {
  Fps._();

  static Fps _instance;

  static Fps get instance {
    if (_instance == null) {
      _instance = Fps._();
    }
    return _instance;
  }

  int count = 0;
  int startTime = -1;
  double fps = 0.0;

  double update(){
    var now = new DateTime.now().millisecondsSinceEpoch;
    if(startTime < 0){
      startTime = now;
    }else{
      count++;
      if(1000 <= now - startTime) {
        fps = count / ((now - startTime) / 1000.0);
        startTime = now;
        count = 0;
      }
    }
    return fps;
  }
}

class DrawnHand extends StatelessWidget {
  const DrawnHand({
    @required this.count,
  })  : assert(count != null);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _HandPainter(count: count),
        ),
      ),
    );
  }
}

/// [CustomPainter] that draws a clock hand.
class _HandPainter extends CustomPainter {
  _HandPainter({
    @required this.count,
  })  : assert(count != null);

  int count;

  @override
  void paint(Canvas canvas, Size size) {
    final center = (Offset.zero & size).center;
    // We want to start at the top, not at the x-axis, so add pi/2.
//    final angle = angleRadians - math.pi / 2.0;
//    final length = size.shortestSide * 0.5 * handSize;
    final position = center + Offset((count % 100).toDouble(), 0);
    final linePaint = Paint()
      ..color = Color(0xFF4285F4)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(center, position, linePaint);

    var fps = Fps.instance.update();
    TextSpan span = new TextSpan(style: new TextStyle(color: Colors.blue[800]), text: "Fps:" + fps.toString());
    TextPainter tp = new TextPainter(text: span, textAlign: TextAlign.left, textDirection: ui.TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, new Offset(0.0, 20.0));

  }

  @override
  bool shouldRepaint(_HandPainter oldDelegate) {
    return true;
  }
}

class AnalogClock extends StatefulWidget {
  const AnalogClock(this.model);

  final ClockModel model;

  @override
  _AnalogClockState createState() => _AnalogClockState();
}



var count = 0;

class _AnalogClockState extends State<AnalogClock> {

  Ticker t;

//  var _now = DateTime.now();
  var _temperature = '';
  var _temperatureRange = '';
  var _condition = '';
  var _location = '';

//  Timer _timer;

  @override
  void initState() {
    t = Ticker(up);
    super.initState();
    widget.model.addListener(_updateModel);
    // Set the initial values.
//    _updateTime();
    _updateModel();
    t.start();
  }

  up(Duration d) {
    setState(() {
      count = count + 1;
    });
  }

  @override
  void didUpdateWidget(AnalogClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.model != oldWidget.model) {
      oldWidget.model.removeListener(_updateModel);
      widget.model.addListener(_updateModel);
    }
  }

  @override
  void dispose() {
//    _timer?.cancel();
    widget.model.removeListener(_updateModel);
    super.dispose();
  }

  void _updateModel() {
    setState(() {
      _temperature = widget.model.temperatureString;
      _temperatureRange = '(${widget.model.low} - ${widget.model.highString})';
      _condition = widget.model.weatherString;
      _location = widget.model.location;
    });
  }

//  void _updateTime() {
//    setState(() {
//      _count = _count + 1;
//      // Update once per second. Make sure to do it at the beginning of each
//      // new second, so that the clock is accurate.
////      _timer = Timer(
////        Duration(milliseconds: 16) - Duration(milliseconds: _now.millisecond),
////        _updateTime,
////      );
//    });
//  }

  @override
  Widget build(BuildContext context) {
    // There are many ways to apply themes to your clock. Some are:
    //  - Inherit the parent Theme (see ClockCustomizer in the
    //    flutter_clock_helper package).
    //  - Override the Theme.of(context).colorScheme.
    //  - Create your own [ThemeData], demonstrated in [AnalogClock].
    //  - Create a map of [Color]s to custom keys, demonstrated in
    //    [DigitalClock].

    final time = DateFormat.Hms().format(DateTime.now());

    return Semantics.fromProperties(
      properties: SemanticsProperties(
        label: 'Analog clock with time $time',
        value: time,
      ),
      child: Container(
        color: Color(0xFFD2E3FC),
        child: Stack(
          children: [
            // Example of a hand drawn with [CustomPainter].
            DrawnHand(count:count),
          ],
        ),
      ),
    );
  }
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

  runApp(ClockCustomizer((ClockModel model) => AnalogClock(model)));
}
