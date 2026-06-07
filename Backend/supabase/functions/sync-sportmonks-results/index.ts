import { createClient } from "jsr:@supabase/supabase-js@2";
import { applyActiveResultOverrides } from "../_shared/result-overrides.ts";
import {
  internalTeamID,
  matchRow,
  participantsFromFixtures,
  standingRow,
  type SportmonksFixture,
  type SportmonksParticipant,
  type SportmonksStanding,
} from "../_shared/sportmonks-normalization.ts";

const providerName = "sportmonks";
const sportmonksBaseURL = "https://api.sportmonks.com/v3/football";
const defaultSeasonID = 26618;
const worldCupLeagueID = 732;
const groupStageID = 77478590;

type SyncMode = "fixtures" | "live" | "standings" | "all";
type SupabaseAdminClient = any;

type SportmonksResponse<T> = {
  data: T[];
  pagination?: {
    has_more?: boolean;
    current_page?: number;
  };
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://bracket48.app",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
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

function errorResponse(
  errorCode: string,
  message: string,
  status: number,
  extra: Record<string, unknown> = {},
): Response {
  return jsonResponse({ error: message, error_code: errorCode, ...extra }, status);
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

  if (request.method !== "POST") {
    return errorResponse("method_not_allowed", "Method not allowed.", 405);
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const sportmonksToken = Deno.env.get("SPORTMONKS_API_TOKEN");

  if (!supabaseURL || !serviceRoleKey || !sportmonksToken) {
    return errorResponse("sportmonks_sync_not_configured", "Results sync is not configured.", 500);
  }

  const syncSecret = Deno.env.get("SYNC_RESULTS_SECRET");
  const authorization = request.headers.get("Authorization");
  const providedSyncSecret = request.headers.get("x-sync-secret");
  const isAuthorized = authorization === `Bearer ${serviceRoleKey}`
    || (!!syncSecret && providedSyncSecret === syncSecret);

  if (!isAuthorized) {
    return errorResponse("unauthorized", "Unauthorized.", 401);
  }

  const body = await safeJSON(request);
  const mode = syncMode(body.mode);
  const seasonID = typeof body.season_id === "number" ? body.season_id : defaultSeasonID;

  const adminClient = createClient(supabaseURL, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  const { data: run, error: runError } = await adminClient
    .from("provider_sync_runs")
    .insert({
      provider_name: providerName,
      sync_type: mode,
      status: "running",
    })
    .select("id")
    .single();

  if (runError || !run?.id) {
    logError("sync-sportmonks-results.create-run", runError ?? "Missing sync run id.");
    return errorResponse("sync_run_create_failed", "Results sync could not start.", 500);
  }

  try {
    const fixtureCount = mode === "standings"
      ? 0
      : await syncFixtures(adminClient, sportmonksToken, seasonID, mode);
    const standingCount = mode === "live"
      ? 0
      : await syncStandings(adminClient, sportmonksToken, seasonID);
    const scoringInvoked = await invokeScoring(supabaseURL);

    await adminClient
      .from("provider_sync_runs")
      .update({
        status: "succeeded",
        fetched_fixture_count: fixtureCount,
        fetched_standing_count: standingCount,
        finished_at: new Date().toISOString(),
      })
      .eq("id", run.id);

    return jsonResponse({
      synced: true,
      provider: providerName,
      mode,
      fixture_count: fixtureCount,
      standing_count: standingCount,
      scoring_invoked: scoringInvoked,
      sync_run_id: run.id,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    logError("sync-sportmonks-results.sync", error);
    await adminClient
      .from("provider_sync_runs")
      .update({
        status: "failed",
        error_message: message,
        finished_at: new Date().toISOString(),
      })
      .eq("id", run.id);

    return errorResponse("results_sync_failed", "Results sync failed. Please try again.", 500, {
      sync_run_id: run.id,
    });
  }
});

async function invokeScoring(supabaseURL: string): Promise<boolean> {
  const syncSecret = Deno.env.get("SYNC_RESULTS_SECRET");
  if (!syncSecret) {
    return false;
  }

  const response = await fetch(`${supabaseURL}/functions/v1/score-brackets`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-sync-secret": syncSecret,
    },
    body: JSON.stringify({ dry_run: false }),
  });

  if (!response.ok) {
    throw new Error(`Scoring failed after sync with status ${response.status}.`);
  }

  return true;
}

async function syncFixtures(
  adminClient: SupabaseAdminClient,
  token: string,
  seasonID: number,
  mode: SyncMode,
): Promise<number> {
  const fixtures = mode === "live"
    ? await fetchLiveFixtures(token)
    : await fetchPaginated<SportmonksFixture>("/fixtures", token, {
      filters: `fixtureSeasons:${seasonID}`,
      include: "participants;scores;state;stage;round;group",
      per_page: "50",
      order: "asc",
    });

  await upsertProviderTeams(adminClient, participantsFromFixtures(fixtures));

  const rows = fixtures.map((fixture) => matchRow(fixture, seasonID));
  if (rows.length > 0) {
    const { error } = await adminClient
      .from("tournament_matches")
      .upsert(rows, { onConflict: "provider_name,provider_fixture_id" });

    if (error) {
      throw error;
    }

    await applyActiveResultOverrides(
      adminClient,
      rows.map((row) => String(row.id)).filter((id) => id.length > 0),
    );
  }

  return fixtures.length;
}

async function syncStandings(
  adminClient: SupabaseAdminClient,
  token: string,
  seasonID: number,
): Promise<number> {
  const standings = await fetchPaginated<SportmonksStanding>(`/standings/seasons/${seasonID}`, token, {
    include: "participant;group;details.type",
    filters: `standingStages:${groupStageID}`,
    per_page: "50",
  });

  const participants = standings
    .map((standing) => standing.participant)
    .filter((participant): participant is SportmonksParticipant => !!participant);
  await upsertProviderTeams(adminClient, participants);

  const rows = standings
    .map(standingRow)
    .filter((row): row is Record<string, unknown> => !!row);
  if (rows.length > 0) {
    const { error } = await adminClient
      .from("group_standings")
      .upsert(rows, { onConflict: "provider_name,season_id,provider_group_id,provider_team_id" });

    if (error) {
      throw error;
    }
  }

  return standings.length;
}

async function fetchLiveFixtures(token: string): Promise<SportmonksFixture[]> {
  return await fetchPaginated<SportmonksFixture>("/livescores", token, {
    filters: `fixtureLeagues:${worldCupLeagueID}`,
    include: "participants;scores;state;stage;round;group",
    per_page: "50",
  });
}

async function fetchPaginated<T>(
  path: string,
  token: string,
  params: Record<string, string>,
): Promise<T[]> {
  const allRows: T[] = [];
  let page = 1;
  let hasMore = true;

  while (hasMore) {
    const response = await sportmonksFetch<SportmonksResponse<T>>(path, token, {
      ...params,
      page: String(page),
    });
    allRows.push(...response.data);
    hasMore = response.pagination?.has_more === true;
    page += 1;
  }

  return allRows;
}

async function sportmonksFetch<T>(
  path: string,
  token: string,
  params: Record<string, string>,
): Promise<T> {
  const url = new URL(`${sportmonksBaseURL}${path}`);
  url.searchParams.set("api_token", token);
  for (const [key, value] of Object.entries(params)) {
    url.searchParams.set(key, value);
  }

  const response = await fetch(url);
  const body = await response.json();
  if (!response.ok) {
    throw new Error(body?.message ?? `Sportmonks request failed with ${response.status}.`);
  }

  return body as T;
}

async function upsertProviderTeams(
  adminClient: SupabaseAdminClient,
  participants: SportmonksParticipant[],
) {
  const uniqueRows = new Map<number, Record<string, unknown>>();

  for (const participant of participants) {
    uniqueRows.set(participant.id, {
      provider_name: providerName,
      provider_team_id: participant.id,
      internal_team_id: internalTeamID(participant),
      name: participant.name,
      short_code: participant.short_code ?? null,
      image_url: participant.image_path ?? null,
      is_placeholder: participant.placeholder === true,
      raw_payload: participant,
      last_synced_at: new Date().toISOString(),
    });
  }

  const rows = Array.from(uniqueRows.values());
  if (rows.length === 0) {
    return;
  }

  const { error } = await adminClient
    .from("provider_teams")
    .upsert(rows, { onConflict: "provider_name,provider_team_id" });

  if (error) {
    throw error;
  }
}

async function safeJSON(request: Request): Promise<Record<string, unknown>> {
  try {
    return await request.json();
  } catch {
    return {};
  }
}

function syncMode(value: unknown): SyncMode {
  return value === "fixtures" || value === "live" || value === "standings" || value === "all"
    ? value
    : "all";
}
