# Question from the talent acquisition lead: which recruiting channel brings in the
# best sales hires, so the budget can move toward it?

section("Recruiting: data checks")
rec_raw <- load_csv("recruitment_data.csv")
stop_if(nrow(rec_raw) != 446, "recruitment_data: expected 446 rows")
stop_if(any(is.na(select(rec_raw, -recruiting_source))), "missing values outside recruiting_source")
rec <- rec_raw |>
  mutate(untracked = is.na(recruiting_source),
         # Kept as its own group. Dropping these rows silently would hide the biggest finding.
         source = coalesce(recruiting_source, "Not recorded"))
n_untracked <- sum(rec$untracked)
say("Hires: ", nrow(rec), " | no source recorded: ", n_untracked, " (", pct(mean(rec$untracked), 0), ")")
record("rec_hires", nrow(rec))
record("rec_untracked", n_untracked)
record("rec_tracked_share", mean(!rec$untracked))
record("rec_untracked_share", mean(rec$untracked))
record("rec_tracked", sum(!rec$untracked))

section("Recruiting: the quick read (all hires, untracked shown as a channel)")
quick <- rec |> group_by(source) |>
  summarize(n = n(), quota = mean(sales_quota_pct), attrition = mean(attrition), rating = mean(performance_rating)) |>
  arrange(desc(quota))
print(quick)
say("On average quota, the top \"channel\" is: ", quick$source[1])
# Fisher instead of chi-squared: Search Firm has 10 hires, and its expected leaver count is under 5.
set.seed(2026)
quick_att_p <- fisher.test(table(rec$source, rec$attrition), simulate.p.value = TRUE, B = 1e5)$p.value
say("Attrition differs by channel, all hires (Fisher, simulated): p = ", fmt_p(quick_att_p))

section("Recruiting: are untracked hires a random gap, or a different group?")
grp <- rec |> group_by(untracked) |>
  summarize(n = n(), quota = mean(sales_quota_pct), attrition = mean(attrition), rating = mean(performance_rating))
print(grp)
t_quota <- t.test(sales_quota_pct ~ untracked, data = rec)
att_tab <- table(rec$untracked, rec$attrition)
p_att <- chisq.test(att_tab)$p.value
say(sprintf("Quota, untracked minus tracked: %+.2f (95%% CI %+.2f to %+.2f), p = %s",
            # t.test orders the groups FALSE then TRUE, so its difference is tracked minus untracked. Flipped here.
            t_quota$estimate[2] - t_quota$estimate[1], -t_quota$conf.int[2], -t_quota$conf.int[1], fmt_p(t_quota$p.value)))
say("Attrition, untracked vs tracked: ", pct(grp$attrition[grp$untracked], 0), " vs ",
    pct(grp$attrition[!grp$untracked], 0), ", p = ", fmt_p(p_att))
record("rec_untracked_quota", grp$quota[grp$untracked])
record("rec_tracked_quota", grp$quota[!grp$untracked])
record("rec_untracked_quota_p", t_quota$p.value)
record("rec_untracked_attrition", grp$attrition[grp$untracked])
record("rec_tracked_attrition", grp$attrition[!grp$untracked])
record("rec_untracked_attrition_p", p_att)

section("Recruiting: channels compared on tracked hires only")
tracked <- filter(rec, !untracked)
ch <- tracked |> group_by(source) |>
  summarize(n = n(),
            quota = mean(sales_quota_pct),
            quota_lo = t.test(sales_quota_pct)$conf.int[1],
            quota_hi = t.test(sales_quota_pct)$conf.int[2],
            rate_ci(attrition) |> select(attrition = rate, att_lo = lo, att_hi = hi)) |>
  arrange(desc(quota))
print(ch)
grp_ci <- rec |> group_by(source = if_else(untracked, "No source recorded", "All tracked hires")) |> summarize(rate_ci(attrition))
write_csv(bind_rows(grp_ci, ch |> transmute(source, n, rate = attrition, lo = att_lo, hi = att_hi)), "outputs/chart_attrition_by_source.csv")
p_quota_ch <- summary(aov(sales_quota_pct ~ source, data = tracked))[[1]][["Pr(>F)"]][1]
p_quota_kw <- kruskal.test(sales_quota_pct ~ source, data = tracked)$p.value
p_att_ch <- fisher.test(table(tracked$source, tracked$attrition))$p.value
say("Quota by channel: ANOVA p = ", fmt_p(p_quota_ch), " | Kruskal-Wallis p = ", fmt_p(p_quota_kw))
say("Attrition by channel (Fisher exact): p = ", fmt_p(p_att_ch))
record("rec_channels", nrow(ch))
record("rec_channel_quota_p", p_quota_ch)
record("rec_channel_attrition_p", p_att_ch)
sf <- ch[ch$source == "Search Firm", ]
record("rec_search_firm_n", sf$n)
record("rec_search_firm_quota_lo", sf$quota_lo)
record("rec_search_firm_quota_hi", sf$quota_hi)

section("Recruiting: headline tests, Holm-adjusted as one family")
fam <- tibble(
  test = c("Untracked vs tracked, quota", "Untracked vs tracked, attrition",
           "Channels differ on quota (tracked)", "Channels differ on attrition (tracked)"),
  p = c(t_quota$p.value, p_att, p_quota_ch, p_att_ch)
) |> mutate(p_holm = p.adjust(p, "holm"))
print(fam)
record("rec_holm_untracked_quota", fam$p_holm[1])
record("rec_holm_untracked_attrition", fam$p_holm[2])
