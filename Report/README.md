# Awesome-R-Project
###
**Hello! This is our descriptive statistics project.**
>**And this is out fabulous team:**
- Artem Komar
- Kyrylo Iovenko
- Mykhailo Zakharash
- Ivan Turinskyi
## Project topic
For out project topic we have decide to pick data sets related to the cybersport theme, since our team consists of geeks and nerds who are pretty interested in 
videogames and and events related to the world of video games. Among these events are gaming tournaments held in many countries around the world. 
Together we decided to analyze the well-known game CS2, which is considered to be one of the most popular esports disciplines in the shooter genre. 

We take a big table with pro CS2 matches (maps, rounds, players, tournaments) and try to look inside the game. 
We want to understand how teams win, what players do on the map, which maps are popular and does it depends on the tournament level. 
All work is done in R with descriptive statistics: means, medians, correlations, simple regression and graphs.

> [!IMPORTANT]
> Some short words that are important for the further understanding of the topic that we will use in the work:.
- **ADR** - average damage per round
- **KAST** - % of rounds where player got a Kill, Assist, Survived or was Traded
- **Tier** - level of the tournament (Tier 1 is the biggest ones)
- **CV** - how uneven is ADR inside the team (in %)

## Ideas
Let's move to the ideas that we apply to our project:

### 1) Impact of individual performance (ADR / KAST) on the game result
**Question:** Do players with high ADR really win the maps?
>For those who doesn't know: ADR is how much damage a player does in one round on average, so team ADR is just the average of 5 players. We will count it for both teams on every map and compare it with the round difference (`score1_game - score2_game`), to see does the team with bigger ADR really win by more rounds. Also we look for "anomaly" maps, where the winner had lower ADR than the opponent.**

**How we will realize that:**
- count mean ADR of each team on the map (average of 5 players)
- count round difference: `score1_game - score2_game`
- build linear regression: round difference depends on the difference of mean ADR of two teams
- look at "anomaly" maps, where the winner had lower ADR than the opponent

**Formula:**

**Tools:**

**Status:**

---

### Map balance and popularity by tournament tier (Tier 1/2/3)

**Question:** Which maps are played the most and is it the same in every tier?

**Our task:**
- count pick rate of every map inside each tier: games on the map / all games in the tier * 100%
- count total rounds in the game: `score1_game + score2_game`
- count overtime rate for every map: games with more than 24 rounds / all games on the map * 100%
  
**Tools:**
  
**Status:**

---

### Solo carry vs team balance (ADR variance inside the team)

**Question:** Team wins because of one star player or because everybody plays even?

**Our task:**
- count SD of ADR of 5 players inside the team on one map
- count CV = SD / mean ADR * 100%, so we can compare teams with different ADR
- use only maps where both teams have all 5 players
- compare winner and loser of the same map (who has lower CV)
- check is it stronger when the win was bigger (groups by round difference)

**Why CV and not only SD:** winners have higher ADR, so their SD is bigger just because of this.

**Tools:**
  
**Status:**

 ---
### Role clustering: correlation between ADR (aggression) and KAST (stability)

**Question:** Do aggressive players (high ADR) also play stable (high KAST)?

> **For those who doesn't know:** KAST is the % of rounds where the player did something useful for the team: got a Kill, Assist, Survived or was Traded (his teammate killed the enemy who killed him). ADR shows how much damage the player does, so it is more about aggression, and KAST shows how stable the player is because he can be useful in many rounds even without a lot of kills. We take both numbers for every player on every map and count the correlation between them to see do players with high ADR also have high KAST. Also we look at players who have more or less KAST than expected for their ADR.


**Our task**
- count Pearson correlation between ADR and KAST for all players on all maps
- check is it the same in every tier and for winners and losers
- count mean ADR and KAST for every player (only players with 30+ maps)
- draw a regression line and look at players who are far from it (more than 1 SD). Some have more KAST than expected for their ADR, some have less
- it is not real clustering (no kmeans), just a simple rule by distance from the line

**Formula:** `r = Σ(ADR - mean ADR)(KAST - mean KAST) / sqrt(Σ(ADR - mean ADR)² * Σ(KAST - mean KAST)²)`

**Tools:**

**Status:**

