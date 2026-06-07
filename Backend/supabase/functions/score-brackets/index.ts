import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  advancingThirdPlaceTeams,
  appRound,
  arrayValue,
  finalGroupIDs,
  groupIDFromName,
  internalKnockoutMatchID,
  numberOrNull,
  objectValue,
  parseGroupStanding,
  parseKnockoutResult,
  scorePoolEntry,
  scoreSimulationEntries,
  scoringVersion,
  sha256,
  type DatabaseGroupStanding,
  type GroupStandingResult,
  type KnockoutResult,
  type PoolEntryRow,
  type ScoreBreakdown,
} from "../_shared/scoring.ts";

type SupabaseAdminClient = any;

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://bracket48.app",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const syncSecretName = "SYNC_RESULTS_SECRET";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return errorResponse("method_not_allowed", "Method not allowed.", 405);
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const syncSecret = Deno.env.get(syncSecretName);

  if (!supabaseURL || !serviceRoleKey) {
    return errorResponse("scoring_not_configured", "Scoring is not configured.", 500);
  }

  const authorization = request.headers.get("Authorization");
  const providedSyncSecret = request.headers.get("x-sync-secret");
  const isAuthorized = authorization === `Bearer ${serviceRoleKey}`
    || (!!syncSecret && providedSyncSecret === syncSecret);

  if (!isAuthorized) {
    return errorResponse("unauthorized", "Unauthorized.", 401);
  }

  const body = await safeJSON(request);
  const dryRun = body.dry_run !== false;
  const writeScores = !dryRun;
  const adminClient = createClient(supabaseURL, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  try {
    const results = await loadResults(adminClient, body.simulation);
    const entries = simulationEntries(body.simulation);
    const scores = entries.length > 0
      ? scoreSimulationEntries(entries, results)
      : await scorePoolEntries(adminClient, results, body.pool_id);

    if (writeScores) {
      await persistScores(adminClient, scores, results.sourceHash);
    }

    return jsonResponse({
      scored: true,
      dry_run: dryRun,
      scoring_version: scoringVersion,
      score_count: scores.length,
      result_source: results.source,
      scores,
    });
  } catch (error) {
    logError("score-brackets.score", error);
    return errorResponse("scoring_failed", "Scoring failed. Please try again.", 500);
  }
});

async function loadResults(
  adminClient: SupabaseAdminClient,
  simulation: unknown,
): Promise<{
  source: "simulation" | "database";
  sourceHash: string;
  groupStandings: GroupStandingResult[];
  finalGroupIDs: Set<string>;
  advancingThirdPlaceTeamIDs: Set<string>;
  knockoutResults: KnockoutResult[];
  eliminatedTeamIDs: Set<string>;
}> {
  const simulationObject = objectValue(simulation);
  if (simulationObject) {
    const groupStandings = arrayValue(simulationObject["group_standings"])
      .map(parseGroupStanding)
      .filter((result): result is GroupStandingResult => !!result);
    const advancingThirdPlaceTeamIDs = new Set(
      arrayValue(simulationObject["advancing_third_place_team_ids"])
        .filter((value): value is string => typeof value === "string"),
    );
    const simulationFinalGroupIDs = new Set(
      arrayValue(simulationObject["final_group_ids"])
        .filter((value): value is string => typeof value === "string"),
    );
    const knockoutResults = arrayValue(simulationObject["knockout_results"])
      .map(parseKnockoutResult)
      .filter((result): result is KnockoutResult => !!result);
    const eliminatedTeamIDs = new Set([
      ...arrayValue(simulationObject["eliminated_team_ids"])
        .filter((value): value is string => typeof value === "string"),
      ...knockoutResults.flatMap((result) => result.eliminated_team_ids ?? []),
    ]);

    return {
      source: "simulation",
      sourceHash: await sha256(JSON.stringify({
        groupStandings,
        finalGroupIDs: [...simulationFinalGroupIDs],
        advancingThirdPlaceTeamIDs: [...advancingThirdPlaceTeamIDs],
        knockoutResults,
        eliminatedTeamIDs: [...eliminatedTeamIDs],
      })),
      groupStandings,
      finalGroupIDs: simulationFinalGroupIDs,
      advancingThirdPlaceTeamIDs,
      knockoutResults,
      eliminatedTeamIDs,
    };
  }

  const groupStandings = await loadDatabaseGroupStandings(adminClient);
  const knockoutResults = await loadDatabaseKnockoutResults(adminClient);
  const advancingThirdPlaceTeamIDs = advancingThirdPlaceTeams(groupStandings);
  const databaseFinalGroupIDs = finalGroupIDs(groupStandings);
  const eliminatedTeamIDs = new Set(knockoutResults.flatMap((result) => result.eliminated_team_ids ?? []));

  return {
    source: "database",
    sourceHash: await sha256(JSON.stringify({
      groupStandings,
      finalGroupIDs: [...databaseFinalGroupIDs],
      advancingThirdPlaceTeamIDs: [...advancingThirdPlaceTeamIDs],
      knockoutResults,
      eliminatedTeamIDs: [...eliminatedTeamIDs],
    })),
    groupStandings: groupStandings.map((standing) => ({
      group_id: groupIDFromName(standing.group_name),
      ordered_team_ids: standing.teams.map((team) => team.team_id).filter((teamID): teamID is string => !!teamID),
    })),
    finalGroupIDs: databaseFinalGroupIDs,
    advancingThirdPlaceTeamIDs,
    knockoutResults,
    eliminatedTeamIDs,
  };
}

async function loadDatabaseGroupStandings(adminClient: SupabaseAdminClient): Promise<DatabaseGroupStanding[]> {
  const { data, error } = await adminClient
    .from("group_standings")
    .select("group_name,team_id,position,points,played,goal_difference,goals_for")
    .order("group_name", { ascending: true })
    .order("position", { ascending: true });

  if (error) {
    throw error;
  }

  const groups = new Map<string, Array<{
    team_id: string | null;
    position: number;
    points: number;
    played: number | null;
    goal_difference: number | null;
    goals_for: number | null;
  }>>();

  for (const row of (data ?? []) as Record<string, unknown>[]) {
    const groupName = String(row.group_name);
    const rows = groups.get(groupName) ?? [];
    rows.push({
      team_id: typeof row.team_id === "string" ? row.team_id : null,
      position: Number(row.position),
      points: Number(row.points ?? 0),
      played: numberOrNull(row.played),
      goal_difference: numberOrNull(row.goal_difference),
      goals_for: numberOrNull(row.goals_for),
    });
    groups.set(groupName, rows);
  }

  return [...groups.entries()]
    .map(([group_name, teams]) => ({ group_name, teams }))
    .filter((group) => group.teams.some((team) => (team.played ?? 0) > 0));
}

async function loadDatabaseKnockoutResults(adminClient: SupabaseAdminClient): Promise<KnockoutResult[]> {
  const { data, error } = await adminClient
    .from("tournament_matches")
    .select("knockout_round,match_number,winner_team_id,home_team_id,away_team_id")
    .eq("phase", "knockout")
    .eq("status", "final")
    .not("winner_team_id", "is", null)
    .order("match_number", { ascending: true });

  if (error) {
    throw error;
  }

  const counters = new Map<string, number>();
  const results: KnockoutResult[] = [];

  for (const row of (data ?? []) as Record<string, unknown>[]) {
    const round = appRound(String(row.knockout_round ?? ""));
    const winnerTeamID = typeof row.winner_team_id === "string" ? row.winner_team_id : null;
    if (!round || !winnerTeamID) {
      continue;
    }
    const participantTeamIDs = [row.home_team_id, row.away_team_id]
      .filter((teamID): teamID is string => typeof teamID === "string");

    const index = (counters.get(round) ?? 0) + 1;
    counters.set(round, index);
    results.push({
      match_id: internalKnockoutMatchID(round, index),
      round,
      winner_team_id: winnerTeamID,
      eliminated_team_ids: participantTeamIDs.filter((teamID) => teamID !== winnerTeamID),
    });
  }

  return results;
}

async function scorePoolEntries(
  adminClient: SupabaseAdminClient,
  results: Awaited<ReturnType<typeof loadResults>>,
  poolID: unknown,
): Promise<ScoreBreakdown[]> {
  let query = adminClient
    .from("pool_entries")
    .select("id,pool_id,bracket_id,user_id,phase,brackets!inner(id,phase,picks)")
    .order("submitted_at", { ascending: true });

  if (typeof poolID === "string" && poolID.length > 0) {
    query = query.eq("pool_id", poolID);
  }

  const { data, error } = await query;
  if (error) {
    throw error;
  }

  return ((data ?? []) as unknown[]).map((entry) => scorePoolEntry(entry as PoolEntryRow, results));
}

async function persistScores(
  adminClient: SupabaseAdminClient,
  scores: ScoreBreakdown[],
  sourceHash: string,
) {
  for (const score of scores) {
    if (!score.pool_id || !score.bracket_id || !score.user_id || score.phase === "combined") {
      continue;
    }

    const { data, error } = await adminClient
      .from("bracket_scores")
      .upsert({
        pool_entry_id: score.pool_entry_id,
        pool_id: score.pool_id,
        bracket_id: score.bracket_id,
        user_id: score.user_id,
        phase: score.phase,
        group_stage_points: score.group_stage_points,
        knockout_points: score.knockout_points,
        total_points: score.total_points,
        max_points: score.max_points,
        possible_points_remaining: score.possible_points_remaining,
        scoring_version: scoringVersion,
        source_hash: sourceHash,
        calculated_at: new Date().toISOString(),
      }, { onConflict: "pool_entry_id" })
      .select("id")
      .single();

    if (error || !data?.id) {
      throw error ?? new Error("Could not persist bracket score.");
    }

    const { error: deleteError } = await adminClient
      .from("bracket_score_events")
      .delete()
      .eq("pool_entry_id", score.pool_entry_id);

    if (deleteError) {
      throw deleteError;
    }

    if (score.events.length > 0) {
      const { error: eventError } = await adminClient
        .from("bracket_score_events")
        .insert(score.events.map((event) => ({
          bracket_score_id: data.id,
          pool_entry_id: score.pool_entry_id,
          ...event,
        })));

      if (eventError) {
        throw eventError;
      }
    }
  }
}

function simulationEntries(simulation: unknown): Array<Record<string, unknown>> {
  const object = objectValue(simulation);
  return object ? arrayValue(object["entries"]).map(objectValue).filter((entry): entry is Record<string, unknown> => !!entry) : [];
}

async function safeJSON(request: Request): Promise<Record<string, unknown>> {
  try {
    const parsed = await request.json();
    return objectValue(parsed) ?? {};
  } catch {
    return {};
  }
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
