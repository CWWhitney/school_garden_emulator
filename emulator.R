# Gaussian-process emulators of the NIFAM school garden decision model
# One emulator per garden option. Run from the repository root: source("emulator.R")

suppressMessages({library(decisionSupport); library(DiceKriging)})
source("model_school_garden.R")   # defines school_garden_function

# Garden options, each an NPV in million VND over 5 years compared with doing nothing:
# passive (no STEM) or STEM education, at a school with or without the public-school
# risk that land is unsuitable or bureaucratic barriers stop the garden
targets <- c("NPV_garden", "NPV_garden_STEM",
             "NPV_garden_public_school", "NPV_garden_STEM_public_school")
n_train <- 800                    # model runs used to fit each emulator
n_test  <- 5000                   # held-out model runs used to check each emulator
n_keep_each <- 5                  # inputs kept per option (the union is used)

# 1. Run the full model ####
set.seed(42)
inputs <- estimate_read_csv("data/inputs_school_garden.csv")
run <- function(n) mcSimulation(inputs, school_garden_function,
                                numberOfModelRuns = n, functionSyntax = "plainNames")
t_model <- system.time(mc <- run(n_train + n_test))["elapsed"]
X <- mc$x[, sapply(mc$x, function(z) length(unique(z)) > 1)]   # drop constants
Y <- mc$y[, targets]

idx_train <- 1:n_train
idx_test  <- n_train + 1:n_test

# 2. Screen with Sobol total-effect indices (variance based) ####
# Run the full model on pick-freeze samples: A, B and A with column i taken from B (Saltelli 2010, Jansen 1999).
# The model has internal randomness (vv, chance_event), so the noise variance is estimated from
# repeat runs and subtracted from the total-effect index.
Xfull <- mc$x
set.seed(99)
n_sobol <- 600                                      # base sample size; model runs = n_sobol * (k + 3)
A <- Xfull[sample(nrow(Xfull), n_sobol), names(X)]
B <- Xfull[sample(nrow(Xfull), n_sobol), names(X)]
base <- Xfull[1, , drop = FALSE]
run_rows <- function(M) {                           # run the full model on given input rows; one column per option
  out <- matrix(NA_real_, nrow(M), length(targets), dimnames = list(NULL, targets))
  for (r in seq_len(nrow(M))) {
    v <- base; v[names(M)] <- M[r, ]
    list2env(as.list(v), envir = globalenv())
    out[r, ] <- unlist(school_garden_function()[targets])
  }
  out
}
fA <- run_rows(A); fB <- run_rows(B); fA2 <- run_rows(A)
V <- apply(rbind(fA, fB), 2, var)
noise <- colMeans((fA - fA2)^2) / 2                 # variance from internal randomness
ST <- S1 <- matrix(0, ncol(A), length(targets), dimnames = list(names(A), targets))
for (i in names(A)) {
  ABi <- A; ABi[[i]] <- B[[i]]
  f <- run_rows(ABi)
  ST[i, ] <- (colMeans((fA - f)^2) / 2 - noise) / V
  S1[i, ] <- colMeans(fB * (f - fA)) / V
}
sobol <- data.frame(input = rownames(ST),
                    setNames(as.data.frame(round(S1, 3)), paste0("S1_", targets)),
                    setNames(as.data.frame(round(ST, 3)), paste0("ST_", targets)),
                    row.names = NULL)
sobol <- sobol[order(-apply(ST, 1, max)), ]
write.csv(sobol, "sobol_indices.csv", row.names = FALSE)
cat("\nShare of output variance from internal randomness:\n"); print(round(noise / V, 3))
keep <- unique(unlist(lapply(targets, function(t) names(sort(ST[, t], decreasing = TRUE))[1:n_keep_each])))
cat("\nInputs kept:", paste(keep, collapse = ", "), "\n")

# 3. Fit one Gaussian process per option on the training runs ####
fits <- lapply(targets, function(t)
  km(~1, design = X[idx_train, keep, drop = FALSE], response = Y[idx_train, t],
     covtype = "matern5_2", nugget.estim = TRUE, control = list(trace = FALSE)))
names(fits) <- targets

# 4. Check them on runs they have never seen ####
preds <- lapply(targets, function(t)
  predict(fits[[t]], newdata = X[idx_test, keep, drop = FALSE], type = "UK"))
names(preds) <- targets
metrics <- do.call(rbind, lapply(targets, function(t) {
  obs <- Y[idx_test, t]; p <- preds[[t]]
  data.frame(option = t,
             R2 = 1 - sum((p$mean - obs)^2) / sum((obs - mean(obs))^2),
             RMSE = sqrt(mean((p$mean - obs)^2)),
             output_SD = sd(obs),
             coverage95 = mean(obs >= p$lower95 & obs <= p$upper95),
             p_positive_model = mean(obs > 0),
             p_positive_emulator = mean(p$mean > 0))
}))
print(metrics, digits = 3, row.names = FALSE)

# 5. Use it: 1 million draws from the emulator of the first option ####
pred_mean <- function(fit, newdata, chunk = 20000) {   # predicts in chunks to limit memory
  unlist(lapply(split(seq_len(nrow(newdata)), ceiling(seq_len(nrow(newdata)) / chunk)), function(i)
    predict(fit, newdata = newdata[i, , drop = FALSE], type = "UK", checkNames = FALSE,
            light.return = TRUE)$mean), use.names = FALSE)
}
set.seed(7)
big <- as.data.frame(lapply(X[, keep, drop = FALSE], function(v) sample(v, 1e6, replace = TRUE)))
t_emul <- system.time(big_pred <- pred_mean(fits[[1]], big))["elapsed"]
t_model_1e6 <- unname(t_model) / (n_train + n_test) * 1e6
cat(sprintf("\n1e6 runs of one option: model about %.0f s, emulator %.0f s\n", t_model_1e6, t_emul))

# 6. Figures ####
dir.create("figures", showWarnings = FALSE)
png("figures/emulator_check.png", 1400, 1300, res = 150)
par(mfrow = c(2, 2), mar = c(4.5, 4.5, 3, 1))
for (t in targets) {
  plot(Y[idx_test, t], preds[[t]]$mean, pch = 16, cex = 0.4, col = "#00000044",
       xlab = "Full model NPV (million VND)", ylab = "Emulator NPV (million VND)",
       main = sprintf("%s (R2 = %.2f)", sub("NPV_", "", t), metrics$R2[metrics$option == t]),
       cex.main = 0.9)
  abline(0, 1, col = "red", lwd = 2)
}
dev.off()

write.csv(metrics, "emulator_results.csv", row.names = FALSE)
