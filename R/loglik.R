# All functions in this file have the same arguments structure
# Args:
#  i: the column of draws to use i.e. the ith obervation 
#     in the initial data.frame 
#  draws: A named list returned by extract_draws containing 
#         all required data and samples
#  data: currently ignored; included for compatibility 
#        with loo::loo.function      
# Returns:
#   A vector of length draws$nsamples containing the pointwise 
#   log-likelihood fo the ith observation 
loglik_gaussian <- function(i, draws, data = data.frame()) {
  sigma <- get_sigma(draws$sigma, data = draws$data, method = "logLik", i = i)
  args <- list(mean = ilink(get_eta(i, draws), draws$f$link), sd = sigma)
  # censor_loglik computes the conventional loglik in case of no censoring 
  out <- censor_loglik(dist = "norm", args = args, i = i, data = draws$data)
  out <- truncate_loglik(out, cdf = pnorm, args = args, data = draws$data)
  weight_loglik(out, i = i, data = draws$data)
}

loglik_student <- function(i, draws, data = data.frame()) {
  sigma <- get_sigma(draws$sigma, data = draws$data, method = "logLik", i = i)
  args <- list(df = draws$nu, mu = ilink(get_eta(i, draws), draws$f$link), 
               sigma = sigma)
  out <- censor_loglik(dist = "student", args = args, i = i, data = draws$data)
  out <- truncate_loglik(out, cdf = pstudent, args = args, data = draws$data)
  weight_loglik(out, i = i, data = draws$data)
}

loglik_cauchy <- function(i, draws, data = data.frame()) {
  sigma <- get_sigma(draws$sigma, data = draws$data, method = "logLik", i = i)
  args <- list(df = 1, mu = ilink(get_eta(i, draws), draws$f$link), 
               sigma = sigma)
  out <- censor_loglik(dist = "student", args = args, i = i, data = draws$data)
  out <- truncate_loglik(out, cdf = pstudent, args = args, data = draws$data)
  weight_loglik(out, i = i, data = draws$data)
}

loglik_lognormal <- function(i, draws, data = data.frame()) {
  sigma <- get_sigma(draws$sigma, data = draws$data, method = "logLik", i = i)
  args <- list(meanlog = get_eta(i, draws), sdlog = sigma)
  out <- censor_loglik(dist = "lnorm", args = args, i = i, data = draws$data)
  out <- truncate_loglik(out, cdf = plnorm, args = args, data = draws$data)
  weight_loglik(out, i = i, data = draws$data)
}

loglik_gaussian_multi <- function(i, draws, data = data.frame()) {
  nobs <- draws$data$N_trait * draws$data$K_trait
  obs <- seq(i, nobs, draws$data$N_trait)
  eta <- get_eta(obs, draws)
  out <- sapply(1:draws$nsamples, function(s) 
    dmulti_normal(draws$data$Y[i, ], Sigma = draws$Sigma[s, , ], 
                  mu = ilink(eta[s, ], draws$f$link), log = TRUE))
  # no truncation allowed
  weight_loglik(out, i = i, data = draws$data)
}

loglik_student_multi <- function(i, draws, data = data.frame()) {
  nobs <- draws$data$N_trait * draws$data$K_trait
  obs <- seq(i, nobs, draws$data$N_trait)
  eta <- get_eta(obs, draws)
  out <- sapply(1:draws$nsamples, function(s) 
    dmulti_student(draws$data$Y[i, ], df = draws$nu[s, ], 
                   Sigma = draws$Sigma[s, , ], log = TRUE,
                   mu = ilink(eta[s, ], draws$f$link)))
  # no truncation allowed
  weight_loglik(out, i = i, data = draws$data)
}

loglik_cauchy_multi <- function(i, draws, data = data.frame()) {
  nobs <- draws$data$N_trait * draws$data$K_trait
  obs <- seq(i, nobs, draws$data$N_trait)
  eta <- get_eta(obs, draws)
  out <- sapply(1:draws$nsamples, function(s) 
    dmulti_student(draws$data$Y[i, ], df = 1,  Sigma = draws$Sigma[s, , ], 
                   mu = ilink(eta[s, ], draws$f$link), log = TRUE))
  # no truncation allowed
  weight_loglik(out, i = i, data = draws$data)
}

loglik_gaussian_cov <- function(i, draws, data = data.frame()) {
  # currently, only ARMA1 processes are implemented
  obs <- with(draws$data, begin_tg[i]:(begin_tg[i] + nobs_tg[i] - 1))
  args <- list(sigma = draws$sigma, se2 = draws$data$se2[obs], 
               nrows = length(obs))
  if (!is.null(draws$ar) && is.null(draws$ma)) {
    # AR1 process
    args$ar <- draws$ar
    Sigma <- do.call(get_cov_matrix_ar1, args)
  } else if (is.null(draws$ar) && !is.null(draws$ma)) {
    # MA1 process
    args$ma <- draws$ma
    Sigma <- do.call(get_cov_matrix_ma1, args)
  } else {
    # ARMA1 process
    args[c("ar", "ma")] <- draws[c("ar", "ma")]
    Sigma <- do.call(get_cov_matrix_arma1, args)
  }
  eta <- get_eta(obs, draws)
  out <- sapply(1:draws$nsamples, function(s)
    dmulti_normal(draws$data$Y[obs], Sigma = Sigma[s, , ], log = TRUE,
                  mu = ilink(eta[s, ], draws$f$link)))
  # weights, truncation and censoring not allowed
  out
}

loglik_student_cov <- function(i, draws, data = data.frame()) {
  # currently, only ARMA1 processes are implemented
  obs <- with(draws$data, begin_tg[i]:(begin_tg[i] + nobs_tg[i] - 1))
  args <- list(sigma = draws$sigma, se2 = draws$data$se2[obs], 
               nrows = length(obs))
  if (!is.null(draws$ar) && is.null(draws$ma)) {
    # AR1 process
    args$ar <- draws$ar
    Sigma <- do.call(get_cov_matrix_ar1, args)
  } else if (is.null(draws$ar) && !is.null(draws$ma)) {
    # MA1 process
    args$ma <- draws$ma
    Sigma <- do.call(get_cov_matrix_ma1, args)
  } else {
    # ARMA1 process
    args[c("ar", "ma")] <- draws[c("ar", "ma")]
    Sigma <- do.call(get_cov_matrix_arma1, args)
  }
  eta <- get_eta(obs, draws)
  out <- sapply(1:draws$nsamples, function(s)
    dmulti_student(draws$data$Y[obs], df = draws$nu[s, ], 
                   mu = ilink(eta[s, ], draws$f$link), 
                   Sigma = Sigma[s, , ], log = TRUE))
  # weights, truncation and censoring not yet allowed
  out
}

loglik_cauchy_cov <- function(i, draws, data = data.frame()) {
  draws$nu <- matrix(rep(1, draws$nsamples))
  loglik_student_cov(i = i, draws = draws, data = data)
}

loglik_gaussian_fixed <- function(i, draws, data = data.frame()) {
  stopifnot(i == 1)
  eta <- get_eta(1:nrow(draws$data$V), draws)
  ulapply(1:draws$nsamples, function(s) 
    dmulti_normal(draws$data$Y, Sigma = draws$data$V, log = TRUE,
                  mu = ilink(eta[s, ], draws$f$link)))
}

loglik_student_fixed <- function(i, draws, data = data.frame()) {
  stopifnot(i == 1)
  eta <- get_eta(1:nrow(draws$data$V), draws)
  sapply(1:draws$nsamples, function(s) 
    dmulti_student(draws$data$Y, df = draws$nu[s, ], 
                   Sigma = draws$data$V, log = TRUE,
                   mu = ilink(eta[s, ], draws$f$link)))
}
  
loglik_cauchy_fixed <- function(i, draws, data = data.frame()) {
  stopifnot(i == 1)
  eta <- get_eta(1:nrow(draws$data$V), draws)
  sapply(1:draws$nsamples, function(s) 
    dmulti_student(draws$data$Y, df = 1, Sigma = draws$data$V, log = TRUE,
                   mu = ilink(eta[s, ], draws$f$link)))
}

loglik_binomial <- function(i, draws, data = data.frame()) {
  trials <- ifelse(length(draws$data$max_obs) > 1, 
                   draws$data$max_obs[i], draws$data$max_obs) 
  args <- list(size = trials, prob = ilink(get_eta(i, draws), draws$f$link))
  out <- censor_loglik(dist = "binom", args = args, i = i, data = draws$data)
  out <- truncate_loglik(out, cdf = pbinom, args = args, data = draws$data)
  weight_loglik(out, i = i, data = draws$data)
}  

loglik_bernoulli <- function(i, draws, data = data.frame()) {
  if (!is.null(draws$data$N_trait)) {  # 2PL model
    eta <- get_eta(i, draws) * exp(get_eta(i + draws$data$N_trait, draws))
  } else {
    eta <-  get_eta(i, draws)
  }
  args <- list(size = 1, prob = ilink(eta, draws$f$link))
  out <- censor_loglik(dist = "binom", args = args, i = i, data = draws$data)
  # no truncation allowed
  out <- weight_loglik(out, i = i, data = draws$data)
  is_nan <- is.nan(out)
  if (any(is_nan)) {
    # for 2PL models NaN may occure for numerical reasons
    warning(paste("observation", i, "had", length(which(is_nan)), 
                  "logLik draws that were NaN"))
    out[is_nan] <- mean(out[!is_nan])
  }
  out
}

loglik_poisson <- function(i, draws, data = data.frame()) {
  args <- list(lambda = ilink(get_eta(i, draws), draws$f$link))
  out <- censor_loglik(dist = "pois", args = args, i = i, 
                       data = draws$data)
  out <- truncate_loglik(out, cdf = ppois, args = args, 
                         data = draws$data)
  weight_loglik(out, i = i, data = draws$data)
}

loglik_negbinomial <- function(i, draws, data = data.frame()) {
  shape <- get_shape(draws$shape, data = draws$data, method = "logLik", i = i)
  args <- list(mu = ilink(get_eta(i, draws), draws$f$link), size = shape)
  out <- censor_loglik(dist = "nbinom", args = args, i = i, data = draws$data)
  out <- truncate_loglik(out, cdf = pnbinom, args = args, data = draws$data)
  weight_loglik(out, i = i, data = draws$data)
}

loglik_geometric <- function(i, draws, data = data.frame()) {
  args <- list(mu = ilink(get_eta(i, draws), draws$f$link), size = 1)
  out <- censor_loglik(dist = "nbinom", args = args, i = i, data = draws$data)
  out <- truncate_loglik(out, cdf = pnbinom, args = args, data = draws$data)
  weight_loglik(out, i = i, data = draws$data)
}

loglik_exponential <- function(i, draws, data = data.frame()) {
  args <- list(rate = 1 / ilink(get_eta(i, draws), draws$f$link))
  out <- censor_loglik(dist = "exp", args = args, i = i, data = draws$data)
  out <- truncate_loglik(out, cdf = pexp, args = args, data = draws$data)
  weight_loglik(out, i = i, data = draws$data)
}

loglik_gamma <- function(i, draws, data = data.frame()) {
  shape <- get_shape(draws$shape, data = draws$data, method = "logLik", i = i)
  args <- list(shape = shape, 
               scale = ilink(get_eta(i, draws), draws$f$link) / shape)
  out <- censor_loglik(dist = "gamma", args = args, i = i, data = draws$data)
  out <- truncate_loglik(out, cdf = pgamma, args = args, data = draws$data)
  weight_loglik(out, i = i, data = draws$data)
}

loglik_weibull <- function(i, draws, data = data.frame()) {
  shape <- get_shape(draws$shape, data = draws$data, method = "logLik", i = i)
  args <- list(scale = ilink(get_eta(i, draws) / shape, draws$f$link),
               shape = shape)
  out <- censor_loglik(dist = "weibull", args = args, i = i, data = draws$data)
  out <- truncate_loglik(out, cdf = pweibull, args = args, data = draws$data)
  weight_loglik(out, i = i, data = draws$data)
}

loglik_inverse.gaussian <- function(i, draws, data = data.frame()) {
  args <- list(mean = ilink(get_eta(i, draws), draws$f$link), 
               shape = draws$shape)
  out <- censor_loglik(dist = "invgauss", args = args, i = i, data = draws$data)
  out <- truncate_loglik(out, cdf = pinvgauss, args = args, data = draws$data)
  weight_loglik(out, i = i, data = draws$data)
}

loglik_beta <- function(i, draws, data = data.frame()) {
  mu <- ilink(get_eta(i, draws), draws$f$link)
  args <- list(shape1 = mu * draws$phi, shape2 = (1 - mu) * draws$phi)
  out <- censor_loglik(dist = "beta", args = args, i = i, data = draws$data)
  out <- truncate_loglik(out, cdf = pbeta, args = args, data = draws$data)
  weight_loglik(out, i = i, data = draws$data)
}

loglik_hurdle_poisson <- function(i, draws, data = data.frame()) {
  theta <- ilink(get_eta(i + draws$data$N_trait, draws), "logit")
  args <- list(lambda = ilink(get_eta(i, draws), draws$f$link))
  out <- hurdle_loglik_discrete(pdf = dpois, theta = theta, 
                                args = args, i = i, data = draws$data)
  weight_loglik(out, i = i, data = draws$data)
}

loglik_hurdle_negbinomial <- function(i, draws, data = data.frame()) {
  theta <- ilink(get_eta(i + draws$data$N_trait, draws), "logit")
  args <- list(mu = ilink(get_eta(i, draws), draws$f$link), 
               size = draws$shape)
  out <- hurdle_loglik_discrete(pdf = dnbinom, theta = theta, 
                                args = args, i = i, data = draws$data)
  weight_loglik(out, i = i, data = draws$data)
}

loglik_hurdle_gamma <- function(i, draws, data = data.frame()) {
  theta <- ilink(get_eta(i + draws$data$N_trait, draws), "logit")
  args <- list(shape = draws$shape, 
               scale = ilink(get_eta(i, draws), draws$f$link) / draws$shape)
  out <- hurdle_loglik_continuous(pdf = dgamma, theta = theta, 
                                  args = args, i = i, data = draws$data)
  weight_loglik(out, i = i, data = draws$data)
}

loglik_zero_inflated_poisson <- function(i, draws, data = data.frame()) {
  theta <- ilink(get_eta(i + draws$data$N_trait, draws), "logit")
  args <- list(lambda = ilink(get_eta(i, draws), draws$f$link))
  out <- zero_inflated_loglik(pdf = dpois, theta = theta, 
                              args = args, i = i, data = draws$data)
  weight_loglik(out, i = i, data = draws$data)
}

loglik_zero_inflated_negbinomial <- function(i, draws, data = data.frame()) {
  theta <- ilink(get_eta(i + draws$data$N_trait, draws), "logit")
  args <- list(mu = ilink(get_eta(i, draws), draws$f$link), 
               size = draws$shape)
  out <- zero_inflated_loglik(pdf = dnbinom, theta = theta, 
                              args = args, i = i, data = draws$data)
  weight_loglik(out, i = i, data = draws$data)
}

loglik_zero_inflated_binomial <- function(i, draws, data = data.frame()) {
  trials <- ifelse(length(draws$data$max_obs) > 1, 
                   draws$data$max_obs[i], draws$data$max_obs) 
  theta <- ilink(get_eta(i + draws$data$N_trait, draws), "logit")
  args <- list(size = trials, prob = ilink(get_eta(i, draws), draws$f$link))
  out <- zero_inflated_loglik(pdf = dbinom, theta = theta, 
                              args = args, i = i, data = draws$data)
  weight_loglik(out, i = i, data = draws$data)
}

loglik_zero_inflated_beta <- function(i, draws, data = data.frame()) {
  theta <- ilink(get_eta(i + draws$data$N_trait, draws), "logit")
  mu <- ilink(get_eta(i, draws), draws$f$link)
  args <- list(shape1 = mu * draws$phi, shape2 = (1 - mu) * draws$phi)
  # zi_beta is technically a hurdle model
  out <- hurdle_loglik_continuous(pdf = dbeta, theta = theta, 
                                  args = args, i = i, data = draws$data)
  weight_loglik(out, i = i, data = draws$data)
}

loglik_categorical <- function(i, draws, data = data.frame()) {
  ncat <- ifelse(length(draws$data$max_obs) > 1, draws$data$max_obs[i], 
                 draws$data$max_obs) 
  if (draws$f$link == "logit") {
    p <- cbind(rep(0, draws$nsamples), 
               get_eta(i, draws, ordinal = TRUE)[, 1, ])
    out <- p[, draws$data$Y[i]] - log(rowSums(exp(p)))
  } else stop(paste("Link", draws$f$link, "not supported"))
  weight_loglik(out, i = i, data = draws$data)
}

loglik_cumulative <- function(i, draws, data = data.frame()) {
  ncat <- ifelse(length(draws$data$max_obs) > 1, 
                 draws$data$max_obs[i], draws$data$max_obs)
  eta <- get_eta(i, draws, ordinal = TRUE)
  y <- draws$data$Y[i]
  if (y == 1) { 
    out <- log(ilink(eta[, 1, 1], draws$f$link))
  } else if (y == ncat) {
    out <- log(1 - ilink(eta[, 1, y - 1], draws$f$link)) 
  } else {
    out <- log(ilink(eta[, 1, y], draws$f$link) - 
                  ilink(eta[, 1, y - 1], draws$f$link))
  }
  weight_loglik(out, i = i, data = draws$data)
}

loglik_sratio <- function(i, draws, data = data.frame()) {
  ncat <- ifelse(length(draws$data$max_obs) > 1, 
                 draws$data$max_obs[i], draws$data$max_obs)
  eta <- get_eta(i, draws, ordinal = TRUE)
  y <- draws$data$Y[i]
  q <- sapply(1:min(y, ncat - 1), function(k) 
    1 - ilink(eta[, 1, k], draws$f$link))
  if (y == 1) {
    out <- log(1 - q[, 1]) 
  } else if (y == 2) {
    out <- log(1 - q[, 2]) + log(q[, 1])
  } else if (y == ncat) {
    out <- rowSums(log(q))
  } else {
    out <- log(1 - q[, y]) + rowSums(log(q[, 1:(y - 1)]))
  }
  weight_loglik(out, i = i, data = draws$data)
}

loglik_cratio <- function(i, draws, data = data.frame()) {
  ncat <- ifelse(length(draws$data$max_obs) > 1, 
                 draws$data$max_obs[i], draws$data$max_obs)
  eta <- get_eta(i, draws, ordinal = TRUE)
  y <- draws$data$Y[i]
  q <- sapply(1:min(y, ncat-1), function(k) 
    ilink(eta[, 1, k], draws$f$link))
  if (y == 1) {
    out <- log(1 - q[, 1])
  }  else if (y == 2) {
    out <- log(1 - q[, 2]) + log(q[, 1])
  } else if (y == ncat) {
    out <- rowSums(log(q))
  } else {
    out <- log(1 - q[, y]) + rowSums(log(q[, 1:(y - 1)]))
  }
  weight_loglik(out, i = i, data = draws$data)
}

loglik_acat <- function(i, draws, data = data.frame()) {
  ncat <- ifelse(length(draws$data$max_obs) > 1, 
                 draws$data$max_obs[i], draws$data$max_obs)
  eta <- get_eta(i, draws, ordinal = TRUE)
  y <- draws$data$Y[i]
  if (draws$f$link == "logit") { # more efficient calculation 
    q <- sapply(1:(ncat - 1), function(k) eta[, 1, k])
    p <- cbind(rep(0, nrow(eta)), q[, 1], 
               matrix(0, nrow = nrow(eta), ncol = ncat - 2))
    if (ncat > 2) {
      p[, 3:ncat] <- sapply(3:ncat, function(k) rowSums(q[, 1:(k - 1)]))
    }
    out <- p[, y] - log(rowSums(exp(p)))
  } else {
    q <- sapply(1:(ncat - 1), function(k) 
      ilink(eta[, 1, k], draws$f$link))
    p <- cbind(apply(1 - q[, 1:(ncat - 1)], 1, prod), 
               matrix(0, nrow = nrow(eta), ncol = ncat - 1))
    if (ncat > 2) {
      p[, 2:(ncat - 1)] <- sapply(2:(ncat - 1), function(k) 
        apply(as.matrix(q[, 1:(k - 1)]), 1, prod) * 
          apply(as.matrix(1 - q[, k:(ncat - 1)]), 1, prod))
    }
    p[, ncat] <- apply(q[, 1:(ncat - 1)], 1, prod)
    out <- log(p[, y]) - log(apply(p, 1, sum))
  }
  weight_loglik(out, i = i, data = draws$data)
}

#---------------loglik helper-functions----------------------------

censor_loglik <- function(dist, args, i, data) {
  # compute (possibly censored) loglik values
  # Args:
  #   dist: name of a distribution for which the functions
  #         d<dist> (pdf) and p<dist> (cdf) are available
  #   args: additional arguments passed to pdf and cdf
  #   data: data initially passed to Stan
  # Returns:
  #   vector of loglik values
  pdf <- get(paste0("d", dist), mode = "function")
  cdf <- get(paste0("p", dist), mode = "function")
  if (is.null(data$cens) || data$cens[i] == 0) {
    do.call(pdf, c(data$Y[i], args, log = TRUE))
  } else if (data$cens[i] == 1) {
    do.call(cdf, c(data$Y[i], args, lower.tail = FALSE, log.p = TRUE))
  } else if (data$cens[i] == -1) {
    do.call(cdf, c(data$Y[i], args, log.p = TRUE))
  }
}

truncate_loglik <- function(x, cdf, args, data) {
  # adjust logLik in truncated models
  # Args:
  #  x: vector of loglik values
  #  cdf: a cumulative distribution function 
  #  args: arguments passed to cdf
  #  data: data initially passed to Stan
  # Returns:
  #   vector of loglik values
  if (!(is.null(data$lb[1]) && is.null(data$ub[1]))) {
    lb <- ifelse(is.null(data$lb[1]), -Inf, data$lb[1])
    ub <- ifelse(is.null(data$ub[1]), Inf, data$ub[1])
    x - log(do.call(cdf, c(ub, args)) - do.call(cdf, c(lb, args)))
  } else {
    x
  }
}

weight_loglik <- function(x, i, data) {
  # weight loglik values according to defined weights
  # Args:
  #  x: vector of loglik values
  #  i: observation number
  #  data: data initially passed to Stan
  # Returns:
  #   vector of loglik values
  if ("weights" %in% names(data)) {
    x * data$weights[i]
  } else {
    x
  }
}

hurdle_loglik_discrete <- function(pdf, theta, args, i, data) {
  # loglik values for discrete hurdle models
  # Args:
  #  pdf: a probability density function 
  #  theta: bernoulli hurdle parameter
  #  args: arguments passed to pdf
  #  data: data initially passed to Stan
  # Returns:
  #   vector of loglik values
  if (data$Y[i] == 0) {
    dbinom(1, size = 1, prob = theta, log = TRUE)
  } else {
    dbinom(0, size = 1, prob = theta, log = TRUE) + 
      do.call(pdf, c(data$Y[i], args, log = TRUE)) -
      log(1 - do.call(pdf, c(0, args)))
  }
}

hurdle_loglik_continuous <- function(pdf, theta, args, i, data) {
  # loglik values for continuous hurdle models
  # does not call log(1 - do.call(pdf, c(0, args)))
  # Args:
  #   same as hurdle_loglik_discrete
  if (data$Y[i] == 0) {
    dbinom(1, size = 1, prob = theta, log = TRUE)
  } else {
    dbinom(0, size = 1, prob = theta, log = TRUE) + 
      do.call(pdf, c(data$Y[i], args, log = TRUE))
  }
}

zero_inflated_loglik <- function(pdf, theta, args, i, data) {
  # loglik values for zero-inflated models
  # Args:
  #  pdf: a probability density function 
  #  theta: bernoulli zero-inflation parameter
  #  args: arguments passed to pdf
  #  data: data initially passed to Stan
  # Returns:
  #   vector of loglik values
  if (data$Y[i] == 0) {
    log(dbinom(1, size = 1, prob = theta) + 
        dbinom(0, size = 1, prob = theta) *
          do.call(pdf, c(0, args)))
  } else {
    dbinom(0, size = 1, prob = theta, log = TRUE) +
      do.call(pdf, c(data$Y[i], args, log = TRUE))
  }
}