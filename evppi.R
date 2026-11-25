# Value of information for the school garden decision, using the emulators
# For each school type the school chooses among doing nothing (NPV 0), a passive garden and a STEM garden.
# Run from the repository root: source("evppi.R")

source("emulator.R")   # gives X, Y, keep, fits, run_rows, pred_mean

school_types <- list(
  "no public-school risk" = c(passive = "NPV_garden", STEM = "NPV_garden_STEM"),
  "public school"         = c(passive = "NPV_garden_public_school", STEM = "NPV_garden_STEM_public_school"))
m <- 150    # values drawn for the input being studied (outer loop)
n <- 1000   # draws of all other inputs per value (inner loop)
pool     <- X[, keep, drop = FALSE]
poolfull <- X   # all varying inputs, for the full-model check

# Value of deciding after learning: E[max(0, options)] - max(0, E[options]), from conditional means
voi <- function(cm) mean(pmax(0, apply(cm, 1, max))) - max(0, colMeans(cm))

# 1. EVPI from the full model: what perfect knowledge of every input is worth ####
evpi <- sapply(school_types, function(o) voi(as.matrix(Y[, o])))
cat("\nExpected NPV (million VND) of each option today:\n"); print(round(colMeans(Y)))
cat("EVPI (million VND per garden):\n"); print(round(evpi, 1))

# 2. EVPPI per input with the emulators ####
# EVPPI_i = E_xi[ max(0, E[option NPV | xi]) ] - max(0, E[option NPV]), maximum over options
set.seed(11)
evppi_emulator <- function(v) {
  xi <- sample(pool[, v], m, replace = TRUE)
  cm <- lapply(school_types, function(o) matrix(NA_real_, m, length(o)))
  for (k in seq_len(m)) {
    nd <- pool[sample(nrow(pool), n, replace = TRUE), , drop = FALSE]
    nd[[v]] <- xi[k]
    for (s in names(school_types))
      for (j in seq_along(school_types[[s]]))
        cm[[s]][k, j] <- mean(pred_mean(fits[[school_types[[s]][j]]], nd))
  }
  sapply(cm, voi)
}
res <- do.call(rbind, lapply(keep, function(v) {
  e <- evppi_emulator(v)
  data.frame(input = v, school_type = names(e), evppi = round(e, 1),
             share_of_evpi = round(e / evpi[names(e)], 3), row.names = NULL)
}))
res <- res[order(res$school_type, -res$evppi), ]
print(res, row.names = FALSE)
write.csv(res, "evppi_results.csv", row.names = FALSE)

# 3. Check the top inputs against the full model (same m and n) ####
evppi_model <- function(v) {
  xi <- sample(poolfull[, v], m, replace = TRUE)
  cm <- t(sapply(xi, function(val) {
    nd <- poolfull[sample(nrow(poolfull), n, replace = TRUE), , drop = FALSE]
    nd[[v]] <- val
    colMeans(run_rows(nd))
  }))
  sapply(school_types, function(o) voi(cm[, o, drop = FALSE]))
}
top <- unique(unlist(lapply(names(school_types), function(s) head(res$input[res$school_type == s], 3))))
set.seed(12)
chk <- do.call(rbind, lapply(top, function(v) {
  e <- evppi_model(v)
  data.frame(input = v, school_type = names(e), evppi_full_model = round(e, 1), row.names = NULL)
}))
chk <- merge(chk, res[, c("input", "school_type", "evppi")], by = c("input", "school_type"))
names(chk)[names(chk) == "evppi"] <- "evppi_emulator"
chk <- chk[order(chk$school_type, -chk$evppi_full_model), ]
print(chk, row.names = FALSE)
write.csv(chk, "evppi_check.csv", row.names = FALSE)

# 4. Figure ####
png("figures/evppi.png", 1500, 900, res = 150)
par(mfrow = c(1, 2), mar = c(4.5, 11, 3, 1))
for (s in names(school_types)) {
  r <- head(res[res$school_type == s, ], 6)
  barplot(rev(r$evppi), names.arg = rev(r$input), horiz = TRUE, las = 1, col = "grey40",
          xlab = "EVPPI (million VND per garden)",
          main = sprintf("%s (EVPI = %.0f)", s, evpi[s]), cex.main = 0.9)
}
dev.off()
