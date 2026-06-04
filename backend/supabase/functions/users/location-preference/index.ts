/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { handleLocationPreferenceRequest } from "./location_preference_handler.ts";

Deno.serve((req: Request) => handleLocationPreferenceRequest(req));

