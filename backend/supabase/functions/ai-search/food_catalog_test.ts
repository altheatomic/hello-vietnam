import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildFoodCatalog } from "./food_catalog.ts";

Deno.test("buildFoodCatalog joins translated names as aliases", () => {
  const catalog = buildFoodCatalog(
    [
      {
        id_food: "food-1",
        name: "Bún bò Huế",
        image_path: "foods/bun-bo-hue.jpg",
      },
    ],
    [
      {
        id_food: "food-1",
        lang_code: "en",
        name: "Hue beef noodle soup",
      },
      {
        id_food: "food-1",
        lang_code: "vi",
        name: "Bún bò Huế",
      },
    ],
  );

  assertEquals(catalog, [
    {
      id: "food-1",
      name: "Bún bò Huế",
      aliases: ["Hue beef noodle soup"],
      imagePath: "foods/bun-bo-hue.jpg",
    },
  ]);
});

Deno.test("buildFoodCatalog ignores malformed rows", () => {
  const catalog = buildFoodCatalog(
    [
      { id_food: null, name: "Missing ID" },
      { id_food: "food-2", name: null },
    ],
    [],
  );

  assertEquals(catalog, []);
});
