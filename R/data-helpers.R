melt_data <- function(data, family, effects, na.action = na.omit) {
  # melt data frame for multinormal models
  #
  # Args:
  #   data: a data.frame
  #   family: the model family
  #   effects: a named list as returned by extract_effects
  #
  # Returns:
  #   data in long format 
  response <- effects$response
  nresp <- length(response)
  if (is.mv(family, response = response)) {
    if (!is(data, "data.frame")) {
      stop("'data' must be a data.frame for this model", call. = FALSE)
    }
    # only keep variables that are relevant for the model
    rel_vars <- c(all.vars(attr(terms(effects$all), "variables")), 
                  all.vars(effects$respform))
    data <- data[, which(names(data) %in% rel_vars), drop = FALSE]
    rsv_vars <- intersect(c("trait", "response"), names(data))
    if (length(rsv_vars)) {
      rsv_vars <- paste0("'", rsv_vars, "'", collapse = ", ")
      stop(paste(rsv_vars, "is a reserved variable name"), call. = FALSE)
    }
    if (is.categorical(family)) {
      # no parameters are modeled for the reference category
      response <- response[-1]
    }
    # prepare the response variable
    # use na.pass as otherwise cbind will complain
    # when data contains NAs in the response
    nobs <- nrow(data)
    trait <- factor(rep(response, each = nobs), levels = response)
    new_cols <- data.frame(trait = trait)
    model_response <- model.response(model.frame(
      effects$respform, data = data, na.action = na.pass))
    # allow to remove NA responses later on
    rows2remove <- which(!complete.cases(model_response))
    if (is.linear(family)) {
      model_response[rows2remove, ] <- NA
      model_response <- as.vector(model_response)
    } else if (is.categorical(family)) {
      model_response[rows2remove] <- NA
    } else if (is.forked(family)) {
      model_response[rows2remove] <- NA
      rsv_vars <- intersect(c(response[2], "main", "spec"), names(data))
      if (length(rsv_vars)) {
        rsv_vars <- paste0("'", rsv_vars, "'", collapse = ", ")
        stop(paste(rsv_vars, "is a reserved variable name"), call. = FALSE)
      }
      one <- rep(1, nobs)
      zero <- rep(0, nobs)
      new_cols$main <- c(one, zero)
      new_cols$spec <- c(zero, one)
      # dummy responses not actually used in Stan
      model_response <- rep(model_response, 2)
    }
    new_cols$response <- model_response
    old_data <- data
    data <- replicate(length(response), old_data, simplify = FALSE)
    data <- do.call(na.action, list(cbind(do.call(rbind, data), new_cols)))
    data <- fix_factor_contrasts(data, optdata = old_data)
  }
  if (isTRUE(attr(effects$fixed, "rsv_intercept"))) {
    if (is.null(data)) 
      stop("'data' must be a data.frame or list", call. = FALSE)
    if ("intercept" %in% names(data)) {
      stop(paste("'intercept' is a reserved variable name in models",
                 "without a fixed effects intercept"), call. = FALSE)
    }
    data$intercept <- rep(1, length(data[[1]]))
  }
  data
}  

combine_groups <- function(data, ...) {
  # combine grouping factors
  #
  # Args:
  #   data: a data.frame
  #   ...: the grouping factors to be combined. 
  #
  # Returns:
  #   a data.frame containing all old variables and 
  #   the new combined grouping factors
  group <- c(...)
  if (length(group)) {
    for (i in 1:length(group)) {
      sgroup <- unlist(strsplit(group[[i]], ":"))
      if (length(sgroup) > 1) {
        new.var <- get(sgroup[1], data)
        for (j in 2:length(sgroup)) {
          new.var <- paste0(new.var, "_", get(sgroup[j], data))
        }
        data[[group[[i]]]] <- new.var
      }
    } 
  }
  data
}

fix_factor_contrasts <- function(data, optdata = NULL) {
  # hard code factor contrasts to be independent
  # of the global "contrasts" option
  # Args:
  #   data: a data.frame
  #   optdata: optional data.frame from which contrasts
  #            are taken if present
  # Returns:
  #   a data.frame with amended contrasts attributes
  stopifnot(is(data, "data.frame"))
  stopifnot(is.null(optdata) || is.list(optdata))
  for (i in seq_along(data)) {
    if (is.factor(data[[i]]) && is.null(attr(data[[i]], "contrasts"))) {
      if (!is.null(attr(optdata[[names(data)[i]]], "contrasts"))) {
        # take contrasts from optdata
        contrasts(data[[i]]) <- attr(optdata[[names(data)[i]]], "contrasts")
      } else {
        # hard code current global "contrasts" option
        contrasts(data[[i]]) <- contrasts(data[[i]])
      }
    }
  }
  data
}

update_data <- function(data, family, effects, ..., 
                        na.action = na.omit,
                        drop.unused.levels = TRUE,
                        terms_attr = NULL) {
  # Update data for use in brms functions
  # Args:
  #   data: the original data.frame
  #   family: the model family
  #   effects: output of extract_effects (see validate.R)
  #   ...: More formulae passed to combine_groups
  #        Currently only used for autocorrelation structures
  #   na.action: function defining how to treat NAs
  #   drop.unused.levels: indicates if unused factor levels
  #                       should be removed
  #   terms_attr: a list of attributes of the terms object of 
  #     the original model.frame; only used with newdata;
  #     this ensures that (1) calls to 'poly' work correctly
  #     and (2) that the number of variables matches the number 
  #     of variable names; fixes issue #73; 
  # Returns:
  #   model.frame in long format with combined grouping variables if present
  if (is.null(attr(data, "terms")) && "brms.frame" %in% class(data)) {
    # to avoid error described in #30
    # brms.frame class is deprecated as of brms > 0.7.0
    data <- as.data.frame(data)
  }
  if (!(isTRUE(attr(data, "brmsframe")) || "brms.frame" %in% class(data))) {
    effects$all <- terms(effects$all)
    attributes(effects$all)[names(terms_attr)] <- terms_attr
    data <- melt_data(data, family = family, effects = effects,
                      na.action = na.action)
    data <- model.frame(effects$all, data = data, na.action = na.action,
                        drop.unused.levels = drop.unused.levels)
    if (any(grepl("__", colnames(data))))
      stop("variable names may not contain double underscores '__'",
           call. = FALSE)
    data <- combine_groups(data, get_random(effects)$group, ...)
    data <- fix_factor_contrasts(data)
    attr(data, "brmsframe") <- TRUE
  }
  data
}

amend_newdata <- function(newdata, fit, re_formula = NULL, 
                          allow_new_levels = FALSE,
                          return_standata = TRUE,
                          check_response = FALSE) {
  # amend newdata passed to predict and fitted methods
  # 
  # Args:
  #   newdata: a data.frame containing new data for prediction 
  #   fit: an object of class brmsfit
  #   re_formula: a random effects formula
  #   allow_new_levels: are new random effects levels allowed?
  #   return_standata: logical; compute the data to be passed 
  #                    to Stan, or just return the updated newdata?
  #   check_response: Should response variables be checked
  #                   for existence and validity?
  #
  # Notes:
  #   used in predict.brmsfit, fitted.brmsfit and linear_predictor.brmsfit
  #
  # Returns:
  #   updated data.frame being compatible with fit$formula
  if (is.null(newdata) || is(newdata, "list")) {
    # to shorten expressions in S3 methods such as predict.brmsfit
    if (return_standata && is.null(newdata)) {
      control <- list(not4stan = TRUE, save_order = TRUE)
      newdata <- standata(fit, re_formula = re_formula, control = control)
    }
    return(newdata)
  } else if (!"data.frame" %in% class(newdata)) {
    stop("newdata must be a data.frame", call. = FALSE)
  }
  # standata will be based on an updated formula if re_formula is specified
  new_ranef <- check_re_formula(re_formula, old_ranef = fit$ranef,
                                data = model.frame(fit))
  new_formula <- update_re_terms(fit$formula, re_formula = re_formula)
  new_nonlinear <- lapply(fit$nonlinear, update_re_terms, 
                          re_formula = re_formula)
  et <- extract_time(fit$autocor$formula)
  ee <- extract_effects(new_formula, et$all, family = family(fit),
                        nonlinear = new_nonlinear, resp_rhs_all = FALSE)
  if (has_splines(ee)) {
    stop(paste("Predictions with 'newdata' are not yet possible", 
               "for models using splines."), call. = FALSE)
  }
  resp_only_vars <- setdiff(all.vars(ee$respform), all.vars(rhs(ee$all)))
  missing_resp <- setdiff(resp_only_vars, names(newdata))
  check_response <- check_response || 
                    (has_arma(fit$autocor) && !use_cov(fit$autocor))
  if (check_response && length(missing_resp)) {
    stop("Response variables must be specified in newdata for this model.",
         call. = FALSE)
  } else {
    for (resp in missing_resp) {
      # add irrelevant response variables but make sure they pass all checks
      newdata[[resp]] <- NA 
    }
  }
  if (is.formula(ee$cens)) {
    for (cens in setdiff(all.vars(ee$cens), names(newdata))) { 
      newdata[[cens]] <- 0 # add irrelevant censor variables
    }
  }
  if (length(fit$ranef)) {
    if (length(new_ranef) && allow_new_levels) {
      # random effects grouping factors do not need to be specified 
      # by the user if new_levels are allowed
      new_gf <- unique(unlist(strsplit(names(new_ranef), split = ":")))
      missing_gf <- setdiff(new_gf, names(newdata))
      newdata[, missing_gf] <- NA
    }
    # brms:::update_data expects all original variables to be present
    # even if not actually used later on
    old_gf <- unique(unlist(strsplit(names(fit$ranef), split = ":")))
    old_ee <- extract_effects(formula(fit), et$all, family = family(fit),
                              nonlinear = fit$nonlinear)
    old_slopes <- unique(ulapply(get_random(old_ee)$form, all.vars))
    unused_vars <- setdiff(union(old_gf, old_slopes), all.vars(ee$all))
    if (length(unused_vars)) {
      newdata[, unused_vars] <- NA
    }
  }
  newdata <- combine_groups(newdata, get_random(ee)$group)
  # try to validate factor levels in newdata
  if (is.data.frame(fit$data)) {
    # validating is possible (implies brms > 0.5.0)
    list_data <- lapply(as.list(fit$data), function(x)
      if (is.numeric(x)) x else as.factor(x))
    is_factor <- sapply(list_data, is.factor)
    is_group <- names(list_data) %in% names(fit$ranef)
    factors <- list_data[is_factor & !is_group]
    if (length(factors)) {
      factor_names <- names(factors)
      factor_levels <- lapply(factors, levels) 
      for (i in seq_along(factors)) {
        new_factor <- newdata[[factor_names[i]]]
        if (!is.null(new_factor)) {
          if (!is.factor(new_factor)) {
            new_factor <- factor(new_factor)
          }
          new_levels <- levels(new_factor)
          old_levels <- factor_levels[[i]]
          old_contrasts <- contrasts(factors[[i]])
          to_zero <- is.na(new_factor) | new_factor %in% ".ZERO"
          if (any(to_zero)) {
            levels(new_factor) <- c(new_levels, ".ZERO")
            new_factor[to_zero] <- ".ZERO"
            old_levels <- c(old_levels, ".ZERO")
            old_contrasts <- rbind(old_contrasts, .ZERO = 0)
          }
          if (any(!new_levels %in% old_levels)) {
            stop(paste("New factor levels are not allowed. \n",
                 "Levels found:", paste(new_levels, collapse = ", ") , "\n",
                 "Levels allowed:", paste(old_levels, collapse = ", ")),
                 call. = FALSE)
          }
          newdata[[factor_names[i]]] <- factor(new_factor, old_levels)
          # don't use contrasts(.) here to avoid dimension checks
          attr(newdata[[factor_names[i]]], "contrasts") <- old_contrasts
        }
      }
    }
    # validate monotonous variables
    if (is.formula(ee$mono)) {
      take_num <- !is_factor & names(list_data) %in% all.vars(ee$mono)
      # factors have already been checked
      num_mono_vars <- names(list_data)[take_num]
      for (v in num_mono_vars) {
        # use 'get' to check whether v is defined in newdata
        new_values <- get(v, newdata)
        min_value <- min(list_data[[v]])
        invalid <- new_values < min_value | 
                   new_values > max(list_data[[v]]) |
                   !is.wholenumber(new_values)
        if (sum(invalid)) {
          stop(paste0("Invalid values in variable '", v, "': ",
                      paste(new_values[invalid], collapse = ",")),
               call. = FALSE)
        }
        attr(newdata[[v]], "min") <- min_value
      }
    }
  } else {
    warning(paste("Validity of factors cannot be checked for", 
                  "fitted model objects created with brms <= 0.5.0"),
            call. = FALSE)
  }
  # validate grouping factors
  if (length(new_ranef)) {
    gnames <- names(new_ranef)
    for (i in seq_along(gnames)) {
      gf <- as.character(get(gnames[i], newdata))
      new_levels <- unique(gf)
      old_levels <- attr(new_ranef[[i]], "levels")
      unknown_levels <- setdiff(new_levels, old_levels)
      if (!allow_new_levels && length(unknown_levels)) {
        stop(paste("levels", paste0(unknown_levels, collapse = ", "), 
                   "of grouping factor", gnames[i], 
                   "not found in the fitted model"), call. = FALSE)
      } 
      if (return_standata) {
        # transform grouping factor levels into their corresponding integers
        # to match the output of make_standata
        newdata[[gnames[i]]] <- sapply(gf, match, table = old_levels)
      }
    }
  }
  if (return_standata) {
    control <- list(is_newdata = TRUE, not4stan = TRUE,
                    save_order = TRUE, omit_response = !check_response)
    control$old_cat <- is.old_categorical(fit)
    old_terms <- attr(model.frame(fit), "terms")
    control$terms_attr <- attributes(old_terms)[c("variables", "predvars")]
    has_mono <- length(rmNULL(get_effect(ee, "mono")))
    p <- if (length(ee$nonlinear)) paste0("_", names(ee$nonlinear)) else ""
    if (has_trials(fit$family) || has_cat(fit$family) || has_mono) {
      # some components should not be computed based on newdata
      comp <- c("trials", "ncat", paste0("Jm", p))
      control[comp] <- standata(fit)[comp]
    } 
    if (is(fit$autocor, "cor_fixed")) {
      fit$autocor$V <- diag(median(diag(fit$autocor$V), na.rm = TRUE), 
                            nrow(newdata))
    }
    newdata <- make_standata(new_formula, data = newdata, family = fit$family, 
                             autocor = fit$autocor, nonlinear = new_nonlinear,
                             partial = fit$partial, control = control)
  }
  newdata
}

get_model_matrix <- function(formula, data = environment(formula),
                             cols2remove = NULL, ...) {
  # Construct Design Matrices for \code{brms} models
  # 
  # Args:
  #   formula: An object of class formula
  #   data: A data frame created with model.frame. 
  #         If another sort of object, model.frame is called first.
  #   cols2remove: names of the columns to remove from 
  #                the model matrix (mainly used for intercepts)
  #   ...: Further arguments passed to amend_terms
  # 
  # Returns:
  #   The design matrix for a regression-like model 
  #   with the specified formula and data. 
  #   For details see the documentation of \code{model.matrix}.
  stopifnot(is.atomic(cols2remove))
  terms <- amend_terms(formula, ...)
  if (is.null(terms)) {
    return(NULL)
  }
  if (isTRUE(attr(terms, "rm_intercept"))) {
    cols2remove <- union(cols2remove, "Intercept")
  }
  X <- stats::model.matrix(terms, data)
  colnames(X) <- rename(colnames(X), check_dup = TRUE)
  if (length(cols2remove)) {
    X <- X[, - which(colnames(X) %in% cols2remove), drop = FALSE]
  }
  X   
}

get_intercepts <- function(effects, data, family = gaussian()) {
  # create a named list with one element per intercept
  # each containing observation numbers corresponding to it
  if (length(effects$nonlinear)) {
    int_names <- NULL
  } else {
    terms <- terms(rhs(effects$fixed))
    if (is.mv(family, response = effects$response)) {
      term_labels <- attr(terms, "term.labels")
      if (attr(terms, "intercept")) {
        int_names <- "Intercept"
      } else {
        if ("trait" %in% term_labels) {
          int_names <- paste0("trait", levels(data$trait))
        } else if (is.forked(family) && all(c("main", "spec") %in% term_labels)) {
          int_names <- c("main", "spec")
        } else {
          int_names <- NULL
        }
      }
    } else {
      if (attr(terms, "intercept")) {
        int_names <- "Intercept"
      } else {
        int_names <- NULL
      }
    }
  }
  if (length(int_names)) {
    mm <- stats::model.matrix(terms, data)
    colnames(mm) <- rename(colnames(mm), check_dup = TRUE)
    out <- lapply(int_names, function(x) which(mm[, x] != 0))
    Jint <- rep(0, nrow(data))
    for (i in seq_along(out)) Jint[out[[i]]] <- i
    out <- structure(out, names = int_names, Jint = Jint)
  } else {
    out <- list()
  }
  out
}

prepare_mono_vars <- function(data, vars, check = TRUE) {
  # prepare monotonous variables for use in Stan
  # Args:
  #   data: a data.frame or named list
  #   vars: names of monotonous variables
  #   check: check the number of levels? 
  # Returns:
  #   'data' with amended monotonous variables
  stopifnot(is.list(data))
  stopifnot(is.atomic(vars))
  vars <- intersect(vars, names(data))
  for (i in seq_along(vars)) {
    # validate predictors to be modeled as monotonous effects
    if (is.ordered(data[[vars[i]]])) {
      # counting starts at zero
      data[[vars[i]]] <- as.numeric(data[[vars[i]]]) - 1 
    } else if (all(is.wholenumber(data[[vars[i]]]))) {
      min_value <- attr(data[[vars[i]]], "min")
      if (is.null(min_value)) {
        min_value <- min(data[[vars[i]]])
      }
      data[[vars[i]]] <- data[[vars[i]]] - min_value
    } else {
      stop(paste("Monotonous predictors must be either integers or",
                 "ordered factors. Error occured for variable", vars[i]), 
           call. = FALSE)
    }
    if (check && max(data[[vars[i]]]) < 2L) {
      stop(paste("Monotonous predictors must have at least 3 different", 
                 "values. Error occured for variable", vars[i]),
           call. = FALSE)
    }
  }
  data
}

arr_design_matrix <- function(Y, r, group)  { 
  # calculate design matrix for autoregressive effects of the response
  #
  # Args:
  #   Y: a vector containing the response variable
  #   r: ARR order
  #   group: vector containing the grouping variable for each observation
  #
  # Notes: 
  #   expects Y to be sorted after group already
  # 
  # Returns:
  #   the design matrix for ARR effects
  stopifnot(length(Y) == length(group))
  if (r > 0) {
    U_group <- unique(group)
    N_group <- length(U_group)
    out <- matrix(0, nrow = length(Y), ncol = r)
    ptsum <- rep(0, N_group + 1)
    for (j in 1:N_group) {
      ptsum[j + 1] <- ptsum[j] + sum(group == U_group[j])
      for (i in 1:r) {
        if (ptsum[j] + i + 1 <= ptsum[j + 1]) {
          out[(ptsum[j] + i + 1):ptsum[j + 1], i] <- 
            Y[(ptsum[j] + 1):(ptsum[j + 1] - i)]
        }
      }
    }
  } else out <- NULL
  out
}

data_fixef <- function(effects, data, family = gaussian(),
                       autocor = cor_arma(), knots = NULL,
                       nlpar = "", not4stan = FALSE) {
  # prepare data for fixed effects for use in Stan 
  # Args:
  #   effects: a list returned by extract_effects
  #   data: the data passed by the user
  #   family: the model family
  #   autocor: object of class 'cor_brms'
  #   nlpar: optional character string naming a non-linear parameter
  #   not4stan: is the data for use in S3 methods only?
  stopifnot(length(nlpar) == 1L)
  p <- if (nchar(nlpar)) paste0("_", nlpar) else ""
  is_ordinal <- is.ordinal(family)
  is_bsts <- is(autocor, "cor_bsts")
  out <- list()
  if (not4stan && !is_ordinal && !is_bsts || nchar(nlpar)) {
    intercepts <- NULL  # don't remove any intercept columns
  } else {
    intercepts <- get_intercepts(effects, data = data, family = family)  
  }
  X <- get_model_matrix(rhs(effects$fixed), data, 
                        forked = is.forked(family),
                        cols2remove = names(intercepts))
  splines <- get_spline_labels(effects)
  if (length(splines)) {
    # having to fit the model first it a little bit arkward
    # but it currently appears to be the only way to avoid
    # calling internal functions of mgcv...
    control <- list(msMaxEval = 0, returnObject = TRUE)
    G <- SW(mgcv::gamm(effects$gam, data = data, 
                       knots = knots, control = control))
    G <- G$gam$model
    Xs <- G[grepl("^X(\\.[[:digit:]]+$|$)", names(G))]
    Xs <- rmNULL(lapply(Xs, function(v) if (is.matrix(v)) v else NULL))
    Zs <- G[grepl("^Xr(\\.[[:digit:]]+$|$)", names(G))]
    Zs <- rmNULL(lapply(Zs, function(v) if (is.matrix(v)) v else NULL))
    if (length(Xs) != 1L || length(Zs) != length(splines)) {
      stop(paste("Spline matrices are invalid. Did you name", 
                 "some of your variables 'X' or 'Xr'?"),
           call. = FALSE)
    }
    Xs <- Xs[[1]]
    knots <- list(length(splines), as.array(ulapply(Zs, ncol)))
    knots <- setNames(knots, paste0(c("ns", "knots"), p))
    out <- c(out, knots, setNames(Zs, paste0("Zs", p, "_", seq_along(Zs))))
    colnames(Xs) <- rename(colnames(Xs))
    X <- cbind(X, Xs[, -1, drop = FALSE])
  }
  out[[paste0("K", p)]] <- ncol(X)
  center_X <- length(intercepts) && !is_bsts && !(is_ordinal && not4stan)
  if (center_X) {
    if (length(intercepts) == 1L) {
      X_means <- colMeans(X)
      X <- sweep(X, 2L, X_means, FUN = "-")
    } else {
      # multiple intercepts for 'multivariate' models
      X_means <- matrix(0, nrow = length(intercepts), ncol = ncol(X))
      for (i in seq_along(intercepts)) {
        X_part <- X[intercepts[[i]], , drop = FALSE]
        X_means[i, ] <- colMeans(X_part)
        X[intercepts[[i]], ] <- sweep(X_part, 2L, X_means[i, ], FUN = "-")
      }
      out[[paste0("nint", p)]] <- length(intercepts)
      out[[paste0("Jint", p)]] <- attr(intercepts, "Jint")
    }
    out[[paste0("X_means", p)]] <- as.array(X_means)
  }
  out[[paste0("X", p)]] <- X
  out
}

data_monef <- function(effects, data, prior = prior_frame(), 
                       nlpar = "", Jm = NULL) {
  # prepare data for monotonous effects for use in Stan 
  # Args:
  #   effects: a list returned by extract_effects
  #   data: the data passed by the user
  #   prior: an object of class prior_frame
  #   nlpar: optional character string naming a non-linear parameter
  #   Jm: optional precomputed values of Jm
  stopifnot(length(nlpar) == 1L)
  p <- if (nchar(nlpar)) paste0("_", nlpar) else ""
  out <- list()
  if (is.formula(effects$mono)) {
    mmf <- model.frame(effects$mono, data)
    mmf <- prepare_mono_vars(mmf, names(mmf), check = is.null(Jm))
    Xm <- get_model_matrix(effects$mono, mmf)
    if (is.null(Jm)) {
      Jm <- as.array(apply(Xm, 2, max))
    }
    out <- c(out, setNames(list(ncol(Xm), Xm, Jm), 
                           paste0(c("Km", "Xm", "Jm"), p)))
    # validate and assign vectors for dirichlet prior
    monef <- colnames(Xm)
    for (i in seq_along(monef)) {
      take <- prior$class == "simplex" & prior$coef == monef[i] & 
              prior$nlpar == nlpar  
      sprior <- paste0(".", prior$prior[take])
      if (nchar(sprior) > 1L) {
        sprior <- as.numeric(eval(parse(text = sprior)))
        if (length(sprior) != Jm[i]) {
          stop(paste0("Invalid dirichlet prior for the simplex of ", 
                      monef[i], ". Expected input of length ", Jm[i], 
                      " but found ", paste(sprior, collapse = ",")),
               call. = FALSE)
        }
        out[[paste0("con_simplex", p, "_", i)]] <- sprior
      } else {
        out[[paste0("con_simplex", p, "_", i)]] <- rep(1, Jm[i]) 
      }
    }
  }
  out
}

data_csef <- function(effects, data) {
  # prepare data for fixed effects for use in Stan 
  # Args:
  #   effects: a list returned by extract_effects
  #   data: the data passed by the user
  out <- list()
  if (is.formula(effects$cse)) {
    Xp <- get_model_matrix(effects$cse, data)
    out <- c(out, list(Kp = ncol(Xp), Xp = Xp))
  }
  out
}

data_ranef <- function(effects, data, family = gaussian(),
                       nlpar = "", cov_ranef = NULL,
                       is_newdata = FALSE, not4stan = FALSE) {
  # prepare data for random effects for use in Stan 
  # Args:
  #   effects: a list returned by extract_effects
  #   data: the data passed by the user
  #   family: the model family
  #   nlpar: optional character string naming a non-linear parameter
  #   cov_ranef: name list of user-defined covariance matrices
  #   is_newdata: was new data passed to the 'data' argument?
  #   not4stan: is the data for use in S3 methods only?
  stopifnot(length(nlpar) == 1L)
  out <- list()
  random <- effects$random
  if (nrow(random)) {
    Z <- lapply(random$form, get_model_matrix, data = data, 
                forked = is.forked(family))
    r <- lapply(Z, colnames)
    ncolZ <- lapply(Z, ncol)
    # numeric levels passed to Stan
    expr <- expression(as.array(as.numeric(as.factor(get(g, data)))), 
                       length(unique(get(g, data))), # number of levels 
                       ncolZ[[i]],  # number of random effects
                       ncolZ[[i]] * (ncolZ[[i]] - 1) / 2)  # number of correlations
    if (is_newdata) {
      # for newdata only as levels are already defined in amend_newdata
      expr[1] <- expression(get(g, data)) 
    }
    for (i in 1:nrow(random)) {
      g <- random$group[[i]]
      p <- if (nchar(nlpar)) paste0(nlpar, "_", i) else i
      name <- paste0(c("J_", "N_", "K_", "NC_"), p)
      for (j in 1:length(name)) {
        out <- c(out, setNames(list(eval(expr[j])), name[j]))
      }
      Zname <- paste0("Z_", p)
      if (isTRUE(not4stan)) {
        # for internal use in S3 methods
        if (ncolZ[[i]] == 1L) {
          Z[[i]] <- as.vector(Z[[i]])
        }
        out <- c(out, setNames(Z[i], Zname))
      } else {
        if (ncolZ[[i]] > 1L) {
          Zname <- paste0(Zname, "_", 1:ncolZ[[i]])
        }
        for (j in 1:ncolZ[[i]]) {
          out <- c(out, setNames(list(as.array(Z[[i]][, j])), Zname[j]))
        }
      }
      if (g %in% names(cov_ranef)) {
        cov_mat <- as.matrix(cov_ranef[[g]])
        if (!isSymmetric(unname(cov_mat))) {
          stop(paste("covariance matrix of grouping factor", g, 
                     "is not symmetric"), call. = FALSE)
        }
        found_level_names <- rownames(cov_mat)
        if (is.null(found_level_names)) {
          stop(paste("rownames are required for covariance matrix of", g),
               call. = FALSE)
        }
        colnames(cov_mat) <- found_level_names
        true_level_names <- levels(as.factor(get(g, data)))
        found <- true_level_names %in% found_level_names
        if (any(!found)) {
          stop(paste("rownames of covariance matrix of", g, 
                     "do not match names of the grouping levels"),
               call. = FALSE)
        }
        cov_mat <- cov_mat[true_level_names, true_level_names, drop = FALSE]
        if (min(eigen(cov_mat, symmetric = TRUE, 
                      only.values = TRUE)$values) <= 0) {
          warning(paste("covariance matrix of grouping factor", g, 
                        "may not be positive definite"), call. = FALSE)
        }
        out <- c(out, setNames(list(t(chol(cov_mat))), paste0("Lcov_", p)))
      }
    }
  }
  out
}
