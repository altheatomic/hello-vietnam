/// <reference lib="dom" />

import { handleWishlistRequest } from "../users/wishlist/wishlist_handler.ts";

Deno.serve((req: Request) => handleWishlistRequest(req));
