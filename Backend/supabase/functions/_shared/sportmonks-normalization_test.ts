import {
  internalTeamID,
  matchRow,
  matchStatus,
  participantsFromFixtures,
  scoreForParticipant,
  standingDetails,
  standingRow,
  type SportmonksFixture,
} from "./sportmonks-normalization.ts";

Deno.test("normalizes final knockout fixtures with scores, penalties, winner, and internal teams", () => {
  const fixture: SportmonksFixture = {
    id: 12345,
    season_id: 26618,
    stage_id: 77479090,
    name: "Argentina vs France",
    details: "Match 104",
    starting_at: "2026-07-19 19:00:00",
    state: { short_name: "FT_PEN", developer_name: "FT_PEN", name: "Finished after penalties" },
    participants: [
      { id: 1, name: "Argentina", short_code: "ARG", meta: { location: "home", winner: true } },
      { id: 2, name: "France", short_code: "FRA", meta: { location: "away", winner: false } },
    ],
    scores: [
      { participant_id: 1, description: "1ST_HALF", score: { goals: 1 } },
      { participant_id: 2, description: "1ST_HALF", score: { goals: 0 } },
      { participant_id: 1, description: "CURRENT", score: { goals: 3 } },
      { participant_id: 2, description: "CURRENT", score: { goals: 3 } },
      { participant_id: 1, description: "PENALTY_SHOOTOUT", score: { goals: 4 } },
      { participant_id: 2, description: "PENALTY_SHOOTOUT", score: { goals: 2 } },
    ],
  };

  const row = matchRow(fixture, 26618);

  assertEquals(row.phase, "knockout");
  assertEquals(row.knockout_round, "final");
  assertEquals(row.match_number, 104);
  assertEquals(row.starts_at, "2026-07-19T19:00:00Z");
  assertEquals(row.status, "final");
  assertEquals(row.home_team_id, "arg");
  assertEquals(row.away_team_id, "fra");
  assertEquals(row.home_score, 3);
  assertEquals(row.away_score, 3);
  assertEquals(row.penalty_home_score, 4);
  assertEquals(row.penalty_away_score, 2);
  assertEquals(row.winner_team_id, "arg");
});

Deno.test("normalizes group fixtures and placeholder knockout slots", () => {
  const groupRow = matchRow({
    id: 100,
    season_id: 26618,
    stage_id: 77478590,
    group: { id: 11, name: "Group A" },
    state: { short_name: "NS" },
    participants: [
      { id: 10, name: "United States", meta: { location: "home" } },
      { id: 11, name: "Mexico", short_code: "MEX", meta: { location: "away" } },
    ],
  }, 26618);

  assertEquals(groupRow.phase, "group_stage");
  assertEquals(groupRow.group_name, "Group A");
  assertEquals(groupRow.home_team_id, "usa");
  assertEquals(groupRow.away_team_id, "mex");
  assertEquals(groupRow.status, "scheduled");

  const placeholderRow = matchRow({
    id: 101,
    season_id: 26618,
    stage_id: 77479086,
    participants: [
      { id: 20, name: "Winner Group A", placeholder: true, meta: { location: "home" } },
      { id: 21, name: "Third Group C/D/E", placeholder: true, meta: { location: "away" } },
    ],
  }, 26618);

  assertEquals(placeholderRow.phase, "knockout");
  assertEquals(placeholderRow.knockout_round, "round_of_32");
  assertEquals(placeholderRow.home_team_id, null);
  assertEquals(placeholderRow.home_slot_label, "Winner Group A");
  assertEquals(placeholderRow.away_slot_label, "Third Group C/D/E");
});

Deno.test("normalizes standings detail payloads", () => {
  const details = [
    stat("overall matches played", 3),
    stat("overall won", "2"),
    stat("overall draw", 1),
    stat("overall lost", 0),
    stat("overall goals for", 5),
    stat("overall goals against", 2),
    stat("overall goal difference", 3),
  ];

  const parsed = standingDetails(details);
  assertEquals(parsed.played, 3);
  assertEquals(parsed.won, 2);
  assertEquals(parsed.drawn, 1);
  assertEquals(parsed.goalDifference, 3);

  const row = standingRow({
    participant_id: 50,
    season_id: 26618,
    position: 1,
    points: 7,
    group: { id: 90, name: "Group B" },
    participant: { id: 50, name: "Côte d'Ivoire", short_code: null },
    details,
  });

  if (!row) {
    throw new Error("Expected standing row.");
  }

  assertEquals(row.group_name, "Group B");
  assertEquals(row.team_id, "civ");
  assertEquals(row.played, 3);
  assertEquals(row.points, 7);
});

Deno.test("maps teams and scores defensively", () => {
  assertEquals(internalTeamID({ id: 1, name: "Korea Republic" }), "kor");
  assertEquals(internalTeamID({ id: 2, name: "Winner Group A", placeholder: true }), null);
  assertEquals(matchStatus("2ND_HALF"), "live");
  assertEquals(matchStatus("POSTP"), "postponed");

  const scores = [
    { participant_id: 7, description: "1ST_HALF", score: { goals: 1 } },
    { participant_id: 7, description: "CURRENT", score: { goals: 2 } },
    { participant_id: 7, description: "PEN", score: { goals: 5 } },
  ];
  assertEquals(scoreForParticipant(scores, 7, false), 2);
  assertEquals(scoreForParticipant(scores, 7, true), 5);

  const participants = participantsFromFixtures([
    { id: 1, season_id: 26618, participants: [{ id: 9, name: "Canada" }] },
    { id: 2, season_id: 26618, participants: [{ id: 10, name: "Mexico" }] },
  ]);
  assertEquals(participants.length, 2);
});

function stat(label: string, value: number | string): Record<string, unknown> {
  return {
    type: { name: label },
    value,
  };
}

function assertEquals(actual: unknown, expected: unknown): void {
  if (actual !== expected) {
    throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}.`);
  }
}
