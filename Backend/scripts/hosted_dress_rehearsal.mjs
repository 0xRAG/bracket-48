#!/usr/bin/env node

import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const poolID = "90000000-0000-4000-8000-000000000201";
const keepSeedData = process.argv.includes("--keep");

const simulation = {
  group_standings: [
    { group_id: "A", ordered_team_ids: ["usa", "mex", "can", "pan"] },
    { group_id: "B", ordered_team_ids: ["eng", "sco", "wal", "irn"] },
  ],
  final_group_ids: ["A", "B"],
  advancing_third_place_team_ids: ["can"],
  knockout_results: [
    { match_id: "r32-1", round: "roundOf32", winner_team_id: "usa", eliminated_team_ids: ["mex"] },
    { match_id: "r16-1", round: "roundOf16", winner_team_id: "arg", eliminated_team_ids: ["usa"] },
    { match_id: "qf-1", round: "quarterfinal", winner_team_id: "bra", eliminated_team_ids: ["eng"] },
    { match_id: "sf-1", round: "semifinal", winner_team_id: "fra", eliminated_team_ids: ["bra"] },
    { match_id: "final", round: "final", winner_team_id: "fra", eliminated_team_ids: ["arg"] },
  ],
  eliminated_team_ids: ["mex", "usa", "eng", "bra", "arg"],
};

const expectedScores = [
  { display_name: "Dress Alpha", phase: "group_stage", total_points: 28, max_points: 28, possible_points_remaining: 0, event_count: 10 },
  { display_name: "Dress Alpha", phase: "knockout", total_points: 50, max_points: 50, possible_points_remaining: 0, event_count: 5 },
  { display_name: "Dress Beta", phase: "group_stage", total_points: 18, max_points: 28, possible_points_remaining: 0, event_count: 6 },
  { display_name: "Dress Beta", phase: "knockout", total_points: 12, max_points: 50, possible_points_remaining: 0, event_count: 2 },
];

async function main() {
  console.log("Seeding hosted dress rehearsal data...");
  await supabaseQueryFile("supabase/tests/hosted_dress_rehearsal_seed.sql");

  try {
    const secrets = await loadSecrets();
    const dryRun = await score(secrets, true);
    assertScoreResponse(dryRun, true);
    console.log(`Dry run scored ${dryRun.score_count} entries from ${dryRun.result_source} results.`);

    const persisted = await score(secrets, false);
    assertScoreResponse(persisted, false);
    console.log(`Persisted run scored ${persisted.score_count} entries.`);

    const verification = await supabaseQueryFile("supabase/tests/hosted_dress_rehearsal_verify.sql", "json");
    assertVerification(parseQueryRows(verification, "dress rehearsal verification"));
    console.log("Verified persisted leaderboard totals, possible points, and score-event counts.");

    await scoreDatabasePool(secrets);
    await assertKnockoutTotals([
      { pool_entry_id: "90000000-0000-4000-8000-000000000402", total_points: 4 },
      { pool_entry_id: "90000000-0000-4000-8000-000000000404", total_points: 4 },
    ]);
    await applyResultOverride(secrets);
    await assertKnockoutTotals([
      { pool_entry_id: "90000000-0000-4000-8000-000000000402", total_points: 0 },
      { pool_entry_id: "90000000-0000-4000-8000-000000000404", total_points: 0 },
    ]);
    console.log("Verified admin result override applies and refreshes scoped scores.");
  } finally {
    if (keepSeedData) {
      console.log("Leaving hosted dress rehearsal data in place because --keep was provided.");
    } else {
      console.log("Cleaning up hosted dress rehearsal data...");
      await supabaseQueryFile("supabase/tests/hosted_dress_rehearsal_cleanup.sql");
    }
  }
}

async function loadSecrets() {
  const output = await supabaseQuery(
    "select max(decrypted_secret) filter (where name = 'bracket48_project_url') as project_url, " +
      "max(decrypted_secret) filter (where name = 'bracket48_sync_secret') as sync_secret " +
      "from vault.decrypted_secrets;",
    "json",
  );
  const [row] = parseQueryRows(output, "Supabase Vault secrets");
  if (!row?.project_url || !row?.sync_secret) {
    throw new Error("Could not load hosted project URL and sync secret from Supabase Vault.");
  }
  return row;
}

async function score(secrets, dryRun) {
  const response = await fetch(`${secrets.project_url}/functions/v1/score-brackets`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-sync-secret": secrets.sync_secret,
    },
    signal: AbortSignal.timeout(60_000),
    body: JSON.stringify({
      dry_run: dryRun,
      pool_id: poolID,
      simulation,
    }),
  });
  const body = await parseFunctionResponse(response, "score-brackets");
  if (!response.ok) {
    throw new Error(`score-brackets returned ${response.status}: ${JSON.stringify(body)}`);
  }
  return body;
}

async function scoreDatabasePool(secrets) {
  const response = await fetch(`${secrets.project_url}/functions/v1/score-brackets`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-sync-secret": secrets.sync_secret,
    },
    signal: AbortSignal.timeout(60_000),
    body: JSON.stringify({
      dry_run: false,
      pool_id: poolID,
    }),
  });
  const body = await parseFunctionResponse(response, "score-brackets");
  if (!response.ok) {
    throw new Error(`database score-brackets returned ${response.status}: ${JSON.stringify(body)}`);
  }
  if (body.scored !== true || body.result_source !== "database" || body.score_count !== 4) {
    throw new Error(`Unexpected database scoring response: ${JSON.stringify(body)}`);
  }
  return body;
}

async function applyResultOverride(secrets) {
  const response = await fetch(`${secrets.project_url}/functions/v1/apply-result-override`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-sync-secret": secrets.sync_secret,
    },
    signal: AbortSignal.timeout(60_000),
    body: JSON.stringify({
      match_id: "dress-r32-1",
      corrected_status: "final",
      corrected_home_score: 0,
      corrected_away_score: 1,
      corrected_winner_team_id: "mex",
      reason: "Dress rehearsal winner correction.",
      scoring_pool_id: poolID,
    }),
  });
  const body = await parseFunctionResponse(response, "apply-result-override");
  if (!response.ok) {
    throw new Error(`apply-result-override returned ${response.status}: ${JSON.stringify(body)}`);
  }
  if (body.overridden !== true || body.match_id !== "dress-r32-1" || body.scoring_invoked !== true) {
    throw new Error(`Unexpected override response: ${JSON.stringify(body)}`);
  }
  return body;
}

async function assertKnockoutTotals(expectedRows) {
  const output = await supabaseQuery(
    "select pool_entry_id, total_points from public.bracket_scores " +
      `where pool_id = '${poolID}' and phase = 'knockout' ` +
      "order by pool_entry_id;",
    "json",
  );
  const actual = parseQueryRows(output, "knockout score totals").map((row) => ({
    pool_entry_id: row.pool_entry_id,
    total_points: row.total_points,
  }));

  if (JSON.stringify(actual) !== JSON.stringify(expectedRows)) {
    throw new Error(`Unexpected knockout score totals: ${JSON.stringify(actual)}.`);
  }
}

function assertScoreResponse(body, dryRun) {
  if (body.scored !== true || body.dry_run !== dryRun || body.result_source !== "simulation" || body.score_count !== 4) {
    throw new Error(`Unexpected score response: ${JSON.stringify(body)}`);
  }

  if (!Array.isArray(body.scores)) {
    throw new Error(`score-brackets response did not include a scores array: ${JSON.stringify(body)}`);
  }

  const actual = [...body.scores]
    .map((score) => ({
      phase: score.phase,
      total_points: score.total_points,
      max_points: score.max_points,
      possible_points_remaining: score.possible_points_remaining,
    }))
    .sort(scoreSort);
  const expected = expectedScores
    .map(({ phase, total_points, max_points, possible_points_remaining }) => ({
      phase,
      total_points,
      max_points,
      possible_points_remaining,
    }))
    .sort(scoreSort);

  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`Unexpected scored totals: ${JSON.stringify(actual)}`);
  }
}

function assertVerification(rows) {
  if (rows.length !== expectedScores.length) {
    throw new Error(`Expected ${expectedScores.length} verification rows, got ${rows.length}.`);
  }

  const failures = rows.filter((row) => row.passed !== true);
  if (failures.length > 0) {
    throw new Error(`Dress rehearsal verification failed: ${JSON.stringify(failures)}`);
  }
}

function scoreSort(lhs, rhs) {
  return rhs.total_points - lhs.total_points || lhs.phase.localeCompare(rhs.phase) || lhs.max_points - rhs.max_points;
}

async function supabaseQuery(sql, output = "table") {
  const { stdout } = await execFileAsync("pnpm", [
    "dlx",
    "supabase",
    "db",
    "query",
    "--workdir",
    "Backend",
    "--linked",
    "--output",
    output,
    sql,
  ], {
    cwd: new URL("../..", import.meta.url),
    env: supabaseCliEnv(),
    maxBuffer: 1024 * 1024 * 10,
  });
  return stripSupabaseNoise(stdout);
}

async function supabaseQueryFile(file, output = "table") {
  const { stdout } = await execFileAsync("pnpm", [
    "dlx",
    "supabase",
    "db",
    "query",
    "--workdir",
    "Backend",
    "--linked",
    "--file",
    file,
    "--output",
    output,
  ], {
    cwd: new URL("../..", import.meta.url),
    env: supabaseCliEnv(),
    maxBuffer: 1024 * 1024 * 10,
  });
  return stripSupabaseNoise(stdout);
}

function parseQueryRows(output, label) {
  let parsed;
  try {
    parsed = JSON.parse(output);
  } catch (error) {
    throw new Error(`Could not parse ${label} JSON output: ${error.message}. Output: ${output}`);
  }

  if (Array.isArray(parsed)) {
    return parsed;
  }

  if (Array.isArray(parsed?.rows)) {
    return parsed.rows;
  }

  throw new Error(`Expected ${label} query output to contain rows, got: ${JSON.stringify(parsed)}`);
}

async function parseFunctionResponse(response, functionName) {
  const text = await response.text();
  if (text.length === 0) {
    throw new Error(`${functionName} returned ${response.status} with an empty response body.`);
  }

  try {
    return JSON.parse(text);
  } catch (error) {
    throw new Error(`${functionName} returned non-JSON response ${response.status}: ${text}`);
  }
}

function supabaseCliEnv() {
  return {
    ...process.env,
    DO_NOT_TRACK: "1",
    NO_COLOR: "1",
    SUPABASE_TELEMETRY_DISABLED: "1",
  };
}

function stripSupabaseNoise(output) {
  return output
    .split("\n")
    .filter((line) => !line.startsWith("Using workdir ") && !line.startsWith("Initialising login role"))
    .join("\n")
    .trim();
}

main().catch((error) => {
  console.error(error.stack ?? error.message);
  process.exit(1);
});
