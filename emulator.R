# Gaussian-process emulator of the NIFAM school garden decision model
# Run from the repository root: source("emulator.R")

suppressMessages({library(decisionSupport); library(DiceKriging)})
source("model_school_garden.R")   # defines school_garden_function

target <- "NPV_garden"            # output to emulate (NPV of a garden at a public school)
n_train <- 150                    # model runs used to fit the emulator
n_test  <- 5000                   # held-out model runs used to check it
n_screen <- 0                     # no separate screening runs: the Sobol screen runs the model itself
n_keep  <- 8                      # inputs kept in the emulator

# 1. Run the full model ####
set.seed(42)
inputs <- estimate_read_csv("data/inputs_school_garden.csv")
run <- function(n) mcSimulation(inputs, school_garden_function,
                                numberOfModelRuns = n, functionSyntax = "plainNames")
t_model <- system.time(mc <- run(n_screen + n_train + n_test))["elapsed"]
X <- mc$x[, sapply(mc$x, function(z) length(unique(z)) > 1)]   # drop constants
y <- mc$y[[target]]

idx_train  <- n_screen + 1:n_train
idx_test   <- n_screen + n_train + 1:n_test

# 2. Screen with Sobol total-effect indices (variance based) ####
# Run the full model on pick-freeze samples: A, B and A with column i taken from B (Saltelli 2010, Jansen 1999).
# The model has internal randomness (vv, chance_event), so the noise variance is estimated from
# repeat runs and subtracted from the total-effect index.
Xfull <- mc$x
set.seed(99)
n_sobol <- 600                                      # base sample size; model runs = n_sobol * (k + 2)
A <- Xfull[sample(nrow(Xfull), n_sobol), names(X)]
B <- Xfull[sample(nrow(Xfull), n_sobol), names(X)]
base <- Xfull[1, , drop = FALSE]
run_rows <- function(M) {                           # run the full model on given input rows
  out <- numeric(nrow(M))
  for (r in seq_len(nrow(M))) {
    v <- base; v[names(M)] <- M[r, ]
    list2env(as.list(v), envir = globalenv())
    out[r] <- school_garden_function()[[target]]
  }
  out
}
fA <- run_rows(A); fB <- run_rows(B); fA2 <- run_rows(A)
V <- var(c(fA, fB))
noise <- mean((fA - fA2)^2) / 2                     # variance from internal randomness
ST <- S1 <- setNames(numeric(ncol(A)), names(A))
for (i in names(A)) {
  ABi <- A; ABi[[i]] <- B[[i]]
  f <- run_rows(ABi)
  ST[i] <- (mean((fA - f)^2) / 2 - noise) / V
  S1[i] <- mean(fB * (f - fA)) / V
}
sobol <- data.frame(input = names(ST), S1 = round(S1, 3), ST = round(ST, 3))
sobol <- sobol[order(-sobol$ST), ]
write.csv(sobol, "sobol_indices.csv", row.names = FALSE)
cat(sprintf("\nShare of output variance from internal randomness: %.2f\n", noise / V))
keep <- sobol$input[1:n_keep]
print(sobol[1:n_keep, ], row.names = FALSE)

# 3. Fit the Gaussian process on the training runs ####
fit <- km(~1, design = X[idx_train, keep, drop = FALSE], response = y[idx_train],
          covtype = "matern5_2", nugget.estim = TRUE, control = list(trace = FALSE))

# 4. Check it on runs it has never seen ####
pred <- predict(fit, newdata = X[idx_test, keep, drop = FALSE], type = "UK")
obs  <- y[idx_test]
rmse <- sqrt(mean((pred$mean - obs)^2))
r2   <- 1 - sum((pred$mean - obs)^2) / sum((obs - mean(obs))^2)
cover <- mean(obs >= pred$lower95 & obs <= pred$upper95)
p_pos <- c(model = mean(obs > 0), emulator = mean(pred$mean > 0))
cat(sprintf("\nHeld-out runs: %d\nR2 = %.2f   RMSE = %.0f   (output SD = %.0f)\n",
            n_test, r2, rmse, sd(obs)))
cat(sprintf("95%% prediction interval covers %.0f%% of held-out runs\n", 100 * cover))
cat(sprintf("Chance NPV > 0: model %.3f, emulator %.3f\n", p_pos[1], p_pos[2]))

# 5. Use it: 1 million draws from the emulator ####
set.seed(7)
big <- as.data.frame(lapply(X[, keep, drop = FALSE], function(v) sample(v, 1e6, replace = TRUE)))
t_emul <- system.time(big_pred <- predict(fit, newdata = big, type = "UK", checkNames = FALSE,
                                          light.return = TRUE)$mean)["elapsed"]
t_model_1e6 <- unname(t_model) / (n_screen + n_train + n_test) * 1e6
cat(sprintf("\n1e6 runs: model about %.0f s, emulator %.0f s\n", t_model_1e6, t_emul))

# 6. Figures ####
dir.create("figures", showWarnings = FALSE)
png("figures/emulator_check.png", 1400, 600, res = 150)
par(mfrow = c(1, 2), mar = c(4.5, 4.5, 3, 1))
plot(obs, pred$mean, pch = 16, cex = 0.4, col = "#00000044",
     xlab = "Full model NPV", ylab = "Emulator NPV",
     main = sprintf("Held-out runs (R2 = %.2f)", r2))
abline(0, 1, col = "red", lwd = 2)
plot(density(obs), lwd = 2, main = "NPV distribution", xlab = "NPV")
lines(density(big_pred), lwd = 2, col = "red")
legend("topright", c("Full model", "Emulator (1e6 draws)"), lwd = 2, col = c("black", "red"), bty = "n")
dev.off()

write.csv(data.frame(metric = c("R2", "RMSE", "coverage95", "n_train", "n_test"),
                     value = c(r2, rmse, cover, n_train, n_test)),
          "emulator_results.csv", row.names = FALSE)
