import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_ai_sample/utils.dart';

class WallpaperRepo {
  //TODO: add to remote config
  final model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-3.1-flash-image-preview',
    generationConfig: GenerationConfig(
      responseModalities: [ResponseModalities.text, ResponseModalities.image],
    ),
  );

  Future<Uint8List> generateWallpaper({required String prompt}) async {
    final response = await model.generateContent([
      Content.text("Generate a wallpaper of $prompt"),
    ]);

    showlog("Image bytes : ${response.inlineDataParts.first.bytes}");

    return response.inlineDataParts.first.bytes;
  }
}
