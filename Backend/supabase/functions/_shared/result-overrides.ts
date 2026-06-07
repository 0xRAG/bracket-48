export type SupabaseAdminClient = any;

export type ResultOverrideRow = {
  id?: string;
  match_id: string;
  corrected_status?: string | null;
  corrected_home_score?: number | null;
  corrected_away_score?: number | null;
  corrected_penalty_home_score?: number | null;
  corrected_penalty_away_score?: number | null;
  corrected_winner_team_id?: string | null;
  reason?: string;
};

export function matchPatchFromOverride(override: ResultOverrideRow): Record<string, unknown> {
  const patch: Record<string, unknown> = {};

  copyIfPresent(patch, "status", override.corrected_status);
  copyIfPresent(patch, "home_score", override.corrected_home_score);
  copyIfPresent(patch, "away_score", override.corrected_away_score);
  copyIfPresent(patch, "penalty_home_score", override.corrected_penalty_home_score);
  copyIfPresent(patch, "penalty_away_score", override.corrected_penalty_away_score);
  copyIfPresent(patch, "winner_team_id", override.corrected_winner_team_id);

  return patch;
}

export function hasCorrectedResultField(override: ResultOverrideRow): boolean {
  return Object.keys(matchPatchFromOverride(override)).length > 0;
}

export async function applyActiveResultOverrides(
  adminClient: SupabaseAdminClient,
  matchIDs?: string[],
): Promise<number> {
  let query = adminClient
    .from("result_overrides")
    .select(
      "id,match_id,corrected_status,corrected_home_score,corrected_away_score,"
        + "corrected_penalty_home_score,corrected_penalty_away_score,corrected_winner_team_id"
    )
    .eq("is_active", true)
    .order("created_at", { ascending: true });

  if (matchIDs && matchIDs.length > 0) {
    query = query.in("match_id", matchIDs);
  }

  const { data, error } = await query;
  if (error) {
    throw error;
  }

  let appliedCount = 0;
  for (const override of (data ?? []) as ResultOverrideRow[]) {
    const patch = matchPatchFromOverride(override);
    if (Object.keys(patch).length === 0) {
      continue;
    }

    const { error: updateError } = await adminClient
      .from("tournament_matches")
      .update(patch)
      .eq("id", override.match_id);

    if (updateError) {
      throw updateError;
    }

    appliedCount += 1;
  }

  return appliedCount;
}

function copyIfPresent(patch: Record<string, unknown>, key: string, value: unknown) {
  if (value !== null && value !== undefined) {
    patch[key] = value;
  }
}
