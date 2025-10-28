// Conditional export for platform-specific image builder
// Uses dart:io on mobile/desktop, web implementation on web
export 'image_builder_web.dart'
    if (dart.library.io) 'image_builder_mobile.dart';
