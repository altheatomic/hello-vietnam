/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { handleWishlistRequest } from "./wishlist_handler.ts";

Deno.serve((req: Request) => handleWishlistRequest(req));
