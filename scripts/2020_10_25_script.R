
# Shocks: COVID-19

# Load libraries
library(tidyverse)
library(geofacet)
library(lubridate)
library(usmap)
library(statebins)
library(patchwork)

# Read in data
covid_race_df <- read_csv("data/covid_race.csv")
state_demo_df <- read_csv("data/state_demo.csv")

state_demo_df <- state_demo_df %>%
  filter(State != "District of Columbia") %>%
  rename("state" = "State") %>%
  mutate(State = state.abb)

# Look at most recent COVID-data
stats_df <- covid_race_df %>%
  filter(Date == "20201021",
         !State %in% c("AS", "GU", "MP", "PR", "VI", "DC")) %>%
  # Combine with state demographic data
  left_join(state_demo_df, by = "State") %>%
  # Calculate case rates, death rates, overall population rates for the Black
  # population
  group_by(State) %>%
  mutate(pop_rate_black = Black/Total,
         pop_rate_white = White/Total,
         case_rate_black = Cases_Black/Cases_Total,
         case_rate_white = Cases_White/Cases_Total,
         death_rate_black = Deaths_Black/Deaths_Total,
         death_rate_white = Deaths_White/Deaths_Total,
         black_cases = case_rate_black/pop_rate_black,
         white_cases = case_rate_white/pop_rate_white,
         black_deaths = death_rate_black/pop_rate_black,
         white_deaths = death_rate_white/pop_rate_white,
         bw_cases = black_cases/white_cases,
         bw_deaths = black_deaths/white_deaths)

# copy-paste custom theme:)
# Create custom theme for maps that adjusts sizing
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

a <- plot_usmap(data = stats_df, regions = "states", values = "bw_cases") +
  # Insert gradient where high values correspond to high Republican win margins
  # and low values correspond to high Democrat win margins, colored
  # appropriately
  scale_fill_gradient2(
    high = "black",
    low = "white",
    # Manually insert sensible breaks
    breaks = c(1, 3, 5),
    limits = c(1, 5),
    name = "COVID case prop.") +
  # Add custom map theme and labels
  ec_map_theme +
  labs(title = "Black-white COVID case proportions",
       subtitle = "Weighed by proportion of state population")

b <- plot_usmap(data = stats_df, regions = "states", values = "bw_deaths") +
  # Insert gradient where high values correspond to high Republican win margins
  # and low values correspond to high Democrat win margins, colored
  # appropriately
  scale_fill_gradient2(
    high = "black",
    low = "white",
    # Manually insert sensible breaks
    breaks = c(0, 2, 4),
    limits = c(0, 4),
    name = "COVID death prop.") +
  # Add custom map theme and labels
  ec_map_theme +
  labs(title = "Black-white COVID death proportions",
       subtitle = "Weighed by proportion of state population")

a+b

ggsave("bwcomparison.png", width = 10, height = 3)



# Read in data
demo <- read_csv("data/demographic_1990-2018.csv")
pvstate_df <- read_csv("data/popvote_bystate_1948-2016.csv")
pollstate_df  <- read_csv("data/pollavg_bystate_1968-2016.csv")

# Clean and join: Note that this section of code was largely written by Sun
# Young for section
pvstate_df$state <- state.abb[match(pvstate_df$state, state.name)]
pollstate_df$state <- state.abb[match(pollstate_df$state, state.name)]
demo_pv <- pvstate_df %>%
  full_join(pollstate_df %>%
              filter(weeks_left == 3) %>%
              group_by(year,party,state) %>%
              summarise(avg_poll=mean(avg_poll)),
            by = c("year", "state")) %>%
  left_join(demo %>%
              select(-c("total")),
            by = c("year", "state"))

demo_pv$region <- state.division[match(demo_pv$state, state.abb)]
demo$region <- state.division[match(demo$state, state.abb)]

# Create lagged variables to find the difference between years in demographics
demo_change <- demo_pv %>%
  group_by(state) %>%
  mutate(Asian_change = Asian - lag(Asian, order_by = year),
         Black_change = Black - lag(Black, order_by = year),
         Hispanic_change = Hispanic - lag(Hispanic, order_by = year),
         Indigenous_change = Indigenous - lag(Indigenous, order_by = year),
         White_change = White - lag(White, order_by = year),
         Female_change = Female - lag(Female, order_by = year),
         Male_change = Male - lag(Male, order_by = year),
         age20_change = age20 - lag(age20, order_by = year),
         age3045_change = age3045 - lag(age3045, order_by = year),
         age4565_change = age4565 - lag(age4565, order_by = year),
         age65_change = age65 - lag(age65, order_by = year))

# Fit an lm model to see how demographic changes affect D_pv2p
demo_change_lm <- lm(D_pv2p ~ Black_change + Hispanic_change + Asian_change +
                       Female_change +
                       age3045_change + age4565_change + age65_change +
                       as.factor(region), data = demo_change)

# Create 2020 data
demo_2020 <- demo %>%
  filter(year == 2018)
demo_2020 <- as.data.frame(demo_2020)
rownames(demo_2020) <- demo_2020$state
demo_2020 <- demo_2020[state.abb, ]

# Calculate changes for 2020
demo_2020_change <- demo %>%
  filter(year %in% c(2016, 2018)) %>%
  group_by(state) %>%
  mutate(Asian_change = Asian - lag(Asian, order_by = year),
         Black_change = Black - lag(Black, order_by = year),
         Hispanic_change = Hispanic - lag(Hispanic, order_by = year),
         Indigenous_change = Indigenous - lag(Indigenous, order_by = year),
         White_change = White - lag(White, order_by = year),
         Female_change = Female - lag(Female, order_by = year),
         Male_change = Male - lag(Male, order_by = year),
         age20_change = age20 - lag(age20, order_by = year),
         age3045_change = age3045 - lag(age3045, order_by = year),
         age4565_change = age4565 - lag(age4565, order_by = year),
         age65_change = age65 - lag(age65, order_by = year)) %>%
  filter(year == 2018)

# Remove row that doesn't exist across both datasets
z <- right_join(demo_2020_change, demo_2020, by = c("state", "Asian", "Black",
                                                    "Hispanic", "Indigenous", "White",
                                                    "Female", "Male", "age20", "age3045", "age4565", "age65",
                                                    "total", "year", "region"))


predict(demo_change_lm, newdata = demo_2020_change)

demo_2020_pred <- data.frame(pred = predict(demo_change_lm, newdata = z),
                             state = state.abb)

# Incorporate other variables: economy and incumbency

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

state_names <- data.frame("state" = state.abb,
                          "statename" = state.name)

# Let's just look at democratic vote share and the difference
dat <- output_d2020 %>%
  drop_na() %>%
  left_join(output_r2020, by = "state") %>%
  group_by(state) %>%
  mutate(D_pv2p = 100*pred_D/(pred_D+pred_R))


# Electoral college votes
ec_df <- ec_df %>%
  select(X1, `2020`) %>%
  rename("state" = "X1",
         "ecvotes" = `2020`) %>%
  unique()

# VArious scenarios

# First one

demo_2020_pred1 <- data.frame(pred = predict(demo_change_lm, newdata = z) + (6.3728-5.694578)*demo_2020$Black,
                             state = state.abb)


m1 <- dat %>%
  rename("statename" = "state") %>%
  left_join(state_names, by = "statename") %>%
  left_join(demo_2020_pred1, by = "state") %>%
  group_by(state) %>%
  mutate(predvs = 0.5*pred + 0.5*D_pv2p) %>%
  ungroup() %>%
  group_by(state) %>%
  mutate(winner = case_when(predvs > 50 ~ "Biden",
                            TRUE ~ "Trump")) %>%
  ungroup() %>%
  select(-state) %>%
  rename("state" = "statename") %>%
  left_join(ec_df, by = "state") %>%
  group_by(winner) %>%
  mutate(wins = sum(ecvotes)) %>%
  ungroup() %>%
  ggplot(aes(state = state, fill = winner)) +
  geom_statebins() +
  theme_statebins() +
  labs(title = "Model 1",
       subtitle = "110 votes Trump and 422 votes Biden, not counting VT and DC",
       fill = "") +
  scale_fill_manual(values=c("steelblue3", "indianred2"),
                    breaks = c("Biden", "Trump")) +
  theme(plot.title = element_text(size = 12),
        plot.subtitle = element_text(size = 8),
        legend.position = "none")

# Second one

z2 <- stats_df %>%
  select(-state) %>%
  rename("state" = "State") %>%
  left_join(z, by = "state")

demo_2020_pred2 <- data.frame(pred = predict(demo_change_lm, newdata = z),
                              state = state.abb,
                              pred2 = predict(demo_change_lm, newdata = z) + (6.3728-5.694578)*demo_2020$Black)

demo_2020_pred2 <- demo_2020_pred2 %>%
  left_join(z2, by = "state") %>%
  mutate(realpred = case_when(bw_deaths > 1 ~ pred2,
                              TRUE ~ pred)) %>%
  select(state, realpred)



m2 <- dat %>%
  rename("statename" = "state") %>%
  left_join(state_names, by = "statename") %>%
  left_join(demo_2020_pred2, by = "state") %>%
  group_by(state) %>%
  mutate(predvs = 0.5*realpred + 0.5*D_pv2p) %>%
  ungroup() %>%
  group_by(state) %>%
  mutate(winner = case_when(predvs > 50 ~ "Biden",
                            TRUE ~ "Trump")) %>%
  ungroup() %>%
  select(-state) %>%
  rename("state" = "statename") %>%
  left_join(ec_df, by = "state") %>%
  group_by(winner) %>%
  mutate(wins = sum(ecvotes)) %>%
  ungroup() %>%
  ggplot(aes(state = state, fill = winner)) +
  geom_statebins() +
  theme_statebins() +
  labs(title = "Model 2",
       subtitle = "110 votes Trump and 422 votes Biden, not counting VT and DC",
       fill = "") +
  scale_fill_manual(values=c("steelblue3", "indianred2"),
                    breaks = c("Biden", "Trump")) +
  theme(plot.title = element_text(size = 12),
        plot.subtitle = element_text(size = 8),
        legend.position = "none")


# Third one

z3 <- stats_df %>%
  select(-state) %>%
  rename("state" = "State") %>%
  left_join(z, by = "state")

ratio <- z3 %>%
  pull(bw_deaths)

demo_2020_pred3 <- data.frame(state = state.abb,
                              ratio = ratio,
                              pred = predict(demo_change_lm, newdata = z) + ((5.694578*ratio)-5.694578)*demo_2020$Black)
m3 <- dat %>%
  rename("statename" = "state") %>%
  left_join(state_names, by = "statename") %>%
  left_join(demo_2020_pred3, by = "state") %>%
  group_by(state) %>%
  mutate(predvs = 0.5*pred + 0.5*D_pv2p) %>%
  ungroup() %>%
  group_by(state) %>%
  mutate(winner = case_when(predvs > 50 ~ "Biden",
                            TRUE ~ "Trump")) %>%
  ungroup() %>%
  select(-state) %>%
  rename("state" = "statename") %>%
  left_join(ec_df, by = "state") %>%
  group_by(winner) %>%
  mutate(wins = sum(ecvotes)) %>%
  ungroup() %>%
  ggplot(aes(state = state, fill = winner)) +
  geom_statebins() +
  theme_statebins() +
  labs(title = "Model 3",
       subtitle = "95 votes Trump and 437 votes Biden, not counting VT and DC",
       fill = "") +
  scale_fill_manual(values=c("steelblue3", "indianred2"),
                    breaks = c("Biden", "Trump")) +
  theme(plot.title = element_text(size = 12),
        plot.subtitle = element_text(size = 8),
        legend.position = "none")

m1+m2+m3

ggsave("hypo.png", width = 11, height = 3.5)









