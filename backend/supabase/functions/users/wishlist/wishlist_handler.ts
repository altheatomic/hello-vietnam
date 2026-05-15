/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { createClient } from "@supabase/supabase-js";

import { corsHeaders } from "../../_shared/cors.ts";
import {
  AuthorizationError,
  requireAuthenticatedUserId,
  requireAuthorizationHeader,
} from "../../auth/auth_guard.ts";

type JsonObject = Record<string, unknown>;
type FavoriteType = "city" | "place" | "food";

type WishlistItem = {
  id: string;
  type: FavoriteType;
  title: string;
  description: string;
  imageUrl: string | null;
};

type FavoriteRef = {
  type: FavoriteType;
  id: string;
  createdAt: string;
};

type FavoriteTableConfig = {
  table: string;
  itemColumns: string[];
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const FAVORITE_FOOD_TABLE = "favorite_food";
const FAVORITE_PLACE_TABLE = "favorite_place";
const FAVORITE_CITY_TABLE = "favorite_city";

const FOOD_TABLE = "food";
const FOOD_TRANSLATION_TABLE = "food_translation";
const PLACE_TABLE = "place";
const DEFAULT_LANGUAGE = "en";
const HANDLER_VERSION = "wishlist-be-2026-05-15-v2";

const CITY_TABLE_CANDIDATES = ["province", "city_province"];
const CITY_ID_CANDIDATES_BY_TABLE: Record<string, string[]> = {
  province: ["id_province", "id_city", "province_id", "id"],
  city_province: ["id_city", "id_province", "city_id", "id"],
};

if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error(
    "Missing required Supabase environment variables for wishlist function.",
  );
}

export async function handleWishlistRequest(req: Request): Promise<Response> {
  console.log(`[wishlist] version=${HANDLER_VERSION} request method=${req.method}`);

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  try {
    const authHeader = requireAuthorizationHeader(
      req.headers.get("Authorization"),
    );

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const userId = await requireAuthenticatedUserId(userClient);

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const service = new WishlistService(adminClient, userId);

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return jsonResponse({ error: "Invalid JSON body." }, 400);
    }

    const payload = body as JsonObject;
    const action = stringValue(payload.action);
    if (!action) {
      return jsonResponse({ error: "Missing action." }, 400);
    }
    console.log(`[wishlist] action=${action}`);

    switch (action) {
      case "listWishlist": {
        const language = stringValue(payload.language) ?? DEFAULT_LANGUAGE;
        const items = await service.listWishlist(language);
        return jsonResponse({ items });
      }
      case "isFavoriteByRawId": {
        const type = requireFavoriteType(payload.type);
        const rawItemId = requiredString(payload.rawItemId, "rawItemId");
        const fallbackName = stringValue(payload.fallbackName);
        return jsonResponse(
          await service.isFavoriteByRawId(type, rawItemId, fallbackName),
        );
      }
      case "toggleFavoriteByRawId": {
        const type = requireFavoriteType(payload.type);
        const rawItemId = requiredString(payload.rawItemId, "rawItemId");
        const fallbackName = stringValue(payload.fallbackName);
        return jsonResponse(
          await service.toggleFavoriteByRawId(type, rawItemId, fallbackName),
        );
      }
      case "setFavorite": {
        const type = requireFavoriteType(payload.type);
        const itemId = requiredString(payload.itemId, "itemId");
        const isFavorite = parseBooleanValue(payload.isFavorite);
        if (isFavorite == null) {
          return jsonResponse(
            {
              error:
                'Invalid "isFavorite". Expected boolean true/false or "true"/"false".',
            },
            400,
          );
        }
        console.log(
          `[wishlist] setFavorite isFavorite=${isFavorite} raw=${String(payload.isFavorite)} type=${type} itemId=${itemId}`,
        );
        return jsonResponse(await service.setFavorite(itemId, type, isFavorite));
      }
      default:
        return jsonResponse({ error: `Unsupported action: ${action}` }, 400);
    }
  } catch (error) {
    console.error("[wishlist] unhandled error", error);
    if (error instanceof AuthorizationError) {
      return jsonResponse({ error: error.message }, error.statusCode);
    }
    const message = error instanceof Error ? error.message : "Unexpected error.";
    return jsonResponse({ error: message }, 500);
  }
}

class WishlistService {
  private cityTableName: string | null = null;
  private favoriteItemColumnCache = new Map<string, string>();

  constructor(
    private readonly client: ReturnType<typeof createClient>,
    private readonly userId: string,
  ) {}

  async listWishlist(language: string): Promise<WishlistItem[]> {
    const foodConfig = favoriteConfigForType("food");
    const placeConfig = favoriteConfigForType("place");
    const cityConfig = favoriteConfigForType("city");

    const [foodRows, placeRows, cityRows] = await Promise.all([
      this.selectFavoriteRows(foodConfig.table, foodConfig.itemColumns, "food"),
      this.selectFavoriteRows(
        placeConfig.table,
        placeConfig.itemColumns,
        "place",
      ),
      this.selectFavoriteRows(cityConfig.table, cityConfig.itemColumns, "city"),
    ]);

    const ordered = [...foodRows, ...placeRows, ...cityRows].sort(
      (a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt),
    );
    if (ordered.length === 0) return [];

    const cityIds = new Set<string>();
    const placeIds = new Set<string>();
    const foodIds = new Set<string>();
    for (const row of ordered) {
      if (row.type === "city") cityIds.add(row.id);
      if (row.type === "place") placeIds.add(row.id);
      if (row.type === "food") foodIds.add(row.id);
    }

    const cityMap = await this.loadCityItems(Array.from(cityIds));
    const placeMap = await this.loadPlaceItems(Array.from(placeIds));
    const foodMap = await this.loadFoodItems(Array.from(foodIds), language);

    const output: WishlistItem[] = [];
    const seen = new Set<string>();
    for (const ref of ordered) {
      const key = `${ref.type}:${ref.id}`;
      if (seen.has(key)) continue;

      const item =
        ref.type === "city"
          ? cityMap.get(ref.id)
          : ref.type === "place"
          ? placeMap.get(ref.id)
          : foodMap.get(ref.id);
      if (!item) continue;

      output.push(item);
      seen.add(key);
    }
    return output;
  }

  async isFavoriteByRawId(
    type: FavoriteType,
    rawItemId: string,
    fallbackName: string | null,
  ): Promise<JsonObject> {
    const itemId = await this.resolveItemId(type, rawItemId, fallbackName);
    const isFavorite = await this.isFavoriteByItemId(type, itemId);
    return { itemId, isFavorite };
  }

  async toggleFavoriteByRawId(
    type: FavoriteType,
    rawItemId: string,
    fallbackName: string | null,
  ): Promise<JsonObject> {
    const itemId = await this.resolveItemId(type, rawItemId, fallbackName);
    const current = await this.isFavoriteByItemId(type, itemId);
    const next = !current;

    await this.setFavoriteByResolvedItemId(type, itemId, next);
    return { itemId, isFavorite: next };
  }

  async setFavorite(
    itemId: string,
    type: FavoriteType,
    isFavorite: boolean,
  ): Promise<JsonObject> {
    const normalizedId = itemId.trim();
    if (!isUuid(normalizedId)) {
      throw new Error(`itemId must be UUID. Received: "${itemId}"`);
    }

    await this.setFavoriteByResolvedItemId(type, normalizedId, isFavorite);
    return { itemId: normalizedId, isFavorite };
  }

  private async setFavoriteByResolvedItemId(
    type: FavoriteType,
    itemId: string,
    isFavorite: boolean,
  ): Promise<void> {
    const config = favoriteConfigForType(type);
    const itemColumn = await this.resolveFavoriteItemColumn(config);
    console.log(
      `[wishlist] setFavorite branch=${isFavorite ? "upsert" : "delete"} type=${type} table=${config.table} itemColumn=${itemColumn} itemId=${itemId}`,
    );

    if (isFavorite) {
      await this.assertItemExists(type, itemId);
      const { error } = await this.client.from(config.table).upsert(
        {
          id_user: this.userId,
          [itemColumn]: itemId,
          created_at: new Date().toISOString(),
        },
        { onConflict: `id_user,${itemColumn}` },
      );
      if (error) throw new Error(`${config.table}: ${error.message}`);
      return;
    }

    {
      const deleteColumns = favoriteItemColumnCandidatesForType(type);
      let deletedRowsCount = 0;

      for (const deleteColumn of deleteColumns) {
        try {
          const { data, error } = await this.client
            .from(config.table)
            .delete()
            .eq("id_user", this.userId)
            .eq(deleteColumn, itemId)
            .select(deleteColumn);

          if (error) {
            if (isUndefinedColumnError(error)) {
              continue;
            }
            throw new Error(`${config.table}: ${error.message}`);
          }

          const deletedRows = asRows(data);
          deletedRowsCount += deletedRows.length;
          console.log(
            `[wishlist] delete attempt table=${config.table} column=${deleteColumn} affected=${deletedRows.length}`,
          );
          if (deletedRows.length === 0) {
            continue;
          }
        } catch (error) {
          if (isUndefinedColumnError(error)) {
            continue;
          }
          throw error;
        }
      }

      console.log(
        `[wishlist] delete type=${type} table=${config.table} user=${this.userId} item=${itemId} deleted_rows=${deletedRowsCount}`,
      );
    }
  }

  private async isFavoriteByItemId(
    type: FavoriteType,
    itemId: string,
  ): Promise<boolean> {
    const config = favoriteConfigForType(type);
    for (const itemColumn of favoriteItemColumnCandidatesForType(type)) {
      try {
        const { data, error } = await this.client
          .from(config.table)
          .select(itemColumn)
          .eq("id_user", this.userId)
          .eq(itemColumn, itemId)
          .limit(1);

        if (error) {
          if (isUndefinedColumnError(error)) {
            continue;
          }
          throw new Error(`${config.table}: ${error.message}`);
        }

        if (asRows(data).length > 0) {
          return true;
        }
      } catch (error) {
        if (isUndefinedColumnError(error)) {
          continue;
        }
        throw error;
      }
    }
    return false;
  }

  private async resolveItemId(
    type: FavoriteType,
    rawItemId: string,
    fallbackName: string | null,
  ): Promise<string> {
    const normalizedRaw = rawItemId.trim();
    if (isUuid(normalizedRaw)) {
      return normalizedRaw;
    }

    const normalizedName = fallbackName?.trim() ?? "";
    if (!normalizedName) {
      throw new Error(
        `Cannot resolve id for ${type}: raw id "${rawItemId}" is not UUID.`,
      );
    }

    const resolvedId =
      type === "city"
        ? await this.findCityIdByName(normalizedName)
        : type === "place"
        ? await this.findPlaceIdByName(normalizedName)
        : await this.findFoodIdByName(normalizedName);

    if (!resolvedId) {
      throw new Error(`Cannot find ${type} id for "${normalizedName}".`);
    }
    return resolvedId;
  }

  private async assertItemExists(type: FavoriteType, itemId: string): Promise<void> {
    if (type === "city") {
      const table = await this.resolveCityTableName();
      if (!table) throw new Error("City table not found.");

      const idCandidates = CITY_ID_CANDIDATES_BY_TABLE[table] ?? ["id"];
      let found = false;
      for (const idColumn of idCandidates) {
        try {
          const { data, error } = await this.client
            .from(table)
            .select(idColumn)
            .eq(idColumn, itemId)
            .maybeSingle();
          if (error) {
            if (isUndefinedColumnError(error)) continue;
            throw error;
          }
          if (data != null) {
            found = true;
            break;
          }
        } catch (error) {
          if (isUndefinedColumnError(error)) continue;
          throw error;
        }
      }

      if (!found) {
        throw new Error(`City item does not exist: ${itemId}`);
      }
      return;
    }

    if (type === "place") {
      const { data, error } = await this.client
        .from(PLACE_TABLE)
        .select("id_place")
        .eq("id_place", itemId)
        .maybeSingle();
      if (error) throw new Error(`${PLACE_TABLE}: ${error.message}`);
      if (data == null) throw new Error(`Place item does not exist: ${itemId}`);
      return;
    }

    const { data, error } = await this.client
      .from(FOOD_TABLE)
      .select("id_food")
      .eq("id_food", itemId)
      .maybeSingle();
    if (error) throw new Error(`${FOOD_TABLE}: ${error.message}`);
    if (data == null) throw new Error(`Food item does not exist: ${itemId}`);
  }

  private async selectFavoriteRows(
    table: string,
    itemColumns: string[],
    type: FavoriteType,
  ): Promise<FavoriteRef[]> {
    const itemColumn = await this.resolveColumnFromCandidates(table, itemColumns);
    const { data, error } = await this.client
      .from(table)
      .select(`${itemColumn},created_at`)
      .eq("id_user", this.userId);
    if (error) throw new Error(`${table}: ${error.message}`);

    const rows = asRows(data);
    const output: FavoriteRef[] = [];
    for (const row of rows) {
      const id = stringValue(row[itemColumn]);
      if (!id) continue;
      output.push({
        type,
        id,
        createdAt: stringValue(row.created_at) ?? new Date(0).toISOString(),
      });
    }
    return output;
  }

  private async resolveFavoriteItemColumn(
    config: FavoriteTableConfig,
  ): Promise<string> {
    const cached = this.favoriteItemColumnCache.get(config.table);
    if (cached) {
      return cached;
    }

    const resolved = await this.resolveColumnFromCandidates(
      config.table,
      config.itemColumns,
    );
    this.favoriteItemColumnCache.set(config.table, resolved);
    return resolved;
  }

  private async resolveColumnFromCandidates(
    table: string,
    candidates: string[],
  ): Promise<string> {
    for (const column of candidates) {
      try {
        const { error } = await this.client.from(table).select(column).limit(1);
        if (error) throw error;
        return column;
      } catch (error) {
        if (isUndefinedColumnError(error)) {
          continue;
        }
        if (isMissingTableError(error)) {
          throw new Error(`Table "${table}" does not exist.`);
        }
        throw error;
      }
    }

    throw new Error(
      `Could not determine favorite item column for "${table}". Tried: ${candidates.join(", ")}`,
    );
  }

  private async loadCityItems(ids: string[]): Promise<Map<string, WishlistItem>> {
    if (ids.length === 0) return new Map<string, WishlistItem>();

    const cityTable = await this.resolveCityTableName();
    if (!cityTable) return new Map<string, WishlistItem>();

    const cityRows = await selectRowsByIdCandidates(
      this.client,
      cityTable,
      ids,
      CITY_ID_CANDIDATES_BY_TABLE[cityTable] ?? ["id"],
    );

    const nameColumn = pickColumn(
      cityRows.rows,
      ["name", "province_name", "city", "province"],
      "name",
    );
    const descriptionColumn = pickOptionalColumn(cityRows.rows, [
      "description",
      "short_description",
      "summary",
    ]);
    const imageColumn = pickOptionalColumn(cityRows.rows, [
      "image_path",
      "url_image",
      "cover_image",
      "image",
    ]);

    const output = new Map<string, WishlistItem>();
    for (const row of cityRows.rows) {
      const id = stringValue(row[cityRows.idColumn]);
      const name = stringValue(row[nameColumn]);
      if (!id || !name) continue;

      output.set(id, {
        id,
        type: "city",
        title: name.startsWith("TP.") ? name : `TP. ${name}`,
        description:
          stringValue(
            descriptionColumn ? row[descriptionColumn] : null,
          ) ?? `${name} is a beautiful destination in Vietnam.`,
        imageUrl: firstImageToken(
          stringValue(imageColumn ? row[imageColumn] : null),
        ),
      });
    }
    return output;
  }

  private async loadPlaceItems(
    ids: string[],
  ): Promise<Map<string, WishlistItem>> {
    if (ids.length === 0) return new Map<string, WishlistItem>();

    const placeRows = await selectRowsByIdCandidates(
      this.client,
      PLACE_TABLE,
      ids,
      ["id_place", "place_id", "id"],
    );

    const nameColumn = pickColumn(placeRows.rows, ["name", "title"], "name");
    const descriptionColumn = pickOptionalColumn(placeRows.rows, [
      "description",
      "short_description",
      "summary",
    ]);
    const imageColumn = pickOptionalColumn(placeRows.rows, [
      "images_path",
      "image_path",
      "url_image",
      "cover_image",
      "image",
    ]);

    const output = new Map<string, WishlistItem>();
    for (const row of placeRows.rows) {
      const id = stringValue(row[placeRows.idColumn]);
      const name = stringValue(row[nameColumn]);
      if (!id || !name) continue;

      output.set(id, {
        id,
        type: "place",
        title: name,
        description:
          stringValue(
            descriptionColumn ? row[descriptionColumn] : null,
          ) ?? `${name} is a must-visit place in Vietnam.`,
        imageUrl: firstImageToken(
          stringValue(imageColumn ? row[imageColumn] : null),
        ),
      });
    }
    return output;
  }

  private async loadFoodItems(
    ids: string[],
    language: string,
  ): Promise<Map<string, WishlistItem>> {
    if (ids.length === 0) return new Map<string, WishlistItem>();

    const foodRows = await selectRowsByIdCandidates(
      this.client,
      FOOD_TABLE,
      ids,
      ["id_food", "food_id", "id"],
    );

    const imageColumn = pickOptionalColumn(foodRows.rows, [
      "image_path",
      "images_path",
      "url_image",
      "cover_image",
      "image",
    ]);
    const fallbackNameColumn = pickOptionalColumn(foodRows.rows, [
      "name",
      "title",
    ]);
    const fallbackDescriptionColumn = pickOptionalColumn(foodRows.rows, [
      "description",
      "short_description",
      "summary",
    ]);

    const translationRows = await selectRowsByIdCandidates(
      this.client,
      FOOD_TRANSLATION_TABLE,
      ids,
      ["food_id", "id_food", "id"],
    );
    const translationLanguageColumn = pickOptionalColumn(translationRows.rows, [
      "lang_code",
      "language",
      "lang",
      "locale",
    ]);
    const translationNameColumn = pickColumn(
      translationRows.rows,
      ["name", "title"],
      "name",
    );
    const translationDescriptionColumn = pickOptionalColumn(
      translationRows.rows,
      ["description", "short_description", "summary"],
    );

    const preferredTranslations = pickPreferredTranslations(
      translationRows.rows,
      translationRows.idColumn,
      translationLanguageColumn,
      language,
    );

    const output = new Map<string, WishlistItem>();
    for (const row of foodRows.rows) {
      const id = stringValue(row[foodRows.idColumn]);
      if (!id) continue;

      const trans = preferredTranslations.get(id);
      const title =
        stringValue(trans?.[translationNameColumn]) ??
        stringValue(fallbackNameColumn ? row[fallbackNameColumn] : null) ??
        "Unnamed food";
      const description =
        stringValue(
          trans && translationDescriptionColumn
            ? trans[translationDescriptionColumn]
            : null,
        ) ??
        stringValue(
          fallbackDescriptionColumn ? row[fallbackDescriptionColumn] : null,
        ) ??
        `${title} is one of Vietnam local specialties.`;

      output.set(id, {
        id,
        type: "food",
        title,
        description,
        imageUrl: firstImageToken(
          stringValue(imageColumn ? row[imageColumn] : null),
        ),
      });
    }
    return output;
  }

  private async resolveCityTableName(): Promise<string | null> {
    if (this.cityTableName != null) return this.cityTableName;

    for (const tableName of CITY_TABLE_CANDIDATES) {
      try {
        const { error } = await this.client.from(tableName).select("*").limit(1);
        if (error) throw error;
        this.cityTableName = tableName;
        return tableName;
      } catch (error) {
        if (isMissingTableError(error)) continue;
        throw error;
      }
    }
    return null;
  }

  private async findCityIdByName(cityName: string): Promise<string | null> {
    const table = await this.resolveCityTableName();
    if (!table) return null;

    const idCandidates = CITY_ID_CANDIDATES_BY_TABLE[table] ?? ["id"];
    const nameCandidates = ["name", "province_name", "city", "province"];
    for (const idColumn of idCandidates) {
      for (const nameColumn of nameCandidates) {
        const id = await findIdByName(this.client, {
          table,
          idColumn,
          nameColumn,
          name: cityName,
        });
        if (id) return id;
      }
    }
    return null;
  }

  private async findPlaceIdByName(placeName: string): Promise<string | null> {
    for (const idColumn of ["id_place", "place_id", "id"]) {
      const id = await findIdByName(this.client, {
        table: PLACE_TABLE,
        idColumn,
        nameColumn: "name",
        name: placeName,
      });
      if (id) return id;
    }
    return null;
  }

  private async findFoodIdByName(foodName: string): Promise<string | null> {
    for (const idColumn of ["food_id", "id_food", "id"]) {
      for (const nameColumn of ["name", "title"]) {
        const id = await findIdByName(this.client, {
          table: FOOD_TRANSLATION_TABLE,
          idColumn,
          nameColumn,
          name: foodName,
        });
        if (id) return id;
      }
    }
    return null;
  }
}

function favoriteConfigForType(type: FavoriteType): FavoriteTableConfig {
  switch (type) {
    case "food":
      return {
        table: FAVORITE_FOOD_TABLE,
        itemColumns: ["id_food", "id_item", "food_id", "id"],
      };
    case "place":
      return {
        table: FAVORITE_PLACE_TABLE,
        itemColumns: ["id_place", "id_item", "place_id", "id"],
      };
    case "city":
      return {
        table: FAVORITE_CITY_TABLE,
        itemColumns: ["id_province", "id_item", "id_city", "id"],
      };
  }
}

function favoriteItemColumnCandidatesForType(type: FavoriteType): string[] {
  const config = favoriteConfigForType(type);
  const ordered = [
    ...config.itemColumns,
    type === "food"
      ? "id_food"
      : type === "place"
      ? "id_place"
      : "id_province",
    "id_item",
    "id",
  ];
  return Array.from(new Set(ordered));
}

async function findIdByName(
  client: ReturnType<typeof createClient>,
  args: {
    table: string;
    idColumn: string;
    nameColumn: string;
    name: string;
  },
): Promise<string | null> {
  const { table, idColumn, nameColumn, name } = args;
  try {
    const exact = await client
      .from(table)
      .select(`${idColumn},${nameColumn}`)
      .ilike(nameColumn, name)
      .limit(1)
      .maybeSingle();
    if (exact.error) throw exact.error;
    const exactId = stringValue(exact.data?.[idColumn]);
    if (exactId) return exactId;

    const fuzzy = await client
      .from(table)
      .select(`${idColumn},${nameColumn}`)
      .ilike(nameColumn, `%${name}%`)
      .limit(1)
      .maybeSingle();
    if (fuzzy.error) throw fuzzy.error;
    return stringValue(fuzzy.data?.[idColumn]);
  } catch (error) {
    if (isMissingTableError(error) || isUndefinedColumnError(error)) {
      return null;
    }
    throw error;
  }
}

async function selectRowsByIdCandidates(
  client: ReturnType<typeof createClient>,
  table: string,
  ids: string[],
  idCandidates: string[],
): Promise<{ idColumn: string; rows: JsonObject[] }> {
  for (const idColumn of idCandidates) {
    try {
      const { data, error } = await client
        .from(table)
        .select("*")
        .in(idColumn, ids);
      if (error) throw error;
      return { idColumn, rows: asRows(data) };
    } catch (error) {
      if (isUndefinedColumnError(error)) continue;
      if (isMissingTableError(error)) {
        throw new Error(`Table "${table}" does not exist.`);
      }
      throw error;
    }
  }

  throw new Error(
    `Could not determine id column for table "${table}". Tried: ${idCandidates.join(", ")}`,
  );
}

function pickPreferredTranslations(
  rows: JsonObject[],
  idColumn: string,
  languageColumn: string | null,
  language: string,
): Map<string, JsonObject> {
  const grouped = new Map<string, JsonObject[]>();
  for (const row of rows) {
    const id = stringValue(row[idColumn]);
    if (!id) continue;
    const list = grouped.get(id) ?? [];
    list.push(row);
    grouped.set(id, list);
  }

  const preferred = new Map<string, JsonObject>();
  for (const [id, candidates] of grouped.entries()) {
    if (!languageColumn) {
      preferred.set(id, candidates[0]);
      continue;
    }

    let exact: JsonObject | null = null;
    let english: JsonObject | null = null;
    for (const row of candidates) {
      const lang = stringValue(row[languageColumn])?.toLowerCase();
      if (!lang) continue;
      if (lang === language.toLowerCase()) {
        exact = row;
        break;
      }
      if (lang === "en" && !english) {
        english = row;
      }
    }
    preferred.set(id, exact ?? english ?? candidates[0]);
  }
  return preferred;
}

function parseFavoriteType(value: string | null): FavoriteType | null {
  if (!value) return null;
  const normalized = value.trim().toLowerCase();
  if (normalized === "city" || normalized === "place" || normalized === "food") {
    return normalized;
  }
  return null;
}

function requireFavoriteType(value: unknown): FavoriteType {
  const parsed = parseFavoriteType(stringValue(value));
  if (!parsed) {
    throw new Error('type must be one of "city", "place", "food".');
  }
  return parsed;
}

function requiredString(value: unknown, name: string): string {
  const parsed = stringValue(value);
  if (!parsed) throw new Error(`Missing ${name}.`);
  return parsed;
}

function parseBooleanValue(value: unknown): boolean | null {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (normalized === "true") return true;
    if (normalized === "false") return false;
  }
  return null;
}

function stringValue(value: unknown): string | null {
  if (value == null) return null;
  const text = String(value).trim();
  return text.length > 0 ? text : null;
}

function asRows(data: unknown): JsonObject[] {
  if (!Array.isArray(data)) return [];
  return data.filter(isPlainObject) as JsonObject[];
}

function isPlainObject(value: unknown): value is JsonObject {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

function pickColumn(
  rows: JsonObject[],
  candidates: string[],
  fallback: string,
): string {
  if (rows.length > 0) {
    const keys = new Set(Object.keys(rows[0]));
    for (const candidate of candidates) {
      if (keys.has(candidate)) return candidate;
    }
  }
  return fallback;
}

function pickOptionalColumn(
  rows: JsonObject[],
  candidates: string[],
): string | null {
  if (rows.length === 0) return null;
  const keys = new Set(Object.keys(rows[0]));
  for (const candidate of candidates) {
    if (keys.has(candidate)) return candidate;
  }
  return null;
}

function firstImageToken(raw: string | null): string | null {
  if (!raw) return null;
  const normalized = raw.trim();
  if (!normalized.includes(",")) return normalized;
  const parts = normalized.split(",").map((part) => part.trim());
  for (const part of parts) {
    if (part) return part;
  }
  return null;
}

function isUuid(value: string): boolean {
  const uuidRegex =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidRegex.test(value);
}

function isMissingTableError(error: unknown): boolean {
  const message = String(error ?? "");
  return (
    message.includes("Could not find the table") ||
    (message.includes("relation") && message.includes("does not exist"))
  );
}

function isUndefinedColumnError(error: unknown): boolean {
  const message = String(error ?? "");
  return (
    (message.includes("column") && message.includes("does not exist")) ||
    (message.includes("Could not find the") && message.includes("column"))
  );
}

function jsonResponse(body: JsonObject, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
