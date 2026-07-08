/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { createClient } from "@supabase/supabase-js";

import { corsHeaders } from "../_shared/cors.ts";
import {
  AuthorizationError,
  requireAuthenticatedUserId,
  requireAuthorizationHeader,
} from "../auth/auth_guard.ts";
import {
  computeInterestStateUpdate,
  EVENT_SCORES,
} from "./explore_behavior.ts";

type JsonObject = Record<string, unknown>;
type ExploreCategoryKey =
  | "activities"
  | "culture"
  | "food"
  | "local_products";
type ExploreContentType = "activity" | "culture" | "food" | "local_product";
type ExploreSortMode = "personalized" | "default" | "name";
type ExploreEventType =
  | "view_detail"
  | "share"
  | "favorite"
  | "add_to_trip"
  | "skip"
  | "unfavorite"
  | "remove_from_trip";

type ExploreItem = {
  id: string;
  name: string;
  imagePath: string;
  category: ExploreCategoryKey;
  subtitle: string | null;
  description: string | null;
  provinceId: string | null;
  provinceName: string | null;
  metadata: Record<string, unknown>;
  personalizedScore?: number;
  matchedTags?: string[];
};

type ExploreSection = {
  category: ExploreCategoryKey;
  items: ExploreItem[];
  emptyMessage: string | null;
};

type ProvinceSummary = {
  id: string;
  name: string;
  area: string | null;
  description: string | null;
};

type CategoryConfig = {
  responseKey: ExploreCategoryKey;
  contentType: ExploreContentType;
  tables: string[];
  translationTables: string[];
  translationIdCandidates: string[];
  translationLanguageCandidates: string[];
  idCandidates: string[];
  provinceCandidates: string[];
  nameCandidates: string[];
  imageCandidates: string[];
  galleryCandidates: string[];
  descriptionCandidates: string[];
  statusCandidates: string[];
  ratingCandidates: string[];
  reviewCountCandidates: string[];
  metadataCandidates: string[];
};

type ContentTypeConfig = {
  table: string;
  idColumn: string;
  provinceColumn: string;
  tagTable: string;
  tagContentIdColumn: string;
};

type ExploreEventPayload = {
  contentType: ExploreContentType;
  contentId: string;
  provinceId: string | null;
  eventType: ExploreEventType;
  requestId: string;
};

type PersonalizationResult = {
  scores: Map<string, number>;
  matchedTags: Map<string, string[]>;
  isPersonalized: boolean;
  personalizationReason: string | null;
  sortMode: ExploreSortMode;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const DEFAULT_SECTION_LIMIT = 4;
const DEFAULT_CATEGORY_LIMIT = 20;
const MAX_SECTION_LIMIT = 12;
const MAX_CATEGORY_LIMIT = 60;
const USER_EXPLORE_EVENT_TABLE = "user_explore_event";
const USER_INTEREST_TAG_TABLE = "user_interest_tag";
const TAG_TABLE = "tag";

const PROVINCE_TABLE_CANDIDATES = ["province", "city_province"];
const PROVINCE_ID_CANDIDATES = ["id_province", "id_city", "province_id", "id"];
const PROVINCE_NAME_CANDIDATES = ["name", "province_name", "city", "title"];
const PROVINCE_AREA_CANDIDATES = ["area", "region", "zone"];
const PROVINCE_DESCRIPTION_CANDIDATES = [
  "description",
  "short_description",
  "summary",
];

const EVENT_SCORE_MAP: Record<ExploreEventType, number> = EVENT_SCORES;

const CATEGORY_CONFIGS: Record<ExploreCategoryKey, CategoryConfig> = {
  activities: {
    responseKey: "activities",
    contentType: "activity",
    tables: ["activity", "activities"],
    translationTables: ["activity_translation", "activity_translations"],
    translationIdCandidates: ["activity_id", "id_activity", "id"],
    translationLanguageCandidates: ["lang_code", "language", "lang", "locale"],
    idCandidates: ["id_activity", "activity_id", "id"],
    provinceCandidates: ["id_province", "id_city", "province_id", "city_id"],
    nameCandidates: ["name", "title"],
    imageCandidates: [
      "cover_image",
      "image_path",
      "images_path",
      "url_image",
      "image",
    ],
    galleryCandidates: ["gallery", "images", "gallery_images"],
    descriptionCandidates: [
      "short_description",
      "description",
      "summary",
      "detailed_description",
    ],
    statusCandidates: ["status", "statuses"],
    ratingCandidates: ["average_rating", "rating_avg", "rating"],
    reviewCountCandidates: ["review_count", "rating_count"],
    metadataCandidates: ["activity_type", "opening_hours", "price_range"],
  },
  culture: {
    responseKey: "culture",
    contentType: "culture",
    tables: ["culture", "cultures"],
    translationTables: ["culture_translation", "culture_translations"],
    translationIdCandidates: ["culture_id", "id_culture", "id"],
    translationLanguageCandidates: ["lang_code", "language", "lang", "locale"],
    idCandidates: ["id_culture", "culture_id", "id"],
    provinceCandidates: ["id_province", "id_city", "province_id", "city_id"],
    nameCandidates: ["name", "title"],
    imageCandidates: [
      "cover_image",
      "image_path",
      "images_path",
      "url_image",
      "image",
    ],
    galleryCandidates: ["gallery", "images", "gallery_images"],
    descriptionCandidates: [
      "short_description",
      "description",
      "summary",
      "detailed_description",
      "cultural_significance",
    ],
    statusCandidates: ["status", "statuses"],
    ratingCandidates: ["average_rating", "rating_avg", "rating"],
    reviewCountCandidates: ["review_count", "rating_count"],
    metadataCandidates: ["origin_history", "event_time", "etiquette"],
  },
  food: {
    responseKey: "food",
    contentType: "food",
    tables: ["food", "foods"],
    translationTables: ["food_translation", "food_translations"],
    translationIdCandidates: ["food_id", "id_food", "id"],
    translationLanguageCandidates: ["lang_code", "language", "lang", "locale"],
    idCandidates: ["id_food", "food_id", "id"],
    provinceCandidates: ["id_province", "id_city", "province_id", "city_id"],
    nameCandidates: ["name", "title"],
    imageCandidates: [
      "cover_image",
      "image_path",
      "images_path",
      "url_image",
      "image",
    ],
    galleryCandidates: ["gallery", "images", "gallery_images"],
    descriptionCandidates: [
      "short_description",
      "description",
      "summary",
      "detailed_description",
    ],
    statusCandidates: ["status", "statuses"],
    ratingCandidates: ["average_rating", "rating_avg", "rating"],
    reviewCountCandidates: ["review_count", "rating_count"],
    metadataCandidates: ["type", "taste_profile", "price_range"],
  },
  local_products: {
    responseKey: "local_products",
    contentType: "local_product",
    tables: ["local_products", "local_product"],
    translationTables: [
      "local_products_translation",
      "local_product_translation",
      "local_products_translations",
    ],
    translationIdCandidates: ["local_product_id", "id_local_product", "id"],
    translationLanguageCandidates: ["lang_code", "language", "lang", "locale"],
    idCandidates: ["id_local_product", "local_product_id", "id"],
    provinceCandidates: ["id_province", "id_city", "province_id", "city_id"],
    nameCandidates: ["name", "title"],
    imageCandidates: [
      "cover_image",
      "image_path",
      "images_path",
      "url_image",
      "image",
    ],
    galleryCandidates: ["gallery", "images", "gallery_images"],
    descriptionCandidates: [
      "short_description",
      "description",
      "summary",
      "detailed_description",
    ],
    statusCandidates: ["status", "statuses"],
    ratingCandidates: ["average_rating", "rating_avg", "rating"],
    reviewCountCandidates: ["review_count", "rating_count"],
    metadataCandidates: ["category", "storage_transport", "price_range"],
  },
};

const CONTENT_TYPE_CONFIGS: Record<ExploreContentType, ContentTypeConfig> = {
  activity: {
    table: "activity",
    idColumn: "id",
    provinceColumn: "id_province",
    tagTable: "activity_tag",
    tagContentIdColumn: "id_activity",
  },
  culture: {
    table: "culture",
    idColumn: "id",
    provinceColumn: "id_province",
    tagTable: "culture_tag",
    tagContentIdColumn: "id_culture",
  },
  food: {
    table: "food",
    idColumn: "id_food",
    provinceColumn: "id_province",
    tagTable: "food_tag",
    tagContentIdColumn: "id_food",
  },
  local_product: {
    table: "local_products",
    idColumn: "id",
    provinceColumn: "id_province",
    tagTable: "local_product_tag",
    tagContentIdColumn: "id_local_product",
  },
};

if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error(
    "Missing required Supabase environment variables for explore function.",
  );
}

export async function handleExploreRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  try {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return jsonResponse({ error: "Invalid JSON body." }, 400);
    }

    const payload = body as JsonObject;
    const action = stringValue(payload.action);
    if (!action) {
      return jsonResponse({ error: "Missing action." }, 400);
    }

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const service = new ExploreService(adminClient);

    switch (action) {
      case "getExploreSections": {
        const provinceId = nullableString(payload.provinceId);
        const language = normalizedLanguage(payload.language);
        const userId = await resolveAuthenticatedUserIdOrNull(req);
        const limitPerCategory = clampPositiveInt(
          payload.limitPerCategory,
          DEFAULT_SECTION_LIMIT,
          MAX_SECTION_LIMIT,
        );
        return jsonResponse(
          await service.getExploreSections(
            provinceId,
            limitPerCategory,
            language,
            userId,
          ),
        );
      }
      case "searchExploreProvinces": {
        const query = requiredString(payload.query, "query");
        const limit = clampPositiveInt(payload.limit, 8, 20);
        return jsonResponse(await service.searchProvinces(query, limit));
      }
      case "getExploreCategoryItems": {
        const category = parseCategory(payload.category);
        const provinceId = nullableString(payload.provinceId);
        const language = normalizedLanguage(payload.language);
        const userId = await resolveAuthenticatedUserIdOrNull(req);
        const sortMode = parseSortMode(payload.sort);
        const limit = clampPositiveInt(
          payload.limit,
          DEFAULT_CATEGORY_LIMIT,
          MAX_CATEGORY_LIMIT,
        );
        const offset = clampNonNegativeInt(payload.offset, 0, 5000);
        return jsonResponse(
          await service.getExploreCategoryItems(
            category,
            provinceId,
            limit,
            offset,
            language,
            userId,
            sortMode,
          ),
        );
      }
      case "recordExploreEvent": {
        const userId = await requireAuthenticatedUserIdFromRequest(req);
        const event = parseExploreEventPayload(payload);
        return jsonResponse(await service.recordExploreEvent(userId, event));
      }
      default:
        return jsonResponse({ error: `Unsupported action: ${action}` }, 400);
    }
  } catch (error) {
    console.error("[explore] unhandled error", error);
    if (error instanceof AuthorizationError) {
      return jsonResponse({ error: error.message }, error.statusCode);
    }
    const message = error instanceof Error ? error.message : "Unexpected error.";
    return jsonResponse({ error: message }, 500);
  }
}

class ExploreService {
  private provinceTableName: string | null | undefined;

  constructor(private readonly client: ReturnType<typeof createClient>) {}

  async getExploreSections(
    requestedProvinceId: string | null,
    limitPerCategory: number,
    language: string | null,
    userId: string | null,
  ): Promise<JsonObject> {
    const province = await this.resolveProvinceOrNull(requestedProvinceId);
    const provinceId = province?.id ?? null;

    const sections = await Promise.all(
      (Object.keys(CATEGORY_CONFIGS) as ExploreCategoryKey[]).map(
        async (category) =>
          [
            category,
            await this.buildSection(
              category,
              province,
              provinceId,
              limitPerCategory,
              language,
              userId,
            ),
          ] as const,
      ),
    );

    return {
      province,
      sections: Object.fromEntries(sections),
    };
  }

  async searchProvinces(query: string, limit: number): Promise<JsonObject> {
    const rows = await this.loadProvinceRows();
    const needle = normalizeSearch(query);
    const matches = rows
      .map((row) => mapProvinceRow(row))
      .filter((item): item is ProvinceSummary => item != null)
      .filter((item) => {
        const haystacks = [
          normalizeSearch(item.name),
          normalizeSearch(item.area),
          normalizeSearch(item.description),
        ];
        return haystacks.some((value) => value.includes(needle));
      })
      .sort((a, b) => compareProvinceMatches(a, b, needle))
      .slice(0, limit);

    return { items: matches };
  }

  async getExploreCategoryItems(
    category: ExploreCategoryKey,
    requestedProvinceId: string | null,
    limit: number,
    offset: number,
    language: string | null,
    userId: string | null,
    sortMode: ExploreSortMode,
  ): Promise<JsonObject> {
    const province = await this.resolveProvinceOrNull(requestedProvinceId);
    const provinceId = province?.id ?? null;
    const loaded = await this.loadCategoryItems(
      CATEGORY_CONFIGS[category],
      province,
      provinceId,
      language,
      userId,
      sortMode,
    );

    const pagedItems = loaded.items.slice(offset, offset + limit);
    const nextOffset = offset + limit < loaded.items.length ? offset + limit : null;

    return {
      category,
      province,
      sort: loaded.sortMode,
      isPersonalized: loaded.isPersonalized,
      personalizationReason: loaded.personalizationReason,
      items: pagedItems,
      nextOffset,
      emptyMessage:
        pagedItems.length > 0
          ? null
          : loaded.emptyMessage ?? emptyMessageForCategory(category, province),
    };
  }

  async recordExploreEvent(
    userId: string,
    payload: ExploreEventPayload,
  ): Promise<JsonObject> {
    const existing = await this.findExistingEvent(userId, payload.requestId);
    if (existing) {
      return {
        success: true,
        duplicated: true,
        eventId: stringValue(existing.id_event),
        eventScore: numericValue(existing.event_score),
      };
    }

    const config = CONTENT_TYPE_CONFIGS[payload.contentType];
    const content = await this.loadContentRecord(config, payload.contentId);
    if (!content) {
      throw new Error(
        `Explore content not found for ${payload.contentType}:${payload.contentId}.`,
      );
    }

    if (
      payload.provinceId &&
      content.provinceId &&
      payload.provinceId !== content.provinceId
    ) {
      throw new Error("Content does not belong to the provided province.");
    }

    const eventScore = EVENT_SCORE_MAP[payload.eventType];
    const tagRows = await this.loadContentTagRows(config, payload.contentId);

    const { data: inserted, error: insertError } = await this.client
      .from(USER_EXPLORE_EVENT_TABLE)
      .insert({
        id_user: userId,
        content_type: payload.contentType,
        content_id: payload.contentId,
        id_province: content.provinceId ?? payload.provinceId,
        event_type: payload.eventType,
        event_score: eventScore,
        request_id: payload.requestId,
      })
      .select("id_event, event_score")
      .single();

    if (insertError) {
      if (isDuplicateKeyError(insertError)) {
        const duplicate = await this.findExistingEvent(userId, payload.requestId);
        if (duplicate) {
          return {
            success: true,
            duplicated: true,
            eventId: stringValue(duplicate.id_event),
            eventScore: numericValue(duplicate.event_score),
          };
        }
      }
      throw new Error(`${USER_EXPLORE_EVENT_TABLE}: ${insertError.message}`);
    }

    let updatedTags = 0;
    for (const tagRow of tagRows) {
      const didUpdate = await this.applyInterestDelta(userId, tagRow, eventScore);
      if (didUpdate) {
        updatedTags += 1;
      }
    }

    return {
      success: true,
      duplicated: false,
      eventId: stringValue(inserted?.["id_event"]),
      eventScore,
      updatedTags,
    };
  }

  private async buildSection(
    category: ExploreCategoryKey,
    province: ProvinceSummary | null,
    provinceId: string | null,
    limit: number,
    language: string | null,
    userId: string | null,
  ): Promise<ExploreSection> {
    const loaded = await this.loadCategoryItems(
      CATEGORY_CONFIGS[category],
      province,
      provinceId,
      language,
      userId,
      "personalized",
    );

    return {
      category,
      items: loaded.items.slice(0, limit),
      emptyMessage:
        loaded.items.length > 0
          ? null
          : loaded.emptyMessage ?? emptyMessageForCategory(category, province),
    };
  }

  private async loadCategoryItems(
    config: CategoryConfig,
    province: ProvinceSummary | null,
    provinceId: string | null,
    language: string | null,
    userId: string | null,
    sortMode: ExploreSortMode,
  ): Promise<{
    items: ExploreItem[];
    emptyMessage: string | null;
    isPersonalized: boolean;
    personalizationReason: string | null;
    sortMode: ExploreSortMode;
  }> {
    try {
      const loadedRows = await this.loadRowsFromCandidateTables(config.tables);
      if (!loadedRows) {
        console.warn(
          `[explore] no content table found for category=${config.responseKey}`,
        );
        return {
          items: [],
          emptyMessage: emptyMessageForCategory(config.responseKey, province),
          isPersonalized: false,
          personalizationReason: "missing_content_table",
          sortMode: "default",
        };
      }

      const rows = loadedRows.rows;
      const provinceColumn = pickOptionalColumn(rows, config.provinceCandidates);
      const idColumn = pickOptionalColumn(rows, config.idCandidates);
      const provinceRows =
        provinceId == null
          ? rows
          : provinceColumn == null
          ? []
          : rows.filter((row) => stringValue(row[provinceColumn]) === provinceId);

      const [provinceNameMap, translations, personalization] = await Promise.all([
        this.buildProvinceNameMap(provinceRows, provinceColumn),
        this.loadTranslations(config, provinceRows, idColumn, language),
        this.buildPersonalization(
          config,
          provinceRows,
          idColumn,
          userId,
          sortMode,
          provinceId,
        ),
      ]);

      const items = provinceRows
        .map((row) =>
          mapExploreItem(
            row,
            config,
            provinceNameMap,
            provinceColumn,
            translations,
            language,
            personalization,
          ),
        )
        .filter((item): item is ExploreItem => item != null)
        .sort((a, b) =>
          compareExploreItems(
            a,
            b,
            personalization.sortMode,
            provinceId,
          )
        );

      return {
        items,
        emptyMessage: null,
        isPersonalized: personalization.isPersonalized,
        personalizationReason: personalization.personalizationReason,
        sortMode: personalization.sortMode,
      };
    } catch (error) {
      console.error(
        `[explore] category load failed: ${config.tables.join(",")}`,
        error,
      );
      return {
        items: [],
        emptyMessage: emptyMessageForCategory(config.responseKey, province),
        isPersonalized: false,
        personalizationReason: "category_load_failed",
        sortMode: "default",
      };
    }
  }

  private async buildPersonalization(
    config: CategoryConfig,
    rows: JsonObject[],
    idColumn: string | null,
    userId: string | null,
    requestedSortMode: ExploreSortMode,
    provinceId: string | null,
  ): Promise<PersonalizationResult> {
    const base: PersonalizationResult = {
      scores: new Map<string, number>(),
      matchedTags: new Map<string, string[]>(),
      isPersonalized: false,
      personalizationReason: null,
      sortMode: requestedSortMode,
    };

    if (requestedSortMode !== "personalized") {
      return base;
    }

    if (provinceId == null) {
      return {
        ...base,
        personalizationReason: "no_province_default",
        sortMode: "default",
      };
    }

    if (!userId) {
      return {
        ...base,
        personalizationReason: "anonymous_default",
        sortMode: "default",
      };
    }

    if (!idColumn || rows.length === 0) {
      return {
        ...base,
        personalizationReason: "empty_content_set",
        sortMode: "default",
      };
    }

    const ids = uniqueStrings(
      rows
        .map((row) => stringValue(row[idColumn]))
        .filter((value): value is string => value != null),
    );
    if (ids.length === 0) {
      return {
        ...base,
        personalizationReason: "empty_content_set",
        sortMode: "default",
      };
    }

    const tagConfig = CONTENT_TYPE_CONFIGS[config.contentType];
    const { data: rawTagRows, error: tagError } = await this.client
      .from(tagConfig.tagTable)
      .select("id_tag, tag_role, " + tagConfig.tagContentIdColumn)
      .in(tagConfig.tagContentIdColumn, ids);
    if (tagError) {
      throw new Error(`${tagConfig.tagTable}: ${tagError.message}`);
    }

    const tagRows = asRows(rawTagRows);
    if (tagRows.length === 0) {
      return {
        ...base,
        personalizationReason: "no_content_tags",
        sortMode: "default",
      };
    }

    const tagIds = uniqueStrings(
      tagRows
        .map((row) => stringValue(row["id_tag"]))
        .filter((value): value is string => value != null),
    );
    if (tagIds.length === 0) {
      return {
        ...base,
        personalizationReason: "no_content_tags",
        sortMode: "default",
      };
    }

    const { data: interestRows, error: interestError } = await this.client
      .from(USER_INTEREST_TAG_TABLE)
      .select("id_tag, final_weight")
      .eq("id_user", userId)
      .in("id_tag", tagIds);
    if (interestError) {
      throw new Error(`${USER_INTEREST_TAG_TABLE}: ${interestError.message}`);
    }

    const interestMap = new Map<string, number>();
    for (const row of asRows(interestRows)) {
      const tagId = stringValue(row["id_tag"]);
      if (!tagId) continue;
      interestMap.set(tagId, numericValue(row["final_weight"]) ?? 0);
    }

    if (interestMap.size === 0) {
      return {
        ...base,
        personalizationReason: "no_interest_profile",
        sortMode: "default",
      };
    }

    const { data: tagMetadataRows, error: tagMetadataError } = await this.client
      .from(TAG_TABLE)
      .select("id_tag, tag_code, tag_name")
      .in("id_tag", tagIds);
    if (tagMetadataError) {
      throw new Error(`${TAG_TABLE}: ${tagMetadataError.message}`);
    }

    const tagLabelMap = new Map<string, string>();
    for (const row of asRows(tagMetadataRows)) {
      const tagId = stringValue(row["id_tag"]);
      const label = stringValue(row["tag_code"]) ?? stringValue(row["tag_name"]);
      if (tagId && label) {
        tagLabelMap.set(tagId, label);
      }
    }

    const scoreMap = new Map<string, number>();
    const matchedTags = new Map<string, string[]>();
    for (const row of tagRows) {
      const itemId = stringValue(row[tagConfig.tagContentIdColumn]);
      const tagId = stringValue(row["id_tag"]);
      if (!itemId || !tagId) continue;

      const finalWeight = interestMap.get(tagId) ?? 0;
      if (finalWeight <= 0) continue;

      const factor = tagRoleFactor(stringValue(row["tag_role"]));
      const nextScore = (scoreMap.get(itemId) ?? 0) + (finalWeight * factor);
      scoreMap.set(itemId, nextScore);

      const label = tagLabelMap.get(tagId);
      if (!label) continue;
      const currentLabels = matchedTags.get(itemId) ?? [];
      if (!currentLabels.includes(label)) {
        currentLabels.push(label);
        matchedTags.set(itemId, currentLabels);
      }
    }

    const isPersonalized = Array.from(scoreMap.values()).some((value) => value > 0);
    return {
      scores: scoreMap,
      matchedTags,
      isPersonalized,
      personalizationReason: isPersonalized
        ? "interest_and_behavior"
        : "no_matching_interests",
      sortMode: isPersonalized ? "personalized" : "default",
    };
  }

  private async applyInterestDelta(
    userId: string,
    tagRow: JsonObject,
    eventScore: number,
  ): Promise<boolean> {
    const tagId = stringValue(tagRow["id_tag"]);
    if (!tagId) {
      return false;
    }

    const factor = tagRoleFactor(stringValue(tagRow["tag_role"]));
    const delta = eventScore * factor;
    if (delta === 0) {
      return false;
    }

    const { data: current, error: currentError } = await this.client
      .from(USER_INTEREST_TAG_TABLE)
      .select("*")
      .eq("id_user", userId)
      .eq("id_tag", tagId)
      .maybeSingle();
    if (currentError) {
      throw new Error(`${USER_INTEREST_TAG_TABLE}: ${currentError.message}`);
    }

    const currentRow = isPlainObject(current) ? current : null;
    const nextState = computeInterestStateUpdate(
      {
        initialWeight: numericValue(currentRow?.["initial_weight"]) ?? 0,
        behaviorScore: numericValue(currentRow?.["behavior_score"]) ?? 0,
        positiveBehaviorCount:
          integerValue(currentRow?.["positive_behavior_count"]) ?? 0,
        negativeBehaviorCount:
          integerValue(currentRow?.["negative_behavior_count"]) ?? 0,
        behaviorCount: integerValue(currentRow?.["behavior_count"]) ?? 0,
        source: stringValue(currentRow?.["source"]),
      },
      eventScore,
      factor,
    );

    const { error: upsertError } = await this.client
      .from(USER_INTEREST_TAG_TABLE)
      .upsert(
        {
          id_user: userId,
          id_tag: tagId,
          initial_weight: nextState.initialWeight,
          behavior_score: nextState.behaviorScore,
          behavior_weight: nextState.behaviorWeight,
          final_weight: nextState.finalWeight,
          positive_behavior_count: nextState.positiveBehaviorCount,
          negative_behavior_count: nextState.negativeBehaviorCount,
          behavior_count: nextState.behaviorCount,
          source: nextState.source,
        },
        { onConflict: "id_user,id_tag" },
      );
    if (upsertError) {
      throw new Error(`${USER_INTEREST_TAG_TABLE}: ${upsertError.message}`);
    }

    return true;
  }

  private async findExistingEvent(
    userId: string,
    requestId: string,
  ): Promise<JsonObject | null> {
    const { data, error } = await this.client
      .from(USER_EXPLORE_EVENT_TABLE)
      .select("id_event, event_score")
      .eq("id_user", userId)
      .eq("request_id", requestId)
      .maybeSingle();
    if (error) {
      throw new Error(`${USER_EXPLORE_EVENT_TABLE}: ${error.message}`);
    }
    return isPlainObject(data) ? data : null;
  }

  private async loadContentRecord(
    config: ContentTypeConfig,
    contentId: string,
  ): Promise<{ id: string; provinceId: string | null } | null> {
    const { data, error } = await this.client
      .from(config.table)
      .select(`${config.idColumn},${config.provinceColumn}`)
      .eq(config.idColumn, contentId)
      .maybeSingle();
    if (error) {
      throw new Error(`${config.table}: ${error.message}`);
    }
    if (!isPlainObject(data)) {
      return null;
    }

    const id = stringValue(data[config.idColumn]);
    if (!id) {
      return null;
    }
    return {
      id,
      provinceId: stringValue(data[config.provinceColumn]),
    };
  }

  private async loadContentTagRows(
    config: ContentTypeConfig,
    contentId: string,
  ): Promise<JsonObject[]> {
    const { data, error } = await this.client
      .from(config.tagTable)
      .select("id_tag, tag_role")
      .eq(config.tagContentIdColumn, contentId);
    if (error) {
      throw new Error(`${config.tagTable}: ${error.message}`);
    }
    return asRows(data);
  }

  private async buildProvinceNameMap(
    rows: JsonObject[],
    provinceColumn: string | null,
  ): Promise<Map<string, string>> {
    const output = new Map<string, string>();
    if (provinceColumn == null) return output;

    const ids = Array.from(
      new Set(
        rows
          .map((row) => stringValue(row[provinceColumn]))
          .filter((value): value is string => value != null && value.length > 0),
      ),
    );
    if (ids.length === 0) return output;

    const provinceRows = await this.loadProvinceRows();
    for (const row of provinceRows) {
      const province = mapProvinceRow(row);
      if (!province) continue;
      if (!ids.includes(province.id)) continue;
      output.set(province.id, province.name);
    }
    return output;
  }

  private async resolveProvinceOrNull(
    provinceId: string | null,
  ): Promise<ProvinceSummary | null> {
    if (!provinceId) return null;

    const rows = await this.loadProvinceRows();
    for (const row of rows) {
      const province = mapProvinceRow(row);
      if (!province) continue;
      if (province.id === provinceId) {
        return province;
      }
    }
    return null;
  }

  private async loadTranslations(
    config: CategoryConfig,
    rows: JsonObject[],
    idColumn: string | null,
    language: string | null,
  ): Promise<Map<string, JsonObject>> {
    if (!language || !idColumn || rows.length === 0) {
      return new Map<string, JsonObject>();
    }

    const ids = uniqueStrings(
      rows
        .map((row) => stringValue(row[idColumn]))
        .filter((value): value is string => value != null),
    );
    if (ids.length === 0) {
      return new Map<string, JsonObject>();
    }

    const loadedTranslations = await this.loadRowsFromCandidateTables(
      config.translationTables,
    );
    if (!loadedTranslations) {
      return new Map<string, JsonObject>();
    }

    const translationRows = loadedTranslations.rows;
    const foreignKeyColumn = pickOptionalColumn(
      translationRows,
      config.translationIdCandidates,
    );
    const languageColumn = pickOptionalColumn(
      translationRows,
      config.translationLanguageCandidates,
    );
    if (!foreignKeyColumn) {
      return new Map<string, JsonObject>();
    }

    const filteredTranslations = translationRows.filter((row) => {
      const foreignId = stringValue(row[foreignKeyColumn]);
      return foreignId != null && ids.includes(foreignId);
    });

    return pickPreferredTranslations(
      filteredTranslations,
      foreignKeyColumn,
      languageColumn,
      language,
    );
  }

  private async loadProvinceRows(): Promise<JsonObject[]> {
    const table = await this.resolveProvinceTableName();
    if (!table) return [];

    const { data, error } = await this.client.from(table).select("*");
    if (error) {
      if (isMissingTableError(error)) {
        return [];
      }
      throw new Error(`${table}: ${error.message}`);
    }

    return asRows(data);
  }

  private async resolveProvinceTableName(): Promise<string | null> {
    if (this.provinceTableName !== undefined) {
      return this.provinceTableName;
    }

    for (const table of PROVINCE_TABLE_CANDIDATES) {
      try {
        const { error } = await this.client.from(table).select("*").limit(1);
        if (!error) {
          this.provinceTableName = table;
          return table;
        }
        if (isMissingTableError(error)) {
          continue;
        }
        throw new Error(`${table}: ${error.message}`);
      } catch (error) {
        if (isMissingTableError(error)) {
          continue;
        }
        throw error;
      }
    }

    this.provinceTableName = null;
    return null;
  }

  private async loadRowsFromCandidateTables(
    tables: string[],
  ): Promise<{ tableName: string; rows: JsonObject[] } | null> {
    for (const table of tables) {
      try {
        const { data, error } = await this.client.from(table).select("*");
        if (error) {
          if (isMissingTableError(error)) {
            continue;
          }
          throw new Error(`${table}: ${error.message}`);
        }
        return {
          tableName: table,
          rows: asRows(data),
        };
      } catch (error) {
        if (isMissingTableError(error)) {
          continue;
        }
        throw error;
      }
    }

    return null;
  }
}

function mapProvinceRow(row: JsonObject): ProvinceSummary | null {
  const idColumn = pickOptionalColumn([row], PROVINCE_ID_CANDIDATES);
  const nameColumn = pickOptionalColumn([row], PROVINCE_NAME_CANDIDATES);
  if (!idColumn || !nameColumn) return null;

  const id = stringValue(row[idColumn]);
  const name = stringValue(row[nameColumn]);
  if (!id || !name) return null;

  const areaColumn = pickOptionalColumn([row], PROVINCE_AREA_CANDIDATES);
  const descriptionColumn = pickOptionalColumn([row], PROVINCE_DESCRIPTION_CANDIDATES);

  return {
    id,
    name,
    area: stringValue(areaColumn ? row[areaColumn] : null),
    description: stringValue(descriptionColumn ? row[descriptionColumn] : null),
  };
}

function mapExploreItem(
  row: JsonObject,
  config: CategoryConfig,
  provinceNameMap: Map<string, string>,
  provinceColumn: string | null,
  translations: Map<string, JsonObject>,
  language: string | null,
  personalization: PersonalizationResult,
): ExploreItem | null {
  const idColumn = pickOptionalColumn([row], config.idCandidates);
  const nameColumn = pickOptionalColumn([row], config.nameCandidates);
  const imageColumn = pickOptionalColumn([row], config.imageCandidates);
  const galleryColumn = pickOptionalColumn([row], config.galleryCandidates);
  const descriptionColumn = pickOptionalColumn([row], config.descriptionCandidates);
  const ratingColumn = pickOptionalColumn([row], config.ratingCandidates);
  const reviewCountColumn = pickOptionalColumn([row], config.reviewCountCandidates);

  if (!idColumn || !nameColumn) {
    return null;
  }

  const id = stringValue(row[idColumn]);
  const translation = language ? translations.get(id ?? "") ?? null : null;
  const name = stringValue(translation?.[nameColumn]) ?? stringValue(row[nameColumn]);
  const imagePath =
    (imageColumn ? firstImageToken(row[imageColumn]) : null) ??
    firstGalleryToken(galleryColumn ? row[galleryColumn] : null) ??
    "";
  const description =
    (descriptionColumn
      ? stringValue(translation?.[descriptionColumn]) ??
        stringValue(row[descriptionColumn])
      : null) ?? null;
  if (!id || !name) {
    return null;
  }

  const provinceId = stringValue(provinceColumn ? row[provinceColumn] : null);
  const provinceName = provinceId ? provinceNameMap.get(provinceId) ?? null : null;
  const personalizedScore = roundScore(personalization.scores.get(id) ?? 0);
  const matchedTags = personalization.matchedTags.get(id) ?? [];

  return {
    id,
    name,
    imagePath,
    category: config.responseKey,
    subtitle: provinceName,
    description,
    provinceId,
    provinceName,
    metadata: {
      ...extractMetadata(row, config.metadataCandidates),
      ...(ratingColumn ? { [ratingColumn]: numericValue(row[ratingColumn]) } : {}),
      ...(reviewCountColumn
        ? { [reviewCountColumn]: integerValue(row[reviewCountColumn]) }
        : {}),
    },
    personalizedScore,
    matchedTags,
  };
}

function compareExploreItems(
  left: ExploreItem,
  right: ExploreItem,
  sortMode: ExploreSortMode,
  provinceId: string | null,
): number {
  if (sortMode === "personalized") {
    const leftScore = left.personalizedScore ?? 0;
    const rightScore = right.personalizedScore ?? 0;
    if (leftScore !== rightScore) {
      return rightScore - leftScore;
    }
  }

  if (sortMode === "name") {
    return left.name.localeCompare(right.name, "vi", { sensitivity: "base" });
  }

  const leftRating = numericValue(left.metadata.average_rating) ??
    numericValue(left.metadata.rating_avg) ??
    numericValue(left.metadata.rating) ??
    -1;
  const rightRating = numericValue(right.metadata.average_rating) ??
    numericValue(right.metadata.rating_avg) ??
    numericValue(right.metadata.rating) ??
    -1;
  if (leftRating !== rightRating) {
    return rightRating - leftRating;
  }

  const leftReviews = integerValue(left.metadata.review_count) ??
    integerValue(left.metadata.rating_count) ??
    -1;
  const rightReviews = integerValue(right.metadata.review_count) ??
    integerValue(right.metadata.rating_count) ??
    -1;
  if (leftReviews !== rightReviews) {
    return rightReviews - leftReviews;
  }

  if (provinceId == null) {
    return compareByStableDailyShuffle(left.id, right.id);
  }

  return left.name.localeCompare(right.name, "vi", { sensitivity: "base" });
}

function compareByStableDailyShuffle(leftId: string, rightId: string): number {
  const seed = currentDaySeed();
  const leftScore = seededHash(`${seed}:${leftId}`);
  const rightScore = seededHash(`${seed}:${rightId}`);
  if (leftScore !== rightScore) {
    return leftScore - rightScore;
  }
  return leftId.localeCompare(rightId, "en", { sensitivity: "base" });
}

function currentDaySeed(): string {
  return new Date().toISOString().slice(0, 10);
}

function seededHash(value: string): number {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function extractMetadata(
  row: JsonObject,
  candidates: string[],
): Record<string, unknown> {
  const output: Record<string, unknown> = {};
  for (const key of candidates) {
    if (!(key in row)) continue;
    const value = row[key];
    if (value == null) continue;
    if (typeof value === "string" && value.trim().length === 0) continue;
    output[key] = value;
  }
  return output;
}

function emptyMessageForCategory(
  category: ExploreCategoryKey,
  province: ProvinceSummary | null,
): string {
  const label = categoryLabel(category);
  if (province) {
    return `Content for ${label} in ${province.name} is being updated.`;
  }
  return `No ${label} data is available yet.`;
}

function categoryLabel(category: ExploreCategoryKey): string {
  switch (category) {
    case "activities":
      return "activities";
    case "culture":
      return "culture";
    case "food":
      return "food";
    case "local_products":
      return "local products";
  }
}

function compareProvinceMatches(
  left: ProvinceSummary,
  right: ProvinceSummary,
  query: string,
): number {
  const leftName = normalizeSearch(left.name);
  const rightName = normalizeSearch(right.name);
  const leftStarts = leftName.startsWith(query) ? 0 : 1;
  const rightStarts = rightName.startsWith(query) ? 0 : 1;
  if (leftStarts !== rightStarts) return leftStarts - rightStarts;
  return left.name.localeCompare(right.name, "vi", { sensitivity: "base" });
}

function parseCategory(value: unknown): ExploreCategoryKey {
  const normalized = normalizeCategory(stringValue(value));
  if (!normalized) {
    throw new Error("Invalid category.");
  }
  return normalized;
}

function normalizeCategory(value: string | null): ExploreCategoryKey | null {
  if (!value) return null;

  switch (value.trim().toLowerCase()) {
    case "activities":
    case "activity":
      return "activities";
    case "culture":
      return "culture";
    case "food":
      return "food";
    case "local_product":
    case "local_products":
    case "local product":
    case "local products":
      return "local_products";
    default:
      return null;
  }
}

function parseContentType(value: unknown): ExploreContentType {
  const parsed = stringValue(value)?.trim().toLowerCase();
  switch (parsed) {
    case "activity":
    case "activities":
      return "activity";
    case "culture":
      return "culture";
    case "food":
      return "food";
    case "local_product":
    case "local_products":
    case "local product":
    case "local products":
      return "local_product";
    default:
      throw new Error("Invalid contentType.");
  }
}

function parseSortMode(value: unknown): ExploreSortMode {
  const parsed = stringValue(value)?.trim().toLowerCase();
  switch (parsed) {
    case "default":
      return "default";
    case "name":
      return "name";
    case "personalized":
    case null:
    case undefined:
      return "personalized";
    default:
      throw new Error("Invalid sort.");
  }
}

function parseExploreEventPayload(value: JsonObject): ExploreEventPayload {
  const contentType = parseContentType(value.contentType);
  const contentId = requiredString(value.contentId, "contentId");
  const provinceId = nullableString(value.provinceId);
  const requestId = requiredString(value.requestId, "requestId");
  const rawEventType = requiredString(value.eventType, "eventType");

  if (!hasOwn(EVENT_SCORE_MAP, rawEventType)) {
    throw new Error(`Unsupported eventType: ${rawEventType}`);
  }

  return {
    contentType,
    contentId,
    provinceId,
    requestId,
    eventType: rawEventType as ExploreEventType,
  };
}

function isRenderableStatus(value: unknown): boolean {
  const status = stringValue(value);
  if (!status) return true;

  switch (status.trim().toLowerCase()) {
    case "active":
    case "published":
    case "approved":
    case "enabled":
    case "public":
    case "live":
      return true;
    case "inactive":
    case "disabled":
    case "draft":
    case "archived":
    case "deleted":
    case "hidden":
      return false;
    default:
      return true;
  }
}

function tagRoleFactor(tagRole: string | null): number {
  switch (tagRole?.trim().toLowerCase()) {
    case "primary":
      return 1;
    case "secondary":
    case null:
    case undefined:
      return 0.5;
    default:
      return 0.5;
  }
}

function firstImageToken(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed) return null;

  if (trimmed.startsWith("[")) {
    try {
      const parsed = JSON.parse(trimmed);
      if (Array.isArray(parsed)) {
        for (const item of parsed) {
          if (typeof item === "string" && item.trim().length > 0) {
            return item.trim();
          }
        }
      }
    } catch {
      return trimmed;
    }
  }

  return trimmed;
}

function firstGalleryToken(value: unknown): string | null {
  if (Array.isArray(value)) {
    for (const item of value) {
      const parsed = stringValue(item);
      if (parsed) return parsed;
    }
    return null;
  }

  if (typeof value === "string") {
    const trimmed = value.trim();
    if (!trimmed) return null;
    if (trimmed.startsWith("[")) {
      try {
        const parsed = JSON.parse(trimmed);
        return firstGalleryToken(parsed);
      } catch {
        return null;
      }
    }
  }

  if (value && typeof value === "object") {
    const objectValue = value as Record<string, unknown>;
    for (const candidate of ["images", "items", "gallery"]) {
      if (candidate in objectValue) {
        const parsed = firstGalleryToken(objectValue[candidate]);
        if (parsed) return parsed;
      }
    }
  }

  return null;
}

function pickOptionalColumn(rows: JsonObject[], candidates: string[]): string | null {
  if (rows.length === 0) return null;

  const keys = new Set<string>();
  for (const row of rows) {
    for (const key of Object.keys(row)) {
      keys.add(key);
    }
  }

  for (const candidate of candidates) {
    if (keys.has(candidate)) return candidate;
  }
  return null;
}

function asRows(data: unknown): JsonObject[] {
  if (!Array.isArray(data)) return [];
  return data.filter(isPlainObject) as JsonObject[];
}

function isPlainObject(value: unknown): value is JsonObject {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function stringValue(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function nullableString(value: unknown): string | null {
  return stringValue(value);
}

function normalizedLanguage(value: unknown): string | null {
  const parsed = stringValue(value)?.toLowerCase();
  return parsed && parsed.length > 0 ? parsed : null;
}

function requiredString(value: unknown, fieldName: string): string {
  const result = stringValue(value);
  if (!result) {
    throw new Error(`Missing ${fieldName}.`);
  }
  return result;
}

function clampPositiveInt(
  value: unknown,
  fallback: number,
  max: number,
): number {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }
  return Math.min(Math.floor(parsed), max);
}

function clampNonNegativeInt(
  value: unknown,
  fallback: number,
  max: number,
): number {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) {
    return fallback;
  }
  return Math.min(Math.floor(parsed), max);
}

function clampNumber(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

function normalizeSearch(value: string | null): string {
  return (value ?? "")
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .trim();
}

function numericValue(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return null;
}

function integerValue(value: unknown): number | null {
  const parsed = numericValue(value);
  return parsed == null ? null : Math.trunc(parsed);
}

function uniqueStrings(values: string[]): string[] {
  return Array.from(new Set(values));
}

function hasOwn<T extends object>(
  source: T,
  key: PropertyKey,
): key is keyof T {
  return Object.prototype.hasOwnProperty.call(source, key);
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
    const existing = grouped.get(id) ?? [];
    existing.push(row);
    grouped.set(id, existing);
  }

  const preferred = new Map<string, JsonObject>();
  for (const [id, candidates] of grouped.entries()) {
    if (!languageColumn) {
      preferred.set(id, candidates[0]);
      continue;
    }

    const normalized = language.toLowerCase();
    const languageRoot = normalized.split("-")[0];
    let exact: JsonObject | null = null;
    let sameRoot: JsonObject | null = null;
    let english: JsonObject | null = null;
    for (const candidate of candidates) {
      const candidateLanguage = stringValue(candidate[languageColumn])?.toLowerCase();
      if (!candidateLanguage) continue;
      if (candidateLanguage === normalized) {
        exact = candidate;
        break;
      }
      if (!sameRoot && candidateLanguage.split("-")[0] === languageRoot) {
        sameRoot = candidate;
      }
      if (!english && candidateLanguage === "en") {
        english = candidate;
      }
    }
    preferred.set(id, exact ?? sameRoot ?? english ?? candidates[0]);
  }
  return preferred;
}

function isMissingTableError(error: unknown): boolean {
  const message = errorMessage(error).toLowerCase();
  return (
    message.includes("does not exist") ||
    message.includes("schema cache") ||
    message.includes("could not find the table")
  );
}

function isDuplicateKeyError(error: unknown): boolean {
  const message = errorMessage(error).toLowerCase();
  return (
    message.includes("duplicate key") ||
    message.includes("already exists") ||
    message.includes("23505")
  );
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  if (error && typeof error === "object") {
    return JSON.stringify(error);
  }
  return String(error);
}

function roundScore(value: number): number {
  return Math.round(value * 1000) / 1000;
}

async function resolveAuthenticatedUserIdOrNull(
  req: Request,
): Promise<string | null> {
  const authHeader = optionalAuthorizationHeader(req.headers.get("Authorization"));
  if (!authHeader) {
    return null;
  }

  try {
    const userClient = createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!, {
      global: { headers: { Authorization: authHeader } },
    });
    return await requireAuthenticatedUserId(userClient);
  } catch (error) {
    if (error instanceof AuthorizationError) {
      return null;
    }
    throw error;
  }
}

async function requireAuthenticatedUserIdFromRequest(
  req: Request,
): Promise<string> {
  const authHeader = requireAuthorizationHeader(
    req.headers.get("Authorization"),
  );
  const userClient = createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!, {
    global: { headers: { Authorization: authHeader } },
  });
  return requireAuthenticatedUserId(userClient);
}

function optionalAuthorizationHeader(value: string | null): string | null {
  const token = value?.trim();
  return token ? token : null;
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
