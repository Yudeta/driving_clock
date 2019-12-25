import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_clock_helper/model.dart';
import 'package:intl/intl.dart';

import 'draw_driving.dart';
import 'resource_container.dart';

class DrivingClock extends StatefulWidget {
  const DrivingClock(this.model);

  final ClockModel model;

  @override
  _DrivingClockState createState() => _DrivingClockState();
}

class _DrivingClockState extends State<DrivingClock> {
  var _now = DateTime.now();
  var _is24HourFormat = true;
  var _temperature = '';
  var _temperatureRange = '';
  var _condition = '';
  var _location = '';

  Ticker _ticker;

  @override
  void initState() {
    super.initState();
    widget.model.addListener(_updateModel);
    // Set the initial values.
    _updateModel();

    ResourceContainer.instance.load();

    // initialize ticker
    _ticker = Ticker(_updateTime);
    _ticker.start();
  }

  @override
  void didUpdateWidget(DrivingClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.model != oldWidget.model) {
      oldWidget.model.removeListener(_updateModel);
      widget.model.addListener(_updateModel);
    }
  }

  @override
  void dispose() {
    _ticker?.stop();
    widget.model.removeListener(_updateModel);
    super.dispose();
  }

  void _updateModel() {
    setState(() {
      _is24HourFormat = widget.model.is24HourFormat;
      _temperature = widget.model.temperatureString;
      _temperatureRange = '(${widget.model.low} - ${widget.model.highString})';
      _condition = widget.model.weatherString;
      _location = widget.model.location;
    });
  }

  void _updateTime(Duration d) {
    setState(() {
      _now = DateTime.now();
    });
  }

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
        label: 'Clock with time $time',
        value: time,
      ),
      child: DrawnDriving(dateTime: _now, is24HourFormat: _is24HourFormat),

//      child: Container(
//        color: Color(0xFFD2E3FC),
//        child: Stack(
//          children: [
//            // Example of a hand drawn with [CustomPainter].
//            DrawnHand(count:count),
//          ],
//        ),
//      ),
    );
  }
}
