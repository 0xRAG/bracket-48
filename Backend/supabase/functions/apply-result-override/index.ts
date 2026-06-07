import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  applyActiveResultOverrides,
  hasCorrectedResultField,
  type ResultOverrideRow,
} from "../_shared/result-overrides.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://bracket48.app",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return errorResponse("method_not_allowed", "Method not allowed.", 405);
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const syncSecret = Deno.env.get("SYNC_RESULTS_SECRET");

  if (!supabaseURL || !serviceRoleKey) {
    return errorResponse("override_not_configured", "Result overrides are not configured.", 500);
  }

  const authorization = request.headers.get("Authorization");
  const providedSyncSecret = request.headers.get("x-sync-secret");
  const isAuthorized = authorization === `Bearer ${serviceRoleKey}`
    || (!!syncSecret && providedSyncSecret === syncSecret);

  if (!isAuthorized) {
    return errorResponse("unauthorized", "Unauthorized.", 401);
  }

  const body = await safeJSON(request);
  const override = overrideFromBody(body);
  const scoringPoolID = stringValue(body.scoring_pool_id);
  if (!override) {
    return errorResponse(
      "invalid_override",
      "Provide a match id, reason, and at least one corrected result field.",
      400,
    );
  }

  const adminClient = createClient(supabaseURL, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  try {
    const { data: match, error: matchError } = await adminClient
      .from("tournament_matches")
      .select("id")
      .eq("id", override.match_id)
      .single();

    if (matchError || !match?.id) {
      return errorResponse("match_not_found", "The match to override was not found.", 404);
    }

    const { error: deactivateError } = await adminClient
      .from("result_overrides")
      .update({ is_active: false })
      .eq("match_id", override.match_id)
      .eq("is_active", true);

    if (deactivateError) {
      throw deactivateError;
    }

    const { data: insertedOverride, error: insertError } = await adminClient
      .from("result_overrides")
      .insert(override)
      .select("id")
      .single();

    if (insertError || !insertedOverride?.id) {
      throw insertError ?? new Error("Could not insert result override.");
    }

    const appliedOverrideCount = await applyActiveResultOverrides(adminClient, [override.match_id]);
    const scoringInvoked = await invokeScoring(supabaseURL, syncSecret, scoringPoolID);

    return jsonResponse({
      overridden: true,
      match_id: override.match_id,
      override_id: insertedOverride.id,
      applied_override_count: appliedOverrideCount,
      scoring_invoked: scoringInvoked,
    });
  } catch (error) {
    logError("apply-result-override", error);
    return errorResponse("override_failed", "Result override failed. Please try again.", 500);
  }
});

async function invokeScoring(
  supabaseURL: string,
  syncSecret: string | undefined,
  poolID: string | null,
): Promise<boolean> {
  if (!syncSecret) {
    return false;
  }

  const response = await fetch(`${supabaseURL}/functions/v1/score-brackets`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-sync-secret": syncSecret,
    },
    body: JSON.stringify({
      dry_run: false,
      ...(poolID ? { pool_id: poolID } : {}),
    }),
  });

  if (!response.ok) {
    throw new Error(`Scoring failed after result override with status ${response.status}.`);
  }

  return true;
}

function overrideFromBody(body: Record<string, unknown>): ResultOverrideRow | null {
  const matchID = stringValue(body.match_id);
  const reason = stringValue(body.reason);
  if (!matchID || !reason || reason.length > 500) {
    return null;
  }

  const override: ResultOverrideRow = {
    match_id: matchID,
    reason,
    corrected_status: statusValue(body.corrected_status),
    corrected_home_score: integerValue(body.corrected_home_score),
    corrected_away_score: integerValue(body.corrected_away_score),
    corrected_penalty_home_score: integerValue(body.corrected_penalty_home_score),
    corrected_penalty_away_score: integerValue(body.corrected_penalty_away_score),
    corrected_winner_team_id: stringValue(body.corrected_winner_team_id),
  };

  return hasCorrectedResultField(override) ? override : null;
}

async function safeJSON(request: Request): Promise<Record<string, unknown>> {
  try {
    const value = await request.json();
    return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {};
  } catch {
    return {};
  }
}

function integerValue(value: unknown): number | null {
  return Number.isInteger(value) ? value as number : null;
}

function stringValue(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function statusValue(value: unknown): string | null {
  const status = stringValue(value);
  return status === "scheduled"
      || status === "live"
      || status === "final"
      || status === "postponed"
      || status === "canceled"
      || status === "unknown"
    ? status
    : null;
}

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
