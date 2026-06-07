import {
  advancingThirdPlaceTeams,
  scorePicks,
  scoreSimulationEntries,
} from "./scoring.ts";

Deno.test("scores exact group order and third-place advancement", () => {
  const score = scorePicks({
    poolEntryID: "entry-1",
    poolID: "pool-1",
    bracketID: "bracket-1",
    userID: "user-1",
    phase: "group_stage",
    picks: {
      predictions: [{
        group_id: "A",
        ordered_team_ids: ["usa", "mex", "can", "pan"],
        predicted_third_place_advances: true,
      }],
    },
    results: {
      groupStandings: [{
        group_id: "A",
        ordered_team_ids: ["usa", "mex", "can", "pan"],
      }],
      finalGroupIDs: new Set(["A"]),
      advancingThirdPlaceTeamIDs: new Set(["can"]),
      knockoutResults: [],
      eliminatedTeamIDs: new Set<string>(),
    },
  });

  if (score.group_stage_points !== 14 || score.total_points !== 14) {
    throw new Error(`Expected 14 group-stage points, got ${score.total_points}.`);
  }

  const ruleIDs = score.events.map((event) => event.rule_id).sort();
  const expected = ["perfect-top-three", "runner-up", "third-place", "third-place-advancement", "winner"];
  if (JSON.stringify(ruleIDs) !== JSON.stringify(expected)) {
    throw new Error(`Unexpected score events: ${JSON.stringify(ruleIDs)}.`);
  }
});

Deno.test("scores combined group-stage and knockout picks", () => {
  const score = scorePicks({
    poolEntryID: "entry-1",
    poolID: "pool-1",
    bracketID: "bracket-1",
    userID: "user-1",
    phase: "combined",
    picks: {
      predictions: [{
        group_id: "D",
        ordered_team_ids: ["eng", "usa", "wal", "irn"],
        predicted_third_place_advances: true,
      }],
      picks: [
        { match_id: "r32-1", round: "roundOf32", picked_winner_team_id: "usa" },
        { match_id: "r16-1", round: "roundOf16", picked_winner_team_id: "arg" },
        { match_id: "qf-1", round: "quarterfinal", picked_winner_team_id: "bra" },
        { match_id: "sf-1", round: "semifinal", picked_winner_team_id: "fra" },
        { match_id: "final", round: "final", picked_winner_team_id: "fra" },
      ],
    },
    results: {
      groupStandings: [{
        group_id: "D",
        ordered_team_ids: ["eng", "usa", "wal", "irn"],
      }],
      finalGroupIDs: new Set(["D"]),
      advancingThirdPlaceTeamIDs: new Set(["wal"]),
      knockoutResults: [
        { match_id: "r32-1", round: "roundOf32", winner_team_id: "usa", eliminated_team_ids: ["mex"] },
        { match_id: "r16-1", round: "roundOf16", winner_team_id: "arg", eliminated_team_ids: ["usa"] },
        { match_id: "qf-1", round: "quarterfinal", winner_team_id: "bra", eliminated_team_ids: ["eng"] },
        { match_id: "sf-1", round: "semifinal", winner_team_id: "fra", eliminated_team_ids: ["bra"] },
        { match_id: "final", round: "final", winner_team_id: "fra", eliminated_team_ids: ["arg"] },
      ],
      eliminatedTeamIDs: new Set(["mex", "usa", "eng", "bra", "arg"]),
    },
  });

  if (score.group_stage_points !== 14 || score.knockout_points !== 50 || score.total_points !== 64) {
    throw new Error(`Expected 64 combined points, got ${score.total_points}.`);
  }

  if (score.max_points !== 64) {
    throw new Error(`Expected max score 64, got ${score.max_points}.`);
  }

  if (score.possible_points_remaining !== 0) {
    throw new Error(`Expected no possible points remaining, got ${score.possible_points_remaining}.`);
  }
});

Deno.test("selects the eight best third-place teams by points and tiebreakers", () => {
  const advancing = advancingThirdPlaceTeams([
    group("A", "a3", 4, 1, 3),
    group("B", "b3", 3, 5, 8),
    group("C", "c3", 3, 2, 4),
    group("D", "d3", 2, 9, 9),
    group("E", "e3", 5, 0, 4),
    group("F", "f3", 1, 8, 8),
    group("G", "g3", 3, 2, 5),
    group("H", "h3", 6, -1, 2),
    group("I", "i3", 4, 2, 1),
    group("J", "j3", 2, 0, 2),
    group("K", "k3", 3, 2, 1),
    group("L", "l3", 4, 2, 6),
  ]);

  const ordered = [...advancing];
  const expected = ["h3", "e3", "l3", "i3", "a3", "b3", "g3", "c3"];
  if (JSON.stringify(ordered) !== JSON.stringify(expected)) {
    throw new Error(`Unexpected third-place teams: ${JSON.stringify(ordered)}.`);
  }
});

Deno.test("scores simulation entries without database IDs", () => {
  const scores = scoreSimulationEntries([{
    entry_id: "sim-1",
    user_id: "demo-user",
    predictions: [{
      group_id: "A",
      ordered_team_ids: ["usa", "mex", "can", "pan"],
      predicted_third_place_advances: false,
    }],
    knockout_picks: [
      { match_id: "final", round: "final", picked_winner_team_id: "arg" },
    ],
  }], {
    groupStandings: [{
      group_id: "A",
      ordered_team_ids: ["usa", "mex", "can", "pan"],
    }],
    finalGroupIDs: new Set(["A"]),
    advancingThirdPlaceTeamIDs: new Set<string>(),
    knockoutResults: [
      { match_id: "final", round: "final", winner_team_id: "arg", eliminated_team_ids: ["fra"] },
    ],
    eliminatedTeamIDs: new Set(["fra"]),
  });

  const score = scores[0];
  if (scores.length !== 1 || score.total_points !== 34 || score.user_id !== "demo-user") {
    throw new Error(`Unexpected simulation score: ${JSON.stringify(score)}.`);
  }
});

Deno.test("calculates possible points remaining from unresolved results", () => {
  const picks = {
    predictions: [{
      group_id: "A",
      ordered_team_ids: ["usa", "mex", "can", "pan"],
      predicted_third_place_advances: true,
    }],
    picks: [
      { match_id: "final", round: "final", picked_winner_team_id: "arg" },
    ],
  };

  const partial = scorePicks({
    poolEntryID: "entry-1",
    poolID: "pool-1",
    bracketID: "bracket-1",
    userID: "user-1",
    phase: "combined",
    picks,
    results: {
      groupStandings: [{
        group_id: "A",
        ordered_team_ids: ["usa", "mex", "can", "pan"],
      }],
      finalGroupIDs: new Set<string>(),
      advancingThirdPlaceTeamIDs: new Set(["can"]),
      knockoutResults: [],
      eliminatedTeamIDs: new Set<string>(),
    },
  });

  if (partial.total_points !== 14 || partial.possible_points_remaining !== 20) {
    throw new Error(`Unexpected partial possible points: ${JSON.stringify(partial)}.`);
  }

  const final = scorePicks({
    poolEntryID: "entry-1",
    poolID: "pool-1",
    bracketID: "bracket-1",
    userID: "user-1",
    phase: "combined",
    picks,
    results: {
      groupStandings: [{
        group_id: "A",
        ordered_team_ids: ["mex", "usa", "can", "pan"],
      }],
      finalGroupIDs: new Set(["A"]),
      advancingThirdPlaceTeamIDs: new Set(["can"]),
      knockoutResults: [
        { match_id: "final", round: "final", winner_team_id: "fra", eliminated_team_ids: ["arg"] },
      ],
      eliminatedTeamIDs: new Set(["arg"]),
    },
  });

  if (final.total_points !== 4 || final.possible_points_remaining !== 0) {
    throw new Error(`Unexpected final possible points: ${JSON.stringify(final)}.`);
  }
});

Deno.test("removes possible points for future knockout picks after team elimination", () => {
  const score = scorePicks({
    poolEntryID: "entry-1",
    poolID: "pool-1",
    bracketID: "bracket-1",
    userID: "user-1",
    phase: "knockout",
    picks: {
      picks: [
        { match_id: "r32-1", round: "roundOf32", picked_winner_team_id: "usa" },
        { match_id: "r16-1", round: "roundOf16", picked_winner_team_id: "usa" },
        { match_id: "final", round: "final", picked_winner_team_id: "usa" },
      ],
    },
    results: {
      groupStandings: [],
      finalGroupIDs: new Set<string>(),
      advancingThirdPlaceTeamIDs: new Set<string>(),
      knockoutResults: [
        { match_id: "r32-1", round: "roundOf32", winner_team_id: "mex", eliminated_team_ids: ["usa"] },
      ],
      eliminatedTeamIDs: new Set(["usa"]),
    },
  });

  if (score.total_points !== 0 || score.possible_points_remaining !== 0) {
    throw new Error(`Expected eliminated future picks to have no remaining upside: ${JSON.stringify(score)}.`);
  }
});

function group(
  groupName: string,
  thirdPlaceTeamID: string,
  points: number,
  goalDifference: number,
  goalsFor: number,
) {
  return {
    group_name: `Group ${groupName}`,
    teams: [
      { team_id: `${groupName.toLowerCase()}1`, position: 1, points: 9, played: 3, goal_difference: 5, goals_for: 8 },
      { team_id: `${groupName.toLowerCase()}2`, position: 2, points: 6, played: 3, goal_difference: 2, goals_for: 5 },
      {
        team_id: thirdPlaceTeamID,
        position: 3,
        points,
        played: 3,
        goal_difference: goalDifference,
        goals_for: goalsFor,
      },
    ],
  };
}
