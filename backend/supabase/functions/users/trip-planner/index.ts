/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { handleTripPlannerRequest } from "./trip_handler.ts";

Deno.serve((req: Request) => handleTripPlannerRequest(req));
