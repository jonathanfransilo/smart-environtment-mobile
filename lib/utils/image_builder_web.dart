// Platform-specific image builder for web
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'file_stub.dart' as custom_file;

Widget buildPlatformImage(
  dynamic file, {
  BoxFit? fit,
  double? width,
  double? height,
}) {
  if (file == null) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFEEEEEE),
      child: Center(child: Icon(Icons.image, size: 50, color: Colors.grey)),
    );
  }

  // On web, file should be custom_file.File with bytes
  if (file is custom_file.File) {
    try {
      // Use FutureBuilder untuk handle async readAsBytes
      return FutureBuilder<Uint8List>(
        future: file.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: width,
              height: height,
              color: const Color(0xFFEEEEEE),
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Container(
              width: width,
              height: height,
              color: const Color(0xFFEEEEEE),
              child: Center(
                child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
              ),
            );
          }

          return Image.memory(
            snapshot.data!,
            fit: fit ?? BoxFit.cover,
            width: width,
            height: height,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: width,
                height: height,
                color: const Color(0xFFEEEEEE),
                child: Center(
                  child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      return Container(
        width: width,
        height: height,
        color: const Color(0xFFEEEEEE),
        child: Center(child: Icon(Icons.error, size: 50, color: Colors.red)),
      );
    }
  }

  // Fallback
  return Container(
    width: width,
    height: height,
    color: const Color(0xFFEEEEEE),
    child: Center(child: Icon(Icons.help, size: 50, color: Colors.grey)),
  );
}
