library(here)
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
ggplot(balance, aes(x = adr_cv, fill = factor(win))) +
geom_density(alpha = 0.5) +
scale_fill_manual(values = c("0" = "#d65a2a", "1" = "#2a78d6"),
labels = c("Lost the map", "Won the map"),name = NULL) +
labs(title = "Solo carry or team balance?",
subtitle = "CV of ADR between 5 players of the team (higher = more uneven)",
x = "CV of team ADR, %", y = "Density", caption = paste(nrow(balance) / 2, "maps")) +theme_minimal(base_size = 13) +
theme(legend.position = "top")

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
ggplot(by_diff_cv, aes(x = diff_group, y = even_share)) +
geom_col(fill = "#2a78d6", width = 0.7) +
geom_hline(yintercept = 50, linetype = "dashed") +
geom_text(aes(label = paste(round(even_share, 1), "%")), vjust = -0.3, size = 5) +
ylim(0, 70) +
labs(title = "Does the winner play more evenly?",
subtitle = "Share of maps where winner had lower ADR CV than opponent",
x = "Round diff (+)", y = "Share of maps, %",
caption = paste(nrow(paired), "maps")) +
theme_minimal(base_size = 13)

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
##AI assisted with Recommending linear model residuals (resid(lm())) and 1 SD thresholds to classify player archetypes without k-means, also
# suggesting arrange() and head(10) logic to isolate top positive/negative outlier players and 
#advising to place color mapping inside geom_point() instead of global aes() to keep a single geom_smooth() regression line.
#images for idea 4
ggsave(here('Output', 'Idea4.png'), width = 10, height = 6, dpi = 300)
ggsave(here('Output', 'Idea4.1.png'), width = 10, height = 6, dpi = 300)

#images for idea 6
ggsave(here('Output', 'Idea6.png'), width = 10, height = 6, dpi = 300)
ggsave(here('Output', 'Idea6.1.png'), width = 10, height = 6, dpi = 300)
