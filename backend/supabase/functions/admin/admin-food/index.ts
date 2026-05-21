/// <reference lib="dom" />
/// <reference path="./deno-globals.d.ts" />

import { handleAdminFoodRequest } from "./admin_food_management_handler.ts";

Deno.serve((req: Request) => handleAdminFoodRequest(req));
