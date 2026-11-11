# The data checks are what stop a bad file or a broken join from quietly
# changing every rate, so they get their own tests on small made-up tables.

library(testthat)
source(file.path(Sys.getenv("REPO_ROOT", ".."), "R/helpers.R"))

test_that("check_keys stops on a duplicate key", {
  df <- data.frame(employee_id = c(1, 2, 2), year = 2016)
  expect_error(check_keys(df, "employee_id", "toy", 3), "duplicate")
})

test_that("check_keys stops on an unexpected row count", {
  df <- data.frame(employee_id = 1:3)
  expect_error(check_keys(df, "employee_id", "toy", 4), "expected 4 rows")
})

test_that("check_keys passes a clean table", {
  df <- data.frame(employee_id = 1:3, year = 2016)
  expect_output(check_keys(df, c("employee_id", "year"), "toy", 3), "keys unique")
})

test_that("rate_ci matches an exact binomial interval", {
  x <- c(rep(1, 3), rep(0, 7))
  r <- rate_ci(x)
  b <- binom.test(3, 10)
  expect_equal(r$rate, 0.3)
  expect_equal(c(r$lo, r$hi), as.numeric(b$conf.int))
})

test_that("or_rows uses the variance matrix it is given", {
  set.seed(1)
  d <- data.frame(y = rbinom(200, 1, 0.3), g = rep(0:1, 100), id = rep(1:100, each = 2))
  m <- glm(y ~ g, family = binomial, data = d)
  plain <- or_rows(m)
  clustered <- or_rows(m, sandwich::vcovCL(m, cluster = ~id))
  expect_equal(plain$odds_ratio, clustered$odds_ratio)
  expect_false(isTRUE(all.equal(plain$p, clustered$p)))
})

test_that("usd writes negative amounts with the sign before the dollar", {
  expect_equal(usd(-234.5), "-$234")
  expect_equal(usd(1799.99), "$1,800")
})
