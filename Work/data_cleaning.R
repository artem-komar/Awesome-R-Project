library(tidyverse)
install.packages("ggthemes")
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
