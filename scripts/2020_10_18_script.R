
# Ground game, demographics, and turnout

# Load libraries
library(tidyverse)
library(geofacet)
library(lubridate)
library(statebins)

## Ground Game

# Read in field offices
x <- read_csv("data/fieldoffice_2012-2016_byaddress.csv")

# Filter for either candidate
trump <- x %>%
  filter(year == 2016,
         candidate == "Trump")

clinton <- x %>%
  filter(year == 2016,
         candidate == "Clinton")

# Create leaflet plot that adds each candidates' field offices and colors
# accordingly
p <- leaflet(data = trump) %>%
  addTiles() %>%
  addCircles(lng = ~longitude,
             lat = ~latitude,
             color = "red")
p %>%
  addCircles(data = clinton,
             lng = ~longitude,
             lat = ~latitude,
             color = "blue")

# Demographics

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


uw <- dat %>%
   rename("statename" = "state") %>%
   left_join(state_names, by = "statename") %>%
   left_join(demo_2020_pred, by = "state") %>%
  group_by(state) %>%
  mutate(model_50_50 = 0.5*pred + 0.5*D_pv2p,
         model_20_80 = 0.2*pred + 0.8*D_pv2p,
         model_80_20 = 0.8*pred + 0.2*D_pv2p) %>%
  ungroup() %>%
  pivot_longer(cols = c(model_50_50, model_20_80, model_80_20),
               names_to = "model", values_to = "predictedvs") %>%
  group_by(state, model) %>%
  mutate(winner = case_when(predictedvs > 50 ~ "Biden",
                            TRUE ~ "Trump")) %>%
  ungroup() %>%
  select(-state) %>%
  rename("state" = "statename")

ec_df <- ec_df %>%
  select(X1, `2020`) %>%
  rename("state" = "X1",
         "ecvotes" = `2020`) %>%
  unique()

uw %>%
  left_join(ec_df, by = "state") %>%
  group_by(model, winner) %>%
  mutate(total_ecvotes = sum(ecvotes)) %>%
  select(model, winner, total_ecvotes) %>%
  unique()

a <- uw %>%
  filter(model == "model_50_50") %>%
  ggplot(aes(state = state, fill = winner)) +
  geom_statebins() +
  theme_statebins() +
  labs(title = "50% Expected Turnout & 50% Demographic Change",
       subtitle = "254 votes Trump and 278 votes Biden, not counting VT and DC",
       fill = "") +
  scale_fill_manual(values=c("steelblue3", "indianred2"),
                    breaks = c("Biden", "Trump")) +
  theme(plot.title = element_text(size = 12),
        plot.subtitle = element_text(size = 8),
        legend.position = "none")

b <- uw %>%
  filter(model == "model_20_80") %>%
  ggplot(aes(state = state, fill = winner)) +
  geom_statebins() +
  theme_statebins() +
  labs(title = "20% Expected Turnout & 80% Demographic Change",
       subtitle = "170 votes Trump and 362 votes Biden, not counting VT and DC",
       fill = "") +
  scale_fill_manual(values=c("steelblue3", "indianred2"),
                    breaks = c("Biden", "Trump")) +
  theme(plot.title = element_text(size = 12),
        plot.subtitle = element_text(size = 8),
        legend.position = "none")

c <- uw %>%
  filter(model == "model_80_20") %>%
  ggplot(aes(state = state, fill = winner)) +
  geom_statebins() +
  theme_statebins() +
  labs(title = "80% Expected Turnout & 20% Demographic Change",
       subtitle = "362 votes Trump and 236 votes Biden, not counting VT and DC",
       fill = "") +
  scale_fill_manual(values=c("steelblue3", "indianred2"),
                    breaks = c("Biden", "Trump")) +
  theme(plot.title = element_text(size = 12),
        plot.subtitle = element_text(size = 8),
        legend.position = "none")

a
ggsave("demo1.png", width = 7, height = 5)

b
ggsave("demo2.png", width = 7, height = 5)

c
ggsave("demo3.png", width = 7, height = 5)

library(stargazer)
stargazer(demo_change_lm, header=FALSE, type='latex', no.space = TRUE,
          column.sep.width = "3pt", font.size = "scriptsize", single.row = TRUE,
          keep = c(1:7, 62:66), omit.table.layout = "sn",
          title = "The electoral effects of demographic change (across states)")


















