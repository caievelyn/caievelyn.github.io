---
title: 2020 Presidential Election Prediction
tags: [Prediction, Historical Data, State v. National, Polls, Popular Vote]
style: border
color: primary
description: My final prediction for the 2020 presidential election, disaggregated by state 2-party vote share.
---

As November 3rd is less than two days away, in this blog post I create a final prediction for the 2020 U.S. presidential election based off of state winners.

[structure here]

(1) model formula (or procedure for obtaining prediction), 
(2) model description and justification, 
(3) coefficients (if using regression) and/or weights (if using ensemble), 
(4) interpretation of coefficients and/or justification of weights, 
(5) model validation (recommended to include both in-sample and out-of-sample performance unless it is impossible due to the characteristics of model and related data availability), 
(6) uncertainty around prediction (e.g. predictive interval)
(7) graphic(s) showing your prediction

## The Model

My model is based off of Abromowitz's time for change model and adapted for the state level. Abromowitz's three explanatory variables are Q2 GDP growth, national net approval ratings for the president, and incumbency. While extremely parsimonious and highly accurate, the model does not show vote choice disaggregated by state. 

One of my explanatory variables is state-level poll estimates instead of national presidential net approval ratings. The figure below shows the trends in Trump's average net approval ratings, calculated by taking the average of the difference between his approval and non-approval ratings, and nation-wide poll estimates for his share of the 2-party vote come November 3rd. As you can see, the troughs and peaks in both charts follow each other quite similarly and indicate that poll estimates and national approval ratings approximate around the same thing, which is vote choice.

![](../figures/approval_polls.png)

Unlike national approval ratings, however, poll estimates can further be disaggregated by state. This data was downloaded from [538](https://projects.fivethirtyeight.com/2020-election-forecast/). The figure below shows how poll estimates have changed from the end of February until the most recent model date, October 30th. Disaggregating by state is important for two reasons:
1) The nature of the winner-takes-all electoral college system means we should be very tuned in to state partisan leanings rather than overall national popular vote share. Exhibit A: The 2000 and 2016 elections, in which the elected President was not the candidate with the majority popular vote share overall.
2) State partisan leanings have implications for down-ballot races as well; if Texas sees a Trump victory by 2 points, for example, down-ballot races are likely quite competitive as well given that Texas has been reliably red until 2016.

![](../figures/pollavgstate.png)

**Model parameters**

Fundamental indicators are a strong predictor of elections. Firstly, voters balance sociotropic and individual-level concerns on the state of society and what that means for their immediate communities. Economic data, at least in national aggregate, is consistent and widely accessible. Voters cast their ballots based off of retrospective assessments of presidential performance, and the economy is good proxy for this retrospection process because its effects are felt immediately in terms of inflation or increased levels of real disposable income, as well as covered extensively by the media and touted by political figures as resume-building credentials. Because of the human difficulty it takes to accurately recall economic performance over a 4-year span, voters overwhelmingly tend to measure the entire 4-year economic performance based off of the last two years, especially the last two quarters of election year ([Healy & Lenz, 2013](https://onlinelibrary.wiley.com/doi/abs/10.1111/ajps.12053)).

![](..figures/gdp.png)

Another piece of the puzzle is incumbency. While voters have no underlying preference for incumbents once other factors are controlled for, the reality is that their time in office confers benefits to their election ([Brown, 2014](https://www-cambridge-org.ezp-prod1.hul.harvard.edu/core/services/aop-cambridge-core/content/view/ECFE39E003912F8AF65C2AD14A34BD8C/S2052263014000062a.pdf/div-class-title-voters-don-t-care-much-about-incumbency-div.pdf)). In fact, only 3 sitting presidents- Ford, Carter, and George H.W. Bush- have lost their re-election campaigns in the post-war era. I believe the main mechanism incumbency confers advantages to candidates is through the financial aspect. Indeed, residents reward sitting presidents for spending in their area, presumably because the spending indicates future prosperity under the President ([Kriner & Reeves, 2012](https://www-cambridge-org.ezp-prod1.hul.harvard.edu/core/services/aop-cambridge-core/content/view/D7E15E901EA52BF92E5986626766224F/S0003055412000159a.pdf/div-class-title-the-influence-of-federal-spending-on-presidential-elections-div.pdf)). I hypothesize that adding an incumbency interaction term to the fundamentals variable will result in a stronger model.

While only 3 incumbent presidents have lost in the 18 post-WWII elections, 11 incumbent parties have lost. This may indicate voters' preferences for a change of pace, as described by [Abromowitz](https://pollyvote.com/en/components/models/retrospective/fundamentals-plus-models/time-for-change-model/). I also believe that this reflects the voter psyche of retrospective voting, as failures and negative events that accrue over a 4-year term may cause voters to simply get tired of the incumbent party. In examining the impact of shocks on presidential elections, it is found that voters still punish/reward incumbents for politically exogenous shocks that are endogenized through government interaction with the issue, such as natural disaster response ([Healy & Malholtra, 2010](https://ideas.repec.org/a/now/jlqjps/100.00009057.html)). Simply by being an incumbent, a candidate is held responsible for factors that may have originated exogenously. Voters may tire of incumbent party platforms for this reason.

Regarding fundamentals, I test two indicators: GDP growth and RDI growth, to determine which can be a better predictor. I avoid looking at stock movements, inflation, or unemployment, as models that regress 2-party vote share against those singular variables find weak R-squared values (respectively, they are 0.08, 0.09, and 0.02) relative to GDP and RDI growth. Additionally, I test Q2 and Q3 to determine whether an average of the two periods or Q3 alone is a better indicator based off of Healy & Lenz's findings that other quarters are weak predictors.

As mentioned previously, poll estimates closely follow presidential approval ratings, which have a strong correlation with the incumbent's 2-party vote share. Therefore, I use the most recent state-level polling data there is available for 2 reasons. The first is that polls tend to converge towards the actual outcome ([Gelman & King, 1993](https://gking.harvard.edu/files/abs/variable-abs.shtml)). The second is that, given the United States's electoral college system, disaggregating by state is of utmost importance because a national popular vote win could very well fail to reflect an electoral college win.

Next, I examine the models' in- and out-of-sample predictive power and examine the coefficients on my model of choice.

## Validation and Uncertainty

Seeing the success of Abromowitz's parsimonious model, I tested several variants of the time for change model and gathered their in-sample R-squared fit values and out-of-sample cross-validation R-squared values. First, I chose to use Q3 economic indicators rather than indicators averaged over Q2 and Q3 because every single model formula variant performed better when using Q3 data rather than averaged Q2 and Q3 economic indicators. This was a surprising finding, as I previously believed that taking the average could protect our model performance by mitigating unusually poor or good economic performance. The formulas I used can be found below. For `mod2`, for example, the adjusted R-squared was 0.800 when solely using the Q3 RDI growth indicator (5-fold cross-validation R-squared was .795), whereas the adjusted R-squared was .788 when using averaged Q2 and Q3 RDI growth (5-fold cross-validation R-squared was .786). When performing cross-validation, the mean squared errors' standard errors were similar. For these reasons, the following models will be tested using only Q3 indicators.

```
mod1 <- formula(D_pv2p ~ avg_poll + GDP_growth_qt + incumbent)
mod2 <- formula(D_pv2p ~ avg_poll + RDI_growth + incumbent)
mod3 <- formula(D_pv2p ~ poll_2party + RDI_growth + incumbent)
mod4 <- formula(D_pv2p ~ poll_2party + RDI_growth + incumbent + RDI_growth:incumbent)
```

![](../figures/full_gt.png)

Indeed, when performing 5-fold cross-validation, `mod4` was the best performer with a mean squared error of 4.17 and R-squared of .833, compared to the worst performer `mod1` with 4.50 MSE and .796 R-squared. The MSE is useful because extreme values are punished more in out-of-sample model evaluations, which is especially pertinent for 2020 since it may indeed yield a more extreme prediction.





*You can find the replication scripts for graphics included in this week's blog [here](https://github.com/caievelyn/election-analytics/blob/master/scripts/2020_11_01_script.R). You can find the necessary data [here](https://github.com/caievelyn/election-analytics/tree/master/data).*
