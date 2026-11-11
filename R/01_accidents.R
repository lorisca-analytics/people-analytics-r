# Question from the safety lead: accidents went up from 2016 to 2017. Why, and
# should the company fund an engagement program at the site that looks worst?

section("Accidents: data checks")
hr2 <- load_csv("hr_data_2.csv")
acc <- load_csv("accident_data.csv")
sv2 <- load_csv("survey_data_2.csv")
check_keys(hr2, c("employee_id", "year"), "hr_data_2", 2940)
check_keys(sv2, c("employee_id", "year"), "survey_data_2", 2940)
check_keys(acc, c("employee_id", "year"), "accident_data", 302)
stop_if(any(!paste(acc$employee_id, acc$year) %in% paste(hr2$employee_id, hr2$year)),
        "accident rows with no matching employee-year")

safety <- hr2 |>
  left_join(acc, by = c("employee_id", "year")) |>
  left_join(sv2, by = c("employee_id", "year")) |>
  mutate(accident = as.integer(!is.na(accident_type)),
         # 1-2 on the 5-point scale counts as disengaged. Set before looking at accidents.
         disengaged = as.integer(engagement <= 2),
         serious = as.integer(accident_type %in% c("Moderate", "Severe")),
         mild = as.integer(accident_type %in% "Mild"))
stop_if(nrow(safety) != 2940, "join changed the row count")
stop_if(any(is.na(safety$engagement)), "employee-years with no engagement score")

# The tests below depend on this being a panel: the same people measured twice.
wide <- safety |>
  select(employee_id, year, location, accident, disengaged, engagement, serious, mild) |>
  pivot_wider(names_from = year, values_from = c(location, accident, disengaged, engagement, serious, mild))
stop_if(nrow(wide) != 1470, "employees do not appear exactly once per year")
moved <- sum(wide$location_2016 != wide$location_2017)
same_score <- mean(wide$engagement_2016 == wide$engagement_2017)
say("Employees in both years: ", nrow(wide), " | changed site: ", moved,
    " | same engagement score both years: ", pct(same_score))
record("acc_employees", nrow(wide))
record("acc_same_engagement_share", same_score)
dropped <- wide$engagement_2017 < wide$engagement_2016
record("acc_engagement_dropped", sum(dropped))
record("acc_engagement_rose", sum(wide$engagement_2017 > wide$engagement_2016))
say("Accident types by year:")
print(table(year = acc$year, type = acc$accident_type))

section("Accidents: is the rise real?")
by_year <- safety |> group_by(year) |> summarize(rate_ci(accident))
print(by_year)
record("acc_rate_2016", by_year$rate[by_year$year == 2016])
record("acc_rate_2017", by_year$rate[by_year$year == 2017])

# McNemar compares each person with themselves, which matches how the data was
# collected. The unpaired test below is printed only to show the two agree here.
mc_all <- mcnemar.test(table(wide$accident_2016, wide$accident_2017))
say("Paired test (McNemar), all sites: p = ", fmt_p(mc_all$p.value))
m_year <- glm(accident ~ factor(year), family = binomial, data = safety)
yr <- or_rows(m_year, vcovCL(m_year, cluster = ~employee_id))[2, ]
say(sprintf("2017 vs 2016 odds ratio, errors clustered by employee: %.2f (95%% CI %.2f to %.2f), p = %s",
            yr$odds_ratio, yr$lo, yr$hi, fmt_p(yr$p)))
record("acc_mcnemar_p", mc_all$p.value)
# For comparison only: the unpaired test the paired one replaces.
chi_unpaired <- chisq.test(table(safety$year, safety$accident))$p.value
say("Unpaired chi-squared, for comparison: p = ", fmt_p(chi_unpaired))
record("acc_unpaired_p", chi_unpaired)
record("acc_year_or", yr$odds_ratio)
record("acc_year_or_lo", yr$lo)
record("acc_year_or_hi", yr$hi)

section("Accidents: by site")
site <- safety |> group_by(location, year) |> summarize(rate_ci(accident)) |> ungroup()
site_change <- site |>
  select(location, year, rate) |>
  pivot_wider(names_from = year, values_from = rate, names_prefix = "r") |>
  mutate(pp_change = 100 * (r2017 - r2016))
site_p <- wide |>
  group_by(location = location_2016) |>
  summarize(p = mcnemar.test(table(factor(accident_2016, 0:1), factor(accident_2017, 0:1)))$p.value) |>
  mutate(p_holm = p.adjust(p, "holm"))
site_change <- left_join(site_change, site_p, by = "location") |> arrange(desc(pp_change))
print(site_change)
say("Sites where the rate went up: ", sum(site_change$pp_change > 0), " of ", nrow(site_change))
record("acc_sites_up", sum(site_change$pp_change > 0))
record("acc_sites_total", nrow(site_change))
top_site <- site_change$location[1]
record("acc_top_site_pp", site_change$pp_change[1])
record("acc_top_site_p_holm", site_change$p_holm[1])

section("Accidents: did disengagement move everywhere, or only at one site?")
dis <- safety |> group_by(location, year) |> summarize(rate_ci(disengaged)) |> ungroup()
print(dis |> select(location, year, n, disengaged = rate, lo, hi))
dis_p <- wide |>
  group_by(location = location_2016) |>
  summarize(dis_2016 = mean(disengaged_2016), dis_2017 = mean(disengaged_2017),
            changed = sum(disengaged_2016 != disengaged_2017),
            # McNemar has no answer when nobody changed. No change means no evidence of a shift.
            p = if (changed == 0) 1 else mcnemar.test(table(factor(disengaged_2016, 0:1), factor(disengaged_2017, 0:1)))$p.value)
print(dis_p)
record("acc_became_disengaged", sum(dis_p$changed))
record("acc_became_disengaged_top_site", dis_p$changed[dis_p$location == top_site])
record("acc_top_site_dis_2016", dis_p$dis_2016[dis_p$location == top_site])
record("acc_top_site_dis_2017", dis_p$dis_2017[dis_p$location == top_site])
# The tell for synthetic data: nobody's score went up, and the only changes are one step down at one site.
say("Engagement moves 2016 to 2017 (rows 2016 score, columns 2017 score):")
print(table(wide$engagement_2016, wide$engagement_2017))

section("Accidents: how much of the rise does disengagement explain?")
# Counterfactual: keep each group's 2017 accident rates, but give it the 2016 share of
# disengaged staff. The gap between that and the actual 2017 rate is the part
# of the rise that more disengagement can account for.
decompose <- function(df) {
  cells <- df |> group_by(year) |>
    summarize(share_dis = mean(disengaged),
              rate_dis = mean(accident[disengaged == 1]),
              rate_eng = mean(accident[disengaged == 0]),
              rate = mean(accident))
  y16 <- cells[cells$year == 2016, ]
  y17 <- cells[cells$year == 2017, ]
  cf <- y16$share_dis * y17$rate_dis + (1 - y16$share_dis) * y17$rate_eng
  tibble(rate_2016 = y16$rate, rate_2017 = y17$rate, rate_2017_if_engagement_held = cf,
         rise_pp = 100 * (y17$rate - y16$rate),
         explained_pp = 100 * (y17$rate - cf),
         share_explained = (y17$rate - cf) / (y17$rate - y16$rate))
}
dec_all <- decompose(safety) |> mutate(location = "All sites", .before = 1)
dec_site <- safety |> group_by(location) |> group_modify(~ decompose(.x)) |> ungroup()
dec <- bind_rows(dec_all, dec_site)
print(dec)
write_csv(dec, "outputs/chart_accident_breakdown.csv")
record("acc_cf_rate_2017", dec_all$rate_2017_if_engagement_held)
record("acc_share_explained_all", dec_all$share_explained)
record("acc_share_explained_top", dec_site$share_explained[dec_site$location == top_site])

# Second method as a check on the first: a model fitted on both years, then
# 2017 predicted with each person's 2016 engagement.
m_cf <- glm(accident ~ factor(year) * location + disengaged, family = binomial, data = safety)
s17 <- filter(safety, year == 2017)
s17_cf <- mutate(s17, disengaged = wide$disengaged_2016[match(employee_id, wide$employee_id)])
model_check <- s17 |>
  mutate(fit = predict(m_cf, s17, type = "response"),
         fit_cf = predict(m_cf, s17_cf, type = "response")) |>
  group_by(location) |>
  summarize(actual = mean(accident), predicted = mean(fit), predicted_if_engagement_held = mean(fit_cf))
say("Model-based check:")
print(model_check)
top_m <- model_check[model_check$location == top_site, ]
top_r <- dec_site[dec_site$location == top_site, ]
record("acc_share_explained_top_model", (top_m$actual - top_m$predicted_if_engagement_held) / (top_r$rate_2017 - top_r$rate_2016))

section("Accidents: did engaged staff also have more accidents?")
eng <- safety |> filter(disengaged == 0)
eng_site <- eng |> group_by(location, year) |> summarize(rate_ci(accident)) |> ungroup() |>
  select(location, year, n, rate) |>
  pivot_wider(names_from = year, values_from = c(n, rate))
print(eng_site)
m_eng <- glm(accident ~ factor(year), family = binomial, data = eng)
eng_or <- or_rows(m_eng, vcovCL(m_eng, cluster = ~employee_id))[2, ]
say(sprintf("Engaged staff only, 2017 vs 2016 odds ratio (clustered): %.2f (95%% CI %.2f to %.2f), p = %s",
            eng_or$odds_ratio, eng_or$lo, eng_or$hi, fmt_p(eng_or$p)))
record("acc_engaged_or", eng_or$odds_ratio)
record("acc_engaged_p", eng_or$p)
record("acc_engaged_or_lo", eng_or$lo)
record("acc_engaged_or_hi", eng_or$hi)
record("acc_engaged_sites_up", sum(eng_site$rate_2017 > eng_site$rate_2016))

section("Accidents: what kind of accidents rose?")
type_counts <- safety |> group_by(year) |> summarize(mild = sum(mild), moderate_or_severe = sum(serious))
print(type_counts)
write_csv(type_counts, "outputs/chart_accident_type.csv")
mc_mild <- mcnemar.test(table(wide$mild_2016, wide$mild_2017))
mc_serious <- mcnemar.test(table(wide$serious_2016, wide$serious_2017))
say("Mild, paired test: p = ", fmt_p(mc_mild$p.value),
    " | Moderate or severe, paired test: p = ", fmt_p(mc_serious$p.value))
record("acc_serious_p", mc_serious$p.value)
record("acc_mild_2016", type_counts$mild[type_counts$year == 2016])
record("acc_mild_2017", type_counts$mild[type_counts$year == 2017])
record("acc_serious_2016", type_counts$moderate_or_severe[type_counts$year == 2016])
record("acc_serious_2017", type_counts$moderate_or_severe[type_counts$year == 2017])
record("acc_added_total", sum(acc$year == 2017) - sum(acc$year == 2016))
record("acc_added_mild", type_counts$mild[type_counts$year == 2017] - type_counts$mild[type_counts$year == 2016])
# Mild rising while serious doesn't is not the same as the mix changing. This tests the mix directly.
mix_p <- chisq.test(table(acc$year, acc$accident_type == "Mild"))$p.value
say("Share of accidents that were mild: ", pct(mean(acc$accident_type[acc$year == 2016] == "Mild")), " to ",
    pct(mean(acc$accident_type[acc$year == 2017] == "Mild")), ", test of the mix: p = ", fmt_p(mix_p))
record("acc_type_mix_p", mix_p)
record("acc_mild_share_2016", mean(acc$accident_type[acc$year == 2016] == "Mild"))
record("acc_mild_share_2017", mean(acc$accident_type[acc$year == 2017] == "Mild"))

section("Accidents: overtime as a second candidate driver")
ot <- wide |> left_join(hr2 |> select(employee_id, year, overtime_hours) |>
                          pivot_wider(names_from = year, values_from = overtime_hours, names_prefix = "ot_"),
                        by = "employee_id")
ot_site <- ot |> group_by(location = location_2016) |>
  summarize(p = t.test(ot_2017, ot_2016, paired = TRUE)$p.value,
            mean_2016 = mean(ot_2016), mean_2017 = mean(ot_2017))
print(ot_site)
m_ot <- glm(accident ~ overtime_hours + factor(year), family = binomial, data = safety)
ot_link <- or_rows(m_ot, vcovCL(m_ot, cluster = ~employee_id))[2, ]
say(sprintf("Overtime and accidents, both years, clustered: odds ratio per hour %.3f, p = %s", ot_link$odds_ratio, fmt_p(ot_link$p)))
record("acc_overtime_link_p", ot_link$p)

section("Accidents: headline tests, Holm-adjusted as one family")
fam <- tibble(
  test = c("Overall rise (paired)", "Rise among engaged staff", "Mild accidents rose", "Moderate or severe rose"),
  p = c(mc_all$p.value, eng_or$p, mc_mild$p.value, mc_serious$p.value)
) |> mutate(p_holm = p.adjust(p, "holm"))
print(fam)
record("acc_holm_overall", fam$p_holm[1])
record("acc_holm_engaged", fam$p_holm[2])
record("acc_holm_mild", fam$p_holm[3])
record("acc_holm_serious", fam$p_holm[4])
