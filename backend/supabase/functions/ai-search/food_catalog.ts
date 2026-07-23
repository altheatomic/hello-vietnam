import type { SupabaseClient } from "@supabase/supabase-js";
import type { FoodCatalogEntry } from "./food_matcher.ts";

type DatabaseRow = Record<string, unknown>;

const CACHE_TTL_MS = 5 * 60 * 1000;
let cachedCatalog: FoodCatalogEntry[] | null = null;
let cacheExpiresAt = 0;

export async function loadFoodCatalog(
  client: SupabaseClient,
): Promise<FoodCatalogEntry[]> {
  const now = Date.now();
  if (cachedCatalog && now < cacheExpiresAt) {
    return cachedCatalog;
  }

  const { data: foodRows, error: foodError } = await client
    .from("food")
    .select("id_food,name,image_path")
    .limit(2000);

  if (foodError) {
    throw new Error(`Could not load food catalog: ${foodError.message}`);
  }

  const { data: translationRows, error: translationError } = await client
    .from("food_translation")
    .select("*")
    .limit(4000);

  if (translationError) {
    console.warn(
      `AI Search food translations unavailable: ${translationError.message}`,
    );
  }

  cachedCatalog = buildFoodCatalog(
    asRows(foodRows),
    translationError ? [] : asRows(translationRows),
  );
  cacheExpiresAt = now + CACHE_TTL_MS;
  return cachedCatalog;
}

export function buildFoodCatalog(
  foodRows: DatabaseRow[],
  translationRows: DatabaseRow[],
): FoodCatalogEntry[] {
  const aliasesByFoodId = new Map<string, Set<string>>();

  for (const row of translationRows) {
    const id = readFirstString(row, ["id_food", "food_id"]);
    const name = readFirstString(row, ["name", "food_name", "title", "label"]);
    if (!id || !name) {
      continue;
    }
    const aliases = aliasesByFoodId.get(id) ?? new Set<string>();
    aliases.add(name);
    aliasesByFoodId.set(id, aliases);
  }

  const catalog: FoodCatalogEntry[] = [];
  for (const row of foodRows) {
    const id = readFirstString(row, ["id_food", "food_id", "id"]);
    const name = readFirstString(row, ["name", "food_name", "title"]);
    if (!id || !name) {
      continue;
    }

    const aliases = [...(aliasesByFoodId.get(id) ?? new Set<string>())]
      .filter((alias) => alias !== name);
    catalog.push({
      id,
      name,
      aliases,
      imagePath: readFirstString(row, [
        "image_path",
        "cover_image",
        "image_url",
      ]),
    });
  }

  return catalog;
}

function asRows(value: unknown): DatabaseRow[] {
  return Array.isArray(value) ? value.filter(isDatabaseRow) : [];
}

function isDatabaseRow(value: unknown): value is DatabaseRow {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readFirstString(
  row: DatabaseRow,
  candidates: string[],
): string | null {
  for (const candidate of candidates) {
    const value = row[candidate];
    if (typeof value === "string" && value.trim()) {
      return value.trim();
    }
  }
  return null;
}
