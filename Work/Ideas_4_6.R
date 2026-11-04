## CLEANING CODE ----
library(tidyverse)
library(ggthemes)
library(here)
library(ggplot2)

# Loading datasets
cs <- read.csv(here("data", "cs2_all_tiers_games.csv"), encoding = "UTF-8", na.strings = c("", "NA"))
t1 <- read.csv(here("data", "cs2_tier1_games.csv"), na.strings = c("", "NA"))
t2 <- read.csv(here("data", "cs2_tier2_games.csv"), na.strings = c("", "NA"))

# Tiers of tournaments
tier1_list <- unique(t1$tournament)
tier2_list <- unique(t2$tournament)
cs$tier <- ifelse(cs$tournament %in% tier1_list, "tier1",
                  ifelse(cs$tournament %in% tier2_list, "tier2", "tier3"))
table(cs$tier)

# filters

# deleting NA team names
cs <- cs[!is.na(cs$team1) & !is.na(cs$team2), ]

# deleting nation teams
cs <- cs[!grepl("Esports Nations Cup", cs$tournament), ]

# deleting russian tournaments
ru_pattern <- "BetBoom|Buster|Games Future|Игры Будущего|России|студенческая лига|Сбера|WINLINE|PARI, PLEASE|Open киберспортивные|VK GG|LanDaLan|CIS|Evelone|Rofl|Streamers League|FISSURE"
ru <- grepl(ru_pattern, cs$tournament, ignore.case = TRUE)
length(unique(cs$tournament[ru]))   
sum(ru)                            
cs <- cs[!ru, ]
# AI helped searching for pattern names

# non-professional tournaments
amateur_pattern <- "Showmatch|Impact League|Шоу-матч|Friday Fight|Media Eleague|Star Series|^RIVALS$|IESF"
cs <- cs[!grepl(amateur_pattern, cs$tournament), ]
# AI helped searching for pattern names
# all-star showmatches (usually played before the finals of large tournaments do not include pro teams)
allstar <- c("Team Germany", "Team USA", "Team Denmark", "Team Poland", "Team IEM",
             "BLAST Dream Team", "Team tabseN", "Team rigoN", "Team captainMo",
             "Stream Team", "Team NA", "Team DD")
cs <- cs[!(cs$team1 %in% allstar | cs$team2 %in% allstar), ]
# AI helped searching for pattern names

# Different spelling of a team
fix_names <- c(
  "BETBOOM TEAM"    = "BetBoom Team",
  "magic"           = "Magic",
  "Team Legacy"     = "Legacy",
  "PARTIZAN"        = "Partizan Esports",
  "Shoke Team"      = "Team Shoke",
  "Team StRoGo"     = "Strogo Team",
  "WICKED"          = "Wicked Gaming",
  "Nordic Partners" = "Nordic Partners Gaming",
  "AM"              = "AM Gaming"
)
# AI helped searching for pattern names
fix_team <- function(x) {
  ifelse(x %in% names(fix_names), fix_names[x], x)
}
cs$team1 <- fix_team(cs$team1)
cs$team2 <- fix_team(cs$team2)

# changing date to the datetime
# starting from October (first pro match in CS2)
cs$datetime <- as.POSIXct(cs$datetime, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
cs <- cs[cs$datetime >= as.POSIXct("2023-10-01", tz = "UTC"), ]
#AI helped to find the R function for datetime
nrow(cs)
#DIVISION into matches and maps
matches <- cs[cs$is_total == "True",]
maps <- cs[cs$is_total == "False",]
nrow(matches)
nrow(maps)

#Deduplication of rows
#We sort them by id first to group those with similar id,
#then we sort by map_name so that without map name would be first
#and will be dleted by !duplicate
#only those without map name are true summaries
matches <- matches[order(matches$match_id, !is.na(matches$map_name)),]
matches <- matches[!duplicated(matches$match_id),]
nrow(matches)

mean(matches$team1_win)
#Team1 win has only 10% the result is flawed, worth recalculating
matches$team1_won <- ifelse(matches$score1_match > matches$score2_match, 1, 0)
mean(matches$team1_won)

sum(is.na(maps$score1_game) | is.na(maps$score2_game))
sum(!pmax(maps$score1_game, maps$score2_game) >= 13, na.rm = T)
#There are missing scores or technical wins (less than 13 rounds were played)
#Let`s delete them
maps <- maps[!is.na(maps$score1_game) & !is.na(maps$score2_game) & 
               pmax(maps$score1_game, maps$score2_game) >= 13, ]

#PIVOT LONGER: players (one row - one player on a map)
wide <- maps
#lets find columns where we can substract certain parameters from (AI suggested the pattern)
name_cols <- grep("^team\\d_player\\d$", names(wide))
#Adding name because in future we will substract certain parameters from here
#Leaving only name
names(wide)[name_cols] <- paste0(names(wide)[name_cols],'_name')
names(wide)[name_cols]

wide <- wide |> select(
  match_id, game_id, tournament, tier, datetime, map_name, team1,
  team2, score1_game, score2_game,
  starts_with('team1_player'), starts_with('team2_player')
)
glimpse(wide)
#Converting to players
players <- wide |> pivot_longer(
  cols = starts_with(c("team1_player", 'team2_player')),
  names_to = c('side' , 'slot', '.value'),
  names_pattern = 'team(.)_player(.)_(.*)'
)

players <- players |> filter(!is.na(name), !is.na(adr))
#AI suggested the pattern with () and .value feature
# + corrected syntaxis


players <- players |> mutate(
  team = ifelse(side == '1', team1, team2),
  opponent = ifelse(side == '1', team2, team1),
  rounds_won = ifelse(side == '1', score1_game, score2_game),
  rounds_lost = ifelse(side == '1', score2_game, score1_game),
  win = ifelse(rounds_won > rounds_lost, 1, 0)
)

#we need to differentiate a nickname and a nationality based on patterns in a name column
players <- players |> mutate(
  nickname = trimws(sub("\\(.*|,.*", "", name)),
  country = ifelse(grepl(", [A-Z]{2}$", name),
                   substr(name, nchar(name) - 1, nchar(name)), NA))
#AI created the regex pattern and we broke column name into nickname and nationality
nrow(players)

#now maps is the table of all maps from each tournament
#one map one tournament one match one pair of a teams fighting
#For certain ideas we need a table which will have a grain 
#one team on a one map 

team_maps <- players |> group_by(
  match_id, game_id, tournament, tier, datetime, map_name,
  team, opponent
) |> summarise(
  n_players = n(),
  adr_mean = mean(adr),
  adr_sd = sd(adr),
  kast_ean = mean(kast),
  rounds_won = first(rounds_won),
  rounds_lost = first(rounds_lost),
  win = first(win)
) |> ungroup()
#AI assisted (syntaxis, column choice)
#we are adding full team check for further more fair evaluation of results
team_maps <- team_maps |> mutate(
  adr_cv = adr_sd / adr_mean * 100,
  round_diff = rounds_won - rounds_lost,
  full_team = (n_players == 5)
)
#We are creating a mirror table for opponents
opp <- team_maps |> 
  select(game_id, opponent = team, opp_adr_mean = adr_mean,
         opp_full_team = full_team)
sample(opp)
team_maps <- team_maps |> left_join(
  opp, by = c('game_id', 'opponent')
)
#Now we have one row - team and its opponent with their parameters
#So we can calculate diff per 

team_maps <- team_maps |> mutate(
  adr_diff = adr_mean - opp_adr_mean,
  both_full = full_team & opp_full_team)


# Numerating maps + its amount
# For 'comeback' evaluations we ought to number the maps first
# sort of: partition by map row_number

maps <- maps |> arrange(match_id, game_id) |> 
  group_by(match_id) |> mutate(
    map_no = row_number(),
    n_maps = n()
  ) |> ungroup()

#We need to see who won the map
maps <- maps |> 
  mutate(map_winner = ifelse(score1_game > score2_game, team1, team2))
maps$map_winner

map1 <- maps |> filter(map_no == 1) |> 
  select(match_id, n_maps, map1_winner = map_winner)
map2 <- maps |> filter(map_no == 2) |> 
  select(match_id, map2_winner = map_winner)
#AI assisted(column choice)
matches <- matches |> 
  left_join(map1, by = 'match_id') |> 
  left_join(map2, by = 'match_id')


#We need to validate that there are not 2 maps won in a row by one team 
#Because that is not a comeback
#We need to verify that it is a bo3
#And that map is complete (not a technical win)
#AI suggested what columns to look for
matches <- matches |> mutate(
  match_winner = ifelse(score1_match>score2_match, team1, team2),
  maps_complete = !is.na(n_maps) & n_maps == score1_match + score2_match,
  order_ok = !(n_maps == 3 & map1_winner == map2_winner),
  bo3_ok = maps_complete & order_ok & bestOf == 3 &
    pmax(score1_match, score2_match) == 2,
  map1_winner_won = map1_winner == match_winner)


nrow(matches)
nrow(maps)
nrow(players)
nrow(team_maps)

## Idea 4. Solo carry vs team balance
# only maps where both teams have 5 players, like in idea 1
# win is from team_maps, team1_win is not reliable
balance <- team_maps |> filter(both_full)

# cv instead of sd, winners have higher adr so their sd is bigger anyway
cor(balance$adr_sd, balance$adr_mean)
cor(balance$adr_cv, balance$adr_mean)

balance |> group_by(win) |>summarise(maps = n(),
avg_adr = mean(adr_mean), sd_mean = mean(adr_sd), sd_median = median(adr_sd),
cv_mean = mean(adr_cv), cv_median = median(adr_cv))

balance |> group_by(tier, win) |> summarise(maps = n(), cv_mean = mean(adr_cv), .groups = "drop")

# the density plot
p4<-ggplot(balance, aes(x = adr_cv, fill = factor(win))) +
geom_density(alpha = 0.5) +
scale_fill_manual(values = c("0" = "#d65a2a", "1" = "#2a78d6"),
labels = c("Lost the map", "Won the map"),name = NULL) +
labs(title = "Solo carry or team balance?",
subtitle = "CV of ADR between 5 players of the team (higher = more uneven)",
x = "CV of team ADR, %", y = "Density", caption = paste(nrow(balance) / 2, "maps")) +theme_minimal(base_size = 13) +
theme(legend.position = "top")

ggsave(here('Output', 'Idea4.png'), plot = p4, width = 10, height = 6, dpi = 300)
##AI suggested the paste() method for combining values into a string. 

# winner vs loser of the same map
winners <- balance |> filter(win == 1) |> select(game_id, round_diff, win_cv = adr_cv)
losers <- balance |> filter(win == 0) |> select(game_id, lose_cv = adr_cv)
paired <- inner_join(winners, losers, by = "game_id") |>
mutate(winner_more_even = win_cv < lose_cv)
nrow(paired)
mean(paired$winner_more_even)
?t.test
t.test(paired$win_cv, paired$lose_cv, paired = TRUE)

##AI suggested the t.test approach to measure the whether the difference between means
#is statistically significant.

# same round diff groups as in idea 1
by_diff_cv <- paired |>
mutate(diff_group = ifelse(round_diff >= 8, "8+", as.character(round_diff)))|>group_by(diff_group) |>
summarise(maps = n(), even_share = mean(winner_more_even) * 100)
by_diff_cv$diff_group <- factor(by_diff_cv$diff_group, levels = c("2", "3", "4", "5", "6", "7", "8+"))
by_diff_cv
# the col plot
p4_1<-ggplot(by_diff_cv, aes(x = diff_group, y = even_share)) +
geom_col(fill = "#2a78d6", width = 0.7) +
geom_hline(yintercept = 50, linetype = "dashed") +
geom_text(aes(label = paste(round(even_share, 1), "%")), vjust = -0.3, size = 5) +
ylim(0, 70) +
labs(title = "Does the winner play more evenly?",
subtitle = "Share of maps where winner had lower ADR CV than opponent",
x = "Round diff (+)", y = "Share of maps, %",
caption = paste(nrow(paired), "maps")) +
theme_minimal(base_size = 13)
ggsave(here('Output', 'Idea4.1.png'), plot = p4_1, width = 10, height = 6, dpi = 300)

##AI suggested to establish limitations for even_share by ylim(0,70) and also 
##suggested adding a dashed baseline at y = 50% (geom_hline) 
## to visually benchmark the results against a neutral 50/50 chance.

## IDEA 6. 
#ADR (aggression) vs KAST (stability)
# players is already one row - one player on a map
cor(players$adr, players$kast, use = "complete.obs")
cor.test(players$adr, players$kast)   # 100k rows, p-value is useless, look at r

##AI suggested using cor.test() to analyze the ADR vs KAST correlation 
## and recommended focusing on the correlation coefficient (r) instead of the p-value 
## due to the large sample size (100k+ rows).

# the scatter plot
# alpha 0.1, with 0.3 it is one blob
ggplot(players, aes(x = adr, y = kast)) +geom_point(alpha = 0.1, size = 1, color = "#2a78d6") +
  geom_smooth(method = "lm", color = "#d65a2a") +
  labs(title = "ADR (aggression) vs KAST (stability)",
       subtitle = "One point - one player on one map",
       x = "ADR", y = "KAST, %",
       caption = paste(nrow(players), "player-maps")) +
  theme_minimal(base_size = 13)
ggsave(here('Output', 'Idea6.png'), width = 10, height = 6, dpi = 300)
##AI suggested implementing geom_smooth(method = "lm") to display 
## the linear regression trend line and visualize the overall direction of the ADR vs KAST relationship 

# is r the same in every tier and for winners and losers
players |> group_by(tier) |> summarise(rows = n(), r = cor(adr, kast))
players |> group_by(win) |> summarise(rows = n(), r = cor(adr, kast))

# one row - one player, group by id (nickname is not unique), only 30+ maps
regulars <- players |>group_by(id) |> summarise(nickname = first(nickname), n_maps = n(),
adr_mean = mean(adr),kast_mean = mean(kast)) |>filter(n_maps >= 30)
nrow(regulars)
cor(regulars$adr_mean, regulars$kast_mean)

##AI suggested using the n() function inside summarise() to count 
## the total number of maps played per player ID, enabling filtration for regular players (30+ maps)

# types without kmeans: distance from the line kast ~ adr, more than 1 sd = special type
regulars$kast_resid <- resid(lm(kast_mean ~ adr_mean, data = regulars))
sd_resid <- sd(regulars$kast_resid)
regulars <- regulars |>
  mutate(type = ifelse(kast_resid > sd_resid, "high KAST for its ADR",
                       ifelse(kast_resid < -sd_resid, "low KAST for its ADR", "typical")))
table(regulars$type)

# top 10 with the highest and the lowest KAST for their ADR
regulars |> arrange(desc(kast_resid)) |> head(10) |> select(nickname, n_maps, adr_mean, kast_mean, kast_resid)
regulars |> arrange(kast_resid) |> head(10) |> select(nickname, n_maps, adr_mean, kast_mean, kast_resid)

# the scatter plot of players
# color only in geom_point, otherwise smooth draws 3 lines
ggplot(regulars, aes(x = adr_mean, y = kast_mean)) +
  geom_point(aes(color = type), alpha = 0.7, size = 2) +
  geom_smooth(method = "lm", color = "black", se = FALSE) +
  scale_color_manual(values = c("high KAST for its ADR" = "#109856","typical" = "grey70",
"low KAST for its ADR" = "#d65a2a"), name = NULL) +
  labs(title = "Player types: ADR (aggression) vs KAST (stability)",
       subtitle = "Average per player, only players with 30+ maps",
       x = "Mean ADR", y = "Mean KAST, %",
       caption = paste(nrow(regulars), "players")) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "top")
ggsave(here('Output', 'Idea6.1.png'), width = 10, height = 6, dpi = 300)
##AI assisted with Recommending linear model residuals (resid(lm())) and 1 SD thresholds to classify player archetypes without k-means, also
# suggesting arrange() and head(10) logic to isolate top positive/negative outlier players and 
#advising to place color mapping inside geom_point() instead of global aes() to keep a single geom_smooth() regression line.

