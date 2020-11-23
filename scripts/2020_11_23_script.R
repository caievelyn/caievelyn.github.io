# Post Election Model Evaluation and Reflection

# Read in libraries
library(tidyverse)
library(usmap)
library(patchwork)

# Read in data
popvote_2020_df <- read_csv("data/popvote_bystate_1948-2020.csv")
final_pred <- read_rds("data/final_pred.rds")

# Examine patterns: Difference in Biden vote share
full_df <- popvote_2020_df %>%
  filter(year == 2020) %>%
  left_join(final_pred, by = "state") %>%
  filter(state != "District of Columbia") %>%
  mutate(D_pv2p = 100 * D_pv2p,
         diff = D_pv2p - pred.fit)

# Create map theme
ec_map_theme <- theme_minimal() +
  theme(legend.position = "right",
        panel.grid = element_blank(),
        axis.text.x = element_blank(),
        axis.text.y = element_blank(),
        axis.title.x = element_blank(),
        axis.title.y = element_blank(),
        legend.text = element_text(size = 12),
        legend.title = element_text(size = 12),
        plot.title = element_text(size = 18),
        plot.subtitle = element_text(size = 14))

# Plot differences
plot_usmap(data = full_df, regions = "state", values = "diff") +
  labs(title = "Difference between actual and predicted state vote share",
       subtitle = "Systematic over-prediction for Biden's 2-party vote share") +
  # Insert gradient
  scale_fill_gradient2(
    high = "royalblue1",
    low = "red1",
    name = "Difference",
    # Insert breaks
    breaks = c(-14,-7,0),
    limits = c(-15, 0))+
  ec_map_theme +
  theme(legend.position = "bottom")

# Save graphic
ggsave("eval_diff.png", height = 6, width = 12)

# How many did I get wrong?
full_df %>%
  mutate(acc = case_when(pred.fit > 50 & D_pv2p < 50 ~ "Wrong",
                         TRUE ~ "Right")) %>%
  ggplot(aes(state = state, fill = acc)) +
    geom_statebins() +
    theme_statebins() +
  scale_fill_manual(breaks = c("Right", "Wrong"),
                    values = c("chartreuse3","brown2"),
                    name = "Accuracy") +
  labs(title = "Accuracy of Predictions",
       subtitle = "10 states were mispredicted, representing 119 electoral votes")

ggsave("eval_acc.png", height = 5, width = 8)

a <- final_pred %>%
  group_by(state) %>%
  mutate(lower = pred.fit - 1.96*pred.se.fit,
         higher = pred.fit + 1.96*pred.se.fit) %>%
  mutate(winner = case_when(lower > 50 ~ "Most likely Biden",
                            higher < 50 ~ "Most likely Trump",
                            TRUE ~ "Confidence Interval indicates toss-up")) %>%
  group_by(winner) %>%
  mutate(total_ecvote = sum(ecvotes)) %>%
  ggplot(aes(state = state, fill = winner)) +
  geom_statebins() +
  theme_statebins() +
  labs(title = "95% Confidence interval for prediction",
       subtitle = "42 EV Trump and 371 EV Biden, others toss-up",
       fill = "") +
  scale_fill_manual(values=c("steelblue3", "indianred2", "plum3"),
                    breaks = c("Most likely Biden", "Most likely Trump", "Confidence Interval indicates toss-up")) +
  theme(plot.title = element_text(size = 12),
        plot.subtitle = element_text(size = 8),
        legend.position = "none")


b <- final_pred %>%
  group_by(state) %>%
  mutate(lower = pred.fit - 1.96*pred.se.fit,
         higher = pred.fit + 1.96*pred.se.fit) %>%
  mutate(winner = case_when(lower > 50 ~ "Hypothetical Biden",
                            higher < 50 ~ "Hypothetical Trump",
                            TRUE ~ "Hypothetical Trump")) %>%
  group_by(winner) %>%
  mutate(total_ecvote = sum(ecvotes)) %>%
  ggplot(aes(state = state, fill = winner)) +
  geom_statebins() +
  theme_statebins() +
  labs(title = "Hypothetical Scenario if all toss-up states were Trump",
       subtitle = "167 EV Trump and 371 EV Biden",
       fill = "") +
  scale_fill_manual(values=c("steelblue3", "indianred2"),
                    breaks = c("Hypothetical Biden", "Hypothetical Trump")) +
  theme(plot.title = element_text(size = 12),
        plot.subtitle = element_text(size = 8),
        legend.position = "none")

a + b

ggsave("eval_hypothetical.png", width = 10, height = 4)

# Calculate RMSE
full_df %>%
  mutate(sq_diff = diff^2,
         sqRMSE = sum(sq_diff) / 50,
         RMSE = sqrt(sqRMSE)) %>% View()

swingstates <- c("Arizona", "Wisconsin", "Minnesota", "Nevada", "Michigan", "New Hampshire",
                 "Ohio", "Pennsylvania", "North Carolina", "Florida", "Iowa", "Texas",
                 "Georgia")

swing_rmse <- full_df %>%
  filter(!state %in% swingstates) %>%
  mutate(sq_diff = diff^2,
         sqRMSE = sum(sq_diff) / 50,
         RMSE = sqrt(sqRMSE))

## Test hypotheses

# 1. Poll mistake

# Read data
historical_df <- read_rds("data/full_df.rds") %>% ungroup()
polls_2020_df <- read_csv("data/presidential_poll_averages_2020.csv")

# 2020 econ data
econ_2020 <- data.frame(RDI_growth = -0.040720404,
                        incumbent = TRUE,
                        incumbent_party = TRUE)

# Create 2020 data
data_2020_nonswing <- polls_2020_df %>%
  mutate(modeldate = mdy(modeldate)) %>%
  top_n(1, modeldate) %>%
  filter(!candidate_name %in% c("Convention Bounce for Joseph R. Biden Jr.", "Convention Bounce for Donald Trump", "Donald Trump")) %>%
  group_by(state) %>%
  mutate(total = sum(pct_trend_adjusted)) %>%
  ungroup() %>%
  mutate(poll_2party = 100 * pct_trend_adjusted / total) %>%
  filter(candidate_name== "Joseph R. Biden Jr.") %>%
  full_join(econ_2020, by = character()) %>%
  filter(!state %in% swingstates,
         !state %in% c("NE-2", "NE-1", "ME-2", "ME-1", "District of Columbia", "National")) %>%
  arrange(state)

data_2020_swing <- polls_2020_df %>%
  mutate(modeldate = mdy(modeldate)) %>%
  top_n(1, modeldate) %>%
  filter(!candidate_name %in% c("Convention Bounce for Joseph R. Biden Jr.", "Convention Bounce for Donald Trump", "Donald Trump")) %>%
  group_by(state) %>%
  mutate(total = sum(pct_trend_adjusted)) %>%
  ungroup() %>%
  mutate(poll_2party = 100 * pct_trend_adjusted / total) %>%
  filter(candidate_name== "Joseph R. Biden Jr.") %>%
  full_join(econ_2020, by = character()) %>%
  filter(state %in% swingstates,
         !state %in% c("NE-2", "NE-1", "ME-2", "ME-1", "District of Columbia", "National")) %>%
  arrange(state)

nonswing_statenames <- data_2020_nonswing %>%
  select(state) %>%
  filter(state != "National")

# Fit on past data
swing <- historical_df %>% filter(state %in% swingstates)
swing_mod <- lm(data = swing, formula = D_pv2p ~ poll_2party + state + incumbent + RDI_growth)
pred_2020_swing <- data.frame(pred = predict(swing_mod, newdata = data_2020_swing, se.fit = TRUE),
                              statename = swingstates)
nonswing <- historical_df %>% filter(!state %in% swingstates)
nonswing_mod <- lm(data = nonswing, formula = D_pv2p ~ poll_2party + RDI_growth + incumbent + RDI_growth:incumbent + incumbent_party)
pred_2020_nonswing <- data.frame(pred = predict(nonswing_mod, newdata = data_2020_nonswing, se.fit = TRUE),
                              statename = nonswing_statenames)

new_data_2020_nonswing <- polls_2020_df %>%
  mutate(modeldate = mdy(modeldate)) %>%
  filter(modeldate > "2020-09-30",
         !candidate_name %in% c("Convention Bounce for Joseph R. Biden Jr.", "Convention Bounce for Donald Trump", "Donald Trump")) %>%
  group_by(state) %>%
  mutate(poll_2party = mean(pct_trend_adjusted)) %>%
  ungroup() %>%
  select(-cycle,-pct_estimate, -modeldate, -pct_trend_adjusted) %>%
  unique() %>%
  full_join(econ_2020, by = character()) %>%
  filter(!state %in% swingstates,
         !state %in% c("NE-2", "NE-1", "ME-2", "ME-1", "District of Columbia", "National")) %>%
  arrange(state)

# Evaluate and predict
pred_2020_core <- data.frame(pred = predict(nonswing_mod, newdata = new_data_2020_nonswing, se.fit = TRUE),
                              statename = nonswing_statenames)
# Take RMSE
pred_2020_core %>%
  left_join(popvote_2020_df, by = "state") %>%
  filter(year == 2020) %>%
  mutate(D_pv2p = 100 * D_pv2p,
         diff = D_pv2p - pred.fit,
         sq_diff = diff^2,
         sqRMSE = sum(sq_diff) / 50,
         RMSE = sqrt(sqRMSE)) %>%
  mutate(acc = case_when(pred.fit > 50 & D_pv2p < 50 ~ "Wrong",
                         TRUE ~ "Right")) %>% View()

new_data_2020_swing <- polls_2020_df %>%
  mutate(modeldate = mdy(modeldate)) %>%
  filter(modeldate > "2020-09-30",
         !candidate_name %in% c("Convention Bounce for Joseph R. Biden Jr.", "Convention Bounce for Donald Trump", "Donald Trump")) %>%
  group_by(state) %>%
  mutate(poll_2party = mean(pct_trend_adjusted)) %>%
  ungroup() %>%
  select(-cycle,-pct_estimate, -modeldate, -pct_trend_adjusted) %>%
  unique() %>%
  full_join(econ_2020, by = character()) %>%
  filter(state %in% swingstates,
         !state %in% c("NE-2", "NE-1", "ME-2", "ME-1", "District of Columbia", "National")) %>%
  arrange(state)

# Evaluate and predict
pred_2020_swing <- data.frame(pred = predict(swing_mod, newdata = new_data_2020_swing, se.fit = TRUE),
                             state = swingstates)
# Take RMSE
pred_2020_swing %>%
  left_join(popvote_2020_df, by = "state") %>%
  filter(year == 2020) %>%
  mutate(D_pv2p = 100 * D_pv2p,
         diff = D_pv2p - pred.fit,
         sq_diff = diff^2,
         sqRMSE = sum(sq_diff) / 50,
         RMSE = sqrt(sqRMSE)) %>%
  mutate(acc = case_when(pred.fit > 50 & D_pv2p < 50 ~ "Wrong",
                         TRUE ~ "Right")) %>% View()




# 2. Interaction term

# Create new core states model + prediction
core_mod <- lm(data = historical_df, formula = D_pv2p ~ poll_2party + RDI_growth + incumbent)
pred_2020_swing <- data.frame(pred = predict(core_mod, newdata = new_data_2020_nonswing, se.fit = TRUE),
                              statename = nonswing_statenames)
# Take RMSE
pred_2020_swing %>%
  left_join(popvote_2020_df, by = "state") %>%
  filter(year == 2020) %>%
  mutate(D_pv2p = 100 * D_pv2p,
         diff = D_pv2p - pred.fit,
         sq_diff = diff^2,
         sqRMSE = sum(sq_diff) / 50,
         RMSE = sqrt(sqRMSE)) %>%
  mutate(acc = case_when(pred.fit > 50 & D_pv2p < 50 ~ "Wrong",
                         TRUE ~ "Right")) %>% View()

# 3. Incumbency party term
swing_mod <- lm(data = historical_df, formula = D_pv2p ~ poll_2party + RDI_growth + incumbent + incumbent_party)
pred_2020_swing <- data.frame(pred = predict(swing_mod, newdata = new_data_2020_swing, se.fit = TRUE),
                              state = swingstates)
# Take RMSE
pred_2020_swing %>%
  left_join(popvote_2020_df, by = "state") %>%
  filter(year == 2020) %>%
  mutate(D_pv2p = 100 * D_pv2p,
         diff = D_pv2p - pred.fit,
         sq_diff = diff^2,
         sqRMSE = sum(sq_diff) / 50,
         RMSE = sqrt(sqRMSE)) %>%
  mutate(acc = case_when(pred.fit > 50 & D_pv2p < 50 ~ "Wrong",
                         TRUE ~ "Right")) %>% View()

## Hypothetical new map
core_mod <- lm(data = historical_df, formula = D_pv2p ~ poll_2party + RDI_growth + incumbent + incumbent_party)
pred_2020_core <- data.frame(pred = predict(core_mod, newdata = new_data_2020_nonswing, se.fit = TRUE),
                             state = nonswing_statenames)
swing_mod <- lm(data = historical_df, formula = D_pv2p ~ poll_2party + RDI_growth + incumbent + incumbent_party)
pred_2020_swing <- data.frame(pred = predict(swing_mod, newdata = new_data_2020_swing, se.fit = TRUE),
                             state = swingstates)

# Electoral college votes
ecvote_df <- ecvote_df %>%
  select(X1, `2020`) %>%
  rename("state" = "X1",
         "ecvotes" = `2020`) %>%
  unique() %>%
  drop_na()

final_pred <- rbind(pred_2020_swing, pred_2020_core) %>%
  mutate(winner = case_when(pred.fit > 50 ~ "Biden",
                            TRUE ~ "Trump")) %>%
  left_join(ecvote_df, by = "state") %>%
  drop_na() %>%
  group_by(winner) %>%
  mutate(total_ecvote = sum(ecvotes))

plot_usmap(data = final_pred, regions = "states", value = "winner") +
  labs(title = "Altered Election Prediction",
       subtitle = "245 votes Trump and 293 votes Biden",
       fill = "") +
  scale_fill_manual(values=c("steelblue3", "indianred2"),
                    breaks = c("Biden", "Trump")) +
  theme(plot.title = element_text(size = 12),
        plot.subtitle = element_text(size = 8),
        legend.position = "none")

ggsave("final_map.png", height = 3, width = 6)

final_pred %>%
  left_join(popvote_2020_df, by = "state") %>%
  filter(year == 2020) %>%
  mutate(D_pv2p = 100 * D_pv2p,
         diff = D_pv2p - pred.fit,
         sq_diff = diff^2,
         sqRMSE = sum(sq_diff) / 50,
         RMSE = sqrt(sqRMSE)) %>%
  mutate(acc = case_when(pred.fit > 50 & D_pv2p < 50 ~ "Wrong",
                         TRUE ~ "Right")) %>% View()






