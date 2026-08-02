import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { discountForVoucher } from "./stripe_payment_store.ts";

Deno.test("discountForVoucher applies capped percentage discounts", () => {
  assertEquals(discountForVoucher(1999, "percent", 50, 500), 500);
});

Deno.test("discountForVoucher clamps fixed discounts to the order total", () => {
  assertEquals(discountForVoucher(499, "fixed", 2000, null), 499);
});

Deno.test("discountForVoucher never returns a negative discount", () => {
  assertEquals(discountForVoucher(499, "fixed", -100, null), 0);
});
