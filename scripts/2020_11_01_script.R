# Final Prediction script

# Load libraries
library(tidyverse)
library(patchwork)
library(skimr)
library(lubridate)
library(ggthemes)
library(geofacet)
library(tidymodels)
library(gt)
library(stargazer)
library(statebins)

# Read in data
approval_df <- read_csv("data/president_approval_polls.csv")
polls_2020_df <- read_csv("data/presidential_poll_averages_2020.csv")
economy_df <- read_csv("data/econ.csv")
popvote_df <- read_csv("data/popvote_1948-2016.csv")
ecvote_df <- read_csv("data/electoralcollegevotes_1948-2020.csv")

# Custom theme
ec_theme <- theme_minimal() +
  theme(legend.position = "right",
        axis.title = element_text(),
        legend.text = element_text(size = 12),
        legend.title = element_text(size = 12),
        plot.title = element_text(size = 18),
        plot.subtitle = element_text(size = 14))


# Find the unique levels of poll grades and filter only for B and above
approval_df$fte_grade %>% unique()
plot_1 <- approval_df %>%
  mutate(net_approval = yes - no,
         end_date = mdy(end_date)) %>%
  filter(fte_grade %in% c("B", "B+", "A/B", "A-", "A", "A+"),
         end_date > "2020-02-27") %>%
  group_by(end_date) %>%
  mutate(avg_net = mean(net_approval)) %>%
  select(end_date, avg_net) %>%
  ggplot(aes(x = end_date, y = avg_net, color= "red")) +
  geom_line() +
  ec_theme +
  theme(legend.position = "none") +
  ylab("Net Approval") +
  xlab(NULL)

plot_2 <- polls_2020_df %>%
  filter(candidate_name == "Donald Trump",
         state == "National") %>%
  mutate(modeldate = mdy(modeldate)) %>%
  group_by(modeldate) %>%
  mutate(poll = mean(pct_trend_adjusted)) %>%
  ggplot(aes(x = modeldate, y = poll, color= "red")) +
  geom_line() +
  ec_theme +
  theme(legend.position = "none") +
  xlab(NULL) +
  ylab("Poll Estimate")

plot_1 + labs(title = "National net approval ratings") + plot_2 + labs(title = "National poll estimates")

ggsave("approval_polls.png", width = 12, height = 4)

# Now geofacet by state
polls_2020_df %>%
  filter(candidate_name %in% c("Donald Trump", "Joseph R. Biden Jr.")) %>%
  mutate(modeldate = mdy(modeldate)) %>%
  group_by(modeldate, state, candidate_name) %>%
  mutate(poll = mean(pct_trend_adjusted)) %>%
  ungroup() %>%
  ggplot() +
  geom_line(aes(x = modeldate, y = poll, color = candidate_name)) +
  facet_geo(~state) +
  ec_theme +
  theme(legend.position = "none") +
  theme(axis.title.y = element_text(size=2.5)) +
  xlab(NULL) +
  ylab("Poll Estiamtes")

ggsave("pollavgstate.png", width = 10, height = 6)


# Econ plot
econ <- popvote_df %>%
  # Filter only for years that both datasets have no NA values for
  filter(incumbent_party == TRUE,
         year >= 1960) %>%
  select(year, winner, pv2p) %>%
  # Join both datasets by year and filter only for Q2 & Q3
  left_join(economy_df %>% filter(year >= 1960), by = "year") %>%
  filter(quarter == 3)

# Create plot of relationship between RDI growth and incumbent party's vote share
econ %>%
  ggplot(aes(x=GDP_growth_qt, y=pv2p,
             label=year)) +
  # Reduce the size of the year labels so they don't obscure the graph
  geom_text(size = 3) +
  # Add confidence intervals and linear regression
  geom_smooth(method="lm", formula = y ~ x, fill = "mistyrose1", color = "red") +
  geom_hline(yintercept=50, lty=2) +
  geom_vline(xintercept=0.01, lty=2) + # median
  xlab("Q3 RDI growth") +
  ylab("Incumbent party's vote share") +
  # Add custom theme
  ec_theme +
  labs(title = "Relationship between the Economy and Vote Share")

ggsave("gdp.png", width = 6, height = 2)



# Time for change model

# First read in various data sets
pv_state_df <- read_csv("data/popvote_bystate_1948-2016.csv")

# Join economic data by state historical data
temp_df <- read_csv("data/econ.csv") %>%
  filter(year >= 1968,
         quarter %in% c(2,3)) %>%
  select(-stock_open, -stock_close, -stock_volume, -unemployment, -inflation, -GDP, -RDI, -date) %>%
  right_join(pv_state_df, by = c("year")) %>%
  select(-total, -D, -R)

# Join with national level data to obtain incumbency values
temp2_df <- read_csv("data/popvote_1948-2016.csv") %>%
  filter(year >= 1968) %>%
  select(year, party, incumbent, incumbent_party) %>%
  right_join(temp_df, by = "year") %>%
  drop_na()

# Read and join poll data
temp3_df <- read_csv("data/pollavg_bystate_1968-2016.csv") %>%
  select(year, state, party, days_left, avg_poll) %>%
  group_by(state, year) %>%
  # Select most recent polling dates to reflect closeness to the election
  top_n(-1, days_left) %>%
  group_by(state, year) %>%
  # Take average of most recent polls
  mutate(total = sum(avg_poll)) %>%
  ungroup() %>%
  group_by(state, year, party) %>%
  # Calculate 2-party poll estimates by dividing the responses by total Dem +
  # Rep responses
  mutate(avg_poll = mean(avg_poll),
         poll_2party = 100 * avg_poll / total)

# Join all data
full_df <- temp3_df %>%
  left_join(temp2_df, by  = c("year", "state", "party")) %>%
  drop_na() %>%
  select(-days_left) %>%
  # Only select democrats for calculating D_pv2p vote share
  filter(party == "democrat")

full_q3 <- full_df %>%
  filter(quarter == 3)

avg_qt <- full_df %>%
  group_by(year) %>%
  mutate(GDP_growth_qt = mean(GDP_growth_qt))

# Predict democratic vote share by running various models
# 1. Unscaled poll numbers, no interaction, Abromowitz T4C model
mod_1_lm <- lm(data = full_q3, formula = D_pv2p ~ avg_poll + GDP_growth_qt + incumbent)
summary(mod_1_lm) #adj Rsq .7948
# 2. Same but average
mod_2_lm <- lm(data = avg_qt, formula = D_pv2p ~ avg_poll + GDP_growth_qt + incumbent)
summary(mod_2_lm) #adj Rsq .7877
# 3. Same but q3
mod_3_lm <- lm(data = full_q3, formula = D_pv2p ~ avg_poll + RDI_growth + incumbent)
summary(mod_3_lm) #adj Rsq .7985
# 4. Same but average
mod_4_lm <- lm(data = avg_qt, formula = D_pv2p ~ avg_poll + RDI_growth + incumbent)
summary(mod_4_lm) #adj Rsq .788
# 5. Using scaled poll numbers
mod_5_lm <- lm(data = full_q3, formula = D_pv2p ~ poll_2party + RDI_growth + incumbent)
summary(mod_5_lm) #adj Rsq 0.8154
# 6. Using interaction
mod_6_lm <- lm(data = full_q3, formula = D_pv2p ~ poll_2party + RDI_growth + incumbent + RDI_growth:incumbent)
summary(mod_6_lm) #adj Rsq 0.8168


# Make formulas
mod1 <- formula(D_pv2p ~ avg_poll + GDP_growth_qt + incumbent)
mod2 <- formula(D_pv2p ~ avg_poll + RDI_growth + incumbent)
mod3 <- formula(D_pv2p ~ poll_2party + RDI_growth + incumbent)
mod4 <- formula(D_pv2p ~ poll_2party + RDI_growth + incumbent + RDI_growth:incumbent)
mod5 <- formula(D_pv2p ~ poll_2party + RDI_growth + incumbent + RDI_growth:incumbent + incumbent_party)

# Make this pretty for display by putting into a dataframe
formulas_df <- tibble(formula = c(mod1, mod2, mod3, mod4, mod5),
                      name = c("T4C model",
                               "T4C with RDI growth instead of GDP",
                               "Scaled 2-party poll model",
                               "Incumbency interaction",
                               "Time for (party) change model"))

# Use map_* functions to extract statistics
full_gt <- formulas_df %>%
  mutate(metrics = map(formula, ~lm(data = full_q3, .)),
         rsq = map_dbl(metrics, ~summary(.)$r.squared),
         mse = map_dbl(metrics, ~mean((.$model$D_pv2p - .$fitted.values)^2)),
         sqrt_mse = map_dbl(mse, ~sqrt(.))) %>%
  select(-formula, -metrics, -mse) %>%
  # Use gt() to turn into a table
  gt() %>%
  tab_header(
    title = "Model variants and in-sample statistics",
    subtitle = "The best performer included Q3 RDI growth, an interaction term between incumbency and RDI growth, and scaled 2-party poll estimates"
  ) %>%
  # Aesthetics: Round decimals to 3 and rename columns
  fmt_number(columns = c("rsq", "sqrt_mse"), decimals = 3) %>%
  cols_label(name = "Model Name",
             rsq = "R Squared",
             sqrt_mse = "MSE")

# Save gt
gtsave(full_gt, "full_gt.png")

# CV out of sample fit

# Construct a linear engine
lm_model <-
  linear_reg() %>%
  set_engine("lm") %>%
  set_mode("regression")

# Split into 5 folds of the data and repeat 10 times for CV
data_folds <- vfold_cv(data = full_q3, v = 5, repeats = 10)
avg_folds <- vfold_cv(data = avg_qt, v = 5, repeats = 10)

# Run cross- validation and collect MSE and rsq values
fit_resamples(object = lm_model,
              preprocessor = mod2,
              resamples = data_folds) %>%
  collect_metrics() # Rsq .796, mean 4.50
fit_resamples(object = lm_model,
              preprocessor = mod2,
              resamples = avg_folds) %>%
  collect_metrics() # Rsq .786, mean 4.61, lower stderr but not enough
fit_resamples(object = lm_model,
              preprocessor = mod1,
              resamples = data_folds) %>%
  collect_metrics() # Rsq .792, mean 4.56
fit_resamples(object = lm_model,
              preprocessor = mod3,
              resamples = data_folds) %>%
  collect_metrics() # Rsq .831, mean 4.19
fit_resamples(object = lm_model,
              preprocessor = mod4,
              resamples = data_folds) %>%
  collect_metrics() # Rsq .833, mean 4.17
fit_resamples(object = lm_model,
              preprocessor = mod5,
              resamples = data_folds) %>%
  collect_metrics() # Rsq .833, mean 4.17

# Looking at coefficients
my_mod <- lm(data = full_q3, formula = D_pv2p ~ poll_2party + RDI_growth + incumbent + RDI_growth:incumbent + incumbent_party + state)
summary(my_mod)

stargazer(my_mod, type = "html", no.space = TRUE, dep.var.caption = "")

# Swing states
swingstates <- c("Arizona", "Wisconsin", "Minnesota", "Nevada", "Michigan", "New Hampshire",
           "Ohio", "Pennsylvania", "North Carolina", "Florida", "Iowa", "Texas",
           "Georgia")

nonswing <- full_q3 %>%
  filter(!state %in% swingstates)

nonswing_mod <- lm(data = nonswing, formula = D_pv2p ~ poll_2party + RDI_growth + incumbent + RDI_growth:incumbent + incumbent_party)
summary(nonswing_mod)

stargazer(nonswing_mod, type = "html", no.space = TRUE, dep.var.caption = "")

swing <- full_q3 %>%
  filter(state %in% swingstates)

swing_mod <- lm(data = swing, formula = D_pv2p ~ poll_2party + state + incumbent + RDI_growth)
summary(swing_mod)

# Output to HTML when creating HTML graphs to use in Github Pages
stargazer(nonswing_mod, swing_mod, type = "text", no.space = TRUE, dep.var.caption = "",
          dep.var.labels = "2-party Democratic vote share")

econ_2020 <- data.frame(RDI_growth = -0.040720404,
                        incumbent = TRUE,
                        incumbent_party = TRUE)

data_2020_nonswing <- polls_2020_df %>%
  mutate(modeldate = mdy(modeldate)) %>%
  top_n(1, modeldate) %>%
  filter(!candidate_name %in% c("Convention Bounce for Joseph R. Biden Jr.", "Convention Bounce for Donald Trump")) %>%
  group_by(state) %>%
  mutate(total = sum(pct_trend_adjusted)) %>%
  ungroup() %>%
  mutate(poll_2party = 100 * pct_trend_adjusted / total) %>%
  filter(candidate_name== "Joseph R. Biden Jr.") %>%
  full_join(econ_2020, by = character()) %>%
  filter(!state %in% swingstates,
         !state %in% c("NE-2", "NE-1", "ME-2", "ME-1", "District of Columbia")) %>%
  arrange(state)

nonswing_statenames <- data_2020_nonswing %>%
  select(state)

# Predict for nonswing states
pred_2020_nonswing <- data.frame(pred = predict(nonswing_mod, newdata = data_2020_nonswing, se.fit = TRUE),
           statename = nonswing_statenames)

data_2020_swing <- polls_2020_df %>%
  mutate(modeldate = mdy(modeldate)) %>%
  top_n(1, modeldate) %>%
  filter(!candidate_name %in% c("Convention Bounce for Joseph R. Biden Jr.", "Convention Bounce for Donald Trump")) %>%
  group_by(state) %>%
  mutate(total = sum(pct_trend_adjusted)) %>%
  ungroup() %>%
  mutate(poll_2party = 100 * pct_trend_adjusted / total) %>%
  filter(candidate_name== "Joseph R. Biden Jr.") %>%
  full_join(econ_2020, by = character()) %>%
  filter(state %in% swingstates,
         !state %in% c("NE-2", "NE-1", "ME-2", "ME-1", "District of Columbia")) %>%
  arrange(state)

swing_statenames <- data_2020_swing %>%
  select(state)

# Electoral college votes
ecvote_df <- ecvote_df %>%
  select(X1, `2020`) %>%
  rename("state" = "X1",
         "ecvotes" = `2020`) %>%
  unique() %>%
  drop_na()

# Predict for nonswing states
pred_2020_swing <- data.frame(pred = predict(swing_mod, newdata = data_2020_swing, se.fit = TRUE),
                                 statename = swing_statenames)

final_pred <- rbind(pred_2020_swing, pred_2020_nonswing) %>%
  mutate(winner = case_when(pred.fit > 50 ~ "Biden",
                            TRUE ~ "Trump")) %>%
  left_join(ecvote_df, by = "state") %>%
  drop_na() %>%
  group_by(winner) %>%
  mutate(total_ecvote = sum(ecvotes))



# Graph!
ggplot(data = final_pred, aes(state = state, fill = winner)) +
  geom_statebins() +
  theme_statebins() +
  labs(title = "Election Prediction",
       subtitle = "96 votes Trump and 442 votes Biden",
       fill = "") +
  scale_fill_manual(values=c("steelblue3", "indianred2"),
                    breaks = c("Biden", "Trump")) +
  theme(plot.title = element_text(size = 12),
        plot.subtitle = element_text(size = 8),
        legend.position = "none")

ggsave("pred_2020_1.png", width = 8, height = 4)

# Normal draws using the standard error
final_pred %>%
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
       subtitle = "In constructing a 95% CI, 42 electoral votes for Trump and 371 votes for Biden fall outside the interval",
       fill = "") +
  scale_fill_manual(values=c("steelblue3", "indianred2", "plum3"),
                    breaks = c("Most likely Biden", "Most likely Trump", "Confidence Interval indicates toss-up")) +
  theme(plot.title = element_text(size = 12),
        plot.subtitle = element_text(size = 8),
        legend.position = "none")

ggsave("pred_2020_2.png", width = 8, height = 4)










