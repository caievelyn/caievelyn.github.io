
## Week 5: Air War Bloc Post

# Load libraries
library(tidyverse)
library(geofacet)
library(lubridate)
library(statebins)

# Read in data
vep_df <- read_csv("data/vep_1980-2016.csv")
pvstate_df <- read_csv("data/popvote_bystate_1948-2016.csv")
pollstate_df  <- read_csv("data/pollavg_bystate_1968-2016.csv")
dpoll_2020 <- read_csv("data/dpoll_2020.csv")
rpoll_2020 <- read_csv("data/rpoll_2020.csv")
ec_df <- read_csv("data/electoralcollegevotes_1948-2020.csv")

# Join voter eligible population data with popular vote by state data
poll_pvstate_vep_df <- pvstate_df %>%
  mutate(D_pv = D/total) %>%
  inner_join(pollstate_df %>% filter(weeks_left == 5)) %>%
  left_join(vep_df)

# Get size of population (using 2016 pop as proxy)
vep_2020 <- vep_df %>%
  filter(year == 2016) %>%
  select(-VAP, -year) %>%
  mutate(VEP = as.integer(VEP))

# Join 2020 VEP with state polls
d2020 <- vep_2020 %>%
  mutate(state = case_when(state == "District of Columbia" ~ "D.C.",
                           TRUE ~ state)) %>%
  left_join(dpoll_2020, by = "state") %>%
  drop_na()
r2020 <- vep_2020 %>%
  mutate(state = case_when(state == "District of Columbia" ~ "D.C.",
                           TRUE ~ state)) %>%
  left_join(rpoll_2020, by = "state") %>%
  drop_na()

# Grab republican party only
rep <- poll_pvstate_vep_df %>%
  filter(party=="republican") %>%
  select(state, year, R, avg_poll, VEP)
# Grab democrat party only
dem <- poll_pvstate_vep_df %>%
  filter(party=="democrat") %>%
  select(state, year, D, avg_poll, VEP)

# Use list of states to iterate through for loop
states <- rep %>%
  select(state) %>%
  unique()
states <- as.list(states)
output_r2020 <- data.frame("state" = NA_character_, "pred_R" = NA_integer_)

# Iterate through each state for republican vote share
for (i in 1:49) {
  a <- rep %>%
    filter(state == states[[1]][i])

  # Fit a binomial logit model to each states' avgpoll and outcome
  fit <- glm(cbind(R, VEP-R) ~ avg_poll, a, family = binomial)

  # Make a prediction using 2020 polls data
  pred <- predict(fit, newdata = data.frame("avg_poll" = r2020$avg_poll[r2020$state == states[[1]][i]]), type="response")[[1]]

  # Create a data frame with this information
  b <- data.frame("state" = states[[1]][i], "pred_R" = pred)

  # Bind it to output
  output_r2020 <- rbind(output_r2020, b)
}

output_d2020 <- data.frame("state" = NA_character_, "pred_D" = NA_integer_)

# Now iterate through each state for democrat vote share
for (i in 1:49) {
  a <- dem %>%
    filter(state == states[[1]][i])

  # Fit a binomial logit model to each states' avgpoll and outcome
  fit <- glm(cbind(D, VEP-D) ~ avg_poll, a, family = binomial)

  # Make a prediction using 2020 polls data
  pred <- predict(fit, newdata = data.frame("avg_poll" = d2020$avg_poll[d2020$state == states[[1]][i]]), type="response")[[1]]

  # Create a data frame with this information
  b <- data.frame("state" = states[[1]][i], "pred_D" = pred)

  # Bind it to output
  output_d2020 <- rbind(output_d2020, b)
}

# Get predicted distribution of draws from the population (R)
sim_Rvotes_2020 <- output_r2020 %>%
  left_join(vep_2020, by = "state") %>%
  drop_na() %>%
  group_by(state) %>%
  mutate(sim_r = map(pred_R, ~rbinom(n = 10000, size = VEP, prob = .)))
# Do the same for Democrat and join
sims_2020 <- output_d2020 %>%
  left_join(vep_2020, by = "state") %>%
  drop_na() %>%
  group_by(state) %>%
  mutate(sim_d = map(pred_D, ~rbinom(n = 10000, size = VEP, prob = .))) %>%
  left_join(sim_Rvotes_2020, by = c("state", "VEP")) %>%
  unnest(c(sim_r, sim_d))

# Now graph
sims_2020 %>%
  ggplot() +
  geom_histogram(position="identity", aes(x = 100*(sim_d-sim_r)/(sim_d+sim_r))) +
  facet_geo(~state) +
  xlab("hypothetical poll support") +
  ylab('probability of state-eligible voter voting for party') +
  theme_bw() +
  scale_x_continuous(limits = c(-50, 50),
                     breaks = seq(-50, 50, by = 25),
                     labels = c("-50", "", "0", "", "50")) +
  theme(axis.title.y = element_text(size=6.5)) +
  ylab(NULL) +
  xlab("Predicted draws of Biden win margin (%)")

# Save plot
ggsave("binommap.png", width = 11, height = 6)

# Look at win predictions
sims_2020 %>%
  mutate(win_margin = 100*(sim_d-sim_r)/(sim_d+sim_r)) %>%
  group_by(state) %>%
  mutate(avg_win_margin = mean(win_margin)) %>%
  ungroup() %>%
  select(state, avg_win_margin) %>%
  unique() %>%
  mutate(winner = case_when(avg_win_margin < 0 ~ "Trump",
                            avg_win_margin > 0 ~ "Biden",
                            TRUE ~ NA_character_)) %>%
  # Create ggplot using cool 'statebins' package - shoutout to Yao
  ggplot(aes(state = state, fill = winner)) +
  geom_statebins() +
  theme_statebins() +
  labs(title = "Predicted Outcomes for the 2020 Presidential Election",
       subtitle = "Through draws from 10,000 binomial processes",
       fill = "") +
  scale_fill_manual(values=c("steelblue3", "indianred2"),
                    breaks = c("Biden", "Trump"))
# Save plot
ggsave("predmap.png", width = 7, height = 5)


# Examine electoral vote division

# Clean electoral college votes dataset
ec_df <- ec_df %>%
  select(X1, `2020`) %>%
  rename("state" = "X1",
         "ecvotes" = `2020`) %>%
  unique()

sims_2020 %>%
  mutate(win_margin = 100*(sim_d-sim_r)/(sim_d+sim_r)) %>%
  group_by(state) %>%
  mutate(avg_win_margin = mean(win_margin)) %>%
  ungroup() %>%
  select(state, avg_win_margin) %>%
  unique() %>%
  mutate(winner = case_when(avg_win_margin < 0 ~ "Trump",
                            avg_win_margin > 0 ~ "Biden",
                            TRUE ~ NA_character_)) %>%
  left_join(ec_df, by = "state") %>%
  group_by(winner) %>%
  mutate(total_ecvotes = sum(ecvotes))

# Missing Vermont and DC from final because of join stuff




### Look at ads

# Read in data
ads_2020 <- read_csv("data/ads_2020.csv") %>%
  pivot_longer(cols = c(biden_airings, trump_airings), names_to = "candidate", values_to = "airings")
ads_2020 %>%
  ggplot(aes(x=as.factor(period_startdate), y=airings, fill = candidate)) +
  geom_bar(stat = "identity", position = "dodge") +
  scale_fill_manual(breaks = c("biden_airings", "trump_airings"),
                    labels = c("Biden", "Trump"),
                    values = c("steelblue3", "indianred2"),
                    name = "") +
  xlab("Period") +
  scale_x_discrete(labels = c("Apr-Sep", "Sep-Oct")) +
  ylab("Quantity of ads aired") +
  labs(title="Political Advertising in the 2020 Election")

# Save plot
ggsave("ads.png", height = 5.5, width = 5)



