// Platform-specific image builder for mobile
import 'dart:io' as io;
import 'package:flutter/widgets.dart';

Widget buildPlatformImage(
  dynamic file, {
  BoxFit? fit,
  double? width,
  double? height,
}) {
  return Image.file(
    file as io.File,
    fit: fit ?? BoxFit.cover,
    width: width,
    height: height,
  );
}
