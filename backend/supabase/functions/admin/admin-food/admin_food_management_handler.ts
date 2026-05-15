/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { createClient } from "@supabase/supabase-js";

import { corsHeaders } from "../../_shared/cors.ts";
import {
  AuthorizationError,
  requireAuthenticatedUserId,
  requireAuthorizationHeader,
  requireRole,
} from "../../auth/auth_guard.ts";

type JsonObject = Record<string, unknown>;

type AdminFoodPayload = {
  id?: string;
  name: string;
  typeId: string;
  city: string;
  urlImage?: string | null;
  description?: string | null;
};

type FoodTypePayload = {
  id: string;
  label: string;
  colorIndex?: number;
};

type FoodTranslationHints = {
  foodIdColumn: string;
  languageColumn: string | null;
  nameColumn: string;
  descriptionColumn: string;
};

type FoodTypeTranslationHints = {
  typeIdColumn: string;
  languageColumn: string | null;
  nameColumn: string;
};

type FoodTypeHints = {
  idColumn: string;
  codeColumn: string | null;
  typeColumn: string | null;
  nameColumn: string | null;
};

type CityHints = {
  idColumn: string;
  nameColumn: string;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const FOOD_TABLE = "food";
const FOOD_TRANSLATION_TABLE = "food_translation";
const FOOD_TYPE_TRANSLATION_TABLE = "food_type_translation";
const FOOD_TYPE_TABLE = "food_type";
const CITY_TABLE_CANDIDATES = ["province", "city_province", "city", "cities"];
const DEFAULT_LANGUAGE = "en";

if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error(
    "Missing required Supabase environment variables for admin-food function.",
  );
}

export async function handleAdminFoodRequest(req: Request): Promise<Response> {
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
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    const userId = await requireAuthenticatedUserId(userClient);

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    await requireRole(adminClient, userId, "admin");

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return jsonResponse({ error: "Invalid JSON body." }, 400);
    }

    const payload = body as JsonObject;
    const action = stringValue(payload.action);
    if (!action) {
      return jsonResponse({ error: "Missing action." }, 400);
    }

    const service = new AdminFoodService(adminClient);

    switch (action) {
      case "listFoods": {
        const language = stringValue(payload.language) ?? DEFAULT_LANGUAGE;
        const foods = await service.listFoods(language);
        return jsonResponse({ foods });
      }
      case "listFoodTypes": {
        const language = stringValue(payload.language) ?? DEFAULT_LANGUAGE;
        const foodTypes = await service.listFoodTypes(language);
        return jsonResponse({ foodTypes });
      }
      case "createFood": {
        const language = stringValue(payload.language) ?? DEFAULT_LANGUAGE;
        const food = requireFoodPayload(payload.food, false);
        const created = await service.createFood(food, language);
        return jsonResponse({ food: created }, 201);
      }
      case "updateFood": {
        const language = stringValue(payload.language) ?? DEFAULT_LANGUAGE;
        const food = requireFoodPayload(payload.food, true);
        const updated = await service.updateFood(food, language);
        return jsonResponse({ food: updated });
      }
      case "deleteFood": {
        const foodId = requiredString(payload.foodId, "foodId");
        await service.deleteFood(foodId);
        return jsonResponse({ success: true });
      }
      case "upsertFoodType": {
        const language = stringValue(payload.language) ?? DEFAULT_LANGUAGE;
        const foodType = requireFoodTypePayload(payload.foodType);
        await service.upsertFoodType(foodType, language);
        return jsonResponse({ success: true });
      }
      case "deleteFoodType": {
        const typeId = requiredString(payload.typeId, "typeId");
        await service.deleteFoodType(typeId);
        return jsonResponse({ success: true });
      }
      case "reassignFoodType": {
        const fromTypeId = requiredString(payload.fromTypeId, "fromTypeId");
        const toTypeId = requiredString(payload.toTypeId, "toTypeId");
        await service.reassignFoodType(fromTypeId, toTypeId);
        return jsonResponse({ success: true });
      }
      default:
        return jsonResponse({ error: `Unsupported action: ${action}` }, 400);
    }
  } catch (error) {
    if (error instanceof AuthorizationError) {
      return jsonResponse({ error: error.message }, error.statusCode);
    }
    const message = error instanceof Error ? error.message : "Unexpected error.";
    return jsonResponse({ error: message }, 500);
  }
}

class AdminFoodService {
  private foodIdColumn = "id_food";
  private foodTypeColumn = "food_type_id";
  private foodCityColumn = "id_province";
  private foodImageColumn = "image_path";
  private foodNameColumn = "name";
  private foodDescriptionColumn = "description";
  private foodCityIsForeignKey = true;

  private foodTranslationHints: FoodTranslationHints | null = null;
  private foodTypeTranslationHints: FoodTypeTranslationHints | null = null;
  private foodTypeHints: FoodTypeHints | null = null;
  private cityHints: CityHints | null = null;
  private cityTableName: string | null = null;

  constructor(private readonly client: ReturnType<typeof createClient>) {}

  async listFoods(language: string): Promise<JsonObject[]> {
    const foodRows = await selectRows(this.client, FOOD_TABLE);
    this.hydrateFoodColumnsFromRows(foodRows);

    const foodTransHints = await this.ensureFoodTranslationHints();
    const preferredFoodTranslations =
      await this.loadPreferredTranslationsByEntity(
        FOOD_TRANSLATION_TABLE,
        foodTransHints.foodIdColumn,
        foodTransHints.languageColumn,
        language,
      );

    const foodTranslationByFoodId = indexByStringKey(
      preferredFoodTranslations,
      foodTransHints.foodIdColumn,
    );

    let cityNameById = new Map<string, string>();
    if (this.foodCityIsForeignKey) {
      const cityHints = await this.ensureCityHints();
      if (cityHints && this.cityTableName) {
        const cityRows = await selectRows(this.client, this.cityTableName);
        cityNameById = indexNameById(
          cityRows,
          cityHints.idColumn,
          cityHints.nameColumn,
        );
      } else {
        // Fallback for deployments that keep city as plain text on food.
        this.foodCityIsForeignKey = false;
      }
    }

    const foods: JsonObject[] = [];
    for (const row of foodRows) {
      const foodId = stringValue(row[this.foodIdColumn]);
      if (!foodId) continue;

      const trans = foodTranslationByFoodId.get(foodId);
      const rawCityName = this.foodCityIsForeignKey
        ? cityNameById.get(stringValue(row[this.foodCityColumn]) ?? "") ??
          stringValue(row.city) ??
          stringValue(row.province) ??
          stringValue(row.city_province) ??
          ""
        : stringValue(row[this.foodCityColumn]) ??
          stringValue(row.city) ??
          stringValue(row.province) ??
          stringValue(row.city_province) ??
          "";
      const cityName = rawCityName.trim().length === 0 ? "Unknown" : rawCityName;

      const name =
        stringValue(trans?.[foodTransHints.nameColumn]) ??
        stringValue(row[this.foodNameColumn]) ??
        stringValue(row.name) ??
        "Unnamed food";

      foods.push({
        id: foodId,
        name,
        typeId:
          stringValue(row[this.foodTypeColumn]) ??
          stringValue(row.type) ??
          "",
        city: cityName,
        urlImage: stringValue(row[this.foodImageColumn]),
        description:
          stringValue(trans?.[foodTransHints.descriptionColumn]) ??
          stringValue(row[this.foodDescriptionColumn]) ??
          stringValue(row.description),
      });
    }

    return foods;
  }

  async listFoodTypes(language: string): Promise<JsonObject[]> {
    const hints = await this.ensureFoodTypeTranslationHints();
    const preferredTypeTranslations = await this.loadPreferredTranslationsByEntity(
      FOOD_TYPE_TRANSLATION_TABLE,
      hints.typeIdColumn,
      hints.languageColumn,
      language,
    );

    const uniqueById = new Map<string, JsonObject>();
    for (const row of preferredTypeTranslations) {
      const id = stringValue(row[hints.typeIdColumn]);
      const label = stringValue(row[hints.nameColumn]);
      if (!id || !label) continue;

      uniqueById.set(id, {
        id,
        label,
        colorIndex: colorIndexForTypeId(id),
      });
    }

    return Array.from(uniqueById.values()).sort((a, b) =>
      requiredString(a.label, "label").toLowerCase().localeCompare(
        requiredString(b.label, "label").toLowerCase(),
      )
    );
  }

  async createFood(
    food: AdminFoodPayload,
    language: string,
  ): Promise<JsonObject> {
    await this.ensureFoodColumns();
    const cityValue = this.foodCityIsForeignKey
      ? await this.resolveCityId(food.city)
      : cleanNullableText(food.city);

    const payload: JsonObject = {
      [this.foodNameColumn]: food.name,
      [this.foodDescriptionColumn]: cleanNullableText(food.description),
      [this.foodTypeColumn]: food.typeId,
      [this.foodCityColumn]: cityValue,
      [this.foodImageColumn]: cleanNullableText(food.urlImage),
    };

    const inserted = await insertSingle(this.client, FOOD_TABLE, payload);
    const foodId =
      stringValue(inserted[this.foodIdColumn]) ??
      stringValue(inserted.id_food) ??
      stringValue(inserted.id);

    if (!foodId) {
      throw new Error("Create food succeeded but no id was returned.");
    }

    try {
      await this.insertFoodTranslation(
        foodId,
        language,
        food.name,
        food.description,
      );
    } catch (error) {
      await deleteWhere(this.client, FOOD_TABLE, this.foodIdColumn, foodId);
      throw error;
    }

    return {
      id: foodId,
      name: food.name,
      typeId: food.typeId,
      city: food.city,
      urlImage: cleanNullableText(food.urlImage),
      description: cleanNullableText(food.description),
    };
  }

  async updateFood(
    food: AdminFoodPayload,
    language: string,
  ): Promise<JsonObject> {
    if (!food.id) {
      throw new Error("Food id is required for update.");
    }

    await this.ensureFoodColumns();
    const cityValue = this.foodCityIsForeignKey
      ? await this.resolveCityId(food.city)
      : cleanNullableText(food.city);

    const payload: JsonObject = {
      [this.foodNameColumn]: food.name,
      [this.foodDescriptionColumn]: cleanNullableText(food.description),
      [this.foodTypeColumn]: food.typeId,
      [this.foodCityColumn]: cityValue,
      [this.foodImageColumn]: cleanNullableText(food.urlImage),
    };

    await updateWhere(this.client, FOOD_TABLE, payload, this.foodIdColumn, food.id);
    await this.upsertFoodTranslation(food.id, language, food.name, food.description);

    return {
      id: food.id,
      name: food.name,
      typeId: food.typeId,
      city: food.city,
      urlImage: cleanNullableText(food.urlImage),
      description: cleanNullableText(food.description),
    };
  }

  async deleteFood(foodId: string): Promise<void> {
    const hints = await this.ensureFoodTranslationHints();
    await deleteWhere(this.client, FOOD_TRANSLATION_TABLE, hints.foodIdColumn, foodId);
    await deleteWhere(this.client, FOOD_TABLE, this.foodIdColumn, foodId);
  }

  async upsertFoodType(type: FoodTypePayload, language: string): Promise<void> {
    await this.ensureFoodTypeBaseRowExists(type.id, type.label);
    const hints = await this.ensureFoodTypeTranslationHints();

    const insertPayload: JsonObject = {
      [hints.typeIdColumn]: type.id,
      [hints.nameColumn]: type.label,
    };
    if (hints.languageColumn) {
      insertPayload[hints.languageColumn] = language;
    }

    let findQuery = this.client
      .from(FOOD_TYPE_TRANSLATION_TABLE)
      .select("*")
      .eq(hints.typeIdColumn, type.id);
    if (hints.languageColumn) {
      findQuery = findQuery.eq(hints.languageColumn, language);
    }

    const { data, error } = await findQuery.limit(1);
    if (error) throw new Error(error.message);

    if ((data ?? []).length > 0) {
      const updatePayload: JsonObject = {
        [hints.nameColumn]: type.label,
      };
      let updateQuery = this.client
        .from(FOOD_TYPE_TRANSLATION_TABLE)
        .update(updatePayload)
        .eq(hints.typeIdColumn, type.id);
      if (hints.languageColumn) {
        updateQuery = updateQuery.eq(hints.languageColumn, language);
      }

      const { error: updateError } = await updateQuery;
      if (updateError) throw new Error(updateError.message);
      return;
    }

    const { error: insertError } = await this.client
      .from(FOOD_TYPE_TRANSLATION_TABLE)
      .insert(insertPayload);
    if (insertError) throw new Error(insertError.message);
  }

  async deleteFoodType(typeId: string): Promise<void> {
    const hints = await this.ensureFoodTypeTranslationHints();
    await deleteWhere(
      this.client,
      FOOD_TYPE_TRANSLATION_TABLE,
      hints.typeIdColumn,
      typeId,
    );

    const baseHints = await this.ensureFoodTypeHints();
    await deleteWhere(this.client, FOOD_TYPE_TABLE, baseHints.idColumn, typeId);
  }

  async reassignFoodType(fromTypeId: string, toTypeId: string): Promise<void> {
    await this.ensureFoodColumns();
    await updateWhere(
      this.client,
      FOOD_TABLE,
      { [this.foodTypeColumn]: toTypeId },
      this.foodTypeColumn,
      fromTypeId,
    );
  }

  private async upsertFoodTranslation(
    foodId: string,
    language: string,
    name: string,
    description?: string | null,
  ): Promise<void> {
    const hints = await this.ensureFoodTranslationHints();
    const insertPayload: JsonObject = {
      [hints.foodIdColumn]: foodId,
      [hints.nameColumn]: name,
      [hints.descriptionColumn]: cleanNullableText(description),
    };
    if (hints.languageColumn) {
      insertPayload[hints.languageColumn] = language;
    }

    let findQuery = this.client
      .from(FOOD_TRANSLATION_TABLE)
      .select("*")
      .eq(hints.foodIdColumn, foodId);
    if (hints.languageColumn) {
      findQuery = findQuery.eq(hints.languageColumn, language);
    }

    const { data, error } = await findQuery.limit(1);
    if (error) throw new Error(error.message);

    if ((data ?? []).length > 0) {
      const updatePayload: JsonObject = {
        [hints.nameColumn]: name,
        [hints.descriptionColumn]: cleanNullableText(description),
      };
      let updateQuery = this.client
        .from(FOOD_TRANSLATION_TABLE)
        .update(updatePayload)
        .eq(hints.foodIdColumn, foodId);
      if (hints.languageColumn) {
        updateQuery = updateQuery.eq(hints.languageColumn, language);
      }

      const { error: updateError } = await updateQuery;
      if (updateError) throw new Error(updateError.message);
      return;
    }

    const { error: insertError } = await this.client
      .from(FOOD_TRANSLATION_TABLE)
      .insert(insertPayload);
    if (insertError) throw new Error(insertError.message);
  }

  private async insertFoodTranslation(
    foodId: string,
    language: string,
    name: string,
    description?: string | null,
  ): Promise<void> {
    const hints = await this.ensureFoodTranslationHints();
    const insertPayload: JsonObject = {
      [hints.foodIdColumn]: foodId,
      [hints.nameColumn]: name,
      [hints.descriptionColumn]: cleanNullableText(description),
    };
    if (hints.languageColumn) {
      insertPayload[hints.languageColumn] = language;
    }

    const { error } = await this.client
      .from(FOOD_TRANSLATION_TABLE)
      .insert(insertPayload);
    if (error) throw new Error(error.message);
  }

  private async ensureFoodColumns(): Promise<void> {
    const rows = await selectRows(this.client, FOOD_TABLE, 1);
    this.hydrateFoodColumnsFromRows(rows);
  }

  private hydrateFoodColumnsFromRows(rows: JsonObject[]): void {
    if (rows.length === 0) return;
    const sample = rows[0];

    this.foodIdColumn = pickExistingColumn(
      sample,
      ["id_food", "food_id", "id"],
      this.foodIdColumn,
    );
    this.foodTypeColumn = pickExistingColumn(
      sample,
      ["food_type_id", "id_food_type", "type_id", "type"],
      this.foodTypeColumn,
    );
    this.foodCityColumn = pickExistingColumn(
      sample,
      [
        "id_province",
        "province_id",
        "id_city",
        "city_id",
        "city_province",
        "city",
        "province",
      ],
      this.foodCityColumn,
    );
    this.foodCityIsForeignKey =
      this.foodCityColumn === "id_province" ||
      this.foodCityColumn === "province_id" ||
      this.foodCityColumn === "id_city" ||
      this.foodCityColumn === "city_id";
    this.foodImageColumn = pickExistingColumn(
      sample,
      ["image_path", "url_image", "image_url", "image"],
      this.foodImageColumn,
    );
    this.foodNameColumn = pickExistingColumn(
      sample,
      ["name", "food_name", "title"],
      this.foodNameColumn,
    );
    this.foodDescriptionColumn = pickExistingColumn(
      sample,
      ["description", "desc"],
      this.foodDescriptionColumn,
    );
  }

  private async ensureFoodTranslationHints(): Promise<FoodTranslationHints> {
    if (this.foodTranslationHints) return this.foodTranslationHints;

    const rows = await selectRows(this.client, FOOD_TRANSLATION_TABLE, 1);
    const sample = rows[0] ?? {};

    this.foodTranslationHints = {
      foodIdColumn: pickExistingColumn(sample, ["id_food", "food_id"], "food_id"),
      languageColumn: pickOptionalColumn(sample, [
        "lang_code",
        "language",
        "lang",
        "locale",
        "language_code",
      ]),
      nameColumn: pickExistingColumn(sample, ["name", "label", "title"], "name"),
      descriptionColumn: pickExistingColumn(
        sample,
        ["description", "desc"],
        "description",
      ),
    };

    return this.foodTranslationHints;
  }

  private async ensureFoodTypeTranslationHints(): Promise<FoodTypeTranslationHints> {
    if (this.foodTypeTranslationHints) return this.foodTypeTranslationHints;

    const rows = await selectRows(this.client, FOOD_TYPE_TRANSLATION_TABLE, 1);
    const sample = rows[0] ?? {};

    this.foodTypeTranslationHints = {
      typeIdColumn: pickExistingColumn(
        sample,
        ["food_type_id", "id_food_type", "type_id", "type"],
        "food_type_id",
      ),
      languageColumn: pickOptionalColumn(sample, [
        "lang_code",
        "language",
        "lang",
        "locale",
        "language_code",
      ]),
      nameColumn: pickExistingColumn(sample, ["name", "label", "title"], "name"),
    };

    return this.foodTypeTranslationHints;
  }

  private async ensureFoodTypeHints(): Promise<FoodTypeHints> {
    if (this.foodTypeHints) return this.foodTypeHints;

    const rows = await selectRows(this.client, FOOD_TYPE_TABLE, 1);
    const sample = rows[0] ?? {};
    const tableLooksEmpty = rows.length === 0;

    const detectedTypeColumn = pickOptionalColumn(sample, [
      "type",
      "food_type",
      "category_type",
    ]);
    const fallbackTypeColumn = tableLooksEmpty ? "type" : null;

    this.foodTypeHints = {
      idColumn: pickExistingColumn(
        sample,
        ["food_type_id", "id_food_type", "type_id", "id"],
        "food_type_id",
      ),
      codeColumn: pickOptionalColumn(sample, ["code", "type_code", "slug"]),
      typeColumn: detectedTypeColumn ?? fallbackTypeColumn,
      nameColumn: pickOptionalColumn(sample, ["name", "label", "title"]),
    };

    return this.foodTypeHints;
  }

  private async ensureCityHints(): Promise<CityHints | null> {
    if (this.cityHints) return this.cityHints;

    for (const tableName of CITY_TABLE_CANDIDATES) {
      try {
        const rows = await selectRows(this.client, tableName, 1);
        const sample = rows[0] ?? {};

        this.cityTableName = tableName;
        const idFallback = tableName === "province" ? "id_province" : "id_city";
        this.cityHints = {
          idColumn: pickExistingColumn(
            sample,
            ["id_province", "province_id", "id_city", "city_id", "id"],
            idFallback,
          ),
          nameColumn: pickExistingColumn(
            sample,
            ["name", "province_name", "city", "province"],
            "name",
          ),
        };
        return this.cityHints;
      } catch (error) {
        if (isMissingTableError(error)) {
          continue;
        }
        throw error;
      }
    }

    return null;
  }

  private async loadPreferredTranslationsByEntity(
    table: string,
    entityIdColumn: string,
    languageColumn: string | null,
    preferredLanguage: string,
  ): Promise<JsonObject[]> {
    const rows = await selectRows(this.client, table);
    if (rows.length === 0) return rows;

    const hasLanguageColumn = languageColumn
      ? Object.prototype.hasOwnProperty.call(rows[0], languageColumn)
      : false;

    const grouped = new Map<string, JsonObject[]>();
    for (const row of rows) {
      const entityId = stringValue(row[entityIdColumn]);
      if (!entityId) continue;
      const list = grouped.get(entityId) ?? [];
      list.push(row);
      grouped.set(entityId, list);
    }

    const picked: JsonObject[] = [];
    for (const groupRows of grouped.values()) {
      if (!hasLanguageColumn || !languageColumn) {
        picked.push(groupRows[0]);
        continue;
      }

      let exact: JsonObject | null = null;
      let english: JsonObject | null = null;

      for (const row of groupRows) {
        const lang = stringValue(row[languageColumn])?.toLowerCase();
        if (!lang) continue;
        if (lang === preferredLanguage.toLowerCase()) {
          exact = row;
          break;
        }
        if (lang === "en" && !english) {
          english = row;
        }
      }

      picked.push(exact ?? english ?? groupRows[0]);
    }

    return picked;
  }

  private async resolveCityId(cityName: string): Promise<string> {
    const hints = await this.ensureCityHints();
    if (!hints || !this.cityTableName) {
      throw new Error(
        "City/province lookup table is missing. Expected one of: province, city_province, city, cities.",
      );
    }

    const normalizedCity = cityName.trim();
    if (!normalizedCity) {
      throw new Error("City/Province cannot be empty.");
    }

    const { data, error } = await this.client
      .from(this.cityTableName)
      .select("*")
      .ilike(hints.nameColumn, normalizedCity)
      .limit(1);
    if (error) throw new Error(error.message);

    const rows = (data ?? []) as JsonObject[];
    if (rows.length > 0) {
      const id = stringValue(rows[0][hints.idColumn]);
      if (id) return id;
    }

    const inserted = await insertSingle(this.client, this.cityTableName, {
      [hints.nameColumn]: normalizedCity,
    });
    const insertedId = stringValue(inserted[hints.idColumn]);
    if (!insertedId) {
      throw new Error("City insert succeeded but no city id was returned.");
    }
    return insertedId;
  }

  private async ensureFoodTypeBaseRowExists(
    typeId: string,
    label?: string,
  ): Promise<void> {
    const hints = await this.ensureFoodTypeHints();

    const { data, error } = await this.client
      .from(FOOD_TYPE_TABLE)
      .select("*")
      .eq(hints.idColumn, typeId)
      .limit(1);
    if (error) throw new Error(error.message);
    if ((data ?? []).length > 0) return;

    const insertPayload: JsonObject = {
      [hints.idColumn]: typeId,
    };
    const normalizedLabel = (label ?? "").trim();
    if (hints.codeColumn) {
      insertPayload[hints.codeColumn] = `type-${typeId.slice(0, 8)}`;
    }
    if (hints.typeColumn && normalizedLabel) {
      insertPayload[hints.typeColumn] = normalizedLabel;
    }
    if (
      hints.nameColumn &&
      hints.nameColumn !== hints.typeColumn &&
      normalizedLabel
    ) {
      insertPayload[hints.nameColumn] = normalizedLabel;
    }

    const { error: insertError } = await this.client
      .from(FOOD_TYPE_TABLE)
      .insert(insertPayload);
    if (insertError) throw new Error(insertError.message);
  }
}

function requireFoodPayload(
  value: unknown,
  requireId: boolean,
): AdminFoodPayload {
  if (!value || typeof value !== "object") {
    throw new Error("Missing food payload.");
  }

  const payload = value as JsonObject;
  const food: AdminFoodPayload = {
    id: stringValue(payload.id) ?? undefined,
    name: requiredString(payload.name, "food.name"),
    typeId: requiredString(payload.typeId, "food.typeId"),
    city: requiredString(payload.city, "food.city"),
    urlImage: cleanNullableText(stringValue(payload.urlImage)),
    description: cleanNullableText(stringValue(payload.description)),
  };

  if (requireId && !food.id) {
    throw new Error("food.id is required.");
  }

  return food;
}

function requireFoodTypePayload(value: unknown): FoodTypePayload {
  if (!value || typeof value !== "object") {
    throw new Error("Missing foodType payload.");
  }

  const payload = value as JsonObject;
  return {
    id: requiredString(payload.id, "foodType.id"),
    label: requiredString(payload.label, "foodType.label"),
    colorIndex:
      typeof payload.colorIndex === "number"
        ? Math.trunc(payload.colorIndex)
        : undefined,
  };
}

async function selectRows(
  client: ReturnType<typeof createClient>,
  table: string,
  limit?: number,
): Promise<JsonObject[]> {
  let query = client.from(table).select("*");
  if (typeof limit === "number") {
    query = query.limit(limit);
  }

  const { data, error } = await query;
  if (error) throw new Error(`${table}: ${error.message}`);
  return (data ?? []) as JsonObject[];
}

async function insertSingle(
  client: ReturnType<typeof createClient>,
  table: string,
  payload: JsonObject,
): Promise<JsonObject> {
  const { data, error } = await client
    .from(table)
    .insert(payload)
    .select("*")
    .single();

  if (error) throw new Error(`${table}: ${error.message}`);
  return (data ?? {}) as JsonObject;
}

async function updateWhere(
  client: ReturnType<typeof createClient>,
  table: string,
  payload: JsonObject,
  column: string,
  value: string,
): Promise<void> {
  const { error } = await client.from(table).update(payload).eq(column, value);
  if (error) throw new Error(`${table}: ${error.message}`);
}

async function deleteWhere(
  client: ReturnType<typeof createClient>,
  table: string,
  column: string,
  value: string,
): Promise<void> {
  const { error } = await client.from(table).delete().eq(column, value);
  if (error) throw new Error(`${table}: ${error.message}`);
}

function pickExistingColumn(
  row: JsonObject,
  candidates: string[],
  fallback: string,
): string {
  for (const key of candidates) {
    if (Object.prototype.hasOwnProperty.call(row, key)) return key;
  }
  return fallback;
}

function pickOptionalColumn(row: JsonObject, candidates: string[]): string | null {
  for (const key of candidates) {
    if (Object.prototype.hasOwnProperty.call(row, key)) return key;
  }
  return null;
}

function indexByStringKey(
  rows: JsonObject[],
  idColumn: string,
): Map<string, JsonObject> {
  const output = new Map<string, JsonObject>();
  for (const row of rows) {
    const key = stringValue(row[idColumn]);
    if (!key) continue;
    output.set(key, row);
  }
  return output;
}

function indexNameById(
  rows: JsonObject[],
  idColumn: string,
  nameColumn: string,
): Map<string, string> {
  const output = new Map<string, string>();
  for (const row of rows) {
    const id = stringValue(row[idColumn]);
    const name = stringValue(row[nameColumn]);
    if (!id || !name) continue;
    output.set(id, name);
  }
  return output;
}

function colorIndexForTypeId(typeId: string): number {
  let hash = 0;
  for (const code of typeId) {
    hash = (hash * 31 + code.charCodeAt(0)) & 0x7fffffff;
  }
  return hash % 8;
}

function requiredString(value: unknown, name: string): string {
  const parsed = stringValue(value);
  if (!parsed) {
    throw new Error(`Missing ${name}.`);
  }
  return parsed;
}

function cleanNullableText(value: unknown): string | null {
  const parsed = stringValue(value);
  return parsed && parsed.length > 0 ? parsed : null;
}

function stringValue(value: unknown): string | null {
  if (value == null) return null;
  const text = String(value).trim();
  return text.length > 0 ? text : null;
}

function isMissingTableError(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error ?? "");
  return (
    message.includes("Could not find the table") ||
    message.includes("relation") && message.includes("does not exist")
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
