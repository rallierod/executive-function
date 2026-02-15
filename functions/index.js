const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");

function extractJsonLdScripts(html) {
  const regex =
    /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  const blocks = [];
  let match;
  while ((match = regex.exec(html)) !== null) {
    const content = (match[1] || "").trim();
    if (content) {
      blocks.push(content);
    }
  }
  return blocks;
}

function isRecipeType(typeField) {
  if (typeof typeField === "string") {
    return typeField.toLowerCase() === "recipe";
  }
  if (Array.isArray(typeField)) {
    return typeField.some((item) => String(item).toLowerCase() === "recipe");
  }
  return false;
}

function findRecipeNode(node) {
  if (Array.isArray(node)) {
    for (const item of node) {
      const found = findRecipeNode(item);
      if (found) {
        return found;
      }
    }
    return null;
  }

  if (!node || typeof node !== "object") {
    return null;
  }

  if (isRecipeType(node["@type"])) {
    return node;
  }

  if (node["@graph"]) {
    const found = findRecipeNode(node["@graph"]);
    if (found) {
      return found;
    }
  }

  for (const value of Object.values(node)) {
    const found = findRecipeNode(value);
    if (found) {
      return found;
    }
  }

  return null;
}

function asString(value) {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed || null;
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  if (Array.isArray(value) && value.length > 0) {
    return asString(value[0]);
  }
  return null;
}

function asStringList(value) {
  if (typeof value === "string") {
    return value
      .split(/[,|]/g)
      .map((item) => item.trim())
      .filter(Boolean);
  }
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .map((item) => asString(item))
    .filter((item) => typeof item === "string" && item.trim().length > 0)
    .map((item) => item.trim());
}

function parseInstructions(value) {
  if (typeof value === "string") {
    return value
      .split(/\n+/g)
      .map((line) => line.trim())
      .filter(Boolean);
  }

  if (Array.isArray(value)) {
    const output = [];
    for (const item of value) {
      if (typeof item === "string") {
        const trimmed = item.trim();
        if (trimmed) {
          output.push(trimmed);
        }
        continue;
      }
      if (item && typeof item === "object") {
        const text = asString(item.text) || asString(item.name);
        if (text) {
          output.push(text.trim());
        }
      }
    }
    return output;
  }

  if (value && typeof value === "object") {
    const text = asString(value.text) || asString(value.name);
    return text ? [text] : [];
  }

  return [];
}

function extractImage(value) {
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed || null;
  }
  if (Array.isArray(value) && value.length > 0) {
    return extractImage(value[0]);
  }
  if (value && typeof value === "object") {
    return asString(value.url) || asString(value.contentUrl);
  }
  return null;
}

function extractCategory(recipe) {
  const direct = asString(recipe.recipeCategory);
  if (direct) {
    return direct;
  }

  const keywords = asStringList(recipe.keywords);
  for (const keyword of keywords) {
    const lower = keyword.toLowerCase();
    if (lower.includes("breakfast")) {
      return "Breakfast";
    }
    if (lower.includes("lunch")) {
      return "Lunch";
    }
    if (lower.includes("dinner")) {
      return "Dinner";
    }
    if (lower.includes("snack")) {
      return "Snack";
    }
  }
  return null;
}

function extractAllergens(recipe) {
  const values = new Set();
  const addFrom = (raw) => {
    for (const item of asStringList(raw)) {
      if (item && item.trim()) {
        values.add(item.trim());
      }
    }
  };

  addFrom(recipe.allergen);
  addFrom(recipe.allergens);
  addFrom(recipe.suitableForDiet);

  if (recipe.nutrition && typeof recipe.nutrition === "object") {
    addFrom(recipe.nutrition.allergen);
    addFrom(recipe.nutrition.allergens);
  }

  return Array.from(values);
}

exports.importRecipe = onCall({ cors: true }, async (request) => {
  const rawUrl = String(request.data?.url || "").trim();
  let url;
  try {
    url = new URL(rawUrl);
  } catch (e) {
    throw new HttpsError("invalid-argument", "Please provide a valid URL.");
  }

  if (!(url.protocol === "http:" || url.protocol === "https:")) {
    throw new HttpsError("invalid-argument", "Only http/https URLs are supported.");
  }

  try {
    const response = await fetch(url.toString(), {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (compatible; ExecutiveFunctionRecipeImporter/1.0)",
        Accept: "text/html,application/xhtml+xml",
      },
    });

    if (!response.ok) {
      throw new HttpsError(
        "failed-precondition",
        `Failed to fetch recipe page (${response.status}).`
      );
    }

    const html = await response.text();
    const scripts = extractJsonLdScripts(html);
    if (scripts.length === 0) {
      throw new HttpsError("not-found", "No JSON-LD scripts found on this page.");
    }

    for (const script of scripts) {
      try {
        const decoded = JSON.parse(script);
        const recipeNode = findRecipeNode(decoded);
        if (!recipeNode) {
          continue;
        }

        return {
          title: asString(recipeNode.name) || "Untitled recipe",
          category: extractCategory(recipeNode),
          ingredients: asStringList(recipeNode.recipeIngredient),
          steps: parseInstructions(recipeNode.recipeInstructions),
          allergens: extractAllergens(recipeNode),
          totalTime: asString(recipeNode.totalTime),
          prepTime: asString(recipeNode.prepTime),
          cookTime: asString(recipeNode.cookTime),
          servings: asString(recipeNode.recipeYield),
          imageUrl: extractImage(recipeNode.image),
          sourceUrl: url.toString(),
          sourceDomain: url.host || "unknown source",
        };
      } catch (e) {
        continue;
      }
    }

    throw new HttpsError("not-found", "No Recipe schema found in JSON-LD.");
  } catch (e) {
    if (e instanceof HttpsError) {
      throw e;
    }
    logger.error("importRecipe failed", e);
    throw new HttpsError("internal", e.message || "Unexpected error while importing recipe.");
  }
});
