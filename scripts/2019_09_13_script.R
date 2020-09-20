
## 9/13/20 Blog Post on swing states

# Load libraries
library(tidyverse)
library(usmap)
library(ggplot2)

# Read in datasets
popvote_df <- read_csv("../data/popvote_1948-2016.csv")
pvstate_df <- read_csv("../data/popvote_bystate_1948-2016.csv")

# Obtain sf from usmap library
states_map <- us_map()

# Filter for past 10 elections
pv_margins_map <- pvstate_df %>%
  filter(year >= 1980) %>%
  # Calculate the win margin by subtracting two-party vote share
  mutate(win_margin = (R_pv2p-D_pv2p)) %>%
  select(-total, -D, -R) %>%
  unique()

## Visualization customization

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

# Create ggplot2 object using usmap shapefiles
p <- plot_usmap(data = pv_margins_map, regions = "states", values = "win_margin") +
  # Facet by year
  facet_wrap(facets = year~.) +
  # Insert gradient where high values correspond to high Republican win margins
  # and low values correspond to high Democrat win margins, colored
  # appropriately
  scale_fill_gradient2(
    high = "indianred1",
    mid = "white",
    low = "royalblue1",
    # Manually insert sensible breaks
    breaks = c(-50,-25,0,25,50),
    limits = c(-50,50),
    name = "Win margin") +
  # Add custom map theme and labels
  ec_map_theme +
  labs(title = "Win Margins for U.S. Presidential Elections",
       subtitle = "Color corresponds to party win margin by popular vote")

# Save graphic
ggsave("PV_margins_general.png", height = 6, width = 12)

## Examining swing states

# Reassign pv_margins_map by using case_when to calculate the difference in
# Democrat vote share from one election to the next
pv_margins_map <- pvstate_df %>%
  filter(year >= 1976) %>%
  select(-total, -D, -R, -R_pv2p) %>%
  group_by(state) %>%
  mutate(swing = case_when(year == 1980 ~ D_pv2p - D_pv2p[year==1976],
                           year == 1984 ~ D_pv2p - D_pv2p[year==1980],
                           year == 1988 ~ D_pv2p - D_pv2p[year==1984],
                           year == 1992 ~ D_pv2p - D_pv2p[year==1988],
                           year == 1996 ~ D_pv2p - D_pv2p[year==1992],
                           year == 2000 ~ D_pv2p - D_pv2p[year==1996],
                           year == 2004 ~ D_pv2p - D_pv2p[year==2000],
                           year == 2008 ~ D_pv2p - D_pv2p[year==2004],
                           year == 2012 ~ D_pv2p - D_pv2p[year==2008],
                           year == 2016 ~ D_pv2p - D_pv2p[year==2012])) %>%
  na.omit()

# Plot values
plot_usmap(data = pv_margins_map, regions = "states", values = "swing") +
  facet_wrap(facets = year~.) +
  scale_fill_gradient2(
    low = "indianred1",
    mid = "white",
    high = "royalblue1",
    breaks = c(-20,-10,0,10,20),
    limits = c(-20, 20),
    name = "Difference in win margin") +
  ec_map_theme +
  labs(title = "Swing States for U.S. Presidential Elections",
       subtitle = "Swing status corresponds to the difference in Democratic popular vote share from the previous election")

# Save graphic
ggsave("swing.png", height = 6, width = 12)
