import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'dart:isolate';

void myIsolate(SendPort isolateToMainStream) {
  ReceivePort mainToIsolateStream = ReceivePort();
  isolateToMainStream.send(mainToIsolateStream.sendPort);

  Offset offsetbase = Offset.zero;
  Offset offsetStep = Offset.zero;
  Offset offsetend = Offset.zero;

  Size poolsize = Size.zero;


  mainToIsolateStream.listen((data) async {
    print('[mainToIsolateStream] $data');
    if(data !=null && data is Size){
      poolsize = data;
      isolateToMainStream.send(poolsize);
    }else if(poolsize.width!=0){
      // await Future.delayed(const Duration(milliseconds: 1),(){
        if(((offsetStep.dx - offsetend.dx).abs() <= (offsetend.dx -offsetbase.dx).abs()/24) && ( (offsetStep.dy - offsetend.dy).abs() <= (offsetend.dx -offsetbase.dx).abs()/24)) {
          offsetbase = Offset(offsetend.dx, offsetend.dy);
          offsetend = Offset(Random.secure().nextInt((poolsize.width - 50).round()).toDouble(),Random.secure().nextInt((poolsize.height - 50).round()).toDouble());
        }else{
          offsetStep= Offset(offsetStep.dx +  (offsetend.dx -offsetbase.dx)/24, offsetStep.dy + (offsetend.dy -offsetbase.dy)/24);
          if(offsetStep.dx >5 && offsetStep.dx < (poolsize.width - 50 -5)  && offsetStep.dy >5 && offsetStep.dy < (poolsize.height - 50 -5)  ){
            // isolateToMainStream.send(offsetStep);yyyZZ
          }else{
            offsetStep = offsetend;
          }
        }
        isolateToMainStream.send(offsetStep);
      // });
    }else{
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

class _MyHomePageState extends State<MyHomePage>{
  final ReceivePort isolateToMainStream = ReceivePort();
  late final SendPort mainToIsolateStream ;
  late final Isolate myIsolateInstance;
  final StreamController<dynamic> pipe = StreamController();

  Future<void>? _initData;
  Future<void> initData() async{
    isolateToMainStream.listen((data) {
      if (data is SendPort) {
        mainToIsolateStream = data;
        // mainToIsolateStream.send(MediaQuery.of(context).size);
      } else if (data is Offset) {
        pipe.add(data);
        print('[isolateToMainStream] $data');
        mainToIsolateStream?.send('Updata offset susscess');
      }
      else{
        mainToIsolateStream?.send('This is from main()');
      }
    });

    myIsolateInstance = await Isolate.spawn(myIsolate, isolateToMainStream.sendPort);

    return Future.value();
  }

  @override
  void initState() {
    _initData=initData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: _initData,
        builder: (context, snapshot) {
          if(snapshot.connectionState==ConnectionState.done){
            mainToIsolateStream.send(MediaQuery.of(context).size);
            return Container(
              color: Colors.blue,
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child:  StreamBuilder(
              stream: pipe.stream,
              builder: (context, snap) {
                if(snap.data!=null && snap.data is Offset){
                  return SizedBox.fromSize(
                    size: MediaQuery.of(context).size,
                    child: CustomPaint(
                      painter: ShapePainter(
                        shapeOffset: snap.data,
                        shapeSize: Size(50,50),
                      ),
                    ),
                  );
                }
                return SizedBox.square();
              },
            ),
            );
          }
          return Center(child: CircularProgressIndicator(),);
        },
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
//             stream: masterPort,
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
  ShapePainter({required this.shapeSize,required this.shapeOffset});
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
    ..color = Colors.black
    ..strokeWidth = 5
    ..style = PaintingStyle.fill
    ..strokeCap = StrokeCap.round;

    Offset center = Offset(shapeSize.width / 2 + shapeOffset.dx, shapeSize.height / 2 + shapeOffset.dy);

    canvas.drawCircle(center, shapeSize.width/2, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    // TODO: implement shouldRepaint
    return true;
  }
}
