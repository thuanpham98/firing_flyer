import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';

const double g = 9.80665;

enum FlyerMessageType {
  idle,
  init,
  update,
  ready,
  killed,
  win,
}

class FlyerMessage {
  final FlyerMessageType type;
  final dynamic data;
  FlyerMessage({required this.data, required this.type});

  FlyerMessage copyWith(
    FlyerMessageType? type,
    dynamic data,
  ) {
    return FlyerMessage(data: data ?? this.data, type: type ?? this.type);
  }

  static Map<String, dynamic> toJson(FlyerMessage m) {
    return {
      'type': m.type.name,
      'data': m.data,
    };
  }
}

class Flyer {
  double mass = 0;
  double vx = 0;
  double vy = 0;
  double ax = 0;
  double ay = 0;
  Offset start = Offset.zero;
  Offset pos = Offset.zero;
  Offset stop = Offset.zero;
  Size size = Size.zero;
  Flyer({
    required this.ax,
    required this.ay,
    required this.pos,
    required this.start,
    required this.stop,
    required this.vx,
    required this.vy,
    required this.size,
    required this.mass,
  });

  Flyer copyWith({
    double? mass = 0,
    double? vx = 0,
    double? vy = 0,
    double? ax = 0,
    double? ay = 0,
    Offset? start,
    Offset? pos,
    Offset? stop,
    Size? size,
  }) {
    return Flyer(
      ax: ax ?? this.ax,
      ay: ay ?? this.ay,
      pos: pos ?? this.pos,
      start: start ?? this.start,
      stop: stop ?? this.start,
      vx: vx ?? this.vx,
      vy: vy ?? this.vy,
      size: size ?? this.size,
      mass: mass ?? this.mass,
    );
  }
}

void positionFlyer(SendPort isolateToMainStream) {
  double t = 0;
  double stepTime = 0.016;

  ReceivePort mainToIsolateStream = ReceivePort();
  isolateToMainStream.send(FlyerMessage.toJson(
    FlyerMessage(
        data: mainToIsolateStream.sendPort, type: FlyerMessageType.init),
  ));
  Size poolsize = Size.zero;
  Flyer flyer = Flyer(
    ax: 0,
    ay: 0,
    pos: Offset.zero,
    start: Offset.zero,
    stop: Offset.zero,
    vx: 0,
    vy: 0,
    size: Size.zero,
    mass: 0,
  );

  mainToIsolateStream.listen((data) async {
    if (data['type'] == FlyerMessageType.init.name) {
      poolsize = data['data'];
      print(' inittt ${poolsize}');
      t = 0;
      stepTime = 0.016;
      flyer = flyer.copyWith(
        ax: 0.5,
        ay: 0.5,
        vx: 60,
        vy: 60,
        size: const Size(50, 50),
        mass: 0.001,
      );
      isolateToMainStream.send(FlyerMessage.toJson(
        FlyerMessage(data: null, type: FlyerMessageType.ready),
      ));
    } else if (data['type'] == FlyerMessageType.ready.name) {
      isolateToMainStream.send(
        FlyerMessage.toJson(
          FlyerMessage(data: null, type: FlyerMessageType.update),
        ),
      );
    } else if (data['type'] == FlyerMessageType.killed.name) {
      t = 0;
      if (flyer.ay < 15) {
        flyer.ay = flyer.ay + 0.001;
        flyer.ax = flyer.ax + 0.001;
        print("UPdata ayyyyy");
      }
      flyer.pos = Offset(
          Random.secure()
              .nextInt((poolsize.width - flyer.size.width).round())
              .toDouble(),
          Random.secure()
              .nextInt((poolsize.height - flyer.size.height - 200).round())
              .toDouble());
      isolateToMainStream.send(
        FlyerMessage.toJson(
          FlyerMessage(data: null, type: FlyerMessageType.killed),
        ),
      );
    } else if (data['type'] == FlyerMessageType.update.name) {
      if (poolsize.width > 0) {
        await Future.delayed(const Duration(milliseconds: 16));
        if (t == 0) {
          flyer.start = Offset(flyer.pos.dx, flyer.pos.dy);
          flyer.stop = Offset(
              Random.secure()
                  .nextInt((poolsize.width - flyer.size.width).round())
                  .toDouble(),
              Random.secure()
                  .nextInt((poolsize.height - flyer.size.height).round())
                  .toDouble());
          t = t + stepTime;
        } else {
          double signX = (flyer.stop.dx - flyer.start.dx).sign;
          double signY = (flyer.stop.dy - flyer.start.dy).sign;
          if (((flyer.stop.dx - flyer.pos.dx).abs() < 5 &&
                  (flyer.stop.dy - flyer.pos.dy).abs() < 5) ||
              (flyer.pos.dy.abs() > poolsize.height) ||
              (flyer.pos.dx.abs() > poolsize.width) ||
              (flyer.pos.dx.abs() < 0) ||
              (flyer.pos.dy.abs() < 0)) {
            t = 0;
            flyer.pos = Offset(
              flyer.stop.dx,
              flyer.stop.dy,
            );
          } else {
            double newX = flyer.start.dx +
                signX * (flyer.vx * t + 0.5 * flyer.ax * pow(t, 2));
            double newY = flyer.start.dy +
                signY * (flyer.vy * t + 0.5 * flyer.ay * pow(t, 2));

            if ((flyer.stop.dx - flyer.pos.dx).abs() < 5) {
              newX = flyer.stop.dx;
            }
            if ((flyer.stop.dy - flyer.pos.dy).abs() < 5) {
              newY = flyer.stop.dy;
            }

            flyer.pos = Offset(
              newX,
              newY,
            );
            if ((newY.abs() + 100 > poolsize.height)) {
              isolateToMainStream.send(
                FlyerMessage.toJson(
                  FlyerMessage(data: null, type: FlyerMessageType.win),
                ),
              );
            }
            t = t + stepTime;
          }
        }
        isolateToMainStream.send(
          FlyerMessage.toJson(
            FlyerMessage(data: {
              'flyer': flyer.pos,
            }, type: FlyerMessageType.update),
          ),
        );
      } else {
        isolateToMainStream.send(
          FlyerMessage.toJson(
            FlyerMessage(data: null, type: FlyerMessageType.update),
          ),
        );
      }
    } else {
      isolateToMainStream.send(
        FlyerMessage.toJson(
          FlyerMessage(data: null, type: FlyerMessageType.idle),
        ),
      );
    }
  });
}

class FlyerPainter extends CustomPainter {
  final Size shapeSize;
  final Offset shapeOffset;
  FlyerPainter({required this.shapeSize, required this.shapeOffset});
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 5
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    Offset center = Offset(shapeSize.width / 2 + shapeOffset.dx,
        shapeSize.height / 2 + shapeOffset.dy);

    canvas.drawCircle(center, shapeSize.width / 2, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
