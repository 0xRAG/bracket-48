import { createClient } from "jsr:@supabase/supabase-js@2";

const providerName = "sportmonks";
const sportmonksBaseURL = "https://api.sportmonks.com/v3/football";
const defaultSeasonID = 26618;
const worldCupLeagueID = 732;
const groupStageID = 77478590;

const knockoutStages: Record<number, string> = {
  77479086: "round_of_32",
  77479087: "round_of_16",
  77479088: "quarterfinal",
  77479089: "semifinal",
  77479090: "final",
  77479091: "third_place",
};

const internalTeamIDsByShortCode: Record<string, string> = {
  ARG: "arg",
  AUS: "aus",
  AUT: "aut",
  BEL: "bel",
  BIH: "bih",
  BRA: "bra",
  CAN: "can",
  CIV: "civ",
  COD: "cod",
  COL: "col",
  CPV: "cpv",
  CRO: "cro",
  CUW: "cuw",
  CZE: "cze",
  DZA: "alg",
  ECU: "ecu",
  EGY: "egy",
  ENG: "eng",
  ESP: "esp",
  FRA: "fra",
  GER: "ger",
  GHA: "gha",
  HAI: "hai",
  IRN: "irn",
  IRQ: "irq",
  JOR: "jor",
  JPN: "jpn",
  KOR: "kor",
  KSA: "ksa",
  MAR: "mar",
  MEX: "mex",
  NED: "ned",
  NOR: "nor",
  NZL: "nzl",
  PAN: "pan",
  POR: "por",
  PRY: "par",
  QAT: "qat",
  SCO: "sco",
  SEN: "sen",
  SUI: "sui",
  SWE: "swe",
  TUN: "tun",
  TUR: "tur",
  URU: "uru",
  USA: "usa",
  UZB: "uzb",
  ZAF: "rsa",
};

const internalTeamIDsByName: Record<string, string> = {
  "algeria": "alg",
  "bosnia and herzegovina": "bih",
  "cape verde": "cpv",
  "cote d'ivoire": "civ",
  "côte d'ivoire": "civ",
  "curacao": "cuw",
  "curaçao": "cuw",
  "czechia": "cze",
  "czech republic": "cze",
  "dr congo": "cod",
  "korea republic": "kor",
  "new zealand": "nzl",
  "south africa": "rsa",
  "united states": "usa",
};

type SyncMode = "fixtures" | "live" | "standings" | "all";

type SportmonksResponse<T> = {
  data: T[];
  pagination?: {
    has_more?: boolean;
    current_page?: number;
  };
};

type SportmonksParticipant = {
  id: number;
  name: string;
  short_code?: string | null;
  image_path?: string | null;
  placeholder?: boolean | null;
  meta?: {
    location?: "home" | "away" | string | null;
    winner?: boolean | null;
  } | null;
};

type SportmonksFixture = {
  id: number;
  league_id?: number | null;
  season_id: number;
  stage_id?: number | null;
  group_id?: number | null;
  round_id?: number | null;
  state_id?: number | null;
  name?: string | null;
  starting_at?: string | null;
  result_info?: string | null;
  details?: string | null;
  placeholder?: boolean | null;
  participants?: SportmonksParticipant[];
  scores?: Record<string, unknown>[];
  state?: {
    name?: string | null;
    short_name?: string | null;
    developer_name?: string | null;
  } | null;
  stage?: {
    id?: number | null;
    name?: string | null;
  } | null;
  round?: {
    id?: number | null;
    name?: string | null;
  } | null;
  group?: {
    id?: number | null;
    name?: string | null;
  } | null;
};

type SportmonksStanding = {
  participant_id: number;
  season_id: number;
  stage_id?: number | null;
  group_id?: number | null;
  position: number;
  points: number;
  participant?: SportmonksParticipant | null;
  group?: {
    id?: number | null;
    name?: string | null;
  } | null;
  details?: Record<string, unknown>[] | null;
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
  adminClient: ReturnType<typeof createClient>,
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
  }

  return fixtures.length;
}

async function syncStandings(
  adminClient: ReturnType<typeof createClient>,
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
  adminClient: ReturnType<typeof createClient>,
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

function participantsFromFixtures(fixtures: SportmonksFixture[]): SportmonksParticipant[] {
  return fixtures.flatMap((fixture) => fixture.participants ?? []);
}

function matchRow(fixture: SportmonksFixture, seasonID: number): Record<string, unknown> {
  const home = participantByLocation(fixture, "home");
  const away = participantByLocation(fixture, "away");
  const stageID = fixture.stage_id ?? fixture.stage?.id ?? null;
  const groupID = fixture.group_id ?? fixture.group?.id ?? null;
  const winner = (fixture.participants ?? []).find((participant) => participant.meta?.winner === true);

  return {
    id: `sportmonks-${fixture.id}`,
    tournament_id: "world-cup-2026",
    provider_name: providerName,
    provider_fixture_id: fixture.id,
    league_id: fixture.league_id ?? worldCupLeagueID,
    season_id: fixture.season_id ?? seasonID,
    stage_id: stageID,
    stage_name: fixture.stage?.name ?? null,
    provider_group_id: groupID,
    group_name: fixture.group?.name ?? null,
    round_id: fixture.round_id ?? fixture.round?.id ?? null,
    round_name: fixture.round?.name ?? null,
    phase: stageID === groupStageID ? "group_stage" : "knockout",
    knockout_round: stageID ? knockoutStages[stageID] ?? null : null,
    match_number: matchNumber(fixture.details),
    fixture_name: fixture.name ?? `Fixture ${fixture.id}`,
    starts_at: parseSportmonksDate(fixture.starting_at),
    is_placeholder: fixture.placeholder === true,
    home_provider_team_id: home?.id ?? null,
    away_provider_team_id: away?.id ?? null,
    home_team_id: home ? internalTeamID(home) : null,
    away_team_id: away ? internalTeamID(away) : null,
    home_slot_label: home?.placeholder === true ? home.name : null,
    away_slot_label: away?.placeholder === true ? away.name : null,
    status: matchStatus(fixture.state?.developer_name ?? fixture.state?.short_name),
    state_short_name: fixture.state?.short_name ?? null,
    state_name: fixture.state?.name ?? null,
    home_score: home ? scoreForParticipant(fixture.scores ?? [], home.id, false) : null,
    away_score: away ? scoreForParticipant(fixture.scores ?? [], away.id, false) : null,
    penalty_home_score: home ? scoreForParticipant(fixture.scores ?? [], home.id, true) : null,
    penalty_away_score: away ? scoreForParticipant(fixture.scores ?? [], away.id, true) : null,
    winner_provider_team_id: winner?.id ?? null,
    winner_team_id: winner ? internalTeamID(winner) : null,
    result_info: fixture.result_info ?? null,
    raw_payload: fixture,
    last_synced_at: new Date().toISOString(),
  };
}

function standingRow(standing: SportmonksStanding): Record<string, unknown> | null {
  const details = standingDetails(standing.details ?? []);
  const participant = standing.participant;
  const groupID = standing.group_id ?? standing.group?.id;
  if (!groupID) {
    return null;
  }

  return {
    provider_name: providerName,
    tournament_id: "world-cup-2026",
    season_id: standing.season_id,
    stage_id: standing.stage_id ?? groupStageID,
    provider_group_id: groupID,
    group_name: standing.group?.name ?? `Group ${groupID}`,
    provider_team_id: standing.participant_id,
    team_id: participant ? internalTeamID(participant) : null,
    team_name: participant?.name ?? `Team ${standing.participant_id}`,
    position: standing.position,
    points: standing.points,
    played: details.played,
    won: details.won,
    drawn: details.drawn,
    lost: details.lost,
    goals_for: details.goalsFor,
    goals_against: details.goalsAgainst,
    goal_difference: details.goalDifference,
    raw_details: standing.details ?? [],
    raw_payload: standing,
    last_synced_at: new Date().toISOString(),
  };
}

function participantByLocation(
  fixture: SportmonksFixture,
  location: "home" | "away",
): SportmonksParticipant | undefined {
  return (fixture.participants ?? []).find((participant) => participant.meta?.location === location);
}

function internalTeamID(participant: SportmonksParticipant): string | null {
  if (participant.placeholder === true) {
    return null;
  }

  const shortCode = participant.short_code?.toUpperCase();
  if (shortCode && internalTeamIDsByShortCode[shortCode]) {
    return internalTeamIDsByShortCode[shortCode];
  }

  return internalTeamIDsByName[normalizeName(participant.name)] ?? null;
}

function normalizeName(name: string): string {
  return name
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
}

function parseSportmonksDate(value?: string | null): string | null {
  return value ? `${value.replace(" ", "T")}Z` : null;
}

function matchNumber(details?: string | null): number | null {
  const match = details?.match(/match\s+(\d+)/i);
  return match ? Number(match[1]) : null;
}

function matchStatus(state?: string | null): string {
  const normalized = state?.toUpperCase() ?? "";
  if (["NS", "TBA"].includes(normalized)) {
    return "scheduled";
  }

  if (["LIVE", "INPLAY", "1ST_HALF", "2ND_HALF", "HT", "ET", "PEN_LIVE", "BREAK"].includes(normalized)) {
    return "live";
  }

  if (["FT", "AET", "FT_PEN", "PEN", "ENDED"].includes(normalized)) {
    return "final";
  }

  if (["POSTPONED", "POSTP"].includes(normalized)) {
    return "postponed";
  }

  if (["CANCELLED", "CANCELED", "ABANDONED"].includes(normalized)) {
    return "canceled";
  }

  return "unknown";
}

function scoreForParticipant(scores: Record<string, unknown>[], participantID: number, penalty: boolean): number | null {
  const participantScores = scores.filter((score) => score["participant_id"] === participantID);
  const matchingScores = participantScores.filter((score) => {
    const description = String(score["description"] ?? "").toUpperCase();
    return penalty ? description.includes("PEN") : !description.includes("PEN");
  });
  const candidates = matchingScores.length > 0 ? matchingScores : participantScores;

  const preferred = candidates.sort(scoreSort)[0];
  if (!preferred) {
    return null;
  }

  return scoreValue(preferred["score"]);
}

function scoreSort(lhs: Record<string, unknown>, rhs: Record<string, unknown>): number {
  return scorePriority(rhs) - scorePriority(lhs);
}

function scorePriority(score: Record<string, unknown>): number {
  const description = String(score["description"] ?? "").toUpperCase();
  if (description.includes("CURRENT")) return 5;
  if (description.includes("2ND_HALF")) return 4;
  if (description.includes("1ST_HALF")) return 3;
  if (description.includes("PEN")) return 2;
  return 1;
}

function scoreValue(score: unknown): number | null {
  if (typeof score === "number") {
    return score;
  }

  if (!score || typeof score !== "object") {
    return null;
  }

  const scoreObject = score as Record<string, unknown>;
  const value = scoreObject["goals"] ?? scoreObject["score"] ?? scoreObject["participant"];
  return typeof value === "number" ? value : null;
}

function standingDetails(details: Record<string, unknown>[]): {
  played: number | null;
  won: number | null;
  drawn: number | null;
  lost: number | null;
  goalsFor: number | null;
  goalsAgainst: number | null;
  goalDifference: number | null;
} {
  const valueFor = (...needles: string[]) => {
    const detail = details.find((candidate) => {
      const type = candidate["type"] as Record<string, unknown> | undefined;
      const label = [
        candidate["type_id"],
        type?.["name"],
        type?.["code"],
        type?.["developer_name"],
      ]
        .map((value) => String(value ?? "").toLowerCase())
        .join(" ");

      return needles.some((needle) => label.includes(needle));
    });

    return detailValue(detail);
  };

  return {
    played: valueFor("played", "overall matches"),
    won: valueFor("won", "overall won"),
    drawn: valueFor("draw", "overall draw"),
    lost: valueFor("lost", "overall lost"),
    goalsFor: valueFor("goals for", "overall goals for"),
    goalsAgainst: valueFor("goals against", "overall goals against"),
    goalDifference: valueFor("goal difference", "overall goal difference"),
  };
}

function detailValue(detail?: Record<string, unknown>): number | null {
  const value = detail?.["value"];
  if (typeof value === "number") {
    return value;
  }

  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }

  return null;
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
