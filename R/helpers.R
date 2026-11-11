suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(broom)
  library(sandwich)
  library(lmtest)
})
options(readr.show_col_types = FALSE, width = 120, pillar.width = 120, dplyr.summarise.inform = FALSE)

load_csv <- function(f) read_csv(file.path("data", f))

section <- function(x) cat("\n\n## ", x, "\n", sep = "")
say <- function(...) cat(..., "\n", sep = "")

# Stops the run instead of printing a warning: a join that drops or duplicates
# rows changes every rate downstream without any error.
stop_if <- function(cond, msg) if (isTRUE(cond)) stop(msg, call. = FALSE)

check_keys <- function(df, keys, name, n_expected) {
  stop_if(nrow(df) != n_expected, sprintf("%s: expected %d rows, got %d", name, n_expected, nrow(df)))
  stop_if(any(duplicated(df[keys])), sprintf("%s: duplicate %s", name, paste(keys, collapse = " + ")))
  say(sprintf("%s: %d rows, keys unique", name, nrow(df)))
}

# Exact binomial CI. Normal-approximation intervals go wrong for small groups
# and rates near zero, and several groups here are both.
rate_ci <- function(x) {
  b <- binom.test(sum(x), length(x))
  tibble(n = length(x), events = sum(x), rate = mean(x), lo = b$conf.int[1], hi = b$conf.int[2])
}

# Odds ratios with a chosen variance matrix, so every model reports the same columns
# whether its errors are classical, HC3 or clustered.
or_rows <- function(m, V = vcov(m)) {
  ct <- coeftest(m, vcov. = V)
  ci <- coefci(m, vcov. = V)
  tibble(term = rownames(ct), odds_ratio = exp(ct[, 1]), lo = exp(ci[, 1]), hi = exp(ci[, 2]), p = ct[, 4])
}

lm_rows <- function(m, V = vcov(m)) {
  ct <- coeftest(m, vcov. = V)
  ci <- coefci(m, vcov. = V)
  tibble(term = rownames(ct), estimate = ct[, 1], lo = ci[, 1], hi = ci[, 2], p = ct[, 4])
}

# Every number the write-up quotes goes through here, so the check script can
# compare the README against a fresh run.
key_numbers <- new.env()
record <- function(name, value) {
  assign(name, value, envir = key_numbers)
  invisible(value)
}

fmt_p <- function(p) ifelse(p < 0.001, "< 0.001", sprintf("%.3f", p))
usd <- function(x) paste0(ifelse(x < 0, "-$", "$"), format(round(abs(x)), big.mark = ",", trim = TRUE))
pct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)
