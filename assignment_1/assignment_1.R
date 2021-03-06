library(data.table)
library(here)
library(MASS)
library(ggplot2)

convert_to_paired_diff <- function(df){
## Convert a dataframe of treatments to a paired difference dataframe
## param df: dataframe to be converted
## return: list with paired difference dataframe, d, number of variable, p, and number of
##         observations, n
  
  # Are there equal number of vars in both treatments
  if(ncol(df)%%2 != 0){
    stop('Not equal number of variables for treatment 1 and 2')
  }
  
  #Number of vars
  p = ncol(df)/2
  
  #Number of obs
  n <- nrow(df)
  
  #Calculate difference between variables for treatments
  d <- matrix(ncol=p,nrow=n)
  
  for(i in 1:p){
    col_name <- paste0('d',i)
    d[,i] <- df[,i]-df[,i+p]
  }
  
  #Return list with paired difference dataframe, number of vars and number of obs
  return(list('d'=as.data.frame(d), 'p' = p, 'n' = n))
}

hypothesis_test <- function(df, significance){
  ## Function to do a paired-difference hypothesis test, outputting the calculated t-squared
  ## along with the critical value and also the result of the hypothesis test and it's p-value
  ## param df: Dataframe containing treatment 1 and treatment 2 data
  ## param significance: significance level of test
  
  #Retrieve paired differences
  paired_diff <- convert_to_paired_diff(df)
  d <- paired_diff$d
  p <- paired_diff$p
  n <- paired_diff$n
  
  #Calc stats
  dbar <- colMeans(d)
  sd <- cov(d)
  t_square <- n*dbar%*%solve(sd)%*%dbar
  crit <- ((n-1)*p/(n-p))*qf(1-significance,p,n-p)
  p_val <- 1-pf(t_square, p, n-p)
  
  #Logic to reject or accept hypothesis at specific level
  if(t_square > crit){
    print(paste0('T^2 = ',round(t_square, 4),' > ', round(crit, 4),
                 ' We thus reject the null hypothesis and conclude that there is a nonzero mean difference between the measurements with significance level alpha = '
                 , significance))
  }else{
    
    print(paste0('T^2 = ',round(t_square, 4),' < ', round(crit, 4),
                 ' We thus do not reject the null hypothesis and conclude that there is not a significant difference between the measurements at significance level alpha = '
                 , significance))
  }
  
  #Also return p-value
  print(paste0('p-value = ', p_val))
}


table_6_1 <- as.data.frame(fread(file = here('assignment_1/T6-1.dat')))

hypothesis_test(table_6_1, 0.05)

confidence_interval <- function(df, a, significance){
## Function to construct T^2 and Bonferroni confidence interval
## param df: dataframe for which to construct confidence interval
## param a: vector in form to select variable for which to construct CI
## param significance: significance level for which to construct CI
## return: list with T^2 CI, t_conf_int, and Bonferroni CI, bonf_conf_int
  
  #Retrieve paired differences
  paired_diff <- convert_to_paired_diff(df)
  d <- paired_diff$d
  p <- paired_diff$p
  n <- paired_diff$n
  
  #Calc stats
  dbar <- colMeans(d)
  sd <- cov(d)
  
  #Build up factors to add and subtract using supplied functions
  t_conf_int <- sqrt((((n-1)*p/(n-p))*qf(1-significance,p,n-p))*(a%*%sd%*%a/n))
  
  bonf_conf_int <- qt(1-significance/(2*p), n-1)*sqrt((a%*%sd%*%a/n))
  
  #Return list with CI's
  return(list('t_conf_int' = c(a%*%dbar - t_conf_int, a%*%dbar + t_conf_int),
              'bonf_conf_int' = c(a%*%dbar - bonf_conf_int, a%*%dbar + bonf_conf_int)))
}

a <- c(1,0)

confidence_interval(table_6_1, a,0.05)

a <- c(0,1)

confidence_interval(table_6_1, a,0.05)

draw_ellipse <- function(df, significance){
## Function to draw confidence region
## param df: two dimensional dataframe for which to construct confidence region
## significance: significance level for which to construct confidence region
  
  #Retrieve paired differences
  p <- ncol(df)
  n <- nrow(df)
  
  # Calc stats
  dbar <- colMeans(df)
  sd <- cov(df)
  crit <- ((n-1)*p/(n*(n-p)))*qf(1-significance,p,n-p)
  
  #Setup region
  x_min <- min(df[,1])
  x_max <- max(df[,1])
  
  y_min <- min(df[,2])
  y_max <- max(df[,2])
  
  x <- seq(x_min,x_max,length=100)
  y <- seq(y_min,y_max,length=100)
  grid_data <- as.matrix(expand.grid(x,y))
  
  ng<-nrow(grid_data)
  np<-length(y)
  
  # Obtaining points inside the elliptic region using sign()
  sign_grid<-matrix(rep(0,ng),nrow=ng,ncol=1)
  
  for (i in 1:ng){
    sign_grid[i,]<-sign((t(dbar - grid_data[i,])%*%solve(sd)%*%(dbar-grid_data[i,]))-crit) 
  }
  
  # Plotting the boundary of ellipse
  plot(df[,1],df[,2],xlim=c(x_min,x_max),ylim=c(y_min,y_max),xlab="x",ylab="y",
       col="red",pch=16,cex=1.25)
  par(new=T)
  contour(x,y,matrix(sign_grid,np),add=TRUE,drawlabels=FALSE,levels=0,lty=2,lwd=2,
          col="black")
  
  mat<-cbind(sign_grid,grid_data)
  
  region<-matrix(mat[mat[,1]==-1],ncol=3)
  
  # Plotting the points inside the ellipse
  par(new=T)
  plot(region[,2:3],xlim=c(x_min,x_max),ylim=c(y_min,y_max),col="red",xlab="x",
       ylab="y",pch=".",main="Ellipse" )
}

paired_diff <- convert_to_paired_diff(table_6_1)
d <- paired_diff$d
significance <- 0.05

draw_ellipse(d, significance)

eq_of_treatments_in_rep_des <- function(df, C, significance){
## Function to do a hypothesis test for equality of treatments in repeated design, with a confidence interval
## param df: dataframe containing measurements of all treatments applied to each unit (each column as a treatment)
## param C: contrast matrix
## param significance: significance level of hypothesis test
  
  # Calc stats
  n <- nrow(df)
  q <- ncol(df)
  dbar <- colMeans(df)
  sd <- cov(df)
  t_squared <- n*t(C%*%dbar)%*%solve(C%*%sd%*%t(C))%*%C%*%dbar
  crit <- (n-1)*(q-1)/(n-q+1)*qf(1-significance,q-1,n-q+1)
  p_val <- 1-pf(t_squared, p, n-p)
  
  #Perform hypothesis test
  if(t_squared > crit){
    print(paste0('T^2 = ', t_squared, ' > ',crit))
    print('We therefore reject the null hypothesis H0:C*mu = 0 and determine that there is possibly treatment effects')
  }else{
    print(paste0('T^2 = ', t_squared, ' < ',crit))
    print('We therefore do not reject the null hypothesis H0:C*mu = 0 and determine that there is no treatment effects')
  }
  
  print(paste0('p-value = ', p_val))
  
  #Build up confidence intervals
  apply(C,1,function(c){
    ci <- sqrt(crit*(t(c)%*%sd%*%c/n))
    print(paste0('100(1-',significance,')% Confidence interval: (',c%*%dbar-ci,'; ',c%*%dbar+ci,')'))
  })
}

C <- matrix(c(-1,-1,1,1,1,-1,1,-1,1,-1,-1,1),nrow=3,byrow = TRUE)

table_6_2 <- as.data.frame(fread(file = here('assignment_1/T6-2.dat')))

eq_of_treatments_in_rep_des(table_6_2, C, 0.05)

treatment_1 <- matrix(c(6,5,8,4,7,7,9,6,9,9), nrow=5)
treatment_2 <- matrix(c(3,1,2,3,6,3), nrow=3)
treatment_3 <- matrix(c(2,5,3,2,3,1,1,3), nrow=4)

mu1 <- colMeans(treatment_1)
mu2 <- colMeans(treatment_2)
mu3 <- colMeans(treatment_3)

mu <- (mu1+mu2+mu3)/3

est_treatment_effect_1 <- mu1-mu
est_treatment_effect_2 <- mu2-mu
est_treatment_effect_3 <- mu3-mu

residual_1 <- treatment_1-mu1
residual_2 <- treatment_2-mu2
residual_3 <- treatment_3-mu3

assertthat::are_equal(treatment_1, mu+est_treatment_effect_1+residual_1)
assertthat::are_equal(treatment_2, mu+est_treatment_effect_2+residual_2)
assertthat::are_equal(treatment_3, mu+est_treatment_effect_3+residual_3)

B <- nrow(treatment_1)*(mu1-mu)%*%t(mu1-mu) + nrow(treatment_2)*(mu2-mu)%*%t(mu2-mu) + nrow(treatment_3)*(mu3-mu)%*%t(mu3-mu)

W <- (t(treatment_1)-mu1)%*%t(t(treatment_1)-mu1) + (t(treatment_2)-mu2)%*%t(t(treatment_2)-mu2) + (t(treatment_3)-mu3)%*%t(t(treatment_3)-mu3)

total <- (t(treatment_1)-mu)%*%t(t(treatment_1)-mu) + ((t(treatment_2)-mu)%*%t(t(treatment_2)-mu)) + ((t(treatment_3)-mu)%*%t(t(treatment_3)-mu))

assertthat::are_equal(B+W, total)

box_test <- function(df, significance){
  g <- nrow(unique(iris[,'Species']))
  
  p <- ncol(iris[,-'Species'])
  
  for(i in 1:g){
    iris_subset <- iris[iris$Species == i, -'Species']
    
    n <- nrow(iris_subset)
    
    S <- cov(iris_subset)
    
    if(i == 1){
      S_pooled <- (n-1)*S
      
      u1 <- 1/(n-1)
      
      u2 <- n - 1
      
      M1 <- (n-1)*log(det(S))
    }else{
      S_pooled <- S_pooled + (n-1)*S
      
      u1 <- u1 + (1/(n-1))
      
      u2 <- u2 + (n - 1)
      
      M1 <- M1 + (n-1)*log(det(S))
    }
  }
  
  u3 <- (2*p*p+3*p-1)/(6*(p+1)*(g-1))
  
  u <- (u1-1/u2)*u3
  
  S_pooled <- 1/u2*S_pooled
  
  M <- u2*log(det(S_pooled))-M1
  
  C <- (1-u)*M
  
  df <- p*(p+1)*(g-1)/2
  
  crit <- qchisq(significance, df = df)
  
  
  #Perform hypothesis test
  if(C > crit){
    print(paste0('C = ', C, ' > ',crit))
    print('We therefore reject the null hypothesis H0:Sigma1 = Sigma2 = Sigma3 = Sigma4 = Sigma and determine that the covariances are possibly not equal')
  }else{
    print(paste0('C = ', C, ' < ',crit))
    print('We therefore do not reject the null hypothesis H0:Sigma1 = Sigma2 = Sigma3 = Sigma4 = Sigma and determine that the covariances are equal')
  }
}

iris <- fread(here('/assignment_1/T11-5.dat'), sep = ' ')

colnames(iris) <- c('Sepal_Length', 'Sepal_Width','Petal_Length', 'Petal_Width','Species')

box_test(iris, 0.05)

