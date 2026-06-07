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
  advancing_third_place_team_ids: ["can"],
  knockout_results: [
    { match_id: "r32-1", round: "roundOf32", winner_team_id: "usa" },
    { match_id: "r16-1", round: "roundOf16", winner_team_id: "arg" },
    { match_id: "qf-1", round: "quarterfinal", winner_team_id: "bra" },
    { match_id: "sf-1", round: "semifinal", winner_team_id: "fra" },
    { match_id: "final", round: "final", winner_team_id: "fra" },
  ],
};

const expectedScores = [
  { display_name: "Dress Alpha", phase: "group_stage", total_points: 28, max_points: 28, event_count: 10 },
  { display_name: "Dress Alpha", phase: "knockout", total_points: 50, max_points: 50, event_count: 5 },
  { display_name: "Dress Beta", phase: "group_stage", total_points: 18, max_points: 28, event_count: 6 },
  { display_name: "Dress Beta", phase: "knockout", total_points: 12, max_points: 50, event_count: 2 },
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
    assertVerification(JSON.parse(verification).rows);
    console.log("Verified persisted leaderboard totals and score-event counts.");
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
  const [row] = JSON.parse(output).rows;
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
    body: JSON.stringify({
      dry_run: dryRun,
      pool_id: poolID,
      simulation,
    }),
  });
  const body = await response.json();
  if (!response.ok) {
    throw new Error(`score-brackets returned ${response.status}: ${JSON.stringify(body)}`);
  }
  return body;
}

function assertScoreResponse(body, dryRun) {
  if (body.scored !== true || body.dry_run !== dryRun || body.result_source !== "simulation" || body.score_count !== 4) {
    throw new Error(`Unexpected score response: ${JSON.stringify(body)}`);
  }

  const actual = [...body.scores]
    .map((score) => ({
      phase: score.phase,
      total_points: score.total_points,
      max_points: score.max_points,
    }))
    .sort(scoreSort);
  const expected = expectedScores
    .map(({ phase, total_points, max_points }) => ({ phase, total_points, max_points }))
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
    maxBuffer: 1024 * 1024 * 10,
  });
  return stripSupabaseNoise(stdout);
}

function stripSupabaseNoise(output) {
  return output
    .split("\n")
    .filter((line) => !line.startsWith("Using workdir ") && !line.startsWith("Initialising login role"))
    .join("\n")
    .trim();
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
