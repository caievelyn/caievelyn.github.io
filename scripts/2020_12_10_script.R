
# Narratives blog assignment

# Load libraries
library(tidyverse)
library(broom)
library(gt)

# Read data and preprocess
uscounties <- read_csv("data/us-counties.txt") %>%
  mutate(fips = as.numeric(fips))
countyvote <- read_csv("data/CountyResults2020 - Sheet1.csv", skip = 1) %>%
  rename(biden = vote1,
         trump = vote2,
         county = name) %>%
  select(-c(vote4:vote38)) %>%
  mutate(totaltwoparty = biden + trump,
         d_2pv = 100 * biden / totaltwoparty,
         r_2pv = 100 * trump / totaltwoparty)
population <- read_csv("data/co-est2019-alldata.csv") %>%
  select(State, County, POPESTIMATE2019) %>%
  separate(col = County, into = c("name", "extra"), sep =" County", fill = "right") %>%
  select(-extra) %>%
  rename(totalpop = POPESTIMATE2019,
         state = State,
         county = name)
election_2016 <- read_csv("data/countypres_2000-2016.csv") %>%
  filter(year == 2016, candidate == "Donald Trump") %>%
  rename(fips = FIPS) %>%
  mutate(vs_2016 = 100 * candidatevotes / totalvotes) %>%
  select(state, county, fips, vs_2016)

# Join data
df <- left_join(uscounties, countyvote, by = c("fips", "county")) %>%
  mutate(deathcaseratio = 100 * deaths/cases,
         thousandcases = 1000 * cases,
         hundreddeaths = 100 * deaths) %>%
  na.omit()

full_df <- left_join(df, population, by = c("county", "state"))

# Test AP Claim
## Calculate COVID cases per capita as of 11/3/2020
full_df <- full_df %>%
  filter(date == "2020-11-03") %>%
  unique() %>%
  mutate(casespercapita = 100000 * cases / totalpop)

full_df %>%
  arrange(desc(casespercapita)) %>%
  slice(1:376) %>%
  mutate(winner = case_when(d_2pv > 50 ~ "Biden",
                            TRUE ~ "Trump")) %>%
  group_by(winner) %>%
  summarize(n())

307 / (307+69)

# Control for 2016 votes
compare_df <- left_join(full_df, election_2016, by = c("county", "state", "fips"))

orig_form <- formula(r_2pv~casespercapita)
partisan_form <- formula(r_2pv~casespercapita + vs_2016)
formulas_df <- tibble(formula = c(orig_form, partisan_form),
                      name = c("Cases per capita model",
                               "Cases per capita & 2016 vote share"))
full_gt <- formulas_df %>%
  mutate(metrics = map(formula, ~lm(data = compare_df, .)),
         rsq = map_dbl(metrics, ~summary(.)$r.squared),
         intercept = map_dbl(metrics, ~summary(.)$coef[1]),
         casespercapita = map_dbl(metrics, ~summary(.)$coef[2]),
         trump_2pv_2016 = map_dbl(metrics, ~summary(.)$coef[3])) %>%
  select(-metrics, -formula) %>%
  mutate(trump_2pv_2016 = case_when(name == "Cases per capita & 2016 vote share" ~ NA_real_,
                                    TRUE ~ trump_2pv_2016)) %>%
  # Use gt() to turn into a table
  gt() %>%
  tab_header(
    title = "Regressing Trump 2-party vote share on COVID cases") %>%
  # Aesthetics: Round decimals to 3 and rename columns
  fmt_number(columns = c("rsq", "intercept", "casespercapita", "trump_2pv_2016"), decimals = 4) %>%
  cols_label(name = "Model Name",
             rsq = "R Squared",
             intercept = "Intercept",
             casespercapita = "Cases per capita coefficient",
             trump_2pv_2016 = "2016 Trump vote share coefficient")

ggplot(data = compare_df, aes(x = casespercapita, y = r_2pv)) +
  geom_point(size = 1.2, color = "indianred3", alpha = 0.7) +
  geom_smooth(method = "glm") +
  theme_minimal() +
  xlab("Cases per 100,000") +
  ylab("Republican 2-party vote share") +
  labs(title = "COVID cases and vote share")

ggsave("scattercovid.png", height = 4, width = 5)


# Save gt
gtsave(full_gt, "full_gt.png")

# Looking at pure case numbers x 2016 vote share
compare_df <- compare_df %>%
  mutate(deathspercapita = 100000 * deaths/totalpop)
general_mod <- lm(data = compare_df, formula = r_2pv ~ casespercapita)
tidy(general_mod) %>% View()

# daily case rates
compare_df %>%
  mutate



ggplot(data = compare_df, aes(x = deathspercapita, y = r_2pv)) +
  geom_point(size = 1.2, color = "indianred3", alpha = 0.7) +
  geom_smooth(method = "glm") +
  theme_minimal() +
  xlab("Deaths per 100,000") +
  ylab("Republican 2-party vote share") +
  labs(title = "COVID cases and vote share")

ggsave("deathsscatter.png", height = 6, width = 7)

compare_df %>%
  arrange(desc(deathspercapita)) %>%
  slice(1:376) %>%
  mutate(winner = case_when(d_2pv > 50 ~ "Biden",
                            TRUE ~ "Trump")) %>%
  group_by(winner) %>%
  summarize(n())

266 / (266+110)









