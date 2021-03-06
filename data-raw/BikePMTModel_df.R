#' Estimate BikePMT Models for households
#'
library(dplyr)
library(purrr)
library(tidyr)
library(splines)

source("data-raw/EstModels.R")
if (!exists("Hh_df"))
  source("data-raw/LoadDataforModelEst.R")

#' converting household data.frame to a list-column data frame segmented by
#' metro ("metro" and "non-metro")
Model_df <- Hh_df %>%
  nest(-metro) %>%
  rename(train=data) %>%
  mutate(test=train) # use the same data for train & test

int_round <- function(x) as.integer(round(x))
int_cround <- function(x) as.integer(ifelse(x<1, ceiling(x), round(x)))
fctr_round1 <- function(x) as.factor(round(x, digits=1))

#' model formula for each segment as a tibble (data.frame), also include a
#' `post_func` column with functions de-transforming predictions to the original
#' scale of the dependent variable
Fmlas_df <- tribble(
  ~name, ~metro,        ~post_func,      ~fmla,
  "hurdle", "metro",    function(y) y,   ~pscl::hurdle(int_cround(BikePMT) ~ AADVMT + Workers + VehPerDriver +
                                                          LifeCycle + Age0to14 + CENSUS_R + D1B*D2A_EPHHM + FwyLaneMiPC + D4c + TranRevMiPC:D4c |
                                                            AADVMT + Workers + LifeCycle + Age0to14 + CENSUS_R +  D1B + D1B:D2A_EPHHM
                                                          + D5 + FwyLaneMiPC + TranRevMiPC,
                                                        data= ., weights=.$hhwgt, na.action=na.exclude),
  "hurdle", "non_metro",function(y) y,   ~pscl::hurdle(int_cround(BikePMT) ~ AADVMT +
                                                              HhSize + LifeCycle + Age0to14 + Age65Plus + D1B + D1B:D2A_EPHHM + D3bpo4 |
                                                              AADVMT + Workers +
                                                              LifeCycle + Age0to14 + D1B + D2A_EPHHM + D3bpo4 + D5,
                                                            data= ., weights=.$hhwgt, na.action=na.exclude)
)

#' call function to estimate models for each segment and add name for each
#' segment
Model_df <- Model_df %>%
  EstModelWith(Fmlas_df)   %>%
  name_list.cols(name_cols=c("metro"))

#' print model summary and goodness of fit
Model_df$model %>% map(summary)
Model_df

#' trim model object of information unnecessary for predictions to save space
BikePMTModel_df <-  Model_df %>%
  dplyr::select(metro, model, post_func) %>%
  mutate(model=map(model, TrimModel))

#' save Model_df to `data/`
#usethis::use_data(BikePMTModel_df, overwrite = TRUE)
