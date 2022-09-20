import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';

enum BulletMessageType {
  idle,
  init,
  update,
  ready,
  fire,
}

class BulletMessage {
  final BulletMessageType type;
  final dynamic data;
  BulletMessage({required this.data, required this.type});

  BulletMessage copyWith(
    BulletMessageType? type,
    dynamic data,
  ) {
    return BulletMessage(data: data ?? this.data, type: type ?? this.type);
  }

  static Map<String, dynamic> toJson(BulletMessage m) {
    return {
      'type': m.type.name,
      'data': m.data,
    };
  }
}

class Bullet {
  double vx = 0;
  double vy = 0;
  double ax = 0;
  double ay = 0;
  Offset start = Offset.zero;
  Offset pos = Offset.zero;
  Offset stop = Offset.zero;
  Size size = Size.zero;
  Bullet({
    required this.ax,
    required this.ay,
    required this.pos,
    required this.start,
    required this.stop,
    required this.vx,
    required this.vy,
    required this.size,
  });

  Bullet copyWith({
    double? vx = 0,
    double? vy = 0,
    double? ax = 0,
    double? ay = 0,
    Offset? start = Offset.zero,
    Offset? pos = Offset.zero,
    Offset? stop = Offset.zero,
    Size? size,
  }) {
    return Bullet(
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

void positionBullet(SendPort isolateToMainStream) {
  double t = 0;
  double stepTime = 0.016;
  double vBullets = 20;
  double aBullets = -5;
  Size poolsize = Size.zero;

  List<Offset> bullet = [];
  List<double> linear = [];

  ReceivePort mainToIsolateStream = ReceivePort();
  isolateToMainStream.send(BulletMessage.toJson(
    BulletMessage(
        data: mainToIsolateStream.sendPort, type: BulletMessageType.init),
  ));

  mainToIsolateStream.listen((data) async {
    if (data['type'] == BulletMessageType.init.name) {
      poolsize = data['data'];
      t = 0;
      stepTime = 0.016;
      vBullets = 20;
      aBullets = -5;
      bullet = [];
      linear = [];
      isolateToMainStream.send(BulletMessage.toJson(
        BulletMessage(data: null, type: BulletMessageType.ready),
      ));
    } else if (data['type'] == BulletMessageType.ready.name) {
      t = 0;
      isolateToMainStream.send(
        BulletMessage.toJson(
          BulletMessage(data: null, type: BulletMessageType.update),
        ),
      );
    } else if (data['type'] == BulletMessageType.fire.name) {
      t = 0;
      double arc = double.parse(data['data'].toString());
      linear.add(arc);
      bullet.add(Offset(poolsize.width / 2, poolsize.height));
      isolateToMainStream.send(
        BulletMessage.toJson(
          BulletMessage(data: null, type: BulletMessageType.update),
        ),
      );
    } else if (data['type'] == BulletMessageType.update.name) {
      if (poolsize.width > 0 && bullet.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 16));
        if (linear.isNotEmpty && bullet.isNotEmpty) {
          t = t + stepTime;
          double sign = linear[0] > 90 ? -1 : 1;
          if (linear[0] == 90) {
            bullet[0] = Offset(bullet[0].dx, bullet[0].dy - vBullets * t);
          } else {
            bullet[0] = Offset(
              bullet[0].dx + vBullets * t * sign,
              -(tan((linear[0] * pi) / 180) * (vBullets * t) * sign) +
                  bullet[0].dy,
            );
          }
          if (bullet[0].dx <= 0 ||
              bullet[0].dx >= poolsize.width ||
              bullet[0].dy <= 0) {
            bullet.removeAt(0);
            linear.removeAt(0);
            t = 0;
          }
        } else {
          t = 0;
        }

        isolateToMainStream.send(
          BulletMessage.toJson(
            BulletMessage(
                data: {'bullet': bullet}, type: BulletMessageType.update),
          ),
        );
      } else {
        isolateToMainStream.send(
          BulletMessage.toJson(
            BulletMessage(data: null, type: BulletMessageType.update),
          ),
        );
      }
    } else {
      isolateToMainStream.send(
        BulletMessage.toJson(
          BulletMessage(data: null, type: BulletMessageType.idle),
        ),
      );
    }
  });
}

class BulletPainter extends CustomPainter {
  final Size shapeSize;
  final Offset shapeOffset;
  BulletPainter({required this.shapeSize, required this.shapeOffset});
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
