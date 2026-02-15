import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:executive_function/features/food/models/recipe.dart';
import 'package:executive_function/features/food/services/recipe_import_service.dart';

void main(List<String> args) async {
  final portArg = args.isNotEmpty ? int.tryParse(args.first) : null;
  final port = portArg ?? 8080;

  final handler = const Pipeline()
      .addMiddleware(_corsMiddleware())
      .addMiddleware(logRequests())
      .addHandler(_router);

  final server = await shelf_io.serve(
    handler,
    InternetAddress.anyIPv4,
    port,
  );

  stdout.writeln('Recipe proxy running on http://localhost:${server.port}');
}

Future<Response> _router(Request request) async {
  if (request.method == 'OPTIONS') {
    return Response.ok('ok');
  }

  if (request.url.path == 'health') {
    return _json({'ok': true});
  }

  if (request.method == 'GET' && request.url.path == 'import-recipe') {
    return _importRecipe(request);
  }

  return _json({'error': 'Not found'}, status: 404);
}

Future<Response> _importRecipe(Request request) async {
  final rawUrl = request.url.queryParameters['url']?.trim() ?? '';
  final uri = Uri.tryParse(rawUrl);

  if (rawUrl.isEmpty || uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return _json(
      {'error': 'Please provide a valid http/https URL via ?url='},
      status: 400,
    );
  }

  try {
    final response = await http.get(
      uri,
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (compatible; ExecutiveFunctionRecipeImporter/1.0)',
        'Accept': 'text/html,application/xhtml+xml',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _json(
        {'error': 'Failed to fetch recipe page (${response.statusCode}).'},
        status: 502,
      );
    }

    final scripts = RecipeImportService.extractJsonLdScripts(response.body);
    if (scripts.isEmpty) {
      return _json({'error': 'No JSON-LD scripts found on this page.'}, status: 422);
    }

    for (final script in scripts) {
      try {
        final decoded = jsonDecode(script);
        final recipeNode = RecipeImportService.findRecipeNode(decoded);
        if (recipeNode == null) {
          continue;
        }

        final recipe = Recipe.fromJsonLd(recipeNode, uri.toString());
        return _json({
          'title': recipe.title,
          'category': recipe.category,
          'ingredients': recipe.ingredients,
          'steps': recipe.steps,
          'allergens': recipe.allergens,
          'totalTime': recipe.totalTime,
          'prepTime': recipe.prepTime,
          'cookTime': recipe.cookTime,
          'servings': recipe.servings,
          'imageUrl': recipe.imageUrl,
          'sourceUrl': recipe.sourceUrl,
          'sourceDomain': recipe.sourceDomain,
        });
      } catch (_) {
        continue;
      }
    }

    return _json({'error': 'No Recipe schema found in JSON-LD.'}, status: 422);
  } catch (e) {
    return _json({'error': e.toString()}, status: 500);
  }
}

Middleware _corsMiddleware() {
  return (innerHandler) {
    return (request) async {
      final response = await innerHandler(request);
      return response.change(headers: {
        ...response.headers,
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      });
    };
  };
}

Response _json(Map<String, dynamic> data, {int status = 200}) {
  return Response(
    status,
    body: jsonEncode(data),
    headers: {'content-type': 'application/json'},
  );
}
