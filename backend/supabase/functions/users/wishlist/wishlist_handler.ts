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
  | "culture"
  | "activity"
  | "local_product";

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
const FAVORITE_CULTURE_TABLE = "favorite_culture";
const FAVORITE_ACTIVITY_TABLE = "favorite_activity";
const FAVORITE_LOCAL_PRODUCT_TABLE = "favorite_local_product";

const FOOD_TABLE = "food";
const FOOD_TRANSLATION_TABLE = "food_translation";
const PLACE_TABLE = "place";
const CULTURE_TABLE = "culture";
const ACTIVITY_TABLE = "activity";
const LOCAL_PRODUCTS_TABLE = "local_products";
const DEFAULT_LANGUAGE = "en";

const CITY_TABLE = "province";
const CITY_ID_CANDIDATES_BY_TABLE: Record<string, string[]> = {
  province: ["id_province"],
};

if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error(
    "Missing required Supabase environment variables for wishlist function.",
  );
}

export async function handleWishlistRequest(req: Request): Promise<Response> {
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
        return jsonResponse(
          await service.setFavorite(itemId, type, isFavorite),
        );
      }
      default:
        return jsonResponse({ error: `Unsupported action: ${action}` }, 400);
    }
  } catch (error) {
    console.error("[wishlist] unhandled error", error);
    if (error instanceof AuthorizationError) {
      return jsonResponse({ error: error.message }, error.statusCode);
    }
    const message = error instanceof Error
      ? error.message
      : "Unexpected error.";
    return jsonResponse({ error: message }, 500);
  }
}

class WishlistService {
  private favoriteItemColumnCache = new Map<string, string>();

  constructor(
    private readonly client: ReturnType<typeof createClient>,
    private readonly userId: string,
  ) {}

  async listWishlist(language: string): Promise<WishlistItem[]> {
    const foodConfig = favoriteConfigForType("food");
    const placeConfig = favoriteConfigForType("place");
    const cityConfig = favoriteConfigForType("city");
    const cultureConfig = favoriteConfigForType("culture");
    const activityConfig = favoriteConfigForType("activity");
    const localProductConfig = favoriteConfigForType("local_product");

    const [
      foodRows,
      placeRows,
      cityRows,
      cultureRows,
      activityRows,
      localProductRows,
    ] = await Promise.all([
      this.selectFavoriteRows(foodConfig.table, foodConfig.itemColumns, "food"),
      this.selectFavoriteRows(
        placeConfig.table,
        placeConfig.itemColumns,
        "place",
      ),
      this.selectFavoriteRows(cityConfig.table, cityConfig.itemColumns, "city"),
      this.selectFavoriteRows(
        cultureConfig.table,
        cultureConfig.itemColumns,
        "culture",
      ),
      this.selectFavoriteRows(
        activityConfig.table,
        activityConfig.itemColumns,
        "activity",
      ),
      this.selectFavoriteRows(
        localProductConfig.table,
        localProductConfig.itemColumns,
        "local_product",
      ),
    ]);

    const ordered = [
      ...foodRows,
      ...placeRows,
      ...cityRows,
      ...cultureRows,
      ...activityRows,
      ...localProductRows,
    ].sort(
      (a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt),
    );
    if (ordered.length === 0) return [];

    const cityIds = new Set<string>();
    const placeIds = new Set<string>();
    const foodIds = new Set<string>();
    const cultureIds = new Set<string>();
    const activityIds = new Set<string>();
    const localProductIds = new Set<string>();
    for (const row of ordered) {
      if (row.type === "city") cityIds.add(row.id);
      if (row.type === "place") placeIds.add(row.id);
      if (row.type === "food") foodIds.add(row.id);
      if (row.type === "culture") cultureIds.add(row.id);
      if (row.type === "activity") activityIds.add(row.id);
      if (row.type === "local_product") localProductIds.add(row.id);
    }

    const [
      cityMap,
      placeMap,
      foodMap,
      cultureMap,
      activityMap,
      localProductMap,
    ] = await Promise.all([
      this.loadCityItems(Array.from(cityIds)),
      this.loadPlaceItems(Array.from(placeIds)),
      this.loadFoodItems(Array.from(foodIds), language),
      this.loadGenericContentItems({
        ids: Array.from(cultureIds),
        table: CULTURE_TABLE,
        idColumn: "id",
        type: "culture",
        fallbackDescription: (title) =>
          `${title} is part of Vietnam cultural heritage.`,
      }),
      this.loadGenericContentItems({
        ids: Array.from(activityIds),
        table: ACTIVITY_TABLE,
        idColumn: "id",
        type: "activity",
        fallbackDescription: (title) =>
          `${title} is a memorable activity to try in Vietnam.`,
      }),
      this.loadGenericContentItems({
        ids: Array.from(localProductIds),
        table: LOCAL_PRODUCTS_TABLE,
        idColumn: "id",
        type: "local_product",
        fallbackDescription: (title) =>
          `${title} is one of Vietnam regional specialties.`,
      }),
    ]);

    const output: WishlistItem[] = [];
    const seen = new Set<string>();
    for (const ref of ordered) {
      const key = `${ref.type}:${ref.id}`;
      if (seen.has(key)) continue;

      const item = ref.type === "city"
        ? cityMap.get(ref.id)
        : ref.type === "place"
        ? placeMap.get(ref.id)
        : ref.type === "food"
        ? foodMap.get(ref.id)
        : ref.type === "culture"
        ? cultureMap.get(ref.id)
        : ref.type === "activity"
        ? activityMap.get(ref.id)
        : localProductMap.get(ref.id);
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
      const { error } = await this.client
        .from(config.table)
        .delete()
        .eq("id_user", this.userId)
        .eq(itemColumn, itemId);
      if (error) throw new Error(`${config.table}: ${error.message}`);
    }
  }

  private async isFavoriteByItemId(
    type: FavoriteType,
    itemId: string,
  ): Promise<boolean> {
    const config = favoriteConfigForType(type);
    const itemColumn = await this.resolveFavoriteItemColumn(config);
    const { data, error } = await this.client
      .from(config.table)
      .select(itemColumn)
      .eq("id_user", this.userId)
      .eq(itemColumn, itemId)
      .limit(1);

    if (error) throw new Error(`${config.table}: ${error.message}`);
    return asRows(data).length > 0;
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

    const resolvedId = type === "city"
      ? await this.findCityIdByName(normalizedName)
      : type === "place"
      ? await this.findPlaceIdByName(normalizedName)
      : type === "food"
      ? await this.findFoodIdByName(normalizedName)
      : type === "culture"
      ? await this.findGenericContentIdByName(CULTURE_TABLE, normalizedName)
      : type === "activity"
      ? await this.findGenericContentIdByName(ACTIVITY_TABLE, normalizedName)
      : await this.findGenericContentIdByName(
        LOCAL_PRODUCTS_TABLE,
        normalizedName,
      );

    if (!resolvedId) {
      throw new Error(`Cannot find ${type} id for "${normalizedName}".`);
    }
    return resolvedId;
  }

  private async assertItemExists(
    type: FavoriteType,
    itemId: string,
  ): Promise<void> {
    if (type === "city") {
      const { data, error } = await this.client
        .from(CITY_TABLE)
        .select("id_province")
        .eq("id_province", itemId)
        .maybeSingle();
      if (error) throw new Error(`${CITY_TABLE}: ${error.message}`);
      if (data == null) {
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

    if (type === "culture") {
      await this.assertGenericItemExists(CULTURE_TABLE, itemId, "Culture");
      return;
    }

    if (type === "activity") {
      await this.assertGenericItemExists(ACTIVITY_TABLE, itemId, "Activity");
      return;
    }

    if (type === "local_product") {
      await this.assertGenericItemExists(
        LOCAL_PRODUCTS_TABLE,
        itemId,
        "Local product",
      );
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

  private async assertGenericItemExists(
    table: string,
    itemId: string,
    label: string,
  ): Promise<void> {
    const { data, error } = await this.client
      .from(table)
      .select("id")
      .eq("id", itemId)
      .maybeSingle();
    if (error) throw new Error(`${table}: ${error.message}`);
    if (data == null) {
      throw new Error(`${label} item does not exist: ${itemId}`);
    }
  }

  private async selectFavoriteRows(
    table: string,
    itemColumns: string[],
    type: FavoriteType,
  ): Promise<FavoriteRef[]> {
    const itemColumn = itemColumns[0];
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

    const resolved = config.itemColumns[0];
    this.favoriteItemColumnCache.set(config.table, resolved);
    return resolved;
  }

  private async loadCityItems(
    ids: string[],
  ): Promise<Map<string, WishlistItem>> {
    if (ids.length === 0) return new Map<string, WishlistItem>();

    const cityRows = await selectRowsByIdCandidates(
      this.client,
      CITY_TABLE,
      ids,
      CITY_ID_CANDIDATES_BY_TABLE[CITY_TABLE],
      "id_province,name,short_description,cover_image",
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
        description: stringValue(
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
      "id_place,name,short_description,cover_image",
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
        description: stringValue(
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
      "id_food,name,description,image_path",
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
      const title = stringValue(trans?.[translationNameColumn]) ??
        stringValue(fallbackNameColumn ? row[fallbackNameColumn] : null) ??
        "Unnamed food";
      const description = stringValue(
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

  private async loadGenericContentItems(args: {
    ids: string[];
    table: string;
    idColumn: string;
    type: Extract<FavoriteType, "culture" | "activity" | "local_product">;
    fallbackDescription: (title: string) => string;
  }): Promise<Map<string, WishlistItem>> {
    const { ids, table, idColumn, type, fallbackDescription } = args;
    if (ids.length === 0) return new Map<string, WishlistItem>();

    const rows = await selectRowsByIdCandidates(
      this.client,
      table,
      ids,
      [idColumn],
      `${idColumn},name,short_description,cover_image`,
    );

    const output = new Map<string, WishlistItem>();
    for (const row of rows.rows) {
      const id = stringValue(row[rows.idColumn]);
      const title = stringValue(row.name);
      if (!id || !title) continue;

      output.set(id, {
        id,
        type,
        title,
        description: stringValue(row.short_description) ??
          fallbackDescription(title),
        imageUrl: firstImageToken(stringValue(row.cover_image)),
      });
    }
    return output;
  }

  private async findCityIdByName(cityName: string): Promise<string | null> {
    return findIdByName(this.client, {
      table: CITY_TABLE,
      idColumn: "id_province",
      nameColumn: "name",
      name: cityName,
    });
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

  private async findGenericContentIdByName(
    table: string,
    name: string,
  ): Promise<string | null> {
    return findIdByName(this.client, {
      table,
      idColumn: "id",
      nameColumn: "name",
      name,
    });
  }
}

function favoriteConfigForType(type: FavoriteType): FavoriteTableConfig {
  switch (type) {
    case "food":
      return {
        table: FAVORITE_FOOD_TABLE,
        itemColumns: ["id_food"],
      };
    case "place":
      return {
        table: FAVORITE_PLACE_TABLE,
        itemColumns: ["id_place"],
      };
    case "city":
      return {
        table: FAVORITE_CITY_TABLE,
        itemColumns: ["id_province"],
      };
    case "culture":
      return {
        table: FAVORITE_CULTURE_TABLE,
        itemColumns: ["id_culture"],
      };
    case "activity":
      return {
        table: FAVORITE_ACTIVITY_TABLE,
        itemColumns: ["id_activity"],
      };
    case "local_product":
      return {
        table: FAVORITE_LOCAL_PRODUCT_TABLE,
        itemColumns: ["id_local_product"],
      };
  }
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
  selectColumns = "*",
): Promise<{ idColumn: string; rows: JsonObject[] }> {
  for (const idColumn of idCandidates) {
    try {
      const { data, error } = await client
        .from(table)
        .select(selectColumns)
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
    `Could not determine id column for table "${table}". Tried: ${
      idCandidates.join(", ")
    }`,
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

export function parseFavoriteType(value: string | null): FavoriteType | null {
  if (!value) return null;
  const normalized = value.trim().toLowerCase();
  if (normalized === "localproduct" || normalized === "local-products") {
    return "local_product";
  }
  if (
    normalized === "city" ||
    normalized === "place" ||
    normalized === "food" ||
    normalized === "culture" ||
    normalized === "activity" ||
    normalized === "local_product"
  ) {
    return normalized;
  }
  return null;
}

function requireFavoriteType(value: unknown): FavoriteType {
  const parsed = parseFavoriteType(stringValue(value));
  if (!parsed) {
    throw new Error(
      'type must be one of "city", "place", "food", "culture", "activity", "local_product".',
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
