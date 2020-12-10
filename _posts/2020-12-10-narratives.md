---
title: Post-election Narratives
tags: [Post-Election, Narratives, Sentiment Analysis]
style: border
color: primary
description: I examine whether counties that experience more COVID cases actually supported Trump more.
---

## Narrative overview

>Trump won the majority of votes in more than 90% of the 376 US counties with the highest number of new COVID-19 cases per capita. - [Business Insider](https://www.businessinsider.com/counties-with-worst-covid-19-surges-overwhelmingly-voted-for-trump-2020-11)

>The regions of the country that Trump carried have also been those most plagued by COVID-19 since late August. - [Time Magazine](https://time.com/5910256/covid-19-presidential-election-outcome/)

>...[In] places where the virus is most rampant now, Trump enjoyed enormous support. - [AP News](https://apnews.com/article/counties-worst-virus-surges-voted-trump-d671a483534024b5486715da6edb6ebf)

A dominant media narrative is that, contrary to what one may think given rational and competent restrospective voting, Donald Trump actually enjoyed an advantage over Joe Biden when it came to COVID-19. Specifically, Trump won more counties with the highest number of COVID-19 cases per capita than Biden did. 

This is not necessarily surprising once you take into account that mask-wearing and prevention of the coronavirus's spread is a polarized and partisan issue. Given Trump's track record of [refusing to wear masks](https://www.nytimes.com/2020/10/02/us/politics/donald-trump-masks.html) or denounce those who fail to abide by social distancing rules, one would expect that red-leaning counties may be faring worse than their blue-leaning counterparts.

That being said, I am interested in expanding upon our knowledge of how the pandemic impacted voting by looking at other quantities of interest, including raw case numbers, death rates, and the rate of change of new daily cases. I conclude with an analysis of how each candidate framed coronavirus-related issues.

## Testing the AP Claim

The AP claims that, of the 376 counties with the highest number of new COVID-19 cases per capita as of early November, 90%+ broke for Trump. I verify this claim by using the [NYT county-level COVID-19 data](https://github.com/nytimes/covid-19-data) and the county-level vote share for 2020. First, I calculate the new case rate per capita by taking the day-to-day difference, dividing by the population, and multiplying by 100,000.


*You can find the replication scripts for graphics included in this week's blog [here](https://github.com/caievelyn/election-analytics/blob/master/scripts/2020_12_10_script.R). You can find the necessary data [here](https://github.com/caievelyn/election-analytics/tree/master/data). Shouout to Cassidy for scraping the Twitter data.*
