/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { handleExploreRequest } from "./explore_handler.ts";

Deno.serve((req: Request) => handleExploreRequest(req));
