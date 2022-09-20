import 'dart:async';
import 'dart:math';

import 'package:firing_flyer/game_engine/bullet.dart';
import 'package:flutter/material.dart';

import 'package:firing_flyer/game_engine/core_widget.dart';
import 'package:firing_flyer/game_engine/flyer.dart';
import 'package:firing_flyer/thread_bool/thread_pool.dart';

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
  late final CustomButtonState gunControll;
  late final ObjectPosition flyerPos;
  late final ObjectPosition bulletPos;
  late final GameScore scoreCounter;
  late final Node? node;
  late final Node? nodeBullet;
  bool checkDone = false;

  Future<void>? _initData;
  Future<void> initData() async {
    node = await ThreadPool.createTask(positionFlyer);
    nodeBullet = await ThreadPool.createTask(positionBullet);

    //  flyer
    node?.masterPort.listen((data) {
      if (data['type'] == FlyerMessageType.init.name) {
        node?.workerPort = data['data'];
        node?.workerPort?.send(
          FlyerMessage.toJson(
            FlyerMessage(data: null, type: FlyerMessageType.ready),
          ),
        );
      } else if (data['type'] == FlyerMessageType.ready.name) {
        node?.workerPort?.send(
          FlyerMessage.toJson(
            FlyerMessage(data: null, type: FlyerMessageType.update),
          ),
        );
      } else if (data['type'] == FlyerMessageType.update.name) {
        if (data['data'] == null) {
          node?.workerPort?.send(
            FlyerMessage.toJson(
              FlyerMessage(data: null, type: FlyerMessageType.update),
            ),
          );
        } else {
          flyerPos.offset = data['data']['flyer'];
          node?.workerPort?.send(
            FlyerMessage.toJson(
              FlyerMessage(data: "done", type: FlyerMessageType.update),
            ),
          );
        }
      } else if (data['type'] == FlyerMessageType.killed.name) {
        scoreCounter.score++;
        node?.workerPort?.send(
          FlyerMessage.toJson(
            FlyerMessage(data: null, type: FlyerMessageType.update),
          ),
        );
      } else if (data['type'] == FlyerMessageType.win.name) {
        scoreCounter.score = 0;
        node?.workerPort?.send(FlyerMessage.toJson(FlyerMessage(
            data: Size(MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height - 200),
            type: FlyerMessageType.init)));
      } else {
        node?.workerPort?.send(
          FlyerMessage.toJson(
            FlyerMessage(data: null, type: FlyerMessageType.idle),
          ),
        );
      }
    });

    // bullets
    nodeBullet?.masterPort.listen((data) {
      if (data['type'] == BulletMessageType.init.name) {
        nodeBullet?.workerPort = data['data'];
        setState(() {});
      } else if (data['type'] == BulletMessageType.ready.name) {
        nodeBullet?.workerPort?.send(
          BulletMessage.toJson(
            BulletMessage(data: null, type: BulletMessageType.ready),
          ),
        );
      } else if (data['type'] == BulletMessageType.update.name) {
        if (data['data'] == null) {
          nodeBullet?.workerPort?.send(
            BulletMessage.toJson(
              BulletMessage(data: null, type: BulletMessageType.update),
            ),
          );
        } else {
          if (data['data']['bullet'] != null &&
              data['data']['bullet'].isNotEmpty) {
            bulletPos.offset = data['data']['bullet'][0];
          } else {
            bulletPos.offset = null;
            checkDone = false;
          }
          if (flyerPos.offset != null && bulletPos.offset != null) {
            if (((bulletPos.offset!) - (flyerPos.offset!)).distance < 30) {
              bulletPos.offset = null;
              flyerPos.offset = null;
              checkDone = false;
              node?.workerPort?.send(
                FlyerMessage.toJson(
                  FlyerMessage(data: null, type: FlyerMessageType.killed),
                ),
              );
              nodeBullet?.workerPort?.send(
                BulletMessage.toJson(
                  BulletMessage(data: "done", type: BulletMessageType.ready),
                ),
              );
            }
          }
          nodeBullet?.workerPort?.send(
            BulletMessage.toJson(
              BulletMessage(data: "done", type: BulletMessageType.update),
            ),
          );
        }
      } else {
        nodeBullet?.workerPort?.send(
          BulletMessage.toJson(
            BulletMessage(data: null, type: BulletMessageType.idle),
          ),
        );
      }
    });
    return Future.value();
  }

  double currentDx = 0;

  @override
  void initState() {
    gunControll = CustomButtonState();
    flyerPos = ObjectPosition();
    bulletPos = ObjectPosition();
    scoreCounter = GameScore();
    _initData = initData();
    super.initState();
  }

  @override
  void dispose() {
    ThreadPool.deleteTask(node!.index);
    ThreadPool.deleteTask(nodeBullet!.index);
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
                node?.workerPort?.send(FlyerMessage.toJson(FlyerMessage(
                    data: Size(MediaQuery.of(context).size.width,
                        MediaQuery.of(context).size.height - 200),
                    type: FlyerMessageType.init)));
                nodeBullet?.workerPort?.send(BulletMessage.toJson(BulletMessage(
                    data: Size(MediaQuery.of(context).size.width,
                        MediaQuery.of(context).size.height - 200),
                    type: BulletMessageType.init)));
                return Container(
                  color: Colors.blue,
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height - 200,
                  child: Stack(
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: 100,
                            width: double.infinity,
                            color: Colors.blueGrey,
                          )
                        ],
                      ),
                      UniCoreWidget(
                        controller: flyerPos,
                        builder: (context, child) {
                          if (flyerPos.offset != null) {
                            return SizedBox.fromSize(
                              size: MediaQuery.of(context).size,
                              child: CustomPaint(
                                painter: FlyerPainter(
                                  shapeOffset: flyerPos.offset!,
                                  shapeSize: Size(50, 50),
                                ),
                              ),
                            );
                          }
                          return SizedBox.shrink();
                        },
                      ),
                      UniCoreWidget(
                        controller: bulletPos,
                        builder: (context, child) {
                          if (bulletPos.offset != null) {
                            return SizedBox.fromSize(
                              size: MediaQuery.of(context).size,
                              child: CustomPaint(
                                painter: BulletPainter(
                                  shapeOffset: bulletPos.offset!,
                                  shapeSize: Size(10, 10),
                                ),
                              ),
                            );
                          }
                          return SizedBox.shrink();
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
              Container(
                padding: EdgeInsets.all(16),
                height: 200,
                width: MediaQuery.of(context).size.width,
                child: Row(
                  children: [
                    GestureDetector(
                      onPanEnd: (details) {
                        currentDx = 0;
                      },
                      onPanStart: (details) {
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
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            width: 120,
                            height: 30,
                            child: UniCoreWidget(
                              controller: gunControll,
                              builder: (context, child) {
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
                          UniCoreWidget(
                            controller: scoreCounter,
                            builder: (context, child) {
                              return Container(
                                alignment: Alignment.center,
                                width: double.infinity,
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  '${scoreCounter.score}',
                                  style: TextStyle(fontSize: 32),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Listener(
                      onPointerDown: (event) async {
                        if (!checkDone) {
                          checkDone = true;
                          nodeBullet?.workerPort?.send(
                            BulletMessage.toJson(
                              BulletMessage(
                                  data: (90 - gunControll.radian),
                                  type: BulletMessageType.fire),
                            ),
                          );
                        }
                      },
                      child: Container(
                        height: 60,
                        width: 60,
                        color: Colors.yellow,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}
