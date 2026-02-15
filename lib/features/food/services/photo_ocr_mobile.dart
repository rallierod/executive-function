import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

Future<String> extractRecipeTextFromImagePath(String imagePath) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final image = InputImage.fromFile(File(imagePath));
    final result = await recognizer.processImage(image);
    return result.text.trim();
  } finally {
    await recognizer.close();
  }
}
