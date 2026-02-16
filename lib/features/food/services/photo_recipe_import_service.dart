import '../models/recipe.dart';
import 'photo_ocr_stub.dart' if (dart.library.io) 'photo_ocr_mobile.dart';
import 'recipe_text_parser.dart';

class PhotoRecipeImportService {
  static Future<Recipe> importFromImagePath(String imagePath) async {
    final text = await extractRecipeTextFromImagePath(imagePath);
    if (text.trim().isEmpty) {
      throw Exception('No readable text found in the image.');
    }

    final id = 'photo://${DateTime.now().millisecondsSinceEpoch}';
    return RecipeTextParser.parse(rawText: text, sourceId: id);
  }
}
