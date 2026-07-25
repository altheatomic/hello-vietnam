import {
  assertEquals,
  assertNotEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  findBestFoodMatch,
  type FoodCatalogEntry,
  normalizeFoodName,
} from "./food_matcher.ts";

const catalog: FoodCatalogEntry[] = [
  {
    id: "food-bun-bo-hue",
    name: "Bún bò Huế",
    aliases: ["Bun bo Hue", "Huế beef noodle soup"],
    imagePath: "foods/bun-bo-hue.jpg",
  },
  {
    id: "food-banh-mi",
    name: "Bánh mì",
    aliases: ["Vietnamese baguette"],
    imagePath: "foods/banh-mi.jpg",
  },
  {
    id: "food-bun-bo-nam-bo",
    name: "Bún bò Nam Bộ",
    aliases: ["Southern beef noodle salad"],
    imagePath: null,
  },
];

Deno.test("normalizeFoodName removes accents and punctuation", () => {
  assertEquals(normalizeFoodName("  Bún bò Huế!  "), "bun bo hue");
});

Deno.test("findBestFoodMatch links an exact accented food name", () => {
  const result = findBestFoodMatch({
    detectedName: "Bún bò Huế",
    alternativeNames: "",
    recognitionConfidence: 0.96,
    catalog,
  });

  assertEquals(result?.id, "food-bun-bo-hue");
  assertEquals(result?.name, "Bún bò Huế");
  assertEquals(result?.match_score, 1);
});

Deno.test("findBestFoodMatch links an unaccented AI result", () => {
  const result = findBestFoodMatch({
    detectedName: "Bun bo Hue",
    alternativeNames: "",
    recognitionConfidence: 0.91,
    catalog,
  });

  assertEquals(result?.id, "food-bun-bo-hue");
});

Deno.test("findBestFoodMatch considers alternative names", () => {
  const result = findBestFoodMatch({
    detectedName: "Bread",
    alternativeNames: "Vietnamese baguette, banh mi",
    recognitionConfidence: 0.88,
    catalog,
  });

  assertEquals(result?.id, "food-banh-mi");
});

Deno.test("findBestFoodMatch rejects unrelated or uncertain results", () => {
  const unrelated = findBestFoodMatch({
    detectedName: "Laptop computer",
    alternativeNames: "",
    recognitionConfidence: 0.99,
    catalog,
  });
  const uncertain = findBestFoodMatch({
    detectedName: "Bun bo Hue",
    alternativeNames: "",
    recognitionConfidence: 0.42,
    catalog,
  });

  assertEquals(unrelated, null);
  assertEquals(uncertain, null);
});

Deno.test("findBestFoodMatch does not guess between ambiguous candidates", () => {
  const result = findBestFoodMatch({
    detectedName: "bun bo",
    alternativeNames: "",
    recognitionConfidence: 0.94,
    catalog,
  });

  assertEquals(result, null);
  assertNotEquals(catalog[0].id, catalog[2].id);
});
