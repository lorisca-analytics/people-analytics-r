# Runs every question in order and writes the results to outputs/.
# Run from the repo root:  Rscript run_all.R   (after Rscript get_data.R)

source("R/helpers.R")
dir.create("outputs", showWarnings = FALSE)

sink("outputs/results.txt", split = TRUE)
say("R ", R.version$major, ".", R.version$minor,
    " | sandwich ", as.character(packageVersion("sandwich")),
    " | lmtest ", as.character(packageVersion("lmtest")))
for (f in sort(list.files("R", pattern = "^[0-9].*\\.R$", full.names = TRUE))) source(f)
sink()

nums <- mget(sort(ls(key_numbers)), envir = key_numbers)
write_csv(tibble(name = names(nums), value = format(signif(unlist(nums), 6), scientific = FALSE, trim = TRUE, drop0trailing = TRUE)), "outputs/key_numbers.csv")
cat("\nWrote outputs/results.txt and outputs/key_numbers.csv\n")
