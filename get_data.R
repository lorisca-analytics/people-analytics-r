# Downloads the eight CSVs into data/.
# The files are DataCamp's synthetic HR data. I don't redistribute them, so they stay
# out of Git and every run fetches the same public copies.
# A checksum per file stops the analysis if the hosted data ever changes,
# because every number in the write-up depends on these exact rows.
# MD5 is enough here: it guards against changed files, not against tampering.
#
# Run from the repo root:  Rscript get_data.R

base_url <- "https://assets.datacamp.com/production/course_5977/datasets/"

expected <- c(
  accident_data.csv    = "e6b7e53a280f00aef1483622937da4b2",
  fair_pay_data.csv    = "50278cd9d58ba3f5b128f692295f6bd0",
  hr_data.csv          = "5c47843cf7c8472a83c6ff1fcf401852",
  hr_data_2.csv        = "eb6d280407da4b4e27283b11111cbc50",
  performance_data.csv = "fbb2f2d98640d549657a54b2eb99fcea",
  recruitment_data.csv = "b509923d9f36fb8fdc9b59d13ef7bcf4",
  survey_data.csv      = "130ea1a09e850179c54e1e6384b6f2e5",
  survey_data_2.csv    = "ae33a555a5a7ecbe65b6c619690fe6df"
)

dir.create("data", showWarnings = FALSE)
for (f in names(expected)) {
  dest <- file.path("data", f)
  if (!file.exists(dest)) download.file(paste0(base_url, f), dest, quiet = TRUE, mode = "wb")
  got <- unname(tools::md5sum(dest))
  if (!identical(got, expected[[f]])) {
    stop(f, " does not match the expected checksum. The hosted file changed, so the results would not be comparable.")
  }
}
cat("data/: 8 files present, checksums match.\n")
