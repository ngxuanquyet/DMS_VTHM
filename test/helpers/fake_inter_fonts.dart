import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Phông Inter của app lấy từ "tài sản" giả (DejaVu Sans) — widget test không tải phông qua mạng.
void fakeInterFonts() {
  GoogleFonts.config.allowRuntimeFetching = false;
  const candidates = [
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    r'C:\Windows\Fonts\segoeui.ttf',
    r'C:\Windows\Fonts\arial.ttf',
  ];
  final fontPath = candidates.cast<String?>().firstWhere(
        (p) => File(p!).existsSync(),
        orElse: () => null,
      );
  if (fontPath == null) return;
  const keys = ['Regular', 'Medium', 'SemiBold', 'Bold'];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (message) async {
    final key = utf8.decode(message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes));
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, Object>{for (final k in keys) 'google_fonts/Inter-$k.ttf': <Object>[]});
    }
    return key.startsWith('google_fonts/Inter-') ? ByteData.sublistView(File(fontPath).readAsBytesSync()) : null;
  });
}
