# Which uncertainties matter for a school garden decision?

A school in Vietnam must decide whether to build a garden. The decision model from [nifam_codas_school_garden](https://github.com/CWWhitney/nifam_codas_school_garden) has 84 uncertain inputs and one output, `NPV_garden`: the net present value (NPV) of the garden over 5 years, in million Vietnamese dong (VND), compared with doing nothing. The school builds the garden if expected NPV is above zero.

This repository answers two questions. Which inputs drive the result? And which are worth researching before the school commits? To make the second question cheap to answer, it replaces the model with an emulator: a fast statistical model fitted to a few hundred model runs. The emulator is a Gaussian process fitted with the R package `DiceKriging`.

## Result: what to research before deciding

Expected NPV is 637 million VND, so the garden is the better choice today. Even so, NPV is below zero in 36% of model runs, and a school that knew it was in one of those cases would not build. The expected value of perfect information (EVPI) measures what that knowledge is worth. Worked example: replacing every negative NPV with zero (the outcome if the school could avoid every loss) and averaging gives 762. Subtracting today's expected NPV of 637 gives an EVPI of 125 million VND per garden. Both averages are calculated from the full model.

The expected value of partial perfect information (EVPPI) gives the same figure for one input at a time: what the school would gain by learning that input exactly before deciding.

| Input | Meaning | Total Sobol index | EVPPI from emulator (million VND) | EVPPI from full model (million VND) |
|---|---|---|---|---|
| `school_event_value` | Value of garden events (million VND per event) | 0.63 | 60 | 68 |
| `if_community_likes` | Chance of community support | 0.28 | 32 | 43 |
| `school_event_freq` | Events per year | 0.19 | 9 | 8 |
| Each of the other 81 inputs | Costs, prices, rates and others | 0.014 or less | 0 for the five tested | not run |

The total Sobol index is the share of output variance that an input causes, alone and through interactions with other inputs. The three inputs above carry nearly all of it. Their total indices exceed their first-order indices (0.54, 0.19 and 0.11, which count each input alone), so they interact. A screen by rank correlation can miss such inputs; this screen does not. The school should therefore find out what garden events are worth and whether the community supports them before it spends effort on better cost estimates.

EVPPI was computed for the 8 inputs with the highest total Sobol index. Each of the other 76 has a total index of 0.002 or less, so its EVPPI is expected to be negligible.

![EVPPI of the kept inputs](figures/evppi.png)

## Result: how well the emulator reproduces the model

The emulator was fitted to 150 model runs on the 8 inputs and tested on 5,000 runs it had never seen (seed 42).

| Check | Value |
|---|---|
| R² on test runs (1 is perfect) | 0.95 |
| Root mean square error (the output standard deviation is 1,144) | 247 |
| Share of test runs inside the emulator's 95% prediction interval | 96% |
| Chance that NPV is above zero, from the model and from the emulator | 0.642 and 0.641 |
| Time for 1 million draws, emulator and model (model time extrapolated) | 22 s and 235 s |

![Emulator check](figures/emulator_check.png)

## Limits and next steps

- For the two largest inputs, the emulator EVPPI is 12% and 26% below the full-model value. Use the ranking and the order of magnitude, not the exact figures. The next step is to refit with more training runs and report the EVPPI spread across seeds.
- Both EVPPI estimates use 150 values of the input and 1,000 draws of the other inputs per value. This nested sampling biases EVPPI slightly upward.
- The full model takes about 0.2 milliseconds per run, so the emulator saves only about 10 times the compute here. An emulator pays off for slower models, such as spatial or multi-year versions of this one.
- The emulator fits one output. Another output needs its own fit.
- The Sobol screen runs the full model about 52,000 times. For a slow model it would have to run on a cheaper surrogate.

## Run it

```r
install.packages(c("decisionSupport", "DiceKriging"))
source("emulator.R")   # Sobol screen, fit and test (about 1 minute)
source("evppi.R")      # EVPI and EVPPI with a full-model check (about 20 minutes)
```

## Files

- `emulator.R`: Sobol screen, emulator fit and test.
- `evppi.R`: EVPI, EVPPI and the full-model check.
- `model_school_garden.R`, `functions/`, `data/inputs_school_garden.csv`: copies of the original model and inputs.
- `sobol_indices.csv`, `emulator_results.csv`, `evppi_results.csv`, `evppi_check.csv`, `figures/`: outputs.

## Citation

See `CITATION.cff`. The model is by the NIFAM CoDAS school garden team; see the original repository.

## License

MIT.
