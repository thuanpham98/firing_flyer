import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'dart:isolate';

import 'package:test_flutter/core_widget.dart';
import 'package:test_flutter/game_engine/flyer.dart';
import 'package:test_flutter/thread_bool/thread_pool.dart';

class Bullets {
  static bool checkDone = false;
}

void main() async {
  if (ThreadPool.index != null) {
    await ThreadPool.disposeThreadPool();
  }
  ThreadPool.initThreadPool(maxThread: 2);
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
  final StreamController<dynamic> pipe = StreamController();
  final StreamController<dynamic> pipeBullet = StreamController();
  late final CustomButtonState gunControll;
  late final Node? node;

  Future<void>? _initData;
  Future<void> initData() async {
    node = await ThreadPool.createTask(positionIsolate);

    node?.masterPort.listen((data) {
      if (data is SendPort) {
        node?.workerPort = data;
      } else if (data is Map) {
        pipe.add(data['flyer']);
        pipeBullet.add(data['bullet']);

        node?.workerPort?.send('Updata offset susscess');
      } else {
        node?.workerPort?.send('This is from main()');
      }
    });
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
    ThreadPool.deleteTask(node!.index);
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
                node?.workerPort?.send(Size(MediaQuery.of(context).size.width,
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
                          // print(snap.data);
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
                          Bullets.checkDone = false;
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
                      onPointerDown: (event) async {
                        if (!Bullets.checkDone) {
                          Bullets.checkDone = true;
                          node?.workerPort?.send({
                            'message': 'pumpBullet',
                            'arc': (90 - gunControll.radian)
                          });
                        }
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
