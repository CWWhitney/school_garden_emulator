# Gaussian-process emulator of a NIFAM school garden model

This repository shows how to replace a slow Monte Carlo decision model with a fast statistical stand-in, called an emulator. The model is the school garden decision model from [nifam_codas_school_garden](https://github.com/CWWhitney/nifam_codas_school_garden). The emulator is a Gaussian process fitted with the R package `DiceKriging`.

## What it does

1. Runs the full model (84 uncertain inputs) and keeps the output `NPV_garden`, the net present value of a garden at a public school.
2. Screens the inputs by rank correlation and keeps the 8 that matter most.
3. Fits a Gaussian process on 150 model runs.
4. Tests it on 5,000 runs it has never seen.
5. Draws 1 million emulated outcomes.

## Result (seed 42)

| Check | Value |
|---|---|
| R² on held-out runs | 0.95 |
| RMSE (output SD is 1143) | 265 |
| 95% prediction interval coverage | 92% |
| Chance that NPV is above zero | model 0.636, emulator 0.638 |
| Time for 1 million draws | emulator 28 s, model about 245 s (extrapolated) |

![Emulator check](figures/emulator_check.png)

## Value of information for the garden decision

`evppi.R` uses the emulator to ask what is worth learning before the school decides. NPV_garden is the gain over doing nothing, so the garden is chosen when expected NPV is above zero (here 629, so build it).

| Quantity | Value (seed 42) |
|---|---|
| EVPI (perfect knowledge of everything) | 129 per garden |
| EVPPI `school_event_value` | 97 (75% of EVPI) |
| EVPPI `if_community_likes` | 18 (14%) |
| EVPPI `school_event_freq` | 4 (3%) |
| EVPPI of the other five kept inputs | 0 |

Costs are well enough known; what the garden earns from school events and whether the community likes it are what to research first. Results are in `evppi_results.csv` and `figures/evppi.png`.

Limits: EVPPI is only computed for the 8 screened inputs, so inputs dropped by the screen count as zero. The nested estimate is not checked against the full model, and it is slightly biased upward by inner-loop sampling.

## What it is not

- The model here is fast already, so the speed gain is small (about 9 times). The gain grows with slower models, which is where emulators are useful.
- The emulator is fitted to one output. Each output needs its own fit.
- Screening by rank correlation can miss inputs that matter only through interactions. A variance-based screen is the next step.
- Prediction intervals are slightly too narrow (92% instead of 95%).

## Run it

```r
install.packages(c("decisionSupport", "DiceKriging"))
source("emulator.R")
```

## Files

- `emulator.R`: the emulator workflow.
- `evppi.R`: EVPI and EVPPI with the emulator.
- `model_school_garden.R`, `functions/`, `data/inputs_school_garden.csv`: copies of the original model and inputs.
- `figures/emulator_check.png`, `emulator_results.csv`: outputs.

## Citation

See `CITATION.cff`. The model is by the NIFAM CoDAS school garden team; see the original repository.

## Licence

MIT.
