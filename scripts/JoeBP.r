## Biopathway
library(R6)
library(deSolve)
library(pracma)
library(mvtnorm)


noise = 0.017^2 #0.0018^2 #0.052^2
SEED=19537
set.seed(SEED)

### define ode 
BP_fun = function(t, x, par_ode){
  k1 = par_ode[1]
  k2 = par_ode[2]
  k3 = par_ode[3]
  k4 = par_ode[4]
  k5 = par_ode[5]
  k6 = par_ode[6]
  as.matrix( c( -k1*x[1]-k2*x[1]*x[3]+k3*x[4], k1*x[1],-k2*x[1]*x[3]+k3*x[4]+k5*x[5]/(k6+x[5]),
   k2*x[1]*x[3]-k3*x[4]-k4*x[4],k4*x[4]-k5*x[5]/(k6+x[5])) )
}

BP_grlNODE= function(par_ode,grad_ode,y_p,z_p) { 
  k1 = par_ode[1]; k2 = par_ode[2]; k3 = par_ode[3]
  k4 = par_ode[4]; v = par_ode[5]; km = par_ode[6]
  lm= max(dim(y_p))
  dz1 = grad_ode[1,];dz2 = grad_ode[2,];dz3 = grad_ode[3,];dz4 = grad_ode[4,];dz5 = grad_ode[5,];
  z1=y_p[1,];z2=y_p[2,];z3=y_p[3,];z4=y_p[4,];z5=y_p[5,];
  dres= c(0)
  dres[1] = sum( -2*( z_p[1,1:lm]-dz1)*(-z1*k1) - 2*(z_p[2,1:lm]-dz2)*z1*k1 )
  dres[2] = sum( -2*( z_p[1,1:lm]-dz1)*(-z1*z3*k2) + 2*(z_p[3,1:lm]-dz3)*z1*z3*k2 - 2*(z_p[4,1:lm]-dz4)*z1*z3*k2 )   
  dres[3] = sum(  2*( z_p[1,1:lm]-dz1)*(-z4*k3) - 2*(z_p[3,1:lm]-dz3)*z4*k3 + 2*(z_p[4,1:lm]-dz4)*z4*k3 )    
  dres[4] = sum( 2*(z_p[4,1:lm]-dz4)*z4*k4 - 2*(z_p[5,1:lm]-dz5)*z4*k4 )   
  dres[5] = sum( -2*(z_p[3,1:lm]-dz3)*z5*v/(km+z5) +  2*(z_p[5,1:lm]-dz5)*z5*v/(km+z5)  )    
  dres[6] = sum( 2*(z_p[3,1:lm]-dz3)*v*z5/(km+z5)^2*km - 2*(z_p[5,1:lm]-dz5)*v*z5/(km+z5)^2*km )                  
  dres
} 

#############################################################

M1 <- function(t,inix,par_ode){
  with( as.list(c(inix,par_ode)),{
    dx1 = -par_ode[1]*x1-par_ode[2]*x1*x3+par_ode[3]*x4
    dx2 =  par_ode[1]*x1
    dx3 = -par_ode[2]*x1*x3+par_ode[3]*x4+par_ode[5]*x5/(par_ode[6]+x5)
    dx4 = par_ode[2]*x1*x3-par_ode[3]*x4-par_ode[4]*x4
    dx5 = par_ode[4]*x4-par_ode[5]*x5/(par_ode[6]+x5) 
    list(c(dx1,dx2,dx3,dx4,dx5))
    })
    }
state = c( x1=1,x2=0,x3=1,x4=0,x5=0 )
truep = c(0.07,0.6,0.05,0.3,0.017,0.3)
##############################################################

source('/Users/joewandy/git/rkhs_gradmatch/kernel.r')
source('/Users/joewandy/git/rkhs_gradmatch/rkhs.r')
source('/Users/joewandy/git/rkhs_gradmatch/rk3g.r')
source('/Users/joewandy/git/rkhs_gradmatch/ode.r')
source('/Users/joewandy/git/rkhs_gradmatch/WarpSin.r')

source('/Users/joewandy/git/rkhs_gradmatch/warpfun.r')
source('/Users/joewandy/git/rkhs_gradmatch/crossv.r')
source('/Users/joewandy/git/rkhs_gradmatch/warpInitLen.r')
source('/Users/joewandy/git/rkhs_gradmatch/third.r')
source('/Users/joewandy/git/rkhs_gradmatch/rkg.r')

##################  generate data, if user want to run the real data just skip this step  #################################### 
kkk0 = ode$new(1,fun=BP_fun,grfun=BP_grlNODE)
xinit = as.matrix(c(1,0,1,0,0))
tinterv = c(0,100)
kkk0$solve_ode(c(0.07,0.6,0.05,0.3,0.017,0.3),xinit,tinterv)
 start =6
 select=2
 pick =c( 1:(start-1),seq(start,(length(kkk0$t)-1),select),length(kkk0$t))

########################### build the ode objects  #######################################
init_par = rep(c(0.1),6)
init_yode = kkk0$y_ode[,pick] ## you can add observation here
init_t = kkk0$t[pick]  ## you can add the time index for the observation here

# kkk = ode$new(1,fun=BP_fun,grfun=BP_grlNODE,t= init_t,ode_par= init_par, y_ode=init_yode )
kkk = ode$new(1,fun=BP_fun,t= init_t,ode_par= init_par, y_ode=init_yode )

n_o = max( dim( kkk$y_ode) )
y_no =  t(kkk$y_ode) + rmvnorm(n_o,c(0,0,0,0,0),noise*diag(5)) ## for real data, we need to let y_no = data where  the row index is the index for states


############################# parameter inference   ############################## 
##### standard gradient matching
ktype='rbf' ## there are two options 'rbf' and 'mlp'
rkgres = rkg(kkk,y_no,ktype) ## do the standard gradiet matching
bbb = rkgres$bbb   ## bbb is a rkhs object which contain all information about interpolation and kernel parameters.

kkk$ode_par
plot(bbb[[1]]$t,rkgres$intp[1,],type='l')              ## plot interpolation with time points for data 
plot(kkk0$t,bbb[[1]]$predictT(kkk0$t)$pred,type='l')   ## plot interpolation with denser grids

############# gradient matching + thrid step
crtype='i'  ## two methods fro third step  'i' fast method means iterative and '3' for slow method means 3rd step

lam=c(1e-4,1e-5)  ## we need to do cross validation for find the weighter parameter
lamil1 = crossv(lam,kkk,bbb,crtype,y_no)
lambdai1=lamil1[[1]]

res = third(lambdai1,kkk,bbb,crtype) ## runing the third step to improve ode parameter estimation 
oppar = res$oppar
plot(res$rk3$rk[[1]]$t,res$rk3$rk[[1]]$predict()$pred,type='l') ## plot interpolation with data grids
plot(kkk0$t,res$rk3$rk[[1]]$predictT(kkk0$t)$pred,type='l')  ## plot interpolation with denser grids

## if we want to see the diagnostic, we need to make crtype='3' and we will see the convergence 
crtype='3'
res = third(lambdai1,kkk,bbb,crtype)


########## warp  
###### warp state
peod = c(200,200,200,200,200)   ## the guessing period for each state  user defined
eps= 20          ## the standard deviation of period  user defined

#lens=c(3,4,5) ## user can define the init value of lens for sigmoid function. the default is c(3,4,5)
fixlens=warpInitLen(peod,eps,rkgres) ## find the start value for the warping basis function.

www = warpfun(kkk,p0,bbb,peod,eps,fixlens,kkk$t,y_no)

dtilda= www$dtilda
bbbw = www$bbbw
resmtest = www$wtime
wfun=www$wfun
wkkk = www$wkkk

wkkk$ode_par

plot(kkk$t,resmtest[1,],type='l')   ## plotting function
plot(resmtest[1,],bbbw[[1]]$predict()$pred,type='l')  ## plot interpolation in warped time domain
plot(kkk$t,bbbw[[1]]$predict()$pred,type='l')  ## plot interpolation in warped time domain
wgrid = wfun[[1]]$predictT(kkk0$t)$pred ## denser grid in warped domain
plot( kkk0$t, bbbw[[1]]$predictT(wgrid)$pred,type='l') ## plot interpolatin with denser grid in original domain

y=seq(0,10,0.01)
plot(y,bbbw[[1]]$predictT(y)$pred,type='l')  ## plot interpolation in warped time domain

##### 3rd step + warp
woption='w'
####   warp   3rd
crtype = 'i'

lamwil= crossv(lam,wkkk,bbbw,crtype,y_no,woption,resmtest,dtilda) 
lambdawi=lamwil[[1]]

res = third(lambdawi,wkkk,bbbw,crtype,woption,dtilda)  ## add third step after warping

oppar = res$oppar  

# plot(res$rk3$rk[[1]]$t,res$rk3$rk[[1]]$predict()$pred,type='l') ## plot interpolation with data grids in warped domain
# plot(kkk$t,res$rk3$rk[[1]]$predict()$pred,type='l') ## plot interpolation with data grids in original domain

wgrid = wfun[[1]]$predictT(kkk0$t)$pred
plot(kkk0$t,res$rk3$rk[[1]]$predictT( wgrid)$pred,type='l')  ## plot interpolation with denser grids in original domain. 

