/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { handleRecommendRequest } from "./recommend_handler.ts";

Deno.serve((req: Request) => handleRecommendRequest(req));
