/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { handleReviewsRequest } from "./reviews_handler.ts";

Deno.serve((req: Request) => handleReviewsRequest(req));
