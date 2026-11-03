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

### Impact of individual performance (ADR / KAST) on the game result
**Question:** Do players with high ADR really win the maps?
>For those who doesn't know: ADR is how much damage a player does in one round on average, so team ADR is just the average of 5 players. We will count it for both teams on every map and compare it with the round difference (`score1_game - score2_game`), to see does the team with bigger ADR really win by more rounds. Also we look for "anomaly" maps, where the winner had lower ADR than the opponent.**

**How we will realize that:**
- count mean ADR of each team on the map (average of 5 players)
- count round difference: `score1_game - score2_game`
- build linear regression: round difference depends on the difference of mean ADR of two teams
- look at "anomaly" maps, where the winner had lower ADR than the opponent

