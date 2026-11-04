## CLEANING CODE ----
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
matches <- matches[order(matches$match_id, !is.na(matches$map_name),]
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
##
## IDEA 1 ----
#Idea 1 
anomaly_maps <-  team_maps |> 
  filter(both_full, win == T) |> 
  mutate(anomaly = adr_diff<0)
mean(anomaly_maps$anomaly, na.rm = T)
anomaly_maps[which.min(anomaly_maps$adr_diff), ] 
nrow(anomaly_maps)

#The jitter plot
ggplot(anomaly_maps, aes(
  x = adr_diff, y =round_diff, color = anomaly
)) +geom_jitter(alpha = 0.1, size = 2, shape = 'square') +
  geom_vline(xintercept = 0) + labs(
    title = 'Winner had higher ADR", "Winner had lower ADR (anomaly)',
    color = NULL,
    x = 'ADR difference',
    y = 'ROUND difference',
  ) + theme_minimal() + theme(
    legend.position = 'none'
  )

#lets divide the difference in rounds into different values 
#to create proper histogram
by_diff <- anomaly_maps |> mutate(
  diff_group = ifelse(round_diff >=8, '8+', as.character(round_diff))
) |> group_by(diff_group) |> 
  summarize(maps_n = n(), anomaly_share = mean(anomaly)*100)
by_diff$diff_group <- factor(by_diff$diff_group, levels = c("2", "3", "4", "5", "6", "7", "8+"))
by_diff |> ggplot(aes(
  x = diff_group, y = anomaly_share
)) + geom_col(fill = '#50C878', width = 0.7) +
  geom_text(aes(label = paste(round(anomaly_share, 2), "%")),
            vjust = -0.3, size = 3.8, hjust = +0.4) + labs(
              x = 'Round difference',
              y = 'Anomaly share',
              caption = '8964 maps'
            ) + theme_minimal() + theme(
              axis.title = element_text(face = 'bold'),
              plot.caption = element_text(face = 'italic')
            )
#AI suggested adding by diff df to show the amount of maps with different round diffs
#I have created the plot


## IDEA 2 ----
maps <- maps |> mutate(
  quarter = paste0(format(datetime, "%Y"), "Q",(as.numeric(format(datetime, "%m")) - 1) %/% 3 + 1)
  )
#AI suggested the formula for quarters
maps$quarter
mappool <- maps |> 
  filter(!is.na(map_name)) |> count(quarter,map_name) |> 
  complete(quarter, map_name, fill = list(n = 0)) |> 
  group_by(quarter) |> mutate(share = n / sum(n, na.rm = T) * 100) |> 
  ungroup()
#AI suggested complete function to fill each quarter (there are maps which were not available for a certain period of time)
# I have revised the work this function does and implemented it

#Tile plot
mappool |> ggplot(aes(
  x = quarter, y = map_name, fill = share
)) + geom_tile(color = 'white', linewidth = 0.2) + 
  geom_text(aes(label = ifelse(share != 0, round(share, 0), '')), size = 3) + 
  scale_fill_gradient(low = '#f9f0ec', high = '#50C878') + theme_minimal() + labs(title = "CS2 map pool by quarter", x = NULL, y = NULL)
