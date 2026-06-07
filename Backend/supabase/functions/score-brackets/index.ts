import { createClient } from "jsr:@supabase/supabase-js@2";

const scoringVersion = "world-cup-default-v1";
const syncSecretName = "SYNC_RESULTS_SECRET";

const rules = {
  correctGroupWinner: 4,
  correctGroupRunnerUp: 3,
  correctGroupThirdPlace: 2,
  correctThirdPlaceAdvancement: 2,
  perfectGroupTopThreeBonus: 3,
  knockoutRoundPoints: {
    roundOf32: 4,
    roundOf16: 6,
    quarterfinal: 8,
    semifinal: 12,
    final: 20,
  } as Record<string, number>,
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-sync-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type BracketPhase = "group_stage" | "knockout";

type PoolEntryRow = {
  id: string;
  pool_id: string;
  bracket_id: string;
  user_id: string;
  phase: BracketPhase;
  brackets?: {
    id: string;
    phase: BracketPhase;
    picks: BracketPicks;
  };
};

type BracketPicks = {
  predictions?: GroupPrediction[];
  picks?: KnockoutPick[];
};

type GroupPrediction = {
  group_id: string;
  ordered_team_ids: string[];
  predicted_third_place_advances: boolean;
};

type KnockoutPick = {
  match_id: string;
  round: string;
  picked_winner_team_id: string;
};

type GroupStandingResult = {
  group_id: string;
  ordered_team_ids: string[];
};

type KnockoutResult = {
  match_id: string;
  round: string;
  winner_team_id: string;
};

type ScoreEvent = {
  source_type: "group_stage_prediction" | "knockout_pick";
  source_id: string;
  rule_id: string;
  points: number;
  reason: string;
};

type ScoreBreakdown = {
  pool_entry_id: string;
  pool_id: string | null;
  bracket_id: string | null;
  user_id: string | null;
  phase: BracketPhase | "combined";
  group_stage_points: number;
  knockout_points: number;
  total_points: number;
  max_points: number;
  events: ScoreEvent[];
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const syncSecret = Deno.env.get(syncSecretName);

  if (!supabaseURL || !serviceRoleKey) {
    return jsonResponse({ error: "Scoring is not configured." }, 500);
  }

  const authorization = request.headers.get("Authorization");
  const providedSyncSecret = request.headers.get("x-sync-secret");
  const isAuthorized = authorization === `Bearer ${serviceRoleKey}`
    || (!!syncSecret && providedSyncSecret === syncSecret);

  if (!isAuthorized) {
    return jsonResponse({ error: "Unauthorized." }, 401);
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
    return jsonResponse({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});

async function loadResults(
  adminClient: ReturnType<typeof createClient>,
  simulation: unknown,
): Promise<{
  source: "simulation" | "database";
  sourceHash: string;
  groupStandings: GroupStandingResult[];
  advancingThirdPlaceTeamIDs: Set<string>;
  knockoutResults: KnockoutResult[];
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
    const knockoutResults = arrayValue(simulationObject["knockout_results"])
      .map(parseKnockoutResult)
      .filter((result): result is KnockoutResult => !!result);

    return {
      source: "simulation",
      sourceHash: await sha256(JSON.stringify({ groupStandings, advancingThirdPlaceTeamIDs: [...advancingThirdPlaceTeamIDs], knockoutResults })),
      groupStandings,
      advancingThirdPlaceTeamIDs,
      knockoutResults,
    };
  }

  const groupStandings = await loadDatabaseGroupStandings(adminClient);
  const knockoutResults = await loadDatabaseKnockoutResults(adminClient);
  const advancingThirdPlaceTeamIDs = advancingThirdPlaceTeams(groupStandings);

  return {
    source: "database",
    sourceHash: await sha256(JSON.stringify({ groupStandings, advancingThirdPlaceTeamIDs: [...advancingThirdPlaceTeamIDs], knockoutResults })),
    groupStandings: groupStandings.map((standing) => ({
      group_id: groupIDFromName(standing.group_name),
      ordered_team_ids: standing.teams.map((team) => team.team_id).filter((teamID): teamID is string => !!teamID),
    })),
    advancingThirdPlaceTeamIDs,
    knockoutResults,
  };
}

async function loadDatabaseGroupStandings(adminClient: ReturnType<typeof createClient>): Promise<Array<{
  group_name: string;
  teams: Array<{
    team_id: string | null;
    position: number;
    points: number;
    goal_difference: number | null;
    goals_for: number | null;
  }>;
}>> {
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
    goal_difference: number | null;
    goals_for: number | null;
  }>>();

  for (const row of data ?? []) {
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

async function loadDatabaseKnockoutResults(adminClient: ReturnType<typeof createClient>): Promise<KnockoutResult[]> {
  const { data, error } = await adminClient
    .from("tournament_matches")
    .select("knockout_round,match_number,winner_team_id")
    .eq("phase", "knockout")
    .eq("status", "final")
    .not("winner_team_id", "is", null)
    .order("match_number", { ascending: true });

  if (error) {
    throw error;
  }

  const counters = new Map<string, number>();
  const results: KnockoutResult[] = [];

  for (const row of data ?? []) {
    const round = appRound(String(row.knockout_round ?? ""));
    const winnerTeamID = typeof row.winner_team_id === "string" ? row.winner_team_id : null;
    if (!round || !winnerTeamID) {
      continue;
    }

    const index = (counters.get(round) ?? 0) + 1;
    counters.set(round, index);
    results.push({
      match_id: internalKnockoutMatchID(round, index),
      round,
      winner_team_id: winnerTeamID,
    });
  }

  return results;
}

async function scorePoolEntries(
  adminClient: ReturnType<typeof createClient>,
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

  return (data ?? []).map((entry) => scorePoolEntry(entry as PoolEntryRow, results));
}

function scorePoolEntry(
  entry: PoolEntryRow,
  results: Awaited<ReturnType<typeof loadResults>>,
): ScoreBreakdown {
  return scorePicks({
    poolEntryID: entry.id,
    poolID: entry.pool_id,
    bracketID: entry.bracket_id,
    userID: entry.user_id,
    phase: entry.phase,
    picks: entry.brackets?.picks ?? {},
    results,
  });
}

function scoreSimulationEntries(
  entries: Array<Record<string, unknown>>,
  results: Awaited<ReturnType<typeof loadResults>>,
): ScoreBreakdown[] {
  return entries.map((entry, index) => {
    const phase = entry["phase"] === "knockout" || entry["phase"] === "group_stage" ? entry["phase"] : "combined";
    return scorePicks({
      poolEntryID: typeof entry["entry_id"] === "string" ? entry["entry_id"] : `simulation-${index + 1}`,
      poolID: null,
      bracketID: null,
      userID: typeof entry["user_id"] === "string" ? entry["user_id"] : null,
      phase,
      picks: {
        predictions: arrayValue(entry["predictions"]) as GroupPrediction[],
        picks: arrayValue(entry["knockout_picks"]) as KnockoutPick[],
      },
      results,
    });
  });
}

function scorePicks(input: {
  poolEntryID: string;
  poolID: string | null;
  bracketID: string | null;
  userID: string | null;
  phase: BracketPhase | "combined";
  picks: BracketPicks;
  results: Awaited<ReturnType<typeof loadResults>>;
}): ScoreBreakdown {
  const events: ScoreEvent[] = [];
  const groupStandingsByID = new Map(input.results.groupStandings.map((standing) => [standing.group_id, standing]));
  const knockoutResultsByMatchID = new Map(input.results.knockoutResults.map((result) => [result.match_id, result]));

  for (const prediction of input.picks.predictions ?? []) {
    const standing = groupStandingsByID.get(prediction.group_id);
    if (!standing) {
      continue;
    }

    events.push(...scoreGroupPrediction(prediction, standing, input.results.advancingThirdPlaceTeamIDs));
  }

  for (const pick of input.picks.picks ?? []) {
    const result = knockoutResultsByMatchID.get(pick.match_id);
    if (!result || result.winner_team_id !== pick.picked_winner_team_id) {
      continue;
    }

    const points = rules.knockoutRoundPoints[pick.round] ?? 0;
    events.push({
      source_type: "knockout_pick",
      source_id: pick.match_id,
      rule_id: "winner",
      points,
      reason: `Correct ${roundDisplayName(pick.round)} winner`,
    });
  }

  const groupStagePoints = events
    .filter((event) => event.source_type === "group_stage_prediction")
    .reduce((total, event) => total + event.points, 0);
  const knockoutPoints = events
    .filter((event) => event.source_type === "knockout_pick")
    .reduce((total, event) => total + event.points, 0);

  return {
    pool_entry_id: input.poolEntryID,
    pool_id: input.poolID,
    bracket_id: input.bracketID,
    user_id: input.userID,
    phase: input.phase,
    group_stage_points: groupStagePoints,
    knockout_points: knockoutPoints,
    total_points: groupStagePoints + knockoutPoints,
    max_points: maximumScore(input.picks),
    events,
  };
}

function scoreGroupPrediction(
  prediction: GroupPrediction,
  standing: GroupStandingResult,
  advancingThirdPlaceTeamIDs: Set<string>,
): ScoreEvent[] {
  const events: ScoreEvent[] = [];
  const predicted = prediction.ordered_team_ids;
  const actual = standing.ordered_team_ids;

  if (predicted[0] === actual[0]) {
    events.push(groupEvent(prediction.group_id, "winner", rules.correctGroupWinner, "Correct group winner"));
  }

  if (predicted[1] === actual[1]) {
    events.push(groupEvent(prediction.group_id, "runner-up", rules.correctGroupRunnerUp, "Correct group runner-up"));
  }

  if (predicted[2] === actual[2]) {
    events.push(groupEvent(prediction.group_id, "third-place", rules.correctGroupThirdPlace, "Correct third-place team"));
  }

  const actualThirdPlaceTeamID = actual[2];
  if (
    actualThirdPlaceTeamID
    && prediction.predicted_third_place_advances === advancingThirdPlaceTeamIDs.has(actualThirdPlaceTeamID)
  ) {
    events.push(groupEvent(
      prediction.group_id,
      "third-place-advancement",
      rules.correctThirdPlaceAdvancement,
      "Correct third-place advancement result",
    ));
  }

  if (predicted.slice(0, 3).join("|") === actual.slice(0, 3).join("|")) {
    events.push(groupEvent(prediction.group_id, "perfect-top-three", rules.perfectGroupTopThreeBonus, "Perfect group top 3"));
  }

  return events;
}

async function persistScores(
  adminClient: ReturnType<typeof createClient>,
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

function groupEvent(groupID: string, ruleID: string, points: number, reason: string): ScoreEvent {
  return {
    source_type: "group_stage_prediction",
    source_id: groupID,
    rule_id: ruleID,
    points,
    reason,
  };
}

function maximumScore(picks: BracketPicks): number {
  const groupPointsPerPrediction = rules.correctGroupWinner
    + rules.correctGroupRunnerUp
    + rules.correctGroupThirdPlace
    + rules.correctThirdPlaceAdvancement
    + rules.perfectGroupTopThreeBonus;
  const groupStagePoints = (picks.predictions ?? []).length * groupPointsPerPrediction;
  const knockoutPoints = (picks.picks ?? []).reduce((total, pick) => total + (rules.knockoutRoundPoints[pick.round] ?? 0), 0);
  return groupStagePoints + knockoutPoints;
}

function advancingThirdPlaceTeams(groups: Awaited<ReturnType<typeof loadDatabaseGroupStandings>>): Set<string> {
  return new Set(groups
    .flatMap((group) => group.teams.map((team) => ({ ...team, group_name: group.group_name })))
    .filter((team) => team.position === 3 && !!team.team_id)
    .sort((lhs, rhs) =>
      rhs.points - lhs.points
      || (rhs.goal_difference ?? 0) - (lhs.goal_difference ?? 0)
      || (rhs.goals_for ?? 0) - (lhs.goals_for ?? 0)
      || lhs.group_name.localeCompare(rhs.group_name)
    )
    .slice(0, 8)
    .map((team) => team.team_id!));
}

function parseGroupStanding(value: unknown): GroupStandingResult | null {
  const object = objectValue(value);
  if (!object || typeof object["group_id"] !== "string") {
    return null;
  }

  const orderedTeamIDs = arrayValue(object["ordered_team_ids"])
    .filter((teamID): teamID is string => typeof teamID === "string");
  return { group_id: object["group_id"], ordered_team_ids: orderedTeamIDs };
}

function parseKnockoutResult(value: unknown): KnockoutResult | null {
  const object = objectValue(value);
  if (
    !object
    || typeof object["match_id"] !== "string"
    || typeof object["round"] !== "string"
    || typeof object["winner_team_id"] !== "string"
  ) {
    return null;
  }

  return {
    match_id: object["match_id"],
    round: object["round"],
    winner_team_id: object["winner_team_id"],
  };
}

function simulationEntries(simulation: unknown): Array<Record<string, unknown>> {
  const object = objectValue(simulation);
  return object ? arrayValue(object["entries"]).map(objectValue).filter((entry): entry is Record<string, unknown> => !!entry) : [];
}

function internalKnockoutMatchID(round: string, index: number): string {
  switch (round) {
  case "roundOf32":
    return `r32-${index}`;
  case "roundOf16":
    return `r16-${index}`;
  case "quarterfinal":
    return `qf-${index}`;
  case "semifinal":
    return `sf-${index}`;
  case "final":
    return "final";
  default:
    return `${round}-${index}`;
  }
}

function appRound(databaseRound: string): string | null {
  switch (databaseRound) {
  case "round_of_32":
    return "roundOf32";
  case "round_of_16":
    return "roundOf16";
  case "quarterfinal":
  case "semifinal":
  case "final":
    return databaseRound;
  default:
    return null;
  }
}

function roundDisplayName(round: string): string {
  switch (round) {
  case "roundOf32":
    return "Round of 32";
  case "roundOf16":
    return "Round of 16";
  case "quarterfinal":
    return "Quarterfinal";
  case "semifinal":
    return "Semifinal";
  case "final":
    return "Final";
  default:
    return "knockout";
  }
}

function groupIDFromName(groupName: string): string {
  return groupName.replace(/^Group\s+/i, "").trim();
}

function numberOrNull(value: unknown): number | null {
  return typeof value === "number" ? value : null;
}

function objectValue(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : null;
}

function arrayValue(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

async function safeJSON(request: Request): Promise<Record<string, unknown>> {
  try {
    const parsed = await request.json();
    return objectValue(parsed) ?? {};
  } catch {
    return {};
  }
}

async function sha256(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
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
