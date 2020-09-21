
# 9/20/20 Blog Post on the Economy

## Load libraries
library(tidyverse)
library(ggplot2)
library(ggthemes)
library(patchwork)
library(gt)
library(tidymodels)

# Read in datasets
economy_df <- read_csv("data/econ.csv")
popvote_df <- read_csv("data/popvote_1948-2016.csv")

# Custom ggplot theme
ec_theme <- theme_fivethirtyeight() +
  theme(legend.position = "right",
        panel.grid = element_blank(),
        axis.title = element_text(),
        legend.text = element_text(size = 12),
        legend.title = element_text(size = 12),
        plot.title = element_text(size = 18),
        plot.subtitle = element_text(size = 14))

# Data preparation


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

# Plots


# Create individual plots for each of the 5 models
p1 <- econ %>%
  ggplot(aes(x=st_gdp, y=pv2p,
             label=year)) +
  # Reduce the size of the year labels so they don't obscure the graph
  geom_text(size = 3) +
  # Add confidence intervals and linear regression
  geom_smooth(method="lm", formula = y ~ x) +
  geom_hline(yintercept=50, lty=2) +
  geom_vline(xintercept=0.01, lty=2) + # median
  xlab("Averaged Q2 and Q3 GDP growth") +
  ylab("Incumbent party's vote share") +
  # Add custom theme
  ec_theme

# Rinse and repeat for the next four graphs
p2 <- econ %>%
  ggplot(aes(x=st_stock, y=pv2p,
             label=year)) +
  geom_text(size = 3) +
  geom_smooth(method="lm", formula = y ~ x) +
  geom_hline(yintercept=50, lty=2) +
  geom_vline(xintercept=0.01, lty=2) + # median
  xlab("Averaged Q2 and Q3 Trading Volume") +
  ylab("Incumbent party's vote share") +
  ec_theme

p3 <- econ %>%
  ggplot(aes(x=st_rdi, y=pv2p,
             label=year)) +
  geom_text(size = 3) +
  geom_smooth(method="lm", formula = y ~ x) +
  geom_hline(yintercept=50, lty=2) +
  geom_vline(xintercept=0.01, lty=2) + # median
  xlab("Averaged Q2 and Q3 RDI Growth") +
  ylab("Incumbent party's vote share") +
  ec_theme

p4 <- econ %>%
  ggplot(aes(x=st_inflation, y=pv2p,
             label=year)) +
  geom_text(size = 3) +
  geom_smooth(method="lm", formula = y ~ x) +
  geom_hline(yintercept=50, lty=2) +
  geom_vline(xintercept=0.01, lty=2) + # median
  xlab("Averaged Q2 and Q3 Inflation") +
  ylab("Incumbent party's vote share") +
  ec_theme

p5 <- econ %>%
  ggplot(aes(x=st_unemp, y=pv2p,
             label=year)) +
  geom_text(size = 3) +
  geom_smooth(method="lm", formula = y ~ x) +
  geom_hline(yintercept=50, lty=2) +
  geom_vline(xintercept=0.01, lty=2) + # median
  xlab("Averaged Q2 and Q3 Unemployment") +
  ylab("Incumbent party's vote share") +
  ec_theme

# Use patchwork to lay out the graphs and save
x1 <- (p3 + p4 + p5)
x2 <- plot_spacer() + p1 + p2 + plot_spacer() + plot_layout(widths = c(.5,1,1,.5))
x1/x2
ggsave("corplot.png", height = 10, width = 16)


# Build several models to test based off the economy


# Define formulas
rdi_form <- formula(pv2p ~ st_rdi)
inflation_form <- formula(pv2p ~ st_inflation)
unemp_form <- formula(pv2p ~ st_unemp)
gdp_form <- formula(pv2p ~ st_gdp)
stock_form <- formula(pv2p ~ st_stock)

# Create a dataframe containing all of the formulas
econ_formulas <- tibble(formula = c(rdi_form,
                                    inflation_form,
                                    unemp_form,
                                    gdp_form,
                                    stock_form),
                        group = c("RDI Growth Model",
                                  "Inflation Model",
                                  "Unemployment Model",
                                  "GDP Growth Model",
                                  "Trading Volume Model"))

# Use map_* functions to apply lm(), summary(), and extract model statistics
# such as mse and rsq
econ_gt <- econ_formulas %>%
  mutate(metrics = map(formula, ~lm(data = econ, .)),
         rsq = map_dbl(metrics, ~summary(.)$r.squared),
         mse = map_dbl(metrics, ~mean((.$model$pv2p - .$fitted.values)^2)),
         sqrt_mse = map_dbl(mse, ~sqrt(.))) %>%
  select(-formula, -metrics, -mse) %>%
  # Use gt() to turn into a table
  gt() %>%
  tab_header(
    title = "Five economic models and in-sample variation statistics",
    subtitle = "As expected, the RDI growth model produced the lowest MSE and highest R^2"
  ) %>%
  # Aesthetics: Round decimals to 2 and rename columns
  fmt_number(columns = c("rsq", "sqrt_mse"), decimals = 2) %>%
  cols_label(group = "Model Name",
             rsq = "R Squared",
             sqrt_mse = "MSE")

# Save gt table
gtsave(econ_gt, "econ_gt.png")

# Use tidymodels for cross-validation


# Construct a linear engine
lm_model <-
  linear_reg() %>%
  set_engine("lm") %>%
  set_mode("regression")

# Split into 5 folds of the data and repeat 10 times for CV
econ_folds <- vfold_cv(data = econ, v = 5, repeats = 10)

# Run cross- validation and collect MSE and rsq values
fit_resamples(object = lm_model,
              preprocessor = rdi_form,
              resamples = econ_folds) %>%
  collect_metrics()

# Predict 2020 data


# Reassign new dataframe to contain the same variables that our formulas are
# based off of; note that we can only use Q2 data for 2020 for now (future
# to-do: adding Q3 data)
GDP_new <- economy_df %>%
  filter(year == 2020 & quarter %in% c(1,2)) %>%
  # Calculate the 'short-term' indicators by averaging Q2 and Q3 indicators
  mutate(st_gdp = sum(GDP_growth_qt)/2,
         st_rdi = sum(RDI_growth)/2,
         st_inflation = sum(inflation)/2,
         st_unemp = sum(unemployment)/2,
         st_stock = sum(stock_volume)/2) %>%
  select(st_rdi, st_gdp, st_inflation, st_unemp, st_stock) %>%
  unique()

# Applying predict() function to all 5 models
pred_gt <- econ_formulas %>%
  mutate(metrics = map(formula, ~lm(data = econ, .)),
         pred = map_dbl(metrics, ~predict(., GDP_new))) %>%
  select(group, pred) %>%
  # Use gt() to turn into a table
  gt() %>%
  tab_header(
    title = "2020 Popular vote share predictions",
    subtitle = "Five economic models demonstrate sensitivity to 2020 Q2"
  ) %>%
  # Aesthetics: Round decimals to 2 and rename columns
  fmt_number(columns = c("pred"), decimals = 2) %>%
  cols_label(group = "Model Name",
             pred = "Predicted incumbent party vote share")

# Save gt table
gtsave(pred_gt, "pred_gt.png")

