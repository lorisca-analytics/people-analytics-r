# Evidence: quick read against checked read

Each row is one claim the data seems to make at first glance, the check I ran on it, and what survived. Every number comes from `outputs/results.txt`, produced by `run_all.R`.

| Question | Quick read | Check | What survived |
|---|---|---|---|
| Is the accident rise real? | 8.5% to 12.0%, chi-squared p = 0.002 | Same 1,470 people both years, so a paired test and errors clustered by employee | Yes. Paired p = 0.002, odds ratio 1.47 (1.16 to 1.87) |
| Which site is the problem? | Southfield, +5.3 points | Paired test per site, Holm across 4 sites | No single site stands out (Southfield p = 0.15). All 4 rose |
| Is disengagement the cause? | Disengagement rose only at Southfield | Recompute 2017 with each site's 2016 disengagement share, plus a model-based version | About 3% of the companywide rise. Between an eighth and a quarter of Southfield's (12% to 26% by two methods) |
| Did engaged staff stay safe? | Not checked in the quick read | Engaged staff only, 2017 vs 2016 | No. Odds ratio 1.53 (1.14 to 2.05), up at all 4 sites |
| What kind of accidents rose? | Not checked in the quick read | Split by type, paired tests, test of the mix | Mild 87 to 136 (p < 0.001). Moderate or severe 38 to 41 (p = 0.82). The mix shift itself is p = 0.20, so a lead to check |
| Overtime? | A natural second suspect | Paired change in overtime per site, overtime against accidents | No significant change at any site, no link to accidents (p = 0.82) |
| Best recruiting channel? | "Not recorded" on quota, and attrition differs by channel (p < 0.001) | Untracked vs tracked first, then channels on tracked hires only, Fisher's exact test | Untracked hires are a different group (attrition 13% vs 28%). Channels don't differ (attrition p = 0.27, quota p = 0.55) |
| Ratings gap by gender? | 32.5% vs 21.5% rated 4+ | Within job level, Mantel-Haenszel, every cutoff, each level, Holm | 1.38 within level (p = 0.013) at the 4+ line only. 0.054 after correcting across cutoffs. No detectable difference by level (p = 0.59). A signal for review |
| New-hire pay premium? | $2,650 more (p = 0.019) | Within job level, HC3 errors, log salary | No premium detected: $783 (-$235 to $1,800), p = 0.13 |
| Does vacation drive engagement? | Sales takes fewer vacation days and is less engaged | Correlation of vacation and engagement | No link (r = -0.01). Dropped as a driver |

## What changed from an earlier version

An earlier version of this analysis answered the same questions with the quick-read column above, plus some confounder checks. Going back over it, I found:

- The sign of the hourly pay gap was backward. New hires in hourly roles earn $1,107 more, not less.
- A chart title said new hires skew toward higher job levels. The difference in mix isn't significant (p = 0.16), so the title was claiming something the data doesn't show.
- It said attrition differs by recruiting source. That result comes entirely from the untracked group.
- It said disengagement explained Southfield's share of the rise. It explains between an eighth and a quarter of it.
- It applied a multiple-testing correction only to the site tests, while listing it as a general check in the write-up.

I fixed each one in this version, and the tests in `tests/` now stop the README from drifting away from the code.
