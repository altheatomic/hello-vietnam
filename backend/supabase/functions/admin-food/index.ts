/// <reference lib="dom" />

import { handleAdminFoodRequest } from "../admin/admin-food/admin_food_management_handler.ts";

Deno.serve((req: Request) => handleAdminFoodRequest(req));
