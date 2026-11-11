# Question for a ratings calibration review: are top ratings (4 or 5) given at the
# same rate to men and women in the same kind of job?
# 4 or 5 is the usual "high performer" line on a 5-point scale. I didn't tune it,
# and I test every other cutoff next to it so the choice can't drive the result.

section("Ratings: data checks")
hr <- load_csv("hr_data.csv")
perf <- load_csv("performance_data.csv")
check_keys(hr, "employee_id", "hr_data", 1470)
check_keys(perf, "employee_id", "performance_data", 1470)
ratings <- inner_join(hr, perf, by = "employee_id") |> mutate(top = as.integer(rating >= 4))
stop_if(nrow(ratings) != 1470, "join lost employees")

section("Ratings: raw gap")
raw <- ratings |> group_by(gender) |> summarize(rate_ci(top), avg_rating = mean(rating))
print(raw)
record("rat_top_female", raw$rate[raw$gender == "Female"])
record("rat_top_male", raw$rate[raw$gender == "Male"])

section("Ratings: job level mix")
print(round(prop.table(table(ratings$gender, ratings$job_level), 1), 3))
by_level <- ratings |> group_by(job_level, gender) |> summarize(rate_ci(top)) |> ungroup()
print(by_level)

section("Ratings: gap within job level")
m_raw <- glm(top ~ gender, family = binomial, data = ratings)
m_lvl <- glm(top ~ gender + job_level, family = binomial, data = ratings)
m_full <- glm(top ~ gender + job_level + department, family = binomial, data = ratings)
or_male <- function(m) filter(or_rows(m), term == "genderMale")
gap <- bind_rows(raw = or_male(m_raw), within_level = or_male(m_lvl), level_and_department = or_male(m_full), .id = "model")
print(gap)
mh <- mantelhaen.test(table(ratings$gender, ratings$top, ratings$job_level))
say(sprintf("Mantel-Haenszel, within level: odds ratio %.2f (95%% CI %.2f to %.2f), p = %s",
            mh$estimate, mh$conf.int[1], mh$conf.int[2], fmt_p(mh$p.value)))
record("rat_or_within_level", gap$odds_ratio[gap$model == "within_level"])
record("rat_or_within_level_p", gap$p[gap$model == "within_level"])
record("rat_or_within_level_lo", gap$lo[gap$model == "within_level"])
record("rat_or_within_level_hi", gap$hi[gap$model == "within_level"])
record("rat_mh_p", mh$p.value)
record("rat_mh_or", unname(mh$estimate))

section("Ratings: every cutoff, within level")
cuts <- lapply(2:5, function(k) {
  d <- mutate(ratings, y = as.integer(rating >= k))
  or_male(glm(y ~ gender + job_level, family = binomial, data = d)) |> mutate(cutoff = paste0(k, "+"), .before = 1)
}) |> bind_rows() |> mutate(p_holm = p.adjust(p, "holm"))
print(cuts)
write_csv(cuts, "outputs/chart_rating_cutoffs.csv")
record("rat_cutoffs_significant", sum(cuts$p_holm < 0.05))
record("rat_or_cut2", cuts$odds_ratio[cuts$cutoff == "2+"])
record("rat_or_cut3", cuts$odds_ratio[cuts$cutoff == "3+"])
record("rat_or_cut5", cuts$odds_ratio[cuts$cutoff == "5+"])
record("rat_holm_4plus", cuts$p_holm[cuts$cutoff == "4+"])

section("Ratings: which level carries the gap")
lvl <- ratings |> group_by(job_level) |>
  summarize(n = n(), p = fisher.test(table(gender, top))$p.value) |>
  mutate(p_holm = p.adjust(p, "holm"))
print(lvl)
say("Rating distribution in Hourly roles, share of each gender:")
print(round(prop.table(table(filter(ratings, job_level == "Hourly") |> select(gender, rating)), 1), 3))
record("rat_hourly_p", lvl$p[lvl$job_level == "Hourly"])
record("rat_hourly_share", mean(ratings$job_level == "Hourly"))
int_p <- anova(m_lvl, glm(top ~ gender * job_level, family = binomial, data = ratings), test = "Chisq")$`Pr(>Chi)`[2]
say("Does the gap differ by job level (gender x level): p = ", fmt_p(int_p))
record("rat_level_interaction_p", int_p)
hr_dist <- prop.table(table(filter(ratings, job_level == "Hourly") |> select(gender, rating)), 1)
record("rat_hourly_f3", hr_dist["Female", "3"])
record("rat_hourly_m3", hr_dist["Male", "3"])
record("rat_hourly_f4", hr_dist["Female", "4"])
record("rat_hourly_m4", hr_dist["Male", "4"])
record("rat_hourly_p_holm", lvl$p_holm[lvl$job_level == "Hourly"])

# No promotion data. If promotions favor one group, controlling for job level
# absorbs part of the gap, so the within-level odds ratio may understate it.
say("Limit: no promotion history, so job level may itself carry part of any gap.")
