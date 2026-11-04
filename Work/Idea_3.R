# ===== DATA CLEANING =====
library(tidyverse)
library(ggthemes)
library(here)

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
ru_pattern <- "Moscow|BetBoom|Buster|Games Future|Игры Будущего|России|студенческая лига|Сбера|WINLINE|PARI, PLEASE|Open киберспортивные|VK GG|LanDaLan|CIS|Evelone|Rofl|Streamers League|FISSURE"
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
matches <- matches[order(matches$match_id, !is.na(matches$map_name)), ]
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
#AI suggested the pattern with () and .value feature
# + corrected syntaxis
players <- players |> filter(!is.na(name), !is.na(adr))

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

# ===== IDEA 3: COMEBACK ANALYSIS =====

# bo3_ok checks whether the match meets our conditions. We also remove the matches, where the winner of the first map is unknown
bo3 <- matches |> filter(bo3_ok == TRUE, !is.na(map1_winner_won))

# Number of bo3 matches 
nrow(bo3)

# Number of matches by tier
table(bo3$tier)

# Check whether the winner of the first map won the match: TRUE - the winners of the first map won the match; False - other team won
table(bo3$map1_winner_won)

# Calculating the overall first map win rate and comeback rate
overall_results <- bo3 |> summarise(
  total_matches = n(),
  first_map_wins = sum(map1_winner_won),
  comebacks = sum(!map1_winner_won),
  first_map_win_rate = round(mean(map1_winner_won)*100, 2),
  comeback_rate = round(mean(!map1_winner_won)*100, 2)
)
overall_results

# Now we compare the values by tier
tier_results <- bo3 |> group_by(tier) |> summarise(
  total_matches = n(),
  first_map_wins = sum(map1_winner_won),
  comebacks = sum(!map1_winner_won),
  first_map_win_rate = round(mean(map1_winner_won)*100, 2),
  comeback_rate = round(mean(!map1_winner_won)*100, 2)
) |> ungroup()
tier_results
 
# Now we check the final scores of the matches. It can either be 2:1 or 1:2
comeback_scores <- bo3 |> filter(map1_winner_won == FALSE) |>
  count(score1_match, score2_match)
comeback_scores
  
# Then we need to reshape our data with pivot_longer so that we can use it for building a column chart  
longer_data <- overall_results |> select(first_map_win_rate, comeback_rate) |>
  pivot_longer(
    cols = everything(),
    names_to = "result",
    values_to = "percentage"
  )
longer_data  

# Now we compare the comeback rates between the tiers. We use geom_col() because we have have already calculated the needed data   
# AI assisted with the visual aspects of the plot: it suggested to use such functions as scale_x_discrete, coord_cartesian, scale_fill_manual and helped with adjusting the plot's appearence(labs and theme)
p1 <- ggplot(tier_results, aes(x = tier, y = comeback_rate, fill = tier)) +
  geom_col(width = 0.65) +
  geom_text(
    aes(label = paste0(comeback_rate, "%")),
    vjust = -0.5,
    size = 5
  ) + scale_fill_manual(
    values = c(
      tier1 = "#d65a2a",
      tier2 = "#109856",
      tier3 = "#2a78d6")
    )+
    scale_x_discrete(
    labels = c(
      tier1 = "Tier 1",
      tier2 = "Tier 2",
      tier3 = "Tier 3"
    )
  ) +
  coord_cartesian(ylim = c(0, 27)) +
  labs(
    title = "Comeback Rate by Tournament Tier",
    subtitle = "Share of BO3 matches won after losing the first map",
    x = "Tournament Tier",
    y = "Comeback Rate (%)",
    caption = paste(nrow(bo3), "BO3 matches")
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold"),
    legend.position = "none",
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank()
  )
p1

# We change the names of the categories to make the plot more readable
# Ai assisted to change the names of the columns
longer_data$result <- factor(longer_data$result, 
levels = c("first_map_win_rate", "comeback_rate"), 
labels = c("First map winner won", "Comeback happened")
)

# Now we make a plot with a comparison of first map win rate and a comeback rate
# AI same as for the previous plot assisted with all the visual functions and aspects: scale_fill_manual, coord_cartesian, and helped with adjusting the plot's appearance(labs and theme)
p2 <- ggplot(longer_data, aes(x=result, y=percentage, fill=result)) +
  geom_col(width=0.65) +
  geom_text(
    aes(label = paste0(percentage, "%")),
    vjust = -0.5,
    size = 5
  ) +
  scale_fill_manual(values = c("#2a78d6", "#d65a2a")) +
  coord_cartesian(ylim = c(0, 90)) +
  labs(
    title = "First Map Advantage vs Comeback Rate",
    subtitle = "Share of BO3 matches by final outcome",
    x = NULL,
    y = "Share of Matches (%)",
    caption = paste(nrow(bo3), "BO3 matches")
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold"),
    legend.position = "none",
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank()
  )
p2

# Saving the plots to the Output folder
ggsave(here('Output', 'Idea3.png'), p1, width = 10, height = 6, dpi = 300)
ggsave(here('Output', 'Idea3.1.png'), p2, width = 10, height = 6, dpi = 300)


