# Draws the four README charts from the tables run_all.R writes.
# Run from the repo root after run_all.R:  Rscript make_charts.R
#
# Two colors only: gray for the before or comparison value, blue for the value
# the finding is about. Every bar or point carries its own label, so nothing
# depends on telling the colors apart.

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})
options(readr.show_col_types = FALSE)

ink <- "#1e2d42"
muted <- "#4a6a8f"
gray <- "#7d8ca0"
blue <- "#3f5fd0"
grid <- "#e5ebf2"

theme_case <- theme_minimal(base_size = 13) +
  theme(text = element_text(color = ink),
        plot.title = element_text(face = "bold", size = 15),
        plot.subtitle = element_text(color = muted, margin = margin(b = 10)),
        plot.caption = element_text(color = muted, hjust = 0, size = 10),
        plot.title.position = "plot", plot.caption.position = "plot",
        axis.text = element_text(color = muted),
        panel.grid.major = element_line(color = grid, linewidth = 0.4),
        panel.grid.minor = element_blank(),
        legend.position = "top", legend.justification = "left",
        plot.background = element_rect(fill = "white", color = NA))
dir.create("figures", showWarnings = FALSE)
save <- function(p, f, w = 8, h = 4.6) ggsave(file.path("figures", f), p, width = w, height = h, dpi = 200, bg = "white")
pct_lab <- function(x) sprintf("%.1f%%", 100 * x)

# 1. Accidents with and without the change in engagement
dec <- read_csv("outputs/chart_accident_breakdown.csv") |>
  mutate(location = factor(location, levels = rev(c("All sites", sort(setdiff(location, "All sites"))))))
long <- dec |>
  select(location, `2016` = rate_2016, `2017 if engagement had not changed` = rate_2017_if_engagement_held, `2017 actual` = rate_2017) |>
  pivot_longer(-location, names_to = "what", values_to = "rate") |>
  mutate(what = factor(what, levels = c("2016", "2017 if engagement had not changed", "2017 actual")))
p1 <- ggplot(dec, aes(y = location)) +
  geom_segment(aes(x = rate_2016, xend = rate_2017, yend = location), color = grid, linewidth = 2.5) +
  geom_point(data = long, aes(x = rate, shape = what, color = what, fill = what), size = 3.6, stroke = 1.3) +
  geom_text(aes(x = rate_2017, label = pct_lab(rate_2017)), nudge_x = 0.006, hjust = 0, size = 3.6, color = ink) +
  geom_text(aes(x = rate_2016, label = pct_lab(rate_2016)), nudge_x = -0.006, hjust = 1, size = 3.6, color = muted) +
  scale_shape_manual(values = c(21, 23, 21), name = NULL) +
  scale_color_manual(values = c(gray, blue, blue), name = NULL) +
  scale_fill_manual(values = c(gray, "white", blue), name = NULL) +
  scale_x_continuous(labels = function(x) paste0(100 * x, "%"), limits = c(0.03, 0.17)) +
  labs(x = "Employees with an accident that year", y = NULL,
       title = "Accidents rose at every site, engagement or not",
       subtitle = "Holding each site's disengagement at its 2016 level barely moves the 2017 rate, except at\nSouthfield. The hollow marker is that what-if. Elsewhere it sits on top of the actual rate.",
       caption = "Same 1,470 employees in both years. Synthetic data.") +
  theme_case
save(p1, "1-accidents-by-site.png")

# 2. Which accidents rose
ty <- read_csv("outputs/chart_accident_type.csv") |>
  pivot_longer(-year, names_to = "type", values_to = "n") |>
  mutate(type = recode(type, mild = "Mild", moderate_or_severe = "Moderate or severe"),
         year = factor(year))
p2 <- ggplot(ty, aes(type, n, fill = year)) +
  geom_col(position = position_dodge(width = 0.75), width = 0.7) +
  geom_text(aes(label = n), position = position_dodge(width = 0.75), vjust = -0.5, size = 4, color = ink) +
  scale_fill_manual(values = c(gray, blue), name = NULL) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(x = NULL, y = "Accidents",
       title = "Almost all the extra accidents were mild",
       subtitle = "49 of the 52 extra accidents were mild. Moderate and severe didn't rise detectably.\nThat pattern can mean more mild cases are being reported, so reporting is the first lead to check.",
       caption = "Paired tests: mild p < 0.001, moderate or severe p = 0.82. Change in the mild share: p = 0.20. Synthetic data.") +
  theme_case + theme(panel.grid.major.x = element_blank())
save(p2, "2-accidents-by-type.png")

# 3. Untracked hires against the tracked channels
att <- read_csv("outputs/chart_attrition_by_source.csv") |>
  mutate(focus = source == "No source recorded",
         label = paste0(source, "  (n = ", n, ")"),
         label = factor(label, levels = label[order(rate)]))
p3 <- ggplot(att, aes(rate, label)) +
  geom_errorbar(aes(xmin = lo, xmax = hi), width = 0, orientation = "y", color = gray, linewidth = 0.8) +
  geom_point(aes(color = focus), size = 3.8) +
  geom_text(aes(label = sprintf("%.0f%%", 100 * rate)), nudge_y = 0.32, size = 3.6, color = ink) +
  scale_color_manual(values = c(gray, blue), guide = "none") +
  scale_x_continuous(labels = function(x) paste0(100 * x, "%"), limits = c(0, 0.85)) +
  labs(x = "Hires who left (lines show 95% intervals)", y = NULL,
       title = "The hires with no recorded source are a different group",
       subtitle = "They leave at about half the rate of tracked hires. Among tracked hires, the four channels\ncan't be told apart (exact test p = 0.27), so channel rankings wait for clean source data.",
       caption = "446 sales hires, 205 with no source recorded. Synthetic data.") +
  theme_case
save(p3, "3-attrition-by-source.png")

# 4. Ratings gap at each cutoff
cu <- read_csv("outputs/chart_rating_cutoffs.csv") |>
  mutate(focus = cutoff == "4+", cutoff = factor(paste("Rated", cutoff), levels = paste("Rated", c("2+", "3+", "4+", "5+"))))
p4 <- ggplot(cu, aes(odds_ratio, cutoff)) +
  geom_vline(xintercept = 1, color = muted, linetype = "dashed") +
  geom_errorbar(aes(xmin = lo, xmax = hi, color = focus), width = 0, orientation = "y", linewidth = 0.9) +
  geom_point(aes(color = focus), size = 3.8) +
  geom_text(aes(x = hi, label = sprintf("%.2f", odds_ratio)), nudge_x = 0.015, hjust = 0, size = 3.6, color = ink) +
  scale_color_manual(values = c(gray, blue), guide = "none") +
  scale_x_log10(breaks = c(0.5, 0.75, 1, 1.5, 2), limits = c(0.55, 2.1)) +
  labs(x = "Odds for men vs women, same job level (log scale, 1 = no gap)", y = NULL,
       title = "A ratings gap shows up only at the top-rating line",
       subtitle = "At 4 or above, men have 1.38 times the odds within the same job level (p = 0.013).\nI used the usual top-rating line without tuning it. At every other cutoff there is no detectable gap.",
       caption = "1,470 employees. Holm-adjusted across all four cutoffs, the 4+ result is p = 0.054. Synthetic data.") +
  theme_case
save(p4, "4-rating-gap-by-cutoff.png")

cat("Wrote 4 charts to figures/\n")
