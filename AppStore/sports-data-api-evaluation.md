# Sports Data API Evaluation

Goal: get reliable fixture, live score, final score, standings, and knockout-result data for the 2026 international soccer tournament.

## Recommendation

Sportmonks is selected for the MVP unless licensing review turns up a blocker. It has public World Cup 2026-specific plans, instant signup, fixtures, live scores, standings, squads, and bracket data. Keep Sportradar as the enterprise fallback if we need premium support, SLAs, or broader licensing coverage.

Implementation status:

- Token stored as a Supabase Edge Function secret.
- Normalized provider tables added in `Backend/supabase/migrations/007_sportmonks_results_ingestion.sql`.
- Protected ingestion function added at `Backend/supabase/functions/sync-sportmonks-results`.
- Confirmed World Cup 2026 provider IDs: league `732`, season `26618`, group stage `77478590`.

## Shortlist

### Sportmonks

Pros:

- Public World Cup 2026 plans and pricing.
- Includes fixtures, live scores, standings, squads, and bracket data in the World Cup plan.
- Easier indie/dev signup path than enterprise-only providers.

Cons:

- Paid monthly plan.
- Need to confirm app-store/public-display rights and rate limits.

Best fit:

- MVP and V1 live scoring.

### API-Football

Pros:

- Established football API with fixtures, standings, and broad competition coverage.
- Familiar RapidAPI-style ecosystem.

Cons:

- Need to verify exact 2026 tournament coverage, latency, and licensing before relying on it.
- World Cup-specific package is less obvious than Sportmonks.

Best fit:

- Backup provider or comparison during integration spike.

### Sportradar

Pros:

- Enterprise-grade sports data provider.
- Strong coverage and support posture.

Cons:

- Usually enterprise sales/pricing.
- More overhead than needed for a small friends-only app.

Best fit:

- Fallback if reliability/licensing requirements exceed indie API options.

### Dedicated 2026 APIs

Examples found:

- Zafronix World Cup API
- WC2026 API
- TheStatsAPI World Cup API

Pros:

- World Cup-specific shape may be convenient.
- Some offer live match/result events.

Cons:

- Need deeper vendor diligence, uptime history, terms, pricing, and data source/licensing review.
- Higher vendor risk than established sports-data providers.

Best fit:

- Prototype comparison only until proven.

## Integration Shape

- Store provider IDs on internal teams and matches.
- Store normalized fixtures/results in `tournament_matches`.
- Store group standings snapshots in `group_standings`.
- Create scheduled Supabase Edge Function to poll fixtures/results.
- Add admin correction path for disputes or provider errors.
- Score brackets from normalized internal results, not directly from provider payloads.

## Data Needed For MVP

- Fixtures with kickoff time, venue, home/away or slot names.
- Group standings: played, wins, draws, losses, goals for/against, points, rank.
- Match status: scheduled, live, halftime, full time, extra time, penalties, postponed.
- Final score and penalty score.
- Knockout winner.
- Provider update timestamp.

## Open Questions

- What does each provider license allow for public display in a consumer app?
- What are live-score latency guarantees?
- Are 2026 tournament fixtures and bracket slots available now?
- Can we cache and retain historical results?
- What are rate limits during match windows?
