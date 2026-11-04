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


---
## Data Cleaning Process

Raw data is big and a bit messy: there are not only pro games, some names are written in different ways and some maps are not real games. So before any analysis we clean it in the script 01_data_cleaning.R. Order of the steps is important, we do the filters first and only then build the tables.

### 1. Loading and tiers

We read three csv files: all games, Tier 1 games and Tier 2 games. Tier of every game is made by the tournament name: if tournament is in the Tier 1 list it is tier1, if in the Tier 2 list it is tier2, all other is tier3 (unique(), %in%, ifelse()).

### 2. Filters

| What we remove | How we find it |
|---|---|
| Rows without team names | is.na() on team1 and team2 |
| National teams tournament | grepl("Esports Nations Cup", ...) |
| Russian regional tournaments | big regex pattern with names (BetBoom, Buster, VK GG, CIS and others), grepl(..., ignore.case = TRUE) |
| Non-professional tournaments and showmatches | regex pattern (Showmatch, Impact League, Friday Fight, Star Series, IESF and others) |
| All-star teams (Team USA, Team Germany, BLAST Dream Team...) | team names in a list, %in%, we delete the game if one of two teams is in the list |
| Games before October 2023 | as.POSIXct() and filter by date, because pro games in CS2 started from October 2023 |

Before deleting Russian tournaments we check how many tournaments and rows will go away (length(unique(...)), sum()), so we know that filter works not too strong.

### 3. Team names

Same team can be written in different ways ("BETBOOM TEAM" and "BetBoom Team", "WICKED" and "Wicked Gaming"). We made a named vector fix_names and the function fix_team() that changes wrong names to the right one (ifelse()).

### 4. Matches and maps

Data has two types of rows, so we divide it by the column is_total:

- **matches** (is_total == "True") - only the result of the whole match. We sort by match_id and drop duplicates (order(), duplicated()). Some team1_win values are wrong, so we count the winner again from the match score.
- **maps** (is_total == "False") - every map separately. We drop maps without score and technical losses: real map must have winner with 13 or more rounds (pmax() >= 13).

### 5. Table of players

Original table has 10 columns for players (team1_player1 ... team2_player5) in one row. With pivot_longer() and regex in names_pattern we make the table where **one row = one player on one map**. After this:

- we drop rows without player name or without ADR
- we add columns: team, opponent, rounds_won, rounds_lost, win (ifelse())
- we take nickname and country from the name string like r1nkle (Artem Moroz), UA (sub(), grepl(), substr(), trimws())

### 6. Table of team maps

With group_by() and summarise() we make the table where **one row = one team on one map**: number of players, mean ADR, SD of ADR, mean KAST and win. Then we add adr_cv (SD / mean * 100), round_diff and full_team (team has all 5 players). By left_join() we take the mean ADR of the opponent and count adr_diff. Column both_full shows that both teams have 5 players, we use only such maps in the ideas about ADR, because with missing player the mean and SD are not fair.

### 7. Map numbers and BO3 checks

For every match we count the number of the map and amount of maps (row_number(), n()), find the winner of the first and the second map and join it to matches (left_join()). Then we make the flags maps_complete, order_ok and bo3_ok. They help to keep only normal BO3 matches, where all maps are in the data and the order is correct. It is used in the idea about comebacks.
