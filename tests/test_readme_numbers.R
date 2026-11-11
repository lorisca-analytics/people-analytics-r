# The numbers the README and the card quote are listed in readme_numbers.csv with the name
# it has in outputs/key_numbers.csv. If a code change moves a number, or someone
# edits the README by hand, this fails and says which one.

library(testthat)
root <- Sys.getenv("REPO_ROOT", "..")

render <- function(value, format) {
  switch(format,
    pct1    = sprintf("%.1f%%", 100 * value),
    pct0    = sprintf("%.0f%%", 100 * value),
    pct1raw = sprintf("%+.1f%%", value),
    pp1     = sprintf("%+.1f points", value),
    int     = sprintf("%d", as.integer(round(value))),
    comma   = format(round(value), big.mark = ","),
    dec2    = sprintf("%.2f", value),
    p2      = sprintf("%.2f", value),
    p3      = sprintf("%.3f", value),
    dec1    = sprintf("%.1f", value),
    usd     = paste0(ifelse(value < 0, "-$", "$"), format(round(abs(value)), big.mark = ",", trim = TRUE)),
    stop("unknown format ", format))
}

read_text <- function(f) paste(readLines(file.path(root, f), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
docs <- list(README.md = read_text("README.md"), card.json = read_text("card.json"))
expected <- read.csv(file.path(root, "tests/readme_numbers.csv"), stringsAsFactors = FALSE, encoding = "UTF-8")
current <- read.csv(file.path(root, "outputs/key_numbers.csv"), stringsAsFactors = FALSE)
values <- setNames(as.numeric(current$value), current$name)

test_that("every mapped number exists in the latest run", {
  expect_true(all(expected$name %in% names(values)),
              info = paste(setdiff(expected$name, names(values)), collapse = ", "))
})

for (i in seq_len(nrow(expected))) {
  row <- expected[i, ]
  test_that(paste(row$file, "quotes", row$name, "correctly"), {
    got <- render(values[[row$name]], row$format)
    # The map text holds the number with a few words of context, so a match
    # points at one place in the document, not any stray occurrence.
    expect_true(grepl(got, row$text, fixed = TRUE), info = sprintf("%s: code gives %s, map says '%s'", row$name, got, row$text))
    expect_true(grepl(row$text, docs[[row$file]], fixed = TRUE), info = sprintf("%s: '%s' not found in %s", row$name, row$text, row$file))
  })
}
