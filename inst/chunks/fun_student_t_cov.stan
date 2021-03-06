  /* multi-student-t log-PDF for special residual covariance structures 
   * currently only ARMA effects of order 1 are implemented 
   * Args: 
   *   y: response vector 
   *   nu: degrees of freedom parameter 
   *   eta: linear predictor 
   *   se2: square of user defined standard errors 
   *        will be set to zero if non are defined 
   *   I: number of groups 
   *   begin: the first observation in each group 
   *   end: the last observation in each group 
   *   nobs: number of observations in each group 
   *   res_cov_matrix: AR1, MA1, or ARMA1 covariance matrix; 
   * Returns: 
   *   sum of the log-PDF values of all observations 
   */ 
   real student_t_cov_log(vector y, real nu, vector eta, vector se2, 
                          int I, int[] begin, int[] end, int[] nobs, 
                          matrix res_cov_matrix) { 
     vector[I] lp; 
     for (i in 1:I) { 
       matrix[nobs[i], nobs[i]] Sigma; 
       Sigma <- res_cov_matrix[1:nobs[i], 1:nobs[i]] 
                + diag_matrix(se2[begin[i]:end[i]]); 
       lp[i] <- multi_student_t_log(y[begin[i]:end[i]], nu, 
                                    eta[begin[i]:end[i]], Sigma); 
     }                        
     return sum(lp); 
   }
