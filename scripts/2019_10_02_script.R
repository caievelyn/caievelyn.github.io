
## Blog post on incumbency

# Load libraries
library(tidyverse)
library(caret)
library(gt)
library(patchwork)

# Read in data
economy_df <- read_csv("data/econ.csv")
popvote_df <- read_csv("data/popvote_1948-2016.csv")
grants_df <- read_csv("data/fedgrants_bystate_1988-2008.csv")
polls_df <- read_csv("data/pollavg_1968-2016.csv")
popvote_state_df <- read_csv("data/popvote_bystate_1948-2016.csv")

# Clean up datasets for polls and economic indicators data
polls_30_days <- polls_df %>%
    filter(party == "democrat") %>%
    group_by(year) %>%
    filter(days_left == 30) %>%
    left_join(popvote_df, by = c("year", "party")) %>%
    select(year, party, avg_support, winner, pv2p, incumbent)

econ <- economy_df %>%
    filter(year %in% c(1988, 1992, 1996, 2000, 2004, 2008, 2012, 2016),
           quarter %in% c(2, 3)) %>%
    group_by(year) %>%
    mutate(st_rdi = sum(RDI_growth)/2) %>%
    select(year, st_rdi) %>%
    unique() %>%
    left_join(popvote_df, by = "year") %>%
    filter(party == "democrat")

# Create data for 2020 and each year
polls_2020 <- data.frame(year = "2020", "avg_support" = 50.3) #using RCP average for 10/2
econ_2020 <- data.frame(year = "2020", "st_rdi"= 0.0517986614)

polls_2016 <- polls_30_days %>% filter(year == 2016)
econ_2016 <- econ %>% filter(year == 2016)

polls_2012 <- polls_30_days %>% filter(year == 2012)
econ_2012 <- econ %>% filter(year == 2012)

polls_2008 <- polls_30_days %>% filter(year == 2008)
econ_2008 <- econ %>% filter(year == 2008)

# Create lm objects
polls_lm <- lm(data = polls_30_days, formula = pv2p ~ avg_support)
econ_lm <- lm(data = econ, formula = pv2p ~ st_rdi)

# Internal validity as-is
summary(polls_lm)$r.squared
summary(econ_lm)$r.squared
mean((polls_lm$model$pv2p - polls_lm$fitted.values)^2)
mean((econ_lm$model$pv2p - econ_lm$fitted.values)^2)
# LOO CV
train(pv2p ~ avg_support, method = "lm", data = polls_30_days, trControl = trainControl(method = "LOOCV"))
train(pv2p ~ st_rdi, method = "lm", data = econ, trControl = trainControl(method = "LOOCV"))



# Weighted ensemble test
weights <- data.frame("pwt" = seq(.05, 0.95, .05))

wt_2016 <- weights %>%
    mutate(poll_pred = map_dbl(pwt, ~predict(polls_lm, polls_2016)*.),
           econ_pred = map_dbl(pwt, ~predict(econ_lm, econ_2016)*(1-.))) %>%
    group_by(pwt) %>%
    mutate(pred = poll_pred + econ_pred) %>%
    mutate(real = 51.16249,
           diff = pred - real,
           mse = diff^2)

wt_2012 <- weights %>%
    mutate(poll_pred = map_dbl(pwt, ~predict(polls_lm, polls_2012)*.),
           econ_pred = map_dbl(pwt, ~predict(econ_lm, econ_2012)*(1-.))) %>%
    group_by(pwt) %>%
    mutate(pred = poll_pred + econ_pred) %>%
    mutate(real = 51.91526,
           diff = pred - real,
           mse = diff^2)

wt_2008 <- weights %>%
    mutate(poll_pred = map_dbl(pwt, ~predict(polls_lm, polls_2008)*.),
           econ_pred = map_dbl(pwt, ~predict(econ_lm, econ_2008)*(1-.))) %>%
    group_by(pwt) %>%
    mutate(pred = poll_pred + econ_pred) %>%
    mutate(real = 53.77077,
           diff = pred - real,
           mse = diff^2)

combined_wts <- left_join(wt_2016, wt_2012, by = "pwt") %>% left_join(wt_2008, by = "pwt") %>%
    select(pwt, mse.x, mse.y, mse) %>%
    group_by(pwt) %>%
    mutate(combined_mse = mse.x + mse.y + mse) %>%
    ungroup() %>%
    arrange(combined_mse) %>%
    slice(1)


weights_gt <- left_join(wt_2016, wt_2012, by = "pwt") %>% left_join(wt_2008, by = "pwt") %>%
    select(pwt, mse.x, mse.y, mse) %>%
    group_by(pwt) %>%
    mutate(combined_mse = mse.x + mse.y + mse) %>%
    ungroup() %>%
    arrange(combined_mse) %>%
    slice(1:10) %>%
    gt() %>%
    tab_header(
        title = "Sensitivity Test for Weighted Ensemble Model",
        subtitle = "Tested on 3 different years: 2016, 2012, and 2008") %>%
    # Aesthetics: Round decimals to 2 and rename columns
    fmt_number(columns = c("mse.x", "mse.y", "mse", "combined_mse"), decimals = 3) %>%
    cols_label(pwt = "Polls weight",
               mse.x = "2016",
               mse.y = "2012",
               mse = "2008",
               combined_mse = "MSE Sum")

# Save gt table
gtsave(weights_gt, "weights_gt.png")

# Visualize differences among weights
p <- ggplot()
p + geom_text(data = wt_2016, aes(x = pwt, y = mse), label = "2016", size = 2) +
    geom_text(data = wt_2012, aes(x = pwt, y = mse), label = "2012", size = 2) +
    geom_text(data = wt_2008, aes(x = pwt, y = mse), label = "2008", size = 2) +
    xlab("Weight of polls model") +
    ylab("Mean squared error") +
    labs(title = "Sensitivity Analysis of Weighted Ensemble for 2008-2016") +
    theme_minimal()
ggsave("sensitive.png", width = 6, height = 3.5)



# Create list of states and their abbreviations to join by
x <- grants_df %>%
    select(state_abb) %>%
    unique() %>%
    mutate(num = 1:51)
y <- popvote_state_df %>%
    select(state) %>%
    unique() %>%
    mutate(num = 1:51)
state_list <- full_join(x, y, by = "num")

# Join popvotestate and incumbency status
popvote_state_df <- popvote_state_df %>%
    left_join(popvote_df, by = "year") %>%
    select(state, year, incumbent, D_pv2p, R_pv2p, party) %>%
    mutate(incumbent_pv2p = case_when(incumbent == TRUE & party == "republican" ~ R_pv2p,
                            incumbent == TRUE & party == "democrat" ~ D_pv2p,
                            TRUE ~ NA_real_)) %>%
    drop_na() %>%
    select(-R_pv2p, -D_pv2p, -party)

# Incumbency
a <- grants_df %>%
    left_join(state_list, by = "state_abb") %>%
    filter(year == 2004) %>%
    left_join(popvote_state_df, by = c("year", "state")) %>%
    select(-state_year_type2) %>%
    drop_na() %>%
    mutate(incumbent_pv2p = incumbent_pv2p/100,
        inc_swing = incumbent_pv2p - state_incvote_avglast3) %>%
    ggplot(aes(x = grant_mil, y = inc_swing)) +
    geom_point() +
    geom_smooth(method = "lm") +
    theme_minimal() +
    xlab("Federal Grants (in millions of dollars)") +
    ylab("Difference in incumbent party vote share") +
    labs(title = "Does spending affect vote share in election years? (2004)")

b <- grants_df %>%
    left_join(state_list, by = "state_abb") %>%
    filter(year == 2004,
           state_year_type == "core + election") %>%
    left_join(popvote_state_df, by = c("year", "state")) %>%
    select(-state_year_type2) %>%
    drop_na() %>%
    mutate(incumbent_pv2p = incumbent_pv2p/100,
           inc_swing = incumbent_pv2p - state_incvote_avglast3) %>%
    ggplot(aes(x = grant_mil, y = inc_swing)) +
    geom_point() +
    geom_smooth(method = "lm") +
    theme_minimal() +
    xlab("Federal Grants (in millions of dollars)") +
    ylab("Difference in incumbent party vote share") +
    labs(title = "Does spending affect vote share for core states? (2004)")

# Arrange graphics and save
a + b
ggsave("spending_core.png", width = 10, height = 4)

