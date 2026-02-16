import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;

import '../models/recipe.dart';

class RecipeImportService {
  static const String _functionsRegion = String.fromEnvironment(
    'FIREBASE_FUNCTIONS_REGION',
    defaultValue: 'us-central1',
  );

  static const String _proxyBase = String.fromEnvironment(
    'RECIPE_PROXY_BASE',
    defaultValue: '',
  );

  static Future<Recipe> importRecipe(String url) async {
    final errors = <String>[];
    try {
      final recipe = await importFromCallable(url);
      developer.log(
        'Imported via Firebase callable: ${recipe.title}',
        name: 'RecipeImportService',
      );
      return recipe;
    } catch (e) {
      developer.log('Callable failed: $e', name: 'RecipeImportService');
      errors.add(e.toString());
    }

    if (_proxyBase.trim().isNotEmpty) {
      try {
        final recipe = await importFromProxy(url);
        developer.log(
          'Imported via local proxy: ${recipe.title}',
          name: 'RecipeImportService',
        );
        return recipe;
      } catch (e) {
        developer.log('Proxy failed: $e', name: 'RecipeImportService');
        errors.add(e.toString());
      }
    }

    try {
      final recipe = await importFromUrlDirect(url);
      developer.log(
        'Imported via direct URL fetch: ${recipe.title}',
        name: 'RecipeImportService',
      );
      return recipe;
    } catch (e) {
      developer.log('Direct fetch failed: $e', name: 'RecipeImportService');
      errors.add(e.toString());
      throw Exception(
        'Recipe import failed. Firebase function + fallback attempts failed.\n'
        '${errors.join('\n')}',
      );
    }
  }

  static Future<Recipe> importFromCallable(String url) async {
    final cleanUrl = url.trim();
    final callable = FirebaseFunctions.instanceFor(
      region: _functionsRegion,
    ).httpsCallable('importRecipe');
    final result = await callable.call(<String, dynamic>{'url': cleanUrl});

    final data = result.data;
    if (data is! Map) {
      throw Exception('Function returned an unexpected response.');
    }

    final decoded = Map<String, dynamic>.from(data);
    return Recipe.fromMap(decoded);
  }

  static Future<Recipe> importFromProxy(String url) async {
    final cleanUrl = url.trim();
    final uri = Uri.parse(
      '$_proxyBase/import-recipe',
    ).replace(queryParameters: {'url': cleanUrl});

    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg =
          _extractErrorMessage(response.body) ??
          'Proxy failed (${response.statusCode}).';
      throw Exception(msg);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Proxy returned an unexpected response.');
    }

    return Recipe.fromMap(decoded);
  }

  static Future<Recipe> importFromUrlDirect(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw Exception('Please enter a valid http/https URL.');
    }

    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch recipe page (${response.statusCode}).');
    }

    final scripts = extractJsonLdScripts(response.body);
    if (scripts.isEmpty) {
      throw Exception('No JSON-LD scripts found on this page.');
    }

    for (final script in scripts) {
      try {
        final decoded = jsonDecode(script);
        final recipeNode = findRecipeNode(decoded);
        if (recipeNode != null) {
          return Recipe.fromJsonLd(recipeNode, uri.toString());
        }
      } catch (_) {
        continue;
      }
    }

    throw Exception('No Recipe schema found in JSON-LD.');
  }

  static List<String> extractJsonLdScripts(String html) {
    final regex = RegExp(
      r'''<script[^>]*type=["']application/ld\+json["'][^>]*>([\s\S]*?)</script>''',
      caseSensitive: false,
      multiLine: true,
    );

    return regex
        .allMatches(html)
        .map((match) => (match.group(1) ?? '').trim())
        .where((block) => block.isNotEmpty)
        .toList();
  }

  static Map<String, dynamic>? findRecipeNode(dynamic node) {
    if (node is List) {
      for (final item in node) {
        final found = findRecipeNode(item);
        if (found != null) {
          return found;
        }
      }
      return null;
    }

    if (node is! Map) {
      return null;
    }

    final map = Map<String, dynamic>.from(node);
    if (_isRecipeType(map['@type'])) {
      return map;
    }

    final graph = map['@graph'];
    if (graph != null) {
      final found = findRecipeNode(graph);
      if (found != null) {
        return found;
      }
    }

    for (final value in map.values) {
      final found = findRecipeNode(value);
      if (found != null) {
        return found;
      }
    }

    return null;
  }

  static bool _isRecipeType(dynamic typeField) {
    if (typeField is String) {
      return typeField.toLowerCase() == 'recipe';
    }
    if (typeField is List) {
      return typeField.any((item) => item.toString().toLowerCase() == 'recipe');
    }
    return false;
  }

  static String? _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) {
          return error.trim();
        }
      }
    } catch (_) {
      // no-op
    }
    return null;
  }
}
