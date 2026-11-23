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

## Emulators for contested decisions (EVCA)

`emulator_evca.R` builds one Gaussian process per account of the garden and asks whether the accounts disagree about what to do. It uses the [`evca`](https://github.com/CWWhitney/26_ev_ambiguity) package and follows the logic of expected value of contested accounts (EVCA): each account stays in its own units, options are dropped only if every account ranks another option higher, and EVCA is reported only for options that remain contested.

Accounts here are the model's budget (NPV), child health value and ecological value outputs. Options are no garden, a garden, and a STEM garden.

| Account | Emulator R² (held-out runs) |
|---|---|
| Budget, garden | 0.94 |
| Budget, STEM garden | 0.82 |
| Child health | 0.41 and 0.35 |
| Ecology | 0.40 |

**Result.** A garden beats both other options in every account, so the Pareto step leaves one option and EVCA is zero for the full model and the emulator. There is nothing to negotiate inside this model.

**Why, and what this does not show.** The accounts are three outputs of one model, and the model already puts health and ecology into money. That is one world with several terms, not several incommensurable worlds, so agreement is built in. A real EVCA needs a separate causal model for each world, built with the people who hold it, with its own variables and units (for example, a school's educational aims or a community's land values). The script is ready for that: replace the `outputs` list with the outputs of each world's model. The health and ecology emulators are also weak (R² about 0.4), so they would need more training runs or better screening before any decision use. The `health` output is also set to zero when a public school has no land, even for the private-school garden; this coupling in the model should be checked.

## The single-output emulator

`emulator.R` is the first version, fitted to `NPV_garden` alone. It is a speed-up demonstration. It treats the decision as one number in one currency, which is the limitation the EVCA version addresses.

## What it is not

- The model here is fast already, so the speed gain is small (about 9 times). The gain grows with slower models, which is where emulators are useful.
- The emulator is fitted to one output. Each output needs its own fit.
- Screening by rank correlation can miss inputs that matter only through interactions. A variance-based screen is the next step.
- Prediction intervals are slightly too narrow (92% instead of 95%).

## Run it

```r
install.packages(c("decisionSupport", "DiceKriging"))
devtools::install_github("CWWhitney/26_ev_ambiguity")
source("emulator.R")        # single-output emulator
source("emulator_evca.R")   # one emulator per account, then EVCA
```

## Files

- `emulator.R`: single-output emulator.
- `emulator_evca.R`: one emulator per account and the EVCA step.
- `model_school_garden.R`, `functions/`, `data/inputs_school_garden.csv`: copies of the original model and inputs.
- `figures/emulator_check.png`, `emulator_results.csv`: outputs.

## Citation

See `CITATION.cff`. The model is by the NIFAM CoDAS school garden team; see the original repository.

## Licence

MIT.
