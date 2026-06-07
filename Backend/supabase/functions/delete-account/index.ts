import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "DELETE, POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function errorResponse(errorCode: string, message: string, status: number): Response {
  return jsonResponse({ error: message, error_code: errorCode }, status);
}

function logError(scope: string, error: unknown): void {
  console.error(JSON.stringify({
    scope,
    message: error instanceof Error ? error.message : String(error),
  }));
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "DELETE" && request.method !== "POST") {
    return errorResponse("method_not_allowed", "Method not allowed.", 405);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return errorResponse("missing_bearer_token", "Missing bearer token.", 401);
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseURL || !anonKey || !serviceRoleKey) {
    return errorResponse("account_deletion_not_configured", "Account deletion is not configured.", 500);
  }

  const userClient = createClient(supabaseURL, anonKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
    global: {
      headers: { Authorization: authorization },
    },
  });

  const { data, error: userError } = await userClient.auth.getUser();
  if (userError || !data.user) {
    return errorResponse("invalid_session", "Invalid or expired session.", 401);
  }

  const adminClient = createClient(supabaseURL, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  const { error: deleteError } = await adminClient.auth.admin.deleteUser(data.user.id);
  if (deleteError) {
    logError("delete-account.delete-user", deleteError);
    return errorResponse("account_deletion_failed", "Account deletion failed. Please try again.", 500);
  }

  return jsonResponse({ deleted: true });
});
