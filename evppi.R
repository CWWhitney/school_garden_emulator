# Value of information for the school garden decision, using the emulator
# Decision: build the garden or do nothing. NPV_garden is already the gain over doing nothing,
# so the garden is chosen when its expected NPV is above zero.
# Run from the repository root: source("evppi.R")

source("emulator.R")   # gives X, y, keep, fit, and the held-out runs

m <- 150    # values drawn for the input being studied (outer loop)
n <- 1000   # draws of all other inputs per value (inner loop)
pool <- X[, keep, drop = FALSE]
poolfull <- X   # all varying inputs, for the full-model check

# 1. EVPI from the full model: what perfect knowledge of every input is worth ####
ev_now  <- max(mean(y), 0)             # best decision under current uncertainty
ev_info <- mean(pmax(y, 0))            # decide after seeing the true NPV
evpi    <- ev_info - ev_now
cat(sprintf("\nExpected NPV %.0f  ->  decide now: %s\n", mean(y), ifelse(mean(y) > 0, "build the garden", "do nothing")))
cat(sprintf("EVPI (full model) = %.0f per garden\n", evpi))

# 2. EVPPI per input with the emulator ####
# EVPPI_i = E_xi[ max(E[NPV | xi], 0) ] - max(E[NPV], 0)
set.seed(11)
evppi_one <- function(v) {
  xi <- sample(pool[, v], m, replace = TRUE)
  cond <- sapply(xi, function(val) {
    nd <- pool[sample(nrow(pool), n, replace = TRUE), , drop = FALSE]
    nd[[v]] <- val
    mean(predict(fit, newdata = nd, type = "UK", checkNames = FALSE, light.return = TRUE)$mean)
  })
  mean(pmax(cond, 0)) - max(mean(cond), 0)
}
evppi <- sapply(keep, evppi_one)
res <- data.frame(input = keep, evppi = round(evppi, 1),
                  share_of_evpi = round(evppi / evpi, 3))
res <- res[order(-res$evppi), ]
print(res, row.names = FALSE)

write.csv(res, "evppi_results.csv", row.names = FALSE)

# 3. Check the top inputs against the full model (same m and n) ####
n_check <- 3
evppi_model <- function(v) {
  xi <- sample(poolfull[, v], m, replace = TRUE)
  cond <- sapply(xi, function(val) {
    nd <- poolfull[sample(nrow(poolfull), n, replace = TRUE), , drop = FALSE]
    nd[[v]] <- val
    mean(run_rows(nd))
  })
  mean(pmax(cond, 0)) - max(mean(cond), 0)
}
set.seed(12)
chk <- res[1:n_check, c("input", "evppi")]
chk$evppi_full_model <- round(sapply(chk$input, evppi_model), 1)
names(chk)[2] <- "evppi_emulator"
print(chk, row.names = FALSE)
write.csv(chk, "evppi_check.csv", row.names = FALSE)

# 4. Figure ####
png("figures/evppi.png", 1400, 700, res = 150)
par(mar = c(4.5, 14, 3, 1))
barplot(rev(res$evppi), names.arg = rev(res$input), horiz = TRUE, las = 1,
        col = "grey40", xlab = "EVPPI (value of resolving this input, per garden)",
        main = sprintf("What is worth learning before deciding (EVPI = %.0f)", evpi))
dev.off()
