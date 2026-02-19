# Fast First Cut: The Gallagher Amendment and Local Fiscal Policy

## Background

Colorado's Gallagher Amendment (1982) fixes the statewide residential share of total assessed value at 45% by adjusting the residential assessment ratio (RAR) annually. Because statewide residential property values grew faster than non-residential values after 1982, the RAR declined steadily from 21% to under 7%. The non-residential assessment ratio (NRAR) stayed fixed at 29%.

This creates county-level variation: jurisdictions with a high initial share of residential property value experienced larger declines in their effective assessment ratio (and thus tax base) than jurisdictions with more commercial property. The instrument `gallagher` constructed in the databuild exploits this by interacting the statewide RAR/NRAR time series with each county's *1980* residential value share, eliminating endogenous composition responses.

## Available Data

The panel covers 63 Colorado counties from roughly 1980--2005. Key variables already constructed in `derived/sample.Rds`:

| Variable | Description |
|---|---|
| `gallagher` | Instrument: $\theta_{c,1980} \times RAR_t + (1-\theta_{c,1980}) \times NRAR_t$ |
| `eff_ar` | Actual effective assessment ratio (uses contemporaneous $\theta_{ct}$) |
| `revenue`, `revenue_pcap` | County property tax revenue (total and per capita) |
| `tax_rate` | County mill levy / 1000 |
| `tax_rate_res` | Effective residential tax rate ($\text{tax\_rate} \times RAR_t$) |
| `mkt_val_total`, `_resi`, `_other` | Implied market values by type |
| `val_share_resi` | Residential share of total market value |
| `hpi` | FHFA county-level house price index (deflated) |
| `permits_tot`, `permits_sf` | Building permits (total and single-family) |
| `pop`, `pop_1980` | Population (current and baseline) |

## Research Questions

### Q1: Fiscal responses to assessment-ratio shocks

**Question.** When counties lose tax base due to declining RAR, how do they adjust? Do they raise mill levies, cut spending, or both?

**Identification.** The Gallagher instrument provides plausibly exogenous variation in the effective assessment ratio. Counties with high 1980 residential shares get "treated" more intensely as the RAR falls. With county and year fixed effects, identification comes from within-county changes in the predicted effective assessment ratio driven by statewide RAR movements interacted with the fixed 1980 composition.

**Estimating equations.** IV regressions of the form already in `estimate.R`:

$$Y_{ct} = \beta \cdot \widehat{\text{eff\_ar}}_{ct} + \alpha_c + \gamma_t + \varepsilon_{ct}$$

where `eff_ar` is instrumented by `gallagher`. Outcomes $Y$:

- `tax_rate_ln` (mill levy response)
- `revenue_ln` and `revenue_pcap` (net revenue effect)

**Fast first cut.**

1. Run the existing IV specifications in `estimate.R` and tabulate first-stage F-stats.
2. Add a reduced-form plot: regress each outcome on `gallagher_ln` with county + year FEs and plot coefficients, or simply plot mean outcomes over time for high- vs. low-residential-share counties (already partially done in `plot.R`).
3. Check robustness to dropping small/outlier counties and to different weighting schemes (unweighted vs. pop-weighted).

### Q2: Land use and development responses

**Question.** Does the Gallagher-driven fiscal pressure change the composition of new development? Jurisdictions facing revenue losses from residential growth have an incentive to tilt land use toward commercial uses. Do we see fewer residential building permits in counties more exposed to the Gallagher shock?

**Identification.** Same instrument. The prediction is that counties with higher 1980 residential shares---which lose more revenue per unit of new residential construction---should see relatively fewer residential permits over time.

**Estimating equations.**

$$\text{permits\_tot\_pcap}_{ct} = \beta \cdot \widehat{\text{eff\_ar}}_{ct} + \alpha_c + \gamma_t + \varepsilon_{ct}$$

and similarly for `permits_sf` (single-family permits) per capita. A positive $\beta$ means that a decline in the effective assessment ratio (more Gallagher pressure) reduces permitting.

**Fast first cut.**

1. Descriptive: plot mean permits per capita (total and single-family) over time for high- vs. low-residential-share counties. This is a simple extension of the existing `plot.R` plots.
2. Estimate the IV regression above. Also estimate a reduced-form regression of permits on `gallagher_ln` directly.
3. Check whether the ratio `permits_sf / permits_tot` shifts---i.e., does the *composition* of permits change even if levels don't?
4. Note: building permit data coverage should be checked. If it starts later than 1980, the pre-period for descriptive comparisons may be short.

### Q3: Capitalization of taxes and spending into home prices

**Question.** Do home prices reflect the fiscal changes induced by the Gallagher Amendment? Specifically: all homeowners in the state face the same RAR decline (same tax-rate cut), but homeowners in high-residential-share counties experience a larger cut in local spending. If home prices in those counties decline *relative* to other counties, it suggests the spending cut is valued more than the (common) tax cut---implying spending was at or below the efficient level.

**Identification.** Two complementary approaches:

*Approach A: Effective assessment ratio on HPI.* IV regression of `hpi_ln` on `eff_ar`, instrumenting with `gallagher`. This is already partially implemented. A positive coefficient means that counties forced into lower assessment ratios see lower home prices---consistent with the spending channel dominating.

*Approach B: Effective residential tax rate on HPI.* IV regression of `hpi_ln` on `tax_rate_res_ln`, instrumenting with `rar_ln` or `gallagher_ln`. This more directly asks: does a lower effective tax rate raise or lower home prices? Standard Tiebout logic says a tax cut raises prices, but if the associated spending cut is too large, prices could fall. This is already coded in `estimate.R`.

**Fast first cut.**

1. Run both IV specifications and report. The key interpretive question is the sign and magnitude of the HPI coefficient.
2. Descriptive: plot mean HPI over time for high- vs. low-residential-share counties. Divergence after 1982 would be suggestive.
3. Check whether HPI data coverage aligns with the assessment-rate panel. The FHFA HPI may not start until the mid-1990s for many counties, which limits the pre-Gallagher comparison period. If so, focus on the post-1982 period and rely on the cross-sectional variation in exposure intensity.
4. Interpretation note: a *negative* coefficient on the effective tax rate (lower tax rate $\to$ lower home prices) is the "smoking gun" for spending being too low. A *positive* coefficient is the standard result. A zero is ambiguous.

## Implementation Plan

### Step 1: Verify and extend the descriptive analysis

Extend `plot.R` to add:
- Permits per capita (total and SF) by high/low residential-share group over time.
- HPI by high/low residential-share group over time.
- A "first-stage" visual: plot the mean effective assessment ratio over time by group, confirming divergence after 1982.

### Step 2: Consolidate IV estimates

Extend `estimate.R` to run a single IV specification across all outcomes:

| Outcome | Expected sign on $\widehat{\text{eff\_ar}}$ | Interpretation |
|---|---|---|
| `revenue_ln` | + | Revenue falls when assessment ratio falls |
| `revenue_pcap` | + | Same, per capita |
| `tax_rate_ln` | - | Mill levies rise to partially offset |
| `mkt_val_total_ln` | ? | Ambiguous: depends on assessor behavior |
| `mkt_val_resi_ln` | + or 0 | Residential values set by market |
| `mkt_val_other_ln` | - | Non-res "values" may be inflated by assessors |
| `val_share_resi` | + | Mechanical: RAR falls, residential share falls |
| `hpi_ln` | + or - | Key test for capitalization |
| `permits_tot_pcap` | + | Fewer permits when fiscal pressure increases |
| `permits_sf / permits_tot` | + | Composition shifts away from residential |

Report first-stage F-statistics and produce a single summary table.

### Step 3: Reduced-form event study

Estimate a dynamic version to check for pre-trends and trace out the time path of effects:

$$Y_{ct} = \sum_{\tau} \beta_\tau \cdot (\theta_{c,1980} \times \mathbf{1}[t = \tau]) + \alpha_c + \gamma_t + \varepsilon_{ct}$$

where $\theta_{c,1980}$ is the 1980 residential value share (continuous treatment intensity). This is a continuous-treatment DiD / event study. The coefficients $\beta_\tau$ trace out how outcomes diverge between high- and low-residential-share counties over time, relative to a base year (e.g., 1982). Pre-1982 coefficients should be near zero if the parallel-trends assumption holds.

### Step 4: Robustness

- Unweighted vs. population-weighted.
- Drop Denver (large outlier).
- Cluster standard errors at the county level (already done).
- Check sensitivity to different base years for the residential share (1980 vs. 1982).

## Potential Complications

1. **Assessor behavior.** The "implied market values" ($\text{assessed} / \text{rate}$) assume assessors apply the statutory rate uniformly. If assessors strategically over- or under-assess certain property types, the implied market values are mismeasured. This matters most for interpreting the `mkt_val_other` results.

2. **TABOR (1992).** Colorado's Taxpayer Bill of Rights imposed additional revenue limits starting in 1992. This interacts with Gallagher: counties may be constrained from raising mill levies even if they want to. Consider splitting the sample at 1992 or including a TABOR interaction.

3. **Broomfield County.** Created in 2001 from parts of four counties. Already excluded from the panel---just confirm this doesn't create composition issues in the later years.

4. **HPI coverage.** The FHFA county-level HPI may have limited coverage for rural Colorado counties. Check how many counties have HPI data and whether the sample for Q3 is representative.

5. **Gallagher repeal (2020).** Amendment B repealed Gallagher in 2020, but the current data only extends to ~2005, so this isn't a concern for the first cut.
