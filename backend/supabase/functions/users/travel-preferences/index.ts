/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { handleTravelPreferencesRequest } from "./travel_preferences_handler.ts";

Deno.serve((req: Request) => handleTravelPreferencesRequest(req));
