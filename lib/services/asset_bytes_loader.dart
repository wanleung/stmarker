import 'dart:typed_data';

typedef AssetBytesLoader = Future<Uint8List> Function(String assetPath);
