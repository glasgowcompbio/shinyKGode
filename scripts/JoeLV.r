source('../rkhs_gradmatch/ode.r')
source('../rkhs_gradmatch/kernel1.r')
source('../rkhs_gradmatch/rkhs1.r')
source('../rkhs_gradmatch/intfun.r')
source('../rkhs_gradmatch/rk3g1.r')
source('../rkhs_gradmatch/WarpSin.r')

noise = 0.1  ## 10db:34 1 20db:34 0.1  30db:2 0.01   40db:18 0.001
SEED = 19537

library(pspline)
### define ode 
    LV_fun = function(t,x,par_ode){
        print(par_ode)
        alpha=par_ode[[1]]
        beta=par_ode[[2]]
        gamma=par_ode[[3]]
        delta=par_ode[[4]]
        as.matrix( c( alpha*x[1]-beta*x[2]*x[1] , -gamma*x[2]+delta*x[1]*x[2] ) )
    }

    LV_grlNODE= function(par,grad_ode,y_p,z_p) { 
        alpha = par[1]; beta= par[2]; gamma = par[3]; delta = par[4]
        dres= c(0)
        dres[1] = sum( -2*( z_p[1,]-grad_ode[1,])*y_p[1,]*alpha ) #sum( -2*( z_p[1,2:lm]-dz1)*z1*alpha ) 
        dres[2] = sum( 2*( z_p[1,]-grad_ode[1,])*y_p[2,]*y_p[1,]*beta)  #sum( 2*( z_p[1,2:lm]-dz1)*z2*z1*beta)
        dres[3] = sum( 2*( z_p[2,]-grad_ode[2,])*gamma*y_p[2,] )    #sum( 2*( z_p[2,2:lm]-dz2)*gamma*z2 )
        dres[4] = sum( -2*( z_p[2,]-grad_ode[2,])*y_p[2,]*y_p[1,]*delta) #sum( -2*( z_p[2,2:lm]-dz2)*z2*z1*delta)
        dres
    }

    M1 = function(t,inix,par_ode){
     with( as.list(c(inix,par_ode)),{
    dx1 =  par_ode[1]*x1-par_ode[2]*x2*x1 
    dx2 =  -par_ode[3]*x2+par_ode[4]*x1*x2
    list(c(dx1,dx2))
      })
    }

# kkk = ode$new(2,fun=LV_fun,grfun=LV_grlNODE)
kkk = ode$new(2,fun=LV_fun)
xinit = as.matrix(c(0.5,1))
tinterv = c(0,6)
params = c(alpha=1, beta=1, gamma=4, delta=1)
kkk$solve_ode(params,xinit,tinterv)  #z_p = kkk$gradient(kkk$y_ode,c(1,1,4,1))
n_o = max( dim( kkk$y_ode) )

set.seed(SEED)
y_no =  t(kkk$y_ode) + rmvnorm(n_o,c(0,0),noise*diag(2))
nst = 2   ## number of states
npar = 4  ## number of parameters

# standard gradient matching
ktype='rbf'
rkgres = rkg(kkk,nst,npar,y_no,ktype)
bbb = rkgres$bbb

kkk$ode_par

############# gradient matching + thrid step
crtype = '3'
lambda3 = 1e-1
res = third(lambda3,kkk,bbb,crtype)

oppar = res$oppar
tail(oppar[[1]],4)


########## warp    rkgw 194.683 seconds   rkg  8.849 seconds
###### warp state
peod = c(6,5.3) #8#9.7     ## the guessing period
eps= 1          ## the standard deviation of period
fixlens=c(3,3)
www = warpfun(kkk,p0,bbb,eps,fixlens)
dtilda= www$dtilda
bbbw = www$bbbw

kkk$ode_par

##### 3rd step + warp
woption='w'
####   warp   3rd
crtype = '3'

lambdaw3= 1e-1
res = third(lambdaw3,kkk,bbbw,crtype,woption,dtilda)

oppar = res$oppar  
tail(oppar[[1]],4)

