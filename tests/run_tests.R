# Run from the repo root after run_all.R:  Rscript tests/run_tests.R
library(testthat)
# test_file runs each file from inside tests/, so the files find the repo through this.
Sys.setenv(REPO_ROOT = normalizePath("."))
res <- lapply(c("tests/test_data_checks.R", "tests/test_readme_numbers.R"),
              function(f) test_file(f, reporter = "summary", stop_on_failure = FALSE))
failed <- sum(vapply(res, function(r) sum(as.data.frame(r)$failed) + sum(as.data.frame(r)$error), numeric(1)))
if (failed > 0) quit(status = 1)
