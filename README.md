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

- `emulator.R`: the whole workflow.
- `model_school_garden.R`, `functions/`, `data/inputs_school_garden.csv`: copies of the original model and inputs.
- `figures/emulator_check.png`, `emulator_results.csv`: outputs.

## Citation

See `CITATION.cff`. The model is by the NIFAM CoDAS school garden team; see the original repository.

## Licence

MIT.
