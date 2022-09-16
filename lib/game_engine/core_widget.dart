import 'package:flutter/material.dart';

class UnicoreController extends ChangeNotifier {}

class UniCoreWidget extends StatelessWidget {
  final UnicoreController controller;
  final TransitionBuilder builder;
  const UniCoreWidget(
      {Key? key, required this.controller, required this.builder})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: controller, builder: builder);
  }
}

class CustomButtonState extends UnicoreController {
  double _radian = 0;

  CustomButtonState();

  set radian(double value) {
    _radian = value;
    notifyListeners();
  }

  double get radian {
    return _radian;
  }
}

class ObjectPosition extends UnicoreController {
  Offset? _offset = Offset.zero;

  ObjectPosition();

  set offset(Offset? value) {
    _offset = value;
    notifyListeners();
  }

  Offset? get offset {
    return _offset;
  }
}
