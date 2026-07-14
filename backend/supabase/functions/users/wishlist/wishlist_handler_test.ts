import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

async function loadParseFavoriteType() {
  Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
  Deno.env.set("SUPABASE_ANON_KEY", "anon");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-role");
  const module = await import("./wishlist_handler.ts");
  return module.parseFavoriteType;
}

Deno.test("parseFavoriteType accepts all wishlist entity types", async () => {
  const parseFavoriteType = await loadParseFavoriteType();

  assertEquals(parseFavoriteType("city"), "city");
  assertEquals(parseFavoriteType("place"), "place");
  assertEquals(parseFavoriteType("food"), "food");
  assertEquals(parseFavoriteType("culture"), "culture");
  assertEquals(parseFavoriteType("activity"), "activity");
  assertEquals(parseFavoriteType("local_product"), "local_product");
});

Deno.test("parseFavoriteType normalizes local product aliases", async () => {
  const parseFavoriteType = await loadParseFavoriteType();

  assertEquals(parseFavoriteType("localProduct"), "local_product");
  assertEquals(parseFavoriteType("local-products"), "local_product");
});

Deno.test("parseFavoriteType rejects unsupported values", async () => {
  const parseFavoriteType = await loadParseFavoriteType();

  assertEquals(parseFavoriteType("province"), null);
  assertEquals(parseFavoriteType(null), null);
});
