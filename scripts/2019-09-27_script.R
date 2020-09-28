
# Poll blog post

# Load libraries
library(tidyverse)
library(ggplot2)
library(usmap)
library(patchwork)

# Create map theme
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

# Read in datasets with column specifications
poll_df <- read_csv("data/pollavg_1968-2016.csv")
poll_state_df <- read_csv("data/pollavg_bystate_1968-2016.csv")
popvote_df <- read_csv("data/popvote_1948-2016.csv")
popvote_state_df <- read_csv("data/popvote_bystate_1948-2016.csv")
ec_df <- read_csv("data/electoralcollegevotes_1948-2020.csv",
                  n_max = 51) %>%
  select(-c(X22:X28)) %>%
  rename("state" = "X1") %>%
  pivot_longer(cols = `1944`:`2020`, values_to = "votes", names_to = "year") %>%
  mutate(year = as.double(year))
economy_df <- read_csv("data/econ.csv")
polls_2020 <- read_csv("data/polls_2020.csv")

# Clean
econ <- popvote_df %>%
  # Filter only for years that both datasets have no NA values for
  filter(incumbent_party == TRUE,
         year >= 1960) %>%
  select(year, winner, pv2p) %>%
  # Join both datasets by year and filter only for Q2 & Q3
  left_join(economy_df %>% filter(year >= 1960), by = "year") %>%
  filter(quarter %in% c(2,3)) %>%
  group_by(year) %>%
  # Calculate the 'short-term' indicators by averaging Q2 and Q3 indicators
  mutate(st_gdp = sum(GDP_growth_qt)/2,
         st_rdi = sum(RDI_growth)/2,
         st_inflation = sum(inflation)/2,
         st_unemp = sum(unemployment)/2,
         st_stock = sum(stock_volume)/2)

# # Join state electoral college votes + poll info
# statepolls_ec_df <- poll_state_df %>%
#   select(year, state, party, weeks_left, avg_poll) %>%
#   left_join(ec_df, by = c("state", "year"))

# # Join previous dataset + actual outcome
# pv_trim_df <- popvote_state_df %>%
#   select(state, year, R_pv2p, D_pv2p)
# form_df <- statepolls_ec_df %>%
#   left_join(pv_trim_df, by = c("state", "year")) %>%
#   mutate(pv2p = case_when(party == "democrat" ~ D_pv2p,
#                           party == "republican" ~ R_pv2p)) %>%
#   select(-D_pv2p, -R_pv2p)

# Examine how well state-level polls predict final outcome

# Join poll_state_df and popvote_state_df
state <- poll_state_df %>%
  left_join(popvote_state_df, by = c("state", "year")) %>%
  group_by(state, year) %>%
  top_n(-1, days_left) %>%
  filter(party == "democrat") %>%
  mutate(diff = D_pv2p - avg_poll)

plot_usmap(data = state, regions = "states", values = "diff") +
  labs(title = "Difference between state polls and state vote shares",
       subtitle = "Actual Democratic vote share by state minus Democratic vote share from state-level polls") +
  facet_wrap(facets = year~.) +
  # Insert gradient
  scale_fill_gradient2(
    high = "royalblue1",
    low = "red1",
    # Manually insert sensible breaks
    breaks = c(-15,0,15,30),
    limits = c(-15, 30),
    name = "Actual vote share - poll vote share") +
  ec_map_theme +
  theme(legend.position = "bottom")

# Save graphic
ggsave("state_diff.png", height = 6, width = 12)

## Difference between national polls and election day outcomes
national <- poll_state_df %>%
  left_join(popvote_df, by = c("year", "party")) %>%
  filter(party == "democrat") %>%
  group_by(state, year) %>%
  top_n(-1, days_left) %>%
  mutate(diff = pv2p - avg_poll)

# Fit regression

# Join fundamentals (economy) and polls
join_df <- left_join(state, econ, by = "year")

# Hold the values for fundamentals predictors for 2020
fundamentals_2020 <-data.frame(st_rdi = 0.05179866, avg_support = 43.5)

# Create new dataframe for 2020 polls
polls_2020 <- polls_2020 %>%
  filter(!is.na(state),
         candidate_party == "DEM",
         str_detect(candidate_name, "Biden")) %>%
  group_by(state) %>%
  top_n(1, end_date) %>%
  mutate(avg_poll = mean(pct)) %>%
  ungroup() %>%
  select(state, avg_poll) %>%
  unique()

# Calculate regression
polls <- lm(data = join_df, formula = D_pv2p ~ avg_poll)
fundamentals <- lm(data = join_df, formula = D_pv2p ~ st_rdi)

## Weighted Ensemble 1: polls and fundamentals matter equally as much
pwt <- 0.5; ewt <- 0.5;
pwt*predict(polls, polls_2020) + ewt*predict(fundamentals, fundamentals_2020)


# Predict difference between polls and fundamentals models
polls <- poll_df %>%
  filter(weeks_left <= 5,
         party == "republican") %>%
  group_by(year) %>%
  top_n(1, weeks_left) %>%
  top_n(1, days_left)%>%
  left_join(popvote_df, by = c("year", "party"))

poll_lm <- lm(data=polls, formula = pv2p ~ avg_support)
summary(poll_lm)


econ_lm <- lm(data = econ, formula = pv2p ~ st_rdi)
summary(econ_lm)

x <- polls %>% left_join(econ, by = c("year", "pv2p")) %>%
  drop_na()

combined_lm <- lm(data  =x, formula = pv2p ~ st_rdi + avg_support)
summary(combined_lm)


a <- ggplot(data=x, aes(x=avg_support, y=pv2p)) +
  geom_smooth(method = "lm") +
  xlab("National poll results 5 weeks before the election") +
  ylab("2 party popular vote share")


b <- ggplot(data=x, aes(x=st_rdi, y=pv2p)) +
  geom_smooth(method = "lm") +
  xlab("Q2 and Q3 averaged RDI") +
  ylab("2 party popular vote share")

a + b

ggsave("pnf.png", width = 12, height = 4)
