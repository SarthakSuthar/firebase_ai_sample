import 'package:flutter/widgets.dart';

void showlog(String msg) {
  debugPrint('\x1B[32m$msg\x1B[0m');
}
