# One Gaussian-process emulator per account of the school garden, then EVCA on the emulated draws.
# Run from the repository root: source("emulator.R")
# Each account keeps its own output and its own units. Nothing is converted into another account's currency.

suppressMessages({library(decisionSupport); library(DiceKriging); library(evca)})
source("model_school_garden.R")

# Accounts (columns) and options (rows) as model outputs. "none" is the do-nothing option, zero by construction.
outputs <- list(
  budget   = c(garden = "NPV_garden", stem = "NPV_garden_STEM"),   # school finances, currency
  health   = c(garden = "health",     stem = "health_STEM"),       # child health value, currency
  ecology  = c(garden = "biodiversity", stem = "biodiversity"))    # ecological value, model assumes it is the same
n_run <- 4000; n_train <- 300; n_keep <- 8; n_draw <- 20000

set.seed(42)
inputs <- estimate_read_csv("data/inputs_school_garden.csv")
mc <- mcSimulation(inputs, school_garden_function, numberOfModelRuns = n_run, functionSyntax = "plainNames")
X <- mc$x[, sapply(mc$x, function(z) length(unique(z)) > 1)]
tr <- seq_len(n_train); te <- (n_train + 1):n_run

# 1. One emulator per model output, with its own screened inputs ####
fit_gp <- function(out) {
  y <- mc$y[[out]]
  rho <- abs(cor(X[tr, ], y[tr], method = "spearman"))[, 1]
  keep <- names(sort(rho, decreasing = TRUE, na.last = NA))[1:n_keep]
  fit <- km(~1, design = X[tr, keep], response = y[tr], covtype = "matern5_2",
            nugget.estim = TRUE, control = list(trace = FALSE))
  r2 <- 1 - sum((predict(fit, X[te, keep], "UK", checkNames = FALSE)$mean - mc$y[[out]][te])^2) /
            sum((mc$y[[out]][te] - mean(mc$y[[out]][te]))^2)
  list(fit = fit, keep = keep, r2 = r2)
}
gps <- lapply(unique(unlist(outputs)), fit_gp); names(gps) <- unique(unlist(outputs))
print(round(sapply(gps, `[[`, "r2"), 2))

# 2. Payoff array: states x options x accounts, from emulated draws of the shared uncertain inputs ####
draw_inputs <- function() as.data.frame(lapply(X, function(v) sample(v, n_draw, replace = TRUE)))
D <- draw_inputs()
emu <- function(out) predict(gps[[out]]$fit, D[, gps[[out]]$keep], "UK", checkNames = FALSE,
                             light.return = TRUE)$mean
opt <- c("none", "garden", "stem")
make_array <- function(get) {
  a <- array(0, c(n_draw, 3, length(outputs)), dimnames = list(NULL, opt, names(outputs)))
  for (w in names(outputs)) for (o in c("garden", "stem")) a[, o, w] <- get(outputs[[w]][[o]])
  a
}
A_emu <- make_array(emu)
A_mod <- array(0, c(n_run, 3, length(outputs)), dimnames = list(NULL, opt, names(outputs)))
for (w in names(outputs)) for (o in c("garden", "stem")) A_mod[, o, w] <- mc$y[[outputs[[w]][[o]]]]

# 3. Per-account results in each account's own units ####
report <- function(A, label) {
  mu <- apply(A, c(2, 3), mean)
  cat("\n", label, ": expected value of each option in each account's own units\n", sep = ""); print(round(mu, 1))
  # Pareto step: drop an option if every account ranks another option at least as high and one strictly higher
  dom <- sapply(opt, function(i) any(sapply(setdiff(opt, i), function(j)
    all(mu[j, ] >= mu[i, ]) && any(mu[j, ] > mu[i, ]))))
  cat("Dominated in every account:", if (any(dom)) names(dom)[dom] else "none", "\n")
  keep <- names(dom)[!dom]
  # range share: 0 = the account's own best option, 1 = its own worst. A convention, not a measurement.
  rng <- apply(mu[keep, , drop = FALSE], 2, function(v) diff(range(v)))
  share <- sweep(sweep(mu[keep, , drop = FALSE], 2, apply(mu[keep, , drop = FALSE], 2, max), "-"), 2,
                 ifelse(rng > 0, rng, 1), "/") * -1
  cat("Loss as a share of each account's own range (0 = its best):\n"); print(round(share, 2))
  invisible(list(mu = mu, keep = keep))
}
r_mod <- report(A_mod, "Full model"); r_emu <- report(A_emu, "Emulator")

# 4. EVCA on the contested options, equal standing as a declared convention ####
contested <- function(A, keep) {
  A <- A[, keep, , drop = FALSE]
  mu <- apply(A, c(2, 3), mean)
  list(A = A, smin = apply(mu, 2, min), srng = pmax(apply(mu, 2, function(v) diff(range(v))), 1e-9))
}
for (nm in c("Full model", "Emulator")) {
  r <- if (nm == "Full model") r_mod else r_emu
  A <- if (nm == "Full model") A_mod else A_emu
  if (length(r$keep) < 2) { cat("\n", nm, ": one option survives the Pareto step, so there is nothing to negotiate.\n", sep = ""); next }
  cc <- contested(A, r$keep)
  w <- rep(1 / dim(cc$A)[3], dim(cc$A)[3])
  d <- evca_decompose(cc$A, model_weights = w, scale_min = cc$smin, scale_range = cc$srng)
  cat(sprintf("\n%s: EVCA with equal standing = %.3f (evidence-reducible %.3f, remaining %.3f) on the 0-1 range-share scale\n",
              nm, d$gap, d$evpi_agg, d$evca_post))
}
