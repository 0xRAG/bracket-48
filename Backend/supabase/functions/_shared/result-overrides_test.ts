import {
  hasCorrectedResultField,
  matchPatchFromOverride,
} from "./result-overrides.ts";

Deno.test("builds tournament match patch from corrected result fields", () => {
  const patch = matchPatchFromOverride({
    match_id: "r32-1",
    corrected_status: "final",
    corrected_home_score: 1,
    corrected_away_score: 2,
    corrected_penalty_home_score: null,
    corrected_penalty_away_score: undefined,
    corrected_winner_team_id: "mex",
  });

  const expected = {
    status: "final",
    home_score: 1,
    away_score: 2,
    winner_team_id: "mex",
  };

  if (JSON.stringify(patch) !== JSON.stringify(expected)) {
    throw new Error(`Unexpected override patch: ${JSON.stringify(patch)}.`);
  }
});

Deno.test("detects whether an override contains corrected result fields", () => {
  if (hasCorrectedResultField({ match_id: "r32-1", reason: "No-op" })) {
    throw new Error("Expected no-op override to be rejected.");
  }

  if (!hasCorrectedResultField({ match_id: "r32-1", reason: "Fix winner", corrected_winner_team_id: "usa" })) {
    throw new Error("Expected corrected winner override to be accepted.");
  }
});
