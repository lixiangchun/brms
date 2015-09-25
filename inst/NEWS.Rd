\name{NEWS}
\title{brms News}
\encoding{UTF-8}

\section{UNDER DEVELOPMENT}{
  \subsection{NEW FEATURES}{
    \itemize{
      \item add support for inverse gaussian models through family \code{inverse.gaussian}
      \item binomial and ordinal families now support the \code{cauchit} link function
      \item allow family functions to be used in the \code{family} argument
      \item easy access to various \code{rstan} plotting functions 
      using the \code{stanplot} method
    }
  }
  \subsection{OTHER CHANGES}{
    \itemize{
      \item improve documenation to better explain differences in 
      autoregressive effects across R packages
    }
  }
  \subsection{BUG FIXES}{
    \itemize{
      \item avoid side effects of \code{rstan}'s compilation routines that could 
      occasionally cause R to crash
    }
  }
}

\section{CHANGES IN VERSION 0.5.0}{
  \subsection{NEW FEATURES}{
    \itemize{
      \item compute the Watanabe-Akaike information criterion (WAIC) and leave-one-out 
      cross-validation (LOO) using the loo package.
      \item provide an interface to shinystan with S3 method \code{launch_shiny}.
      \item new functions \code{get_prior} and \code{set_prior} to make prior specifications easier.
      \item log-likelihood values and posterior predictive samples can now 
      be calculated within R after the model has been fitted. 
      \item make predictions based on new data using S3 method \code{predict}.
      \item allow for customized covariance structures of grouping factors with multiple random effects.
      \item new S3 methods \code{fitted} and \code{residuals} to compute fitted 
      values and residuals, respectively.
    }
  }
  \subsection{OTHER CHANGES}{
    \itemize{
      \item arguments \code{WAIC} and \code{predict} are removed from function \code{brm},
      as they are no longer necessary.
      \item new argument \code{cluster_type} in function \code{brm} allowing to choose the cluster type 
      created by the parallel package
      \item remove chains that fail to initialize while sampling in parallel leaving 
      the other chains untouched.
      \item redesign trace and density plots to be faster and more stable.
      \item S3 method \code{VarCorr} now always returns covariance matrices regardless of whether 
      correlations were estimated.
    }
  }
  \subsection{BUG FIXES}{
    \itemize{
       \item fix a bug in S3 method \code{hypothesis} related to the calculation of 
       Bayes factors for point hypotheses.
       \item user defined covariance matrices that are not strictly positive definite 
       for numerical reasons should now be handled correctly.
       \item fix minor issues with internal parameter naming.
       \item perform additional checking on user defined priors.
    }
  }
}

\section{CHANGES IN VERSION 0.4.1}{
  \subsection{NEW FEATURES}{
    \itemize{
      \item allow for sampling from all specified proper priors in the model.
      \item calculate Bayes factors for point hypotheses in S3 method \code{hypothesis}.
    }
  }
  \subsection{BUG FIXES}{
    \itemize{
      \item fix a bug that could cause an error for models with multiple grouping factors.
      \item fix a bug that could cause an error for weighted poisson and exponential models. 
    }
  }
}

\section{CHANGES IN VERSION 0.4.0}{
  \subsection{NEW FEATURES}{
    \itemize{
      \item implement the Watanabe-Akaike Information Criterion (WAIC)
      \item implement the ||-syntax for random effects allowing for the estimation of 
      random effects standard deviations without the estimation of correlations.
      \item allow to combine multiple grouping factors within one random effects 
      argument using the interaction symbol \code{:}
      \item generalize S3 method \code{hypothesis} to be used with all parameter classes 
      not just fixed effects. In addition, one-sided hypothesis testing is now possible.
      \item introduce new family \code{multigaussian} allowing for multivariate normal regression.
      \item introduce new family \code{bernoulli} for dichotomous response variables 
      as a more efficient alternative to families \code{binomial} or \code{categorical}
      in this special case.
    }
  }
  \subsection{OTHER CHANGES}{
    \itemize{
      \item slightly change the internal structure of brms to reflect that 
      \code{rstan} is finally on CRAN.
      \item thoroughly check validity of the response variable before the data is passed to Stan.
      \item prohibit variable names containing double underscores \code{__} 
      to avoid naming conflicts.
      \item allow function calls with several arguments (e.g. \code{poly(x,3)}) 
      in the formula argument of function \code{brm}.
      \item always center random effects estimates returned by S3 method \code{ranef} around zero.
      \item prevent the use of customized covariance matrices for 
      grouping factors with multiple random effects for now. 
      \item remove any experimental \code{JAGS} code from the package. 
    }
  }
  \subsection{BUG FIXES}{
    \itemize{
      \item fix a bug in S3 method \code{hypothesis} leading to an error when numbers with 
      decimal places were used in the formulation of the hypotheses. 
      \item fix a bug in S3 method \code{ranef} that caused an error for 
      grouping factors with only one random effect.
      \item fix a bug that could cause the fixed intercept to be 
      wrongly estimated in the presence of multiple random intercepts. 
    }
  }
}

\section{CHANGES IN VERSION 0.3.0}{
  \subsection{NEW FEATURES}{
    \itemize{
      \item introduce new methods \code{parnames} and \code{posterior_samples} 
      for class 'brmsfit' to extract parameter names and posterior samples 
      for given parameters, respectively.
      \item introduce new method \code{hypothesis} for class \code{brmsfit} 
      allowing to test non-linear hypotheses concerning fixed effects
      \item introduce new argument \code{addition} in function brm 
      to get a more flexible approach in specifying additional information 
      on the response variable (e.g., standard errors for meta-analysis). 
      Alternatively, this information can also be passed to the \code{formula} argument directly.
      \item introduce weighted and censored regressions through argument 
      \code{addition} of function brm
      \item introduce new argument \code{cov.ranef} in function brm allowing 
      for customized covariance structures of random effects
      \item introduce new argument \code{autocor} in function brm 
      allowing for autocorrelation of the response variable.
      \item introduce new functions \code{cor.ar}, \code{cor.ma}, and \code{cor.arma}, 
      to be used with argument \code{autocor} for modeling autoregressive, moving-average, 
      and autoregressive-moving-average models. 
    }
  }
  \subsection{OTHER CHANGES}{
    \itemize{
      \item amend parametrization of random effects to increase efficiency of 
      the sampling algorithms
      \item improve vectorization of sampling statements
    }
  }
  \subsection{BUG FIXES}{
    \itemize{
      \item fix a bug that could cause an error when fitting poisson models 
      while \code{predict = TRUE}
      \item fix a bug that caused an error when sampling only one chain 
      while \code{silent = TRUE}   
    }
  }
}

\section{CHANGES IN VERSION 0.2.0}{
  \subsection{NEW FEATURES}{
    \itemize{
      \item new S3 class \code{brmsfit} to be returned by function brm
      \item new methods for class \code{brmsfit}: \code{summary}, \code{print}, 
      \code{plot}, \code{predict}, \code{fixef}, \code{ranef}, \code{VarCorr}, 
      \code{nobs}, \code{ngrps}, and \code{formula}
      \item introduce new argument \code{silent} in function brm, allowing 
      to suppress most of Stan's intermediate output
      \item introduce new families \code{negbinomial} (negative binomial) 
      and \code{geometric} to allow for more flexibility in modeling count data
    }
  }
  \subsection{OTHER CHANGES}{
    \itemize{
      \item amend warning and error messages to make them more informative
      \item correct examples in the documentation
      \item extend the README file 
    }
  }
  \subsection{BUG FIXES}{
    \itemize{
      \item fix a bug that caused an error when formulas contained more complicated function calls
      \item fix a bug that caused an error when posterior predictives were 
      sampled for family \code{cumulative}
      \item fix a bug that prohibited to use of improper flat priors 
      for parameters that have proper priors by default
    }
  }
}

\section{CHANGES IN VERSION 0.1.0}{
  \itemize{
    \item initial release version
  }
}