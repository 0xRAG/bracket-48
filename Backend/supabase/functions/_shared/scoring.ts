export const scoringVersion = "world-cup-default-v1";

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

export type BracketPhase = "group_stage" | "knockout";

export type PoolEntryRow = {
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

export type BracketPicks = {
  predictions?: GroupPrediction[];
  picks?: KnockoutPick[];
};

export type GroupPrediction = {
  group_id: string;
  ordered_team_ids: string[];
  predicted_third_place_advances: boolean;
};

export type KnockoutPick = {
  match_id: string;
  round: string;
  picked_winner_team_id: string;
};

export type GroupStandingResult = {
  group_id: string;
  ordered_team_ids: string[];
};

export type KnockoutResult = {
  match_id: string;
  round: string;
  winner_team_id: string;
  eliminated_team_ids?: string[];
};

export type ScoreEvent = {
  source_type: "group_stage_prediction" | "knockout_pick";
  source_id: string;
  rule_id: string;
  points: number;
  reason: string;
};

export type ScoreBreakdown = {
  pool_entry_id: string;
  pool_id: string | null;
  bracket_id: string | null;
  user_id: string | null;
  phase: BracketPhase | "combined";
  group_stage_points: number;
  knockout_points: number;
  total_points: number;
  max_points: number;
  possible_points_remaining: number;
  events: ScoreEvent[];
};

export type ScoringResults = {
  groupStandings: GroupStandingResult[];
  finalGroupIDs: Set<string>;
  advancingThirdPlaceTeamIDs: Set<string>;
  knockoutResults: KnockoutResult[];
  eliminatedTeamIDs: Set<string>;
};

export type DatabaseGroupStanding = {
  group_name: string;
  teams: Array<{
    team_id: string | null;
    position: number;
    points: number;
    played?: number | null;
    goal_difference: number | null;
    goals_for: number | null;
  }>;
};

export function scorePoolEntry(
  entry: PoolEntryRow,
  results: ScoringResults,
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

export function scoreSimulationEntries(
  entries: Array<Record<string, unknown>>,
  results: ScoringResults,
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

export function scorePicks(input: {
  poolEntryID: string;
  poolID: string | null;
  bracketID: string | null;
  userID: string | null;
  phase: BracketPhase | "combined";
  picks: BracketPicks;
  results: ScoringResults;
}): ScoreBreakdown {
  const events: ScoreEvent[] = [];
  const groupStandingsByID = new Map(input.results.groupStandings.map((standing) => [standing.group_id, standing]));
  const knockoutResultsByMatchID = new Map(input.results.knockoutResults.map((result) => [result.match_id, result]));

  const groupPredictionScores = new Map<string, number>();
  for (const prediction of input.picks.predictions ?? []) {
    const standing = groupStandingsByID.get(prediction.group_id);
    if (!standing) {
      continue;
    }

    const groupEvents = scoreGroupPrediction(prediction, standing, input.results.advancingThirdPlaceTeamIDs);
    groupPredictionScores.set(
      prediction.group_id,
      groupEvents.reduce((total, event) => total + event.points, 0),
    );
    events.push(...groupEvents);
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
    possible_points_remaining: possiblePointsRemaining(input.picks, input.results, groupPredictionScores),
    events,
  };
}

export function scoreGroupPrediction(
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

export function maximumScore(picks: BracketPicks): number {
  const groupPointsPerPrediction = rules.correctGroupWinner
    + rules.correctGroupRunnerUp
    + rules.correctGroupThirdPlace
    + rules.correctThirdPlaceAdvancement
    + rules.perfectGroupTopThreeBonus;
  const groupStagePoints = (picks.predictions ?? []).length * groupPointsPerPrediction;
  const knockoutPoints = (picks.picks ?? []).reduce((total, pick) => total + (rules.knockoutRoundPoints[pick.round] ?? 0), 0);
  return groupStagePoints + knockoutPoints;
}

export function possiblePointsRemaining(
  picks: BracketPicks,
  results: ScoringResults,
  currentGroupPredictionScores = new Map<string, number>(),
): number {
  const groupPointsPerPrediction = rules.correctGroupWinner
    + rules.correctGroupRunnerUp
    + rules.correctGroupThirdPlace
    + rules.correctThirdPlaceAdvancement
    + rules.perfectGroupTopThreeBonus;
  const knockoutResultsByMatchID = new Set(results.knockoutResults.map((result) => result.match_id));

  const groupStageRemaining = (picks.predictions ?? []).reduce((total, prediction) => {
    if (results.finalGroupIDs.has(prediction.group_id)) {
      return total;
    }

    const provisionalPoints = currentGroupPredictionScores.get(prediction.group_id) ?? 0;
    return total + Math.max(0, groupPointsPerPrediction - provisionalPoints);
  }, 0);

  const knockoutRemaining = (picks.picks ?? []).reduce((total, pick) => {
    if (knockoutResultsByMatchID.has(pick.match_id)) {
      return total;
    }

    if (results.eliminatedTeamIDs.has(pick.picked_winner_team_id)) {
      return total;
    }

    return total + (rules.knockoutRoundPoints[pick.round] ?? 0);
  }, 0);

  return groupStageRemaining + knockoutRemaining;
}

export function finalGroupIDs(groups: DatabaseGroupStanding[]): Set<string> {
  return new Set(groups
    .filter((group) => group.teams.length >= 4 && group.teams.every((team) => (team.played ?? 0) >= 3))
    .map((group) => groupIDFromName(group.group_name)));
}

export function advancingThirdPlaceTeams(groups: DatabaseGroupStanding[]): Set<string> {
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

export function parseGroupStanding(value: unknown): GroupStandingResult | null {
  const object = objectValue(value);
  if (!object || typeof object["group_id"] !== "string") {
    return null;
  }

  const orderedTeamIDs = arrayValue(object["ordered_team_ids"])
    .filter((teamID): teamID is string => typeof teamID === "string");
  return { group_id: object["group_id"], ordered_team_ids: orderedTeamIDs };
}

export function parseKnockoutResult(value: unknown): KnockoutResult | null {
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
    eliminated_team_ids: arrayValue(object["eliminated_team_ids"])
      .filter((teamID): teamID is string => typeof teamID === "string"),
  };
}

export function internalKnockoutMatchID(round: string, index: number): string {
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

export function appRound(databaseRound: string): string | null {
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

export function groupIDFromName(groupName: string): string {
  return groupName.replace(/^Group\s+/i, "").trim();
}

export function numberOrNull(value: unknown): number | null {
  return typeof value === "number" ? value : null;
}

export function objectValue(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : null;
}

export function arrayValue(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

export async function sha256(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
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
