# Two shorter checks. Engagement gives context for the accidents case. New-hire pay
# answers a compensation question with a "no premium detected" result, which is
# worth reporting because not significant does not mean zero.

section("Also checked: engagement by department")
sv <- load_csv("survey_data.csv")
check_keys(sv, "employee_id", "survey_data", 1470)
sv <- mutate(sv, sales = department == "Sales")
print(sv |> group_by(department) |>
        summarize(n = n(), avg_engagement = mean(engagement), disengaged = mean(engagement <= 2),
                  avg_vacation = mean(vacation_days_taken)))
sens <- lapply(1:3, function(k) {
  d <- mutate(sv, y = as.integer(engagement <= k))
  m <- glm(y ~ sales + I(salary / 10000) + vacation_days_taken, family = binomial, data = d)
  filter(or_rows(m), term == "salesTRUE") |> mutate(disengaged_if = paste0("score <= ", k), .before = 1)
}) |> bind_rows()
say("Sales vs other departments, odds of disengagement, holding salary and vacation fixed, at three cutoffs:")
print(sens)
record("eng_sales_or_cut2", sens$odds_ratio[2])
record("eng_sales_or_cut2_lo", sens$lo[2])
record("eng_sales_or_cut2_hi", sens$hi[2])
record("eng_sales_or_min", min(sens$odds_ratio))
record("eng_sales_or_max", max(sens$odds_ratio))
r_vac <- cor.test(sv$vacation_days_taken, sv$engagement)
say(sprintf("Vacation days vs engagement score: r = %.2f, p = %s", r_vac$estimate, fmt_p(r_vac$p.value)))
record("eng_vacation_r", r_vac$estimate)

section("Also checked: are new hires paid more?")
pay <- load_csv("fair_pay_data.csv")
check_keys(pay, "employee_id", "fair_pay_data", 1470)
print(pay |> group_by(new_hire) |> summarize(n = n(), avg_salary = mean(salary)))
raw_t <- t.test(salary ~ new_hire, data = pay)
raw_gap <- raw_t$estimate[2] - raw_t$estimate[1]
say(sprintf("Raw gap, new minus current: %s, p = %s", usd(raw_gap), fmt_p(raw_t$p.value)))
record("pay_raw_gap", raw_gap)

mix_p <- chisq.test(table(pay$new_hire, pay$job_level))$p.value
say("Job level mix, new vs current: p = ", fmt_p(mix_p), " (no detectable difference in mix)")
record("pay_mix_p", mix_p)

within <- pay |> group_by(job_level) |>
  summarize(n_new = sum(new_hire == "Yes"),
            gap_new_minus_current = mean(salary[new_hire == "Yes"]) - mean(salary[new_hire == "No"]))
print(within)
record("pay_gap_hourly", within$gap_new_minus_current[within$job_level == "Hourly"])

# Residual spread differs by job level, which breaks the equal-spread assumption
# behind classical standard errors. HC3 doesn't need it, so I report both.
m <- lm(salary ~ new_hire + job_level, data = pay)
say("Residual SD by job level:")
print(tibble(job_level = pay$job_level, r = residuals(m)) |> group_by(job_level) |> summarize(resid_sd = sd(r)))
cls <- filter(lm_rows(m), term == "new_hireYes")
hc3 <- filter(lm_rows(m, vcovHC(m, type = "HC3")), term == "new_hireYes")
print(bind_rows(classical = cls, HC3 = hc3, .id = "errors"))
say(sprintf("New-hire premium within job level (HC3): %s (95%% CI %s to %s), p = %s, R-squared %.3f",
            usd(hc3$estimate), usd(hc3$lo), usd(hc3$hi), fmt_p(hc3$p), summary(m)$r.squared))
record("pay_premium", hc3$estimate)
record("pay_premium_lo", hc3$lo)
record("pay_premium_hi", hc3$hi)
record("pay_premium_p", hc3$p)

ml <- lm(log(salary) ~ new_hire + job_level, data = pay)
hl <- filter(lm_rows(ml, vcovHC(ml, type = "HC3")), term == "new_hireYes")
say(sprintf("Log-salary check (HC3): %+.1f%%, p = %s", 100 * (exp(hl$estimate) - 1), fmt_p(hl$p)))
record("pay_premium_log_pct", 100 * (exp(hl$estimate) - 1))
record("pay_premium_log_p", hl$p)

int_p <- anova(m, lm(salary ~ new_hire * job_level, data = pay))$`Pr(>F)`[2]
say("Does the premium differ by level (interaction F-test): p = ", fmt_p(int_p))
