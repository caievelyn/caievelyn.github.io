
# Text analysis: 11/30 presentation

# Load libraries
library(quanteda)
library(tidyverse)
library(lubridate)
library(patchwork)
library(gt)
library(syuzhet)
library(stringr)

# Read in Data
campaign_speeches <- read_csv("data/campaignspeech_2019-2020.csv") %>%
  filter(approx_date > "2017-11-01") %>%
  mutate(date = case_when(approx_date < "2020-04-01" ~ "Pre-COVID Shutdown",
                                   TRUE ~ "Post-COVID Shutdown"))
trump_twt <- read_csv("data/trumptweets_2016-2020.csv") %>%
  filter(date > "2020-03-01" & date < "2020-11-04")
biden_twt <- read_csv("data/JoeBidenTweets.csv") %>%
  filter(timestamp > "2020-03-01" & timestamp < "2020-11-04")

# Pre-processing
trump_speech_corpus <- corpus(campaign_speeches %>% filter(candidate == "Donald Trump"),
                        text_field = "text",
                        docid_field = "url")
biden_speech_corpus <- corpus(campaign_speeches %>% filter(candidate == "Joe Biden"),
                              text_field = "text",
                              docid_field = "url")
# Tokenize
trump_toks <- tokens(trump_speech_corpus,
                      remove_punct = TRUE,
                      remove_symbols = TRUE,
                      remove_numbers = TRUE,
                      remove_url = TRUE) %>%
  tokens_tolower() %>%
  tokens_remove(pattern=c("joe","biden","donald","trump","president","kamala","harris", "white", "house", "america", "american", "united", "states")) %>%
  tokens_remove(pattern=stopwords("en")) %>%
  # tokens_select(min_nchar=3) %>%
  tokens_ngrams(n=2)
biden_toks <- tokens(biden_speech_corpus,
                      remove_punct = TRUE,
                      remove_symbols = TRUE,
                      remove_numbers = TRUE,
                      remove_url = TRUE) %>%
  tokens_tolower() %>%
  tokens_remove(pattern=c("joe","biden","donald","trump","president","kamala","harris", "white", "house", "america", "american", "united", "states")) %>%
  tokens_remove(pattern=stopwords("en")) %>%
  # tokens_select(min_nchar=3) %>%
  tokens_ngrams(n=2)
# Make doc-freq matrices
trump_speech_dfm <- dfm(trump_toks, groups = "date")
biden_speech_dfm <- dfm(biden_toks, groups = "date")
# Make keyness plot
trump_speech_keyness <- textstat_keyness(trump_speech_dfm, target = "Post-COVID Shutdown")
a <- textplot_keyness(trump_speech_keyness, color = c("darkgoldenrod2", "brown4")) +
  labs(title = "Donald Trump's Campaign Speeches") +
  theme(legend.position = "bottom")
biden_speech_keyness <- textstat_keyness(biden_speech_dfm, target = "Post-COVID Shutdown")
b <- textplot_keyness(biden_speech_keyness, color = c("darkgoldenrod2", "brown4")) +
  labs(title = "Joe Biden's Campaign Speeches") +
  theme(legend.position = "bottom")
# Save plots
a
ggsave("speechkeyness1.png", height = 7, width = 10)
b
ggsave("speechkeyness2.png", height = 7, width = 10)


# Text frequencies
trump_tstat_freq <- textstat_frequency(trump_speech_dfm, groups = "date")
biden_tstat_freq <- textstat_frequency(biden_speech_dfm, groups = "date")
# Create string of phrases relating to the economy
econ_str <- c("billion_dollars", "billions_dollars",
               "manufacturing_jobs", "middle_class", "million_jobs",
              "millions_dollars", "millions_jobs", "much_money", "new_deal",
              "new_jobs", "raise_taxes", "small_business", "small_businesses",
              "social_security", "stock_market")
speech_freqs <- full_join(biden_tstat_freq, trump_tstat_freq, by = c("feature", "group")) %>%
  filter(feature %in% econ_str)

gt_output <- data.frame(speech_freqs) %>%
  filter(group == "Post-COVID Shutdown") %>%
  rename(Trump_Freq = frequency.y,
         Biden_Freq = frequency.x) %>%
  select(-rank.x, -rank.y, -group, -docfreq.x, -docfreq.y) %>%
  gt()

gtsave(data = gt_output, filename = "freq_gt.png")

# Find a better way to visualize?




## Sentiment Analysis

a <- biden_twt %>%
  filter(timestamp > "2020-02-01" & timestamp < "2020-04-01") %>%
  mutate(sentiment = map_dbl(tweet, ~get_sentiment(., method = "syuzhet"))) %>%
  ggplot(aes(x = timestamp, y = sentiment)) +
  geom_line() +
  theme_minimal() +
  xlab("Date") +
  ylab("Sentiment") +
  labs(subtitle = "Joe Biden's Tweets") +
  geom_hline(yintercept = 0, color = "red")

b <- trump_twt %>%
  filter(isRetweet == FALSE,
         date > "2020-02-01" & date < "2020-04-01") %>%
  mutate(sentiment = map_dbl(text, ~get_sentiment(., method = "syuzhet"))) %>%
  ggplot(aes(x = date, y = sentiment)) +
  geom_line()+
  theme_minimal() +
  xlab("Date") +
  ylab("Sentiment") +
  labs(subtitle = "Donald Trump's Tweets") +
  geom_hline(yintercept = 0, color = "red")

a+b

ggsave("tweets.png", height = 6, width = 10)

# Define another string of economic key words
econ_str1 <- c("economy", "econ", "dollars",
               "manufacturing", "jobs", "middle class",
               "money", "tax cut", "new deal",
              "new jobs", "tax", "small business", "small businesses",
              "stock", "market", "GDP", "business", "businesses",
              "inflation", "employment", "unemployment", "work",
              "income", "wealth", "salary", "salaries", "prices", "price",
              "trade", "invest", "investment", "bank", "deflation", "asset")

library(sjmisc)

a <- biden_twt %>%
  filter(timestamp > "2020-01-01" & timestamp < "2020-11-04") %>%
  mutate(econ = map(tweet, ~str_detect(., pattern = econ_str1)),
         econ = map(econ, ~case_when(. == FALSE ~ 0,
                                     TRUE ~ 1)),
         econtalk = map_dbl(econ, ~sum(.))) %>%
  filter(econtalk != 0) %>%
  mutate(sentiment = map_dbl(tweet, ~get_sentiment(., method = "syuzhet"))) %>%
  ggplot(aes(x = timestamp, y = sentiment)) +
  geom_point() +
  theme_minimal() +
  xlab("Date") +
  ylab("Sentiment") +
  labs(subtitle = "Joe Biden's Tweets") +
  geom_hline(yintercept = 0, color = "red")+
  ylim(-6, 8)

b <- trump_twt %>%
  filter(date > "2020-01-01" & date < "2020-11-04") %>%
  mutate(econ = map(text, ~str_detect(., pattern = econ_str1)),
         econ = map(econ, ~case_when(. == FALSE ~ 0,
                                     TRUE ~ 1)),
         econtalk = map_dbl(econ, ~sum(.))) %>%
  filter(econtalk != 0) %>%
  mutate(sentiment = map_dbl(text, ~get_sentiment(., method = "syuzhet"))) %>%
  ggplot(aes(x = date, y = sentiment)) +
  geom_point() +
  theme_minimal() +
  xlab("Date") +
  ylab("Sentiment") +
  labs(subtitle = "Trump's Tweets") +
  geom_hline(yintercept = 0, color = "red") +
  ylim(-6, 8)

a + b


