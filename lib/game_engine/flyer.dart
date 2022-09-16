import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';

enum FlyerMessageType {
  idle,
  init,
  update,
  ready,
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
  });

  Flyer copyWith({
    double? vx = 0,
    double? vy = 0,
    double? ax = 0,
    double? ay = 0,
    Offset? start = Offset.zero,
    Offset? pos = Offset.zero,
    Offset? stop = Offset.zero,
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
    );
  }
}

void positionFlyer(SendPort isolateToMainStream) {
  double vx = 5;
  double vy = 5;
  double ax = 0.5;
  double ay = 0.5;
  double t = 0;
  double stepTime = 0.001;
  double tBullets = 0.01;
  double vBullets = 20;

  ReceivePort mainToIsolateStream = ReceivePort();
  isolateToMainStream.send(FlyerMessage.toJson(
    FlyerMessage(
        data: mainToIsolateStream.sendPort, type: FlyerMessageType.init),
  ));

  Offset offsetbase = Offset.zero;
  Offset offsetStep = Offset.zero;
  Offset offsetend = Offset.zero;

  Size poolsize = Size.zero;

  List<Offset> bullet = [];
  List<double> linear = [];

  mainToIsolateStream.listen((data) async {
    if (data['type'] == FlyerMessageType.init.name) {
      poolsize = data['data'];
      vx = 50;
      vy = 30;
      ax = 0;
      ay = 0;
      t = 0;
      stepTime = 0.001;
      isolateToMainStream.send(FlyerMessage.toJson(
        FlyerMessage(data: null, type: FlyerMessageType.ready),
      ));
    } else if (data['type'] == FlyerMessageType.ready.name) {
      isolateToMainStream.send(
        FlyerMessage.toJson(
          FlyerMessage(data: null, type: FlyerMessageType.update),
        ),
      );
    } else if (data['type'] == FlyerMessageType.update.name) {
      if (poolsize.width > 0) {
        await Future.delayed(const Duration(microseconds: 1000));
        if (linear.isNotEmpty && bullet.isNotEmpty) {
          double sign = linear[0] > 90 ? -1 : 1;
          if (linear[0] == 90) {
            bullet[0] = Offset(bullet[0].dx, bullet[0].dy - 0.1 * t);
          } else {
            bullet[0] = Offset(
              bullet[0].dx + vBullets * tBullets * sign,
              -(tan((linear[0] * pi) / 180) * (vBullets * tBullets) * sign) +
                  bullet[0].dy,
            );
          }

          if ((Offset(offsetend.dx - bullet[0].dx, offsetend.dy - bullet[0].dy))
                  .distance <
              30) {
            print("arrow>>>>");

            t = 0;
            offsetbase = Offset.zero;
            offsetStep = Offset.zero;
            offsetend = Offset.zero;
            bullet.removeAt(0);
            linear.removeAt(0);
          } else {
            if (bullet[0].dx < 0 ||
                bullet[0].dx > poolsize.width ||
                bullet[0].dy < 0) {
              bullet.removeAt(0);
              linear.removeAt(0);
            }
          }
        }

        if (t == 0) {
          offsetbase = Offset(offsetStep.dx, offsetStep.dy);
          offsetend = Offset(
              Random.secure().nextInt((poolsize.width - 50).round()).toDouble(),
              Random.secure()
                  .nextInt((poolsize.height - 50).round())
                  .toDouble());
          stepTime =
              ((offsetend.dx - offsetbase.dx) / poolsize.width).abs() / 100;
          t = t + stepTime;
        } else {
          if ((Offset(offsetend.dx - offsetStep.dx,
                      offsetend.dx - offsetStep.dx))
                  .distance <
              5) {
            t = 0;
          } else {
            double signX = (offsetend.dx - offsetbase.dx).sign;
            double signY = (offsetend.dy - offsetbase.dy).sign;
            offsetStep = Offset(
              offsetbase.dx + signX * (vx * t + 0.5 * ax * pow(t, 2)),
              offsetbase.dy + signY * (vy * t + 0.5 * ay * pow(t, 2)),
            );
            t = t + stepTime;
          }
        }
        isolateToMainStream.send(
          FlyerMessage.toJson(
            FlyerMessage(data: {
              'flyer': offsetStep,
              'bullet': bullet.isEmpty ? null : bullet
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
    // try {
    //   data = json.decode(data);
    //   print(data is FlyerMessage);
    // } catch (e) {
    //   print(e);
    // }
    // print(data);
    // if (data != null && data is Map) {
    //   if (data['message'] == "pumpBullet") {
    //     double arc = double.parse(data['arc'].toString());
    //     linear.add(arc);
    //     bullet.add(Offset(poolsize.width / 2, poolsize.height));
    //     // print("new bullet");
    //     // print(bullet);
    //   }
    // } else if (data != null && data is Size) {
    //   poolsize = data;
    //   vx = 50;
    //   vy = 30;
    //   ax = 0;
    //   ay = 0;
    //   t = 0;
    //   stepTime = 0.001;
    //   isolateToMainStream.send(poolsize);
    // } else if (data is String && poolsize.width != 0) {
    //   await Future.delayed(const Duration(microseconds: 1000));
    //   if (linear.isNotEmpty && bullet.isNotEmpty) {
    //     double sign = linear[0] > 90 ? -1 : 1;
    //     if (linear[0] == 90) {
    //       bullet[0] = Offset(bullet[0].dx, bullet[0].dy - 0.1 * t);
    //     } else {
    //       bullet[0] = Offset(
    //         bullet[0].dx + vBullets * tBullets * sign,
    //         -(tan((linear[0] * pi) / 180) * (vBullets * tBullets) * sign) +
    //             bullet[0].dy,
    //       );
    //     }

    //     if ((Offset(offsetend.dx - bullet[0].dx, offsetend.dy - bullet[0].dy))
    //             .distance <
    //         30) {
    //       print("arrow>>>>");

    //       t = 0;
    //       offsetbase = Offset.zero;
    //       offsetStep = Offset.zero;
    //       offsetend = Offset.zero;
    //       bullet.removeAt(0);
    //       linear.removeAt(0);
    //     } else {
    //       if (bullet[0].dx < 0 ||
    //           bullet[0].dx > poolsize.width ||
    //           bullet[0].dy < 0) {
    //         bullet.removeAt(0);
    //         linear.removeAt(0);
    //       }
    //     }
    //   }

    //   if (t == 0) {
    //     offsetbase = Offset(offsetStep.dx, offsetStep.dy);
    //     offsetend = Offset(
    //         Random.secure().nextInt((poolsize.width - 50).round()).toDouble(),
    //         Random.secure().nextInt((poolsize.height - 50).round()).toDouble());
    //     stepTime =
    //         ((offsetend.dx - offsetbase.dx) / poolsize.width).abs() / 100;
    //     t = t + stepTime;
    //   } else {
    //     if ((Offset(offsetend.dx - offsetStep.dx, offsetend.dx - offsetStep.dx))
    //             .distance <
    //         5) {
    //       t = 0;
    //     } else {
    //       double signX = (offsetend.dx - offsetbase.dx).sign;
    //       double signY = (offsetend.dy - offsetbase.dy).sign;
    //       offsetStep = Offset(
    //         offsetbase.dx + signX * (vx * t + 0.5 * ax * pow(t, 2)),
    //         offsetbase.dy + signY * (vy * t + 0.5 * ay * pow(t, 2)),
    //       );
    //       t = t + stepTime;
    //     }
    //   }
    //   isolateToMainStream.send(
    //       {'flyer': offsetStep, 'bullet': bullet.isEmpty ? null : bullet});
    // } else {
    //   isolateToMainStream.send("stream isolate");
    // }
  });

  // isolateToMainStream.send('This is from myIsolate()');
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
