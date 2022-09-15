import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'dart:isolate';

import 'package:test_flutter/core_widget.dart';

//  [Quaratic equations]
void positionIsolate(SendPort isolateToMainStream) {
  double vx = 5;
  double vy = 5;
  double ax = 0.5;
  double ay = 0.5;
  double t = 0;
  double stepTime = 0.001;

  ReceivePort mainToIsolateStream = ReceivePort();
  isolateToMainStream.send(mainToIsolateStream.sendPort);

  Offset offsetbase = Offset.zero;
  Offset offsetStep = Offset.zero;
  Offset offsetend = Offset.zero;

  Size poolsize = Size.zero;

  List<Offset> bullet = [];
  List<double> linear = [];

  mainToIsolateStream.listen((data) async {
    // print(data);
    if (data != null && data is Map) {
      if (data['message'] == "pumpBullet") {
        double arc = double.parse(data['arc'].toString());
        print(arc);
        // linear.add(data['arc']);
        // bullet.add(Offset(poolsize.width / 2, poolsize.height));
      }
    } else if (data != null && data is Size) {
      poolsize = data;
      vx = 50;
      vy = 30;
      ax = 0;
      ay = 0;
      t = 0;
      stepTime = 0.001;
      isolateToMainStream.send(poolsize);
    } else if (data is String && poolsize.width != 0) {
      await Future.delayed(const Duration(milliseconds: 1));
      if (linear.isNotEmpty) {
        // bullet[0] = Offset((poolsize.height - 0.1 * t) / data['arc'],
        //     poolsize.height - 0.1 * t);
        // if (bullet[0].dx < 0 ||
        //     bullet[0].dx > poolsize.width ||
        //     bullet[0].dy < 0) {
        //   bullet.removeAt(0);
        // }
      }

      if (t == 0) {
        offsetbase = Offset(offsetStep.dx, offsetStep.dy);
        offsetend = Offset(
            Random.secure().nextInt((poolsize.width - 50).round()).toDouble(),
            Random.secure().nextInt((poolsize.height - 50).round()).toDouble());
        stepTime =
            ((offsetend.dx - offsetbase.dx) / poolsize.width).abs() / 100;
        t = t + stepTime;
      } else {
        if ((Offset(offsetend.dx - offsetStep.dx, offsetend.dx - offsetStep.dx))
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
      isolateToMainStream.send({'flyer': offsetStep, 'bullet': bullet});
    } else {
      isolateToMainStream.send("stream isolate");
    }
  });

  isolateToMainStream.send('This is from myIsolate()');
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ReceivePort isolateToMainStream = ReceivePort();
  late final SendPort mainToIsolateStream;
  late final Isolate myIsolateInstance;
  final StreamController<dynamic> pipe = StreamController();
  final StreamController<dynamic> pipeBullet = StreamController();
  late final CustomButtonState gunControll;

  Future<void>? _initData;
  Future<void> initData() async {
    isolateToMainStream.listen((data) {
      if (data is SendPort) {
        mainToIsolateStream = data;
      } else if (data is Map) {
        pipe.add(data['flyer']);
        // print(data['bullet']);
        if (data['bullet'].isNotEmpty) {
          pipeBullet.add(data['bullet']);
        }

        mainToIsolateStream.send('Updata offset susscess');
      } else {
        mainToIsolateStream.send('This is from main()');
      }
    });

    myIsolateInstance =
        await Isolate.spawn(positionIsolate, isolateToMainStream.sendPort);

    return Future.value();
  }

  double currentDx = 0;

  @override
  void initState() {
    gunControll = CustomButtonState();
    _initData = initData();
    super.initState();
  }

  @override
  void dispose() {
    myIsolateInstance.kill();
    pipe.close();
    pipeBullet.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FutureBuilder(
            future: _initData,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                mainToIsolateStream.send(Size(MediaQuery.of(context).size.width,
                    MediaQuery.of(context).size.height - 200));
                return Container(
                  color: Colors.blue,
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height - 200,
                  child: Stack(
                    children: [
                      StreamBuilder(
                        stream: pipe.stream,
                        builder: (context, snap) {
                          if (snap.data != null && snap.data is Offset) {
                            return SizedBox.fromSize(
                              size: MediaQuery.of(context).size,
                              child: CustomPaint(
                                painter: ShapePainter(
                                  shapeOffset: snap.data,
                                  shapeSize: Size(50, 50),
                                ),
                              ),
                            );
                          }
                          return SizedBox.square();
                        },
                      ),
                      StreamBuilder(
                        stream: pipeBullet.stream,
                        builder: (context, snap) {
                          if (snap.data != null &&
                              snap.data is List &&
                              snap.data.isNotEmpty) {
                            return SizedBox.fromSize(
                              size: MediaQuery.of(context).size,
                              child: CustomPaint(
                                painter: ShapePainter(
                                  shapeOffset: snap.data[0],
                                  shapeSize: Size(10, 10),
                                ),
                              ),
                            );
                          }
                          return SizedBox.square();
                        },
                      ),
                    ],
                  ),
                );
              }
              return const Center(
                child: CircularProgressIndicator(),
              );
            },
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onPanEnd: (details) {
                        // print("end");
                        currentDx = 0;
                      },
                      onPanStart: (details) {
                        // print('start again');
                        currentDx = details.globalPosition.dx;
                      },
                      onPanUpdate: (details) {
                        if (currentDx < details.globalPosition.dx) {
                          if (gunControll.radian < 45) {
                            gunControll.radian++;
                          }
                        } else if (currentDx > details.globalPosition.dx) {
                          if (gunControll.radian > -45) {
                            gunControll.radian--;
                          }
                        }
                        currentDx = details.globalPosition.dx;
                      },
                      child: Container(
                        height: 90,
                        width: 90,
                        color: Colors.red,
                      ),
                    ),
                    Container(
                      width: 150,
                      child: UniCoreWidget(
                        controller: gunControll,
                        builder: (context, child) {
                          // print(gunControll.radian);
                          return Transform.rotate(
                            angle: (gunControll.radian * pi / 180),
                            child: Container(
                              height: 200,
                              width: 50,
                              color: Colors.green,
                            ),
                          );
                        },
                      ),
                    ),
                    Listener(
                      onPointerDown: (event) {
                        mainToIsolateStream.send({
                          'message': 'pumpBullet',
                          'arc': (gunControll.radian * pi / 180)
                        });
                      },
                      child: Container(
                        height: 90,
                        width: 90,
                        color: Colors.yellow,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
// class _MyHomePageState extends State<MyHomePage> {
//   final ReceivePort masterPort = ReceivePort();
//   late final SendPort slaveport ;
//   late final Isolate isolate;
//   static Size poolsize = Size(300,300);
//   int count = 0 ;
//
//   static Future<void> randomPosistion(SendPort sendPort) async{
//     Offset offsetbase = Offset.zero;
//     Offset offsetStep = Offset.zero;
//     Offset offsetend = Offset.zero;
//     final ReceivePort workerPort = ReceivePort();
//
//     sendPort.send(workerPort.sendPort);
//     print(">>.start listen");
//     workerPort.listen((message)  async {
//       // await Future.delayed(const Duration(milliseconds: 1),(){
//         if(((offsetStep.dx - offsetend.dx).abs() <= (offsetend.dx -offsetbase.dx).abs()/300) && ( (offsetStep.dy - offsetend.dy).abs() <= (offsetend.dx -offsetbase.dx).abs()/300)) {
//           offsetbase = Offset(offsetend.dx, offsetend.dy);
//           offsetend = Offset(Random.secure().nextInt((poolsize.width - 50).round()).toDouble(),Random.secure().nextInt((poolsize.height - 50).round()).toDouble());
//         }
//
//         offsetStep= Offset(offsetStep.dx +  (offsetend.dx -offsetbase.dx)/300, offsetStep.dy + (offsetend.dy -offsetbase.dy)/300);
//         if(offsetStep.dx >5 && offsetStep.dx < (poolsize.width - 50 -5)  && offsetStep.dy >5 && offsetStep.dy < (poolsize.height - 50 -5)  ){
//           sendPort.send(offsetStep);
//         }else{
//           offsetStep = offsetend;
//         }
//       // });
//     });
//
//       // while(true){
//       //   await Future.delayed(const Duration(milliseconds: 1),(){
//       //     if(((offsetStep.dx - offsetend.dx).abs() <= (offsetend.dx -offsetbase.dx).abs()/300) && ( (offsetStep.dy - offsetend.dy).abs() <= (offsetend.dx -offsetbase.dx).abs()/300)) {
//       //       offsetbase = Offset(offsetend.dx, offsetend.dy);
//       //       offsetend = Offset(Random.secure().nextInt((poolsize.width - 50).round()).toDouble(),Random.secure().nextInt((poolsize.height - 50).round()).toDouble());
//       //     }
//       //
//       //     offsetStep= Offset(offsetStep.dx +  (offsetend.dx -offsetbase.dx)/300, offsetStep.dy + (offsetend.dy -offsetbase.dy)/300);
//       //     if(offsetStep.dx >5 && offsetStep.dx < (poolsize.width - 50 -5)  && offsetStep.dy >5 && offsetStep.dy < (poolsize.height - 50 -5)  ){
//       //       sendPort.send(offsetStep);
//       //     }else{
//       //       offsetStep = offsetend;
//       //     }
//       //   });
//       // }
//   }
//   Future? _initdata;
//
//   Future initdata() async{
//     isolate = await Isolate.spawn(randomPosistion, masterPort.sendPort);
//     // masterPort.listen((message) {
//     //   if(message.data!=null && message.data is SendPort){
//     //     slaveport = message;
//     //     masterPort.close();
//     //   }
//     // });
//
//     return Future.value();
//   }
//   @override
//   void initState() {
//     _initdata = initdata();
//     super.initState();
//   }
//
//   @override
//   void dispose() {
//     super.dispose();
//     masterPort.close();
//     isolate.kill();
//   }
//
//   // @override
//   // void didUpdateWidget(covariant MyHomePage oldWidget) {
//   //   print(oldWidget.)
//   //   super.didUpdateWidget(oldWidget);
//   // }
//   Capability? pauseCap;
//   void _incrementCounter() {
//     isolate.resume(pauseCap!);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: FutureBuilder(
//         future: _initdata,
//         builder: (context, snapshotF) {
//         if(snapshotF.connectionState==ConnectionState.done){
//           return StreamBuilder<dynamic>(
//             stream: masterPort,snapshotS
//             builder: (context, snapshotS) {
//               count ++;
//               Offset pos = Offset.zero;
//
//               if(snapshotS.data!=null && snapshotS.data is SendPort){
//                 print(">>>>>>>>init>>>>>>>>>");
//                 print(snapshotS.data);
//                 slaveport = snapshotS.data;
//                 return SizedBox.shrink();
//               }
//
//               if(snapshotS.data!=null && snapshotS.data is Offset){
//                 print(">>>>>>>>>slave port>>>>>>>>");
//                 print(slaveport);
//                 // slaveport.send("next");
//                 pos = snapshotS.data as Offset;
//                 return SizedBox.fromSize(
//                   size: MediaQuery.of(context).size,
//                   child: CustomPaint(
//                     painter: ShapePainter(
//                       shapeOffset: pos,
//                       shapeSize: Size(50,50),
//                     ),
//                   ),
//                 );
//               }
//
//               return SizedBox.shrink();
//
//             },
//           );
//
//           // return Center(
//           //   child: Container(
//           //     color: Colors.blue,
//           //     height: poolsize.height,
//           //     width: poolsize.width,
//           //     child: Stack(children: [
//           //       StreamBuilder<dynamic>(
//           //         stream: receivePort,
//           //         builder: (context, snapshot) {
//           //           Offset pos = Offset.zero;
//           //           if(snapshot.data!=null){
//           //             pos = snapshot.data as Offset;
//           //           }
//           //           return Positioned(
//           //             left: pos.dx,
//           //             top: pos.dy,
//           //             child: Listener(
//           //               onPointerDown: (e){
//           //                 pauseCap = isolate.pause();
//           //               },
//           //               child: Container(height: 50,width: 50, color: Colors.red,),
//           //             ),
//           //           );
//           //         },
//           //       ),
//           //     ],),
//           //   ),
//           // );
//         }
//         return Center(child: Container(child: CircularProgressIndicator(),),);
//       },),
//
//       floatingActionButton: FloatingActionButton(
//         onPressed: _incrementCounter,
//         tooltip: 'Increment',
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }

class ShapePainter extends CustomPainter {
  final Size shapeSize;
  final Offset shapeOffset;
  ShapePainter({required this.shapeSize, required this.shapeOffset});
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
    // TODO: implement shouldRepaint
    return true;
  }
}
