# Decisions

Each entry: what I had to choose, the options, what I picked, and what it cost.

## 1. Two cases in depth instead of five side by side

- **Options:** answer all five questions the data supports (recruiting, engagement, new-hire pay, ratings, accidents) at equal depth, or pick the ones where checking changes the answer.
- **Picked:** accidents and recruiting as the lead cases, ratings as a careful third, engagement and pay as short checks.
- **Why:** in accidents and recruiting the quick read points at the wrong fix, and each ends in one action an owner can take. Engagement holds up under checks, and pay comes back as no premium I could detect. Each fits in a paragraph.
- **Gave up:** breadth. A reader looking for a full tour of the data won't find it here.

## 2. Untracked hires stay in as their own group

- **Options:** (a) drop the 205 hires with no source, (b) fold them into an "Other" channel, (c) keep them as a separate group and test whether they differ from tracked hires.
- **Picked:** (c).
- **Why:** (a) assumes the gap is random, and it isn't: untracked hires leave at 13% against 28%. (b) makes "Other" the best channel. Testing them as a group is what shows the channel ranking can't be trusted yet.
- **Gave up:** a clean channel ranking. The honest answer is "not yet".

## 3. Paired tests for the accident data

- **Options:** compare 2016 and 2017 as two independent groups (chi-squared, plain logistic regression), or as the same people measured twice.
- **Picked:** paired. McNemar's test for rates, and logistic regression with standard errors clustered by employee.
- **Why:** all 1,470 employees appear in both years and none changed site, so the test should use that pairing.
- **Gave up:** nothing on this data. The unpaired test gives the same answer (p = 0.002 either way).

## 4. A what-if breakdown instead of only a regression for accidents

- **Options:** (a) regress accidents on year and disengagement and read the year coefficient, (b) recompute 2017 with each site's 2016 share of disengaged staff and compare with the actual rate.
- **Picked:** (b) as the headline, with a model-based version of the same what-if as a check.
- **Why:** (b) answers the question the safety lead asks, "how much of the rise is disengagement?", in the same units as the rise. A regression coefficient needs translating.
- **Gave up:** the breakdown holds each group's 2017 accident rate fixed, so it assumes engaged and disengaged staff would have had the same 2017 rates whatever the mix. The model-based check gives the same picture at the companywide level and a lower share at Southfield (12% against 26%), so I report the range.

## 5. The usual 4+ line for "high performer", not tuned

- **Options:** pick the cutoff that shows the clearest gap, use the average rating, or use the usual "high performer" line on a 5-point scale (4 or 5) and show every other cutoff next to it.
- **Picked:** the 4+ line, with 2+, 3+ and 5+ reported alongside.
- **Why:** choosing a line after seeing the data is the easiest way to manufacture a gap. Showing all four lets a reader see that the gap exists only at 4+.
- **Gave up:** a simpler chart. And with all four cutoffs counted, the 4+ result is p = 0.054 after correction, which I report.

## 6. Job level as a control, with a warning

- **Options:** compare ratings by gender raw, or within job level.
- **Picked:** within job level, and say what that misses.
- **Why:** men sit more often in salaried and manager roles, where top ratings are common, so the raw gap mixes two things. But if promotion itself is uneven, controlling for level hides part of a real gap. Without promotion data I can't tell which, so the 1.38 is reported as possibly understating the gap.
- **Gave up:** a single clean number.

## 7. Robust standard errors on pay

- **Options:** classical standard errors, or heteroskedasticity-robust ones (HC3).
- **Picked:** HC3.
- **Why:** residual spread differs by job level (about $6,600 for salaried staff, $11,600 for managers), which breaks the equal-spread assumption behind classical standard errors. HC3 doesn't rely on it.
- **Gave up:** nothing here. Classical and HC3 agree ($783, p = 0.13), which is worth knowing.

## 8. Holm adjustment within each set of related tests

- **Options:** no correction, a correction across every test in the repo, or a correction within each set of tests that answer one question.
- **Picked:** five sets: the accident headline tests, the four sites, the recruiting headline tests, the four rating cutoffs and the three job levels. Raw and adjusted values side by side.
- **Why:** each set answers one question for one owner. One correction across everything would mix unrelated questions and push borderline results further out. Not correcting at all would let chance results through.
- **Gave up:** two results fall just short after correction (untracked hires' quota, p = 0.057, and the 4+ ratings gap, p = 0.054). I report them as signals, and the recruiting recommendation rests on attrition, which holds at p < 0.001.

## 9. Download the data instead of committing it

- **Options:** commit the eight CSVs, or download them on each run.
- **Picked:** download, with a checksum per file.
- **Why:** the data's terms don't clearly allow redistribution. The checksum stops the run if the hosted files change, because every quoted number depends on these exact rows.
- **Gave up:** the repo needs a network connection to run, and breaks if the files move. The URLs worked on Nov 11, 2026.

## 10. The README's numbers are tested

- **Options:** write numbers into the README by hand, or check them against the code.
- **Picked:** the numbers the README and the card quote are recorded by the scripts in `outputs/key_numbers.csv` and mapped in `tests/readme_numbers.csv`. CI fails if the two disagree, or if a fresh run changes the committed numbers file. Chart text and DECISIONS.md are checked by hand.
- **Why:** a README that drifts from its code can't be trusted, and nobody notices until a number is questioned.
- **Gave up:** a README edit now needs the map updated too.
