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
type FavoriteType =
  | "city"
  | "place"
  | "food"
  | "activity"
  | "culture"
  | "localProduct";
type WishlistDisplayType =
  | FavoriteType;

type WishlistItemBase = {
  id: string;
  type: FavoriteType;
  displayType: WishlistDisplayType;
  title: string;
  description: string;
  imageUrl: string | null;
};

type WishlistItem = WishlistItemBase & {
  createdAt: string;
};

type FavoriteRef = {
  type: FavoriteType;
  id: string;
  createdAt: string;
};

type FavoriteTableConfig = {
  tables: string[];
  itemColumns: string[];
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const FAVORITE_FOOD_TABLE = "favorite_food";
const FAVORITE_PLACE_TABLE = "favorite_place";
const FAVORITE_PROVINCE_TABLE = "favorite_province";
const FAVORITE_CITY_TABLE = "favorite_city";
const FAVORITE_ACTIVITY_TABLE = "favorite_activity";
const FAVORITE_CULTURE_TABLE = "favorite_culture";
const FAVORITE_LOCAL_PRODUCT_TABLE = "favorite_local_product";

const FOOD_TABLE = "food";
const FOOD_TRANSLATION_TABLE = "food_translation";
const PLACE_TABLE = "place";
const ACTIVITY_TABLE = "activity";
const CULTURE_TABLE = "culture";
const LOCAL_PRODUCT_TABLE = "local_products";
const PLACE_TRANSLATION_TABLE = "place_translation";
const ACTIVITY_TRANSLATION_TABLE = "activity_translation";
const CULTURE_TRANSLATION_TABLE = "culture_translation";
const LOCAL_PRODUCTS_TRANSLATION_TABLE = "local_products_translation";
const PROVINCE_TRANSLATION_TABLE = "province_translation";
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
    const message = errorMessage(error);
    return jsonResponse({ error: message }, 500);
  }
}

class WishlistService {
  private cityTableName: string | null = null;
  private favoriteTableNameCache = new Map<string, string>();
  private favoriteItemColumnCache = new Map<string, string>();

  constructor(
    private readonly client: ReturnType<typeof createClient>,
    private readonly userId: string,
  ) {}

  async listWishlist(language: string): Promise<WishlistItem[]> {
    const foodConfig = favoriteConfigForType("food");
    const placeConfig = favoriteConfigForType("place");
    const cityConfig = favoriteConfigForType("city");
    const activityConfig = favoriteConfigForType("activity");
    const cultureConfig = favoriteConfigForType("culture");
    const localProductConfig = favoriteConfigForType("localProduct");

    const [foodRows, placeRows, cityRows, activityRows, cultureRows, localProductRows] =
        await Promise.all([
      this.selectFavoriteRows(foodConfig, "food"),
      this.selectFavoriteRows(placeConfig, "place"),
      this.selectFavoriteRows(cityConfig, "city"),
      this.selectFavoriteRows(activityConfig, "activity"),
      this.selectFavoriteRows(cultureConfig, "culture"),
      this.selectFavoriteRows(localProductConfig, "localProduct"),
    ]);

    const ordered = [
      ...foodRows,
      ...placeRows,
      ...cityRows,
      ...activityRows,
      ...cultureRows,
      ...localProductRows,
    ].sort(
      (a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt),
    );
    if (ordered.length === 0) return [];

    const cityIds = new Set<string>();
    const placeIds = new Set<string>();
    const foodIds = new Set<string>();
    const activityIds = new Set<string>();
    const cultureIds = new Set<string>();
    const localProductIds = new Set<string>();
    for (const row of ordered) {
      if (row.type === "city") cityIds.add(row.id);
      if (row.type === "place") placeIds.add(row.id);
      if (row.type === "food") foodIds.add(row.id);
      if (row.type === "activity") activityIds.add(row.id);
      if (row.type === "culture") cultureIds.add(row.id);
      if (row.type === "localProduct") localProductIds.add(row.id);
    }

    const cityMap = await this.loadCityItems(Array.from(cityIds), language);
    const placeMap = await this.loadPlaceItems(Array.from(placeIds), language);
    const foodMap = await this.loadFoodItems(Array.from(foodIds), language);
    const activityMap = await this.loadActivityItems(
      Array.from(activityIds),
      language,
    );
    const cultureMap = await this.loadCultureItems(
      Array.from(cultureIds),
      language,
    );
    const localProductMap = await this.loadLocalProductItems(
      Array.from(localProductIds),
      language,
    );

    const output: WishlistItem[] = [];
    const seen = new Set<string>();
    for (const ref of ordered) {
      const key = `${ref.type}:${ref.id}`;
      if (seen.has(key)) continue;

      const item =
        ref.type === "city"
          ? cityMap.get(ref.id)
          : ref.type === "activity"
          ? activityMap.get(ref.id)
          : ref.type === "culture"
          ? cultureMap.get(ref.id)
          : ref.type === "localProduct"
          ? localProductMap.get(ref.id)
          : ref.type === "place"
          ? placeMap.get(ref.id)
          : foodMap.get(ref.id);
      if (!item) continue;

      output.push({ ...item, createdAt: ref.createdAt });
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
    const tableName = await this.resolveFavoriteTableName(config);
    const itemColumn = await this.resolveFavoriteItemColumn(tableName, config);
    console.log(
      `[wishlist] setFavorite branch=${isFavorite ? "upsert" : "delete"} type=${type} table=${tableName} itemColumn=${itemColumn} itemId=${itemId}`,
    );

    if (isFavorite) {
      await this.assertItemExists(type, itemId);
      const { error } = await this.client.from(tableName).upsert(
        {
          id_user: this.userId,
          [itemColumn]: itemId,
          created_at: new Date().toISOString(),
        },
        { onConflict: `id_user,${itemColumn}` },
      );
      if (error) throw new Error(`${tableName}: ${error.message}`);
      return;
    }

    {
      const deleteColumns = favoriteItemColumnCandidatesForType(type);
      let deletedRowsCount = 0;

      for (const deleteColumn of deleteColumns) {
        try {
          const { data, error } = await this.client
            .from(tableName)
            .delete()
            .eq("id_user", this.userId)
            .eq(deleteColumn, itemId)
            .select(deleteColumn);

          if (error) {
            if (isUndefinedColumnError(error)) {
              continue;
            }
            throw new Error(`${tableName}: ${error.message}`);
          }

          const deletedRows = asRows(data);
          deletedRowsCount += deletedRows.length;
          console.log(
            `[wishlist] delete attempt table=${tableName} column=${deleteColumn} affected=${deletedRows.length}`,
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
        `[wishlist] delete type=${type} table=${tableName} user=${this.userId} item=${itemId} deleted_rows=${deletedRowsCount}`,
      );
    }
  }

  private async isFavoriteByItemId(
    type: FavoriteType,
    itemId: string,
  ): Promise<boolean> {
    const config = favoriteConfigForType(type);
    const tableName = await this.resolveFavoriteTableName(config);
    for (const itemColumn of favoriteItemColumnCandidatesForType(type)) {
      try {
        const { data, error } = await this.client
          .from(tableName)
          .select(itemColumn)
          .eq("id_user", this.userId)
          .eq(itemColumn, itemId)
          .limit(1);

        if (error) {
          if (isUndefinedColumnError(error)) {
            continue;
          }
          throw new Error(`${tableName}: ${error.message}`);
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
        : type === "activity"
        ? await this.findActivityIdByName(normalizedName)
        : type === "culture"
        ? await this.findCultureIdByName(normalizedName)
        : type === "localProduct"
        ? await this.findLocalProductIdByName(normalizedName)
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

    if (type === "activity") {
      await this.assertEntityExists(ACTIVITY_TABLE, ["id_activity", "activity_id", "id"], itemId, "Activity");
      return;
    }

    if (type === "culture") {
      await this.assertEntityExists(CULTURE_TABLE, ["id_culture", "culture_id", "id"], itemId, "Culture");
      return;
    }

    if (type === "localProduct") {
      await this.assertEntityExists(
        LOCAL_PRODUCT_TABLE,
        ["id_local_product", "local_product_id", "id_local_products", "id"],
        itemId,
        "Local product",
      );
      return;
    }

    if (type === "place") {
      await this.assertEntityExists(PLACE_TABLE, ["id_place", "place_id", "id"], itemId, "Place");
      return;
    }

    await this.assertEntityExists(FOOD_TABLE, ["id_food", "food_id", "id"], itemId, "Food");
  }

  private async selectFavoriteRows(
    config: FavoriteTableConfig,
    type: FavoriteType,
  ): Promise<FavoriteRef[]> {
    const table = await this.resolveFavoriteTableName(config);
    const itemColumn = await this.resolveFavoriteItemColumn(table, config);
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

  private async resolveFavoriteTableName(
    config: FavoriteTableConfig,
  ): Promise<string> {
    const cacheKey = config.tables.join("|");
    const cached = this.favoriteTableNameCache.get(cacheKey);
    if (cached) {
      return cached;
    }

    for (const tableName of config.tables) {
      try {
        const { error } = await this.client.from(tableName).select("*").limit(1);
        if (error) throw error;
        this.favoriteTableNameCache.set(cacheKey, tableName);
        return tableName;
      } catch (error) {
        if (isMissingTableError(error)) {
          continue;
        }
        throw error;
      }
    }

    throw new Error(`No favorite table found. Tried: ${config.tables.join(", ")}`);
  }

  private async resolveFavoriteItemColumn(
    tableName: string,
    config: FavoriteTableConfig,
  ): Promise<string> {
    const cached = this.favoriteItemColumnCache.get(tableName);
    if (cached) {
      return cached;
    }

    const resolved = await this.resolveColumnFromCandidates(
      tableName,
      config.itemColumns,
    );
    this.favoriteItemColumnCache.set(tableName, resolved);
    return resolved;
  }

  private async assertEntityExists(
    table: string,
    idCandidates: string[],
    itemId: string,
    label: string,
  ): Promise<void> {
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
      throw new Error(`${label} item does not exist: ${itemId}`);
    }
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

  private async loadCityItems(
    ids: string[],
    language: string,
  ): Promise<Map<string, WishlistItemBase>> {
    if (ids.length === 0) return new Map<string, WishlistItemBase>();

    const cityTable = await this.resolveCityTableName();
    if (!cityTable) return new Map<string, WishlistItemBase>();

    const cityRows = await selectRowsByIdCandidates(
      this.client,
      cityTable,
      ids,
      CITY_ID_CANDIDATES_BY_TABLE[cityTable] ?? ["id"],
    );
    const cityTranslations = await loadPreferredTranslationsForIds(
      this.client,
      PROVINCE_TRANSLATION_TABLE,
      ids,
      ["id_province", "id_city", "province_id", "city_id", "id"],
      language,
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

    const output = new Map<string, WishlistItemBase>();
    for (const row of cityRows.rows) {
      const id = stringValue(row[cityRows.idColumn]);
      const name = stringValue(row[nameColumn]);
      if (!id || !name) continue;
      const trans = cityTranslations.preferredById.get(id);
      const title =
        stringValue(
          trans && cityTranslations.titleColumn
            ? trans[cityTranslations.titleColumn]
            : null,
        ) ?? name;
      const description =
        stringValue(
          trans && cityTranslations.descriptionColumn
            ? trans[cityTranslations.descriptionColumn]
            : null,
        ) ??
        stringValue(
          descriptionColumn ? row[descriptionColumn] : null,
        ) ?? `${title} is a beautiful destination in Vietnam.`;

      output.set(id, {
        id,
        type: "city",
        displayType: "city",
        title,
        description,
        imageUrl:
          firstImageToken(
            stringValue(
              trans && cityTranslations.imageColumn
                ? trans[cityTranslations.imageColumn]
                : null,
            ),
          ) ??
          firstImageToken(stringValue(imageColumn ? row[imageColumn] : null)),
      });
    }
    return output;
  }

  private async loadPlaceItems(
    ids: string[],
    language: string,
  ): Promise<Map<string, WishlistItemBase>> {
    if (ids.length === 0) return new Map<string, WishlistItemBase>();

    const placeRows = await selectRowsByIdCandidates(
      this.client,
      PLACE_TABLE,
      ids,
      ["id_place", "place_id", "id"],
    );
    const placeTranslations = await loadPreferredTranslationsForIds(
      this.client,
      PLACE_TRANSLATION_TABLE,
      ids,
      ["id_place", "place_id", "id"],
      language,
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

    const output = new Map<string, WishlistItemBase>();
    for (const row of placeRows.rows) {
      const id = stringValue(row[placeRows.idColumn]);
      const name = stringValue(row[nameColumn]);
      if (!id || !name) continue;
      const trans = placeTranslations.preferredById.get(id);
      const title =
        stringValue(
          trans && placeTranslations.titleColumn
            ? trans[placeTranslations.titleColumn]
            : null,
        ) ?? name;
      const description =
        stringValue(
          trans && placeTranslations.descriptionColumn
            ? trans[placeTranslations.descriptionColumn]
            : null,
        ) ??
        stringValue(
          descriptionColumn ? row[descriptionColumn] : null,
        ) ?? `${title} is a must-visit place in Vietnam.`;

      output.set(id, {
        id,
        type: "place",
        displayType: "place",
        title,
        description,
        imageUrl:
          firstImageToken(
            stringValue(
              trans && placeTranslations.imageColumn
                ? trans[placeTranslations.imageColumn]
                : null,
            ),
          ) ??
          firstImageToken(stringValue(imageColumn ? row[imageColumn] : null)),
      });
    }
    return output;
  }

  private async loadFoodItems(
    ids: string[],
    language: string,
  ): Promise<Map<string, WishlistItemBase>> {
    if (ids.length === 0) return new Map<string, WishlistItemBase>();

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
      ["name", "title", "food_name"],
      "name",
    );
    const translationDescriptionColumn = pickOptionalColumn(
      translationRows.rows,
      ["description", "short_description", "summary", "overview", "content"],
    );

    const preferredTranslations = pickPreferredTranslations(
      translationRows.rows,
      translationRows.idColumn,
      translationLanguageColumn,
      language,
    );

    const output = new Map<string, WishlistItemBase>();
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
        displayType: "food",
        title,
        description,
        imageUrl: firstImageToken(
          stringValue(imageColumn ? row[imageColumn] : null),
        ),
      });
    }
    return output;
  }

  private async loadActivityItems(
    ids: string[],
    language: string,
  ): Promise<Map<string, WishlistItemBase>> {
    return this.loadTranslatedEntityItems({
      ids,
      table: ACTIVITY_TABLE,
      translationTable: ACTIVITY_TRANSLATION_TABLE,
      idCandidates: ["id_activity", "activity_id", "id"],
      type: "activity",
      displayType: "activity",
      emptyDescriptionFallback: "This activity is worth experiencing in Vietnam.",
      language,
    });
  }

  private async loadCultureItems(
    ids: string[],
    language: string,
  ): Promise<Map<string, WishlistItemBase>> {
    return this.loadTranslatedEntityItems({
      ids,
      table: CULTURE_TABLE,
      translationTable: CULTURE_TRANSLATION_TABLE,
      idCandidates: ["id_culture", "culture_id", "id"],
      type: "culture",
      displayType: "culture",
      emptyDescriptionFallback: "This cultural highlight reflects local heritage in Vietnam.",
      language,
    });
  }

  private async loadLocalProductItems(
    ids: string[],
    language: string,
  ): Promise<Map<string, WishlistItemBase>> {
    return this.loadTranslatedEntityItems({
      ids,
      table: LOCAL_PRODUCT_TABLE,
      translationTable: LOCAL_PRODUCTS_TRANSLATION_TABLE,
      idCandidates: ["id_local_product", "local_product_id", "id_local_products", "id"],
      type: "localProduct",
      displayType: "localProduct",
      emptyDescriptionFallback: "This local product is one of Vietnam's notable specialties.",
      language,
    });
  }

  private async loadTranslatedEntityItems(args: {
    ids: string[];
    table: string;
    translationTable: string;
    idCandidates: string[];
    type: FavoriteType;
    displayType: WishlistDisplayType;
    emptyDescriptionFallback: string;
    language: string;
  }): Promise<Map<string, WishlistItemBase>> {
    const {
      ids,
      table,
      translationTable,
      idCandidates,
      type,
      displayType,
      emptyDescriptionFallback,
      language,
    } = args;
    if (ids.length === 0) return new Map<string, WishlistItemBase>();

    const rows = await selectRowsByIdCandidates(
      this.client,
      table,
      ids,
      idCandidates,
    );
    const translations = await loadPreferredTranslationsForIds(
      this.client,
      translationTable,
      ids,
      idCandidates,
      language,
    );

    const nameColumn = pickOptionalColumn(rows.rows, [
      "name",
      "title",
      "province_name",
      "city_name",
      "place_name",
      "food_name",
      "activity_name",
      "culture_name",
      "local_product_name",
      "product_name",
    ]);
    const descriptionColumn = pickOptionalColumn(rows.rows, [
      "description",
      "short_description",
      "summary",
      "overview",
      "content",
    ]);
    const imageColumn = pickOptionalColumn(rows.rows, [
      "images_path",
      "image_path",
      "url_image",
      "cover_image",
      "image",
      "image_url",
    ]);

    const output = new Map<string, WishlistItemBase>();
    for (const row of rows.rows) {
      const id = stringValue(row[rows.idColumn]);
      if (!id) continue;

      const trans = translations.preferredById.get(id);
      const title =
        stringValue(
          trans && translations.titleColumn ? trans[translations.titleColumn] : null,
        ) ??
        stringValue(nameColumn ? row[nameColumn] : null) ??
        "Untitled";
      const description =
        stringValue(
          trans && translations.descriptionColumn
            ? trans[translations.descriptionColumn]
            : null,
        ) ??
        stringValue(descriptionColumn ? row[descriptionColumn] : null) ??
        emptyDescriptionFallback;
      const imageUrl =
        firstImageToken(
          stringValue(
            trans && translations.imageColumn ? trans[translations.imageColumn] : null,
          ),
        ) ?? firstImageToken(stringValue(imageColumn ? row[imageColumn] : null));

      output.set(id, {
        id,
        type,
        displayType,
        title,
        description,
        imageUrl,
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
    for (const idColumn of ["id_province", "id_city", "province_id", "city_id", "id"]) {
      for (const nameColumn of ["name", "title", "province_name", "city", "province"]) {
        const id = await findIdByName(this.client, {
          table: PROVINCE_TRANSLATION_TABLE,
          idColumn,
          nameColumn,
          name: cityName,
        });
        if (id) return id;
      }
    }

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
      for (const nameColumn of ["name", "title"]) {
        const translatedId = await findIdByName(this.client, {
          table: PLACE_TRANSLATION_TABLE,
          idColumn,
          nameColumn,
          name: placeName,
        });
        if (translatedId) return translatedId;
      }

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

  private async findActivityIdByName(activityName: string): Promise<string | null> {
    return findEntityIdByName(this.client, {
      table: ACTIVITY_TABLE,
      translationTable: ACTIVITY_TRANSLATION_TABLE,
      idCandidates: ["id_activity", "activity_id", "id"],
      name: activityName,
    });
  }

  private async findCultureIdByName(cultureName: string): Promise<string | null> {
    return findEntityIdByName(this.client, {
      table: CULTURE_TABLE,
      translationTable: CULTURE_TRANSLATION_TABLE,
      idCandidates: ["id_culture", "culture_id", "id"],
      name: cultureName,
    });
  }

  private async findLocalProductIdByName(
    localProductName: string,
  ): Promise<string | null> {
    return findEntityIdByName(this.client, {
      table: LOCAL_PRODUCT_TABLE,
      translationTable: LOCAL_PRODUCTS_TRANSLATION_TABLE,
      idCandidates: ["id_local_product", "local_product_id", "id_local_products", "id"],
      name: localProductName,
    });
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
        tables: [FAVORITE_FOOD_TABLE],
        itemColumns: ["id_food", "id_item", "food_id", "id"],
      };
    case "place":
      return {
        tables: [FAVORITE_PLACE_TABLE],
        itemColumns: ["id_place", "id_item", "place_id", "id"],
      };
    case "city":
      return {
        tables: [FAVORITE_PROVINCE_TABLE, FAVORITE_CITY_TABLE],
        itemColumns: ["id_province", "id_item", "id_city", "id"],
      };
    case "activity":
      return {
        tables: [FAVORITE_ACTIVITY_TABLE],
        itemColumns: ["id_activity", "activity_id", "id_item", "id"],
      };
    case "culture":
      return {
        tables: [FAVORITE_CULTURE_TABLE],
        itemColumns: ["id_culture", "culture_id", "id_item", "id"],
      };
    case "localProduct":
      return {
        tables: [FAVORITE_LOCAL_PRODUCT_TABLE],
        itemColumns: ["id_local_product", "local_product_id", "id_local_products", "id_item", "id"],
      };
  }
}

function favoriteItemColumnCandidatesForType(type: FavoriteType): string[] {
  const config = favoriteConfigForType(type);
  const ordered = [
    ...config.itemColumns,
    type === "food"
      ? "id_food"
      : type === "activity"
      ? "id_activity"
      : type === "culture"
      ? "id_culture"
      : type === "localProduct"
      ? "id_local_product"
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

async function loadPreferredTranslationsForIds(
  client: ReturnType<typeof createClient>,
  table: string,
  ids: string[],
  idCandidates: string[],
  language: string,
): Promise<{
  preferredById: Map<string, JsonObject>;
  titleColumn: string | null;
  descriptionColumn: string | null;
  imageColumn: string | null;
}> {
  if (ids.length === 0) {
    return {
      preferredById: new Map<string, JsonObject>(),
      titleColumn: null,
      descriptionColumn: null,
      imageColumn: null,
    };
  }

  try {
    const translationRows = await selectRowsByIdCandidates(
      client,
      table,
      ids,
      idCandidates,
    );
    const languageColumn = pickOptionalColumn(translationRows.rows, [
      "lang_code",
      "language",
      "lang",
      "locale",
    ]);

    return {
      preferredById: pickPreferredTranslations(
        translationRows.rows,
        translationRows.idColumn,
        languageColumn,
        language,
      ),
      titleColumn: pickOptionalColumn(translationRows.rows, [
        "name",
        "title",
        "province_name",
        "city_name",
        "place_name",
        "food_name",
        "activity_name",
        "culture_name",
        "local_product_name",
        "product_name",
      ]),
      descriptionColumn: pickOptionalColumn(translationRows.rows, [
        "description",
        "short_description",
        "summary",
        "overview",
        "content",
      ]),
      imageColumn: pickOptionalColumn(translationRows.rows, [
        "image_path",
        "images_path",
        "url_image",
        "cover_image",
        "image",
        "image_url",
      ]),
    };
  } catch (error) {
    if (isMissingTableError(error) || isUndefinedColumnError(error)) {
      return {
        preferredById: new Map<string, JsonObject>(),
        titleColumn: null,
        descriptionColumn: null,
        imageColumn: null,
      };
    }
    throw error;
  }
}

async function findEntityIdByName(
  client: ReturnType<typeof createClient>,
  args: {
    table: string;
    translationTable: string;
    idCandidates: string[];
    name: string;
  },
): Promise<string | null> {
  const { table, translationTable, idCandidates, name } = args;
  const nameCandidates = [
    "name",
    "title",
    "province_name",
    "city_name",
    "place_name",
    "food_name",
    "activity_name",
    "culture_name",
    "local_product_name",
    "product_name",
  ];

  for (const idColumn of idCandidates) {
    for (const nameColumn of nameCandidates) {
      const translatedId = await findIdByName(client, {
        table: translationTable,
        idColumn,
        nameColumn,
        name,
      });
      if (translatedId) return translatedId;
    }
  }

  for (const idColumn of idCandidates) {
    for (const nameColumn of nameCandidates) {
      const entityId = await findIdByName(client, {
        table,
        idColumn,
        nameColumn,
        name,
      });
      if (entityId) return entityId;
    }
  }

  return null;
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
  if (
    normalized === "city" ||
    normalized === "place" ||
    normalized === "food" ||
    normalized === "activity" ||
    normalized === "culture" ||
    normalized === "localproduct" ||
    normalized === "local_product"
  ) {
    return normalized === "localproduct" || normalized === "local_product"
      ? "localProduct"
      : (normalized as FavoriteType);
  }
  return null;
}

function requireFavoriteType(value: unknown): FavoriteType {
  const parsed = parseFavoriteType(stringValue(value));
  if (!parsed) {
    throw new Error(
      'type must be one of "city", "place", "food", "activity", "culture", "localProduct".',
    );
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

function uniqueNonEmptyStrings(values: Array<string | null>): string[] {
  const result = new Set<string>();
  for (const value of values) {
    if (value) {
      result.add(value);
    }
  }
  return Array.from(result);
}

function resolvePlaceDisplayType(
  placeRow: JsonObject,
  subcategoryRow: JsonObject | null | undefined,
): WishlistDisplayType {
  const candidates = [
    stringValue(placeRow["place_category"]),
    stringValue(placeRow["category"]),
    stringValue(placeRow["category_type"]),
    stringValue(placeRow["type"]),
    stringValue(placeRow["content_type"]),
    stringValue(subcategoryRow?.["place_category"]),
    stringValue(subcategoryRow?.["category"]),
    stringValue(subcategoryRow?.["category_type"]),
    stringValue(subcategoryRow?.["type"]),
    stringValue(subcategoryRow?.["name"]),
  ];

  for (const candidate of candidates) {
    const normalized = normalizeWishlistDisplayType(candidate);
    if (normalized) return normalized;
  }

  return "place";
}

function normalizeWishlistDisplayType(
  value: string | null,
): WishlistDisplayType | null {
  if (!value) return null;

  const normalized = value.toLowerCase().replace(/[\s_\-]/g, "");
  if (normalized.includes("localproduct") || normalized.includes("souvenir")) {
    return "localProduct";
  }
  if (normalized.includes("culture")) {
    return "culture";
  }
  if (normalized.includes("activity")) {
    return "activity";
  }
  if (normalized.includes("food")) {
    return "food";
  }
  if (normalized.includes("city") || normalized.includes("province")) {
    return "city";
  }
  if (
    normalized.includes("place") ||
    normalized.includes("destination") ||
    normalized.includes("attraction")
  ) {
    return "place";
  }
  return null;
}

function isUuid(value: string): boolean {
  const uuidRegex =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidRegex.test(value);
}

function isMissingTableError(error: unknown): boolean {
  const message = errorMessage(error);
  return (
    message.includes("Could not find the table") ||
    (message.includes("relation") && message.includes("does not exist")) ||
    (message.includes("Table \"") && message.includes("does not exist"))
  );
}

function isUndefinedColumnError(error: unknown): boolean {
  const message = errorMessage(error);
  return (
    (message.includes("column") && message.includes("does not exist")) ||
    (message.includes("Could not find the") && message.includes("column"))
  );
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  if (typeof error === "string") {
    return error;
  }
  if (error && typeof error === "object") {
    const record = error as Record<string, unknown>;
    const parts = [
      stringValue(record.message),
      stringValue(record.details),
      stringValue(record.hint),
      stringValue(record.code),
      stringValue(record.error_description),
      stringValue(record.error),
    ].filter((value): value is string => value != null && value.trim().length > 0);

    if (parts.length > 0) {
      return parts.join(" | ");
    }

    try {
      return JSON.stringify(error);
    } catch (_) {
      return String(error);
    }
  }
  return "Unexpected error.";
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
