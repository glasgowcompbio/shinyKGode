## Biopathway

noise = 0.017^2 #0.0018^2 #0.052^2
SEED=19537

library(pspline)
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

### generate data
source('ode.r')
kkk0 = ode$new(1,fun=BP_fun,grfun=BP_grlNODE)
xinit = as.matrix(c(1,0,1,0,0))
tinterv = c(0,100)
kkk0$solve_ode(c(0.07,0.6,0.05,0.3,0.017,0.3),xinit,tinterv)
 start =6
 select=2
 pick =c( 1:(start-1),seq(start,(length(kkk0$t)-1),select),length(kkk0$t))

kkk = ode$new(1,fun=BP_fun,grfun=BP_grlNODE)
kkk$y_ode = kkk0$y_ode[,pick]
kkk$t = kkk0$t[pick]
n_o = max( dim( kkk$y_ode) )

set.seed(SEED)
y_no =  t(kkk$y_ode) + rmvnorm(n_o,c(0,0,0,0,0),noise*diag(5))
nst = 5    ## number of states
npar = 6   ## number of parameters

############################# parameter inference   ##############################
source('kernel1.r')
source('rkhs1.r')
source('intfun.r')
source('rk3g1.r')
 

##### standard gradient matching
ktype='rbf'
rkgres = rkg(kkk,nst,npar,y_no,ktype)
bbb = rkgres$bbb

kkk$ode_par

############# gradient matching + thrid step
crtype = '3'
lambda3 = 1e-5
res = third(lambda3,kkk,bbb,crtype)

oppar = res$oppar
tail(oppar[[1]],6)


########## warp    rkgw 194.683 seconds   rkg  8.849 seconds
source('WarpSin.r')
###### warp state
peod = c(200,200,200,200,200) #8#9.7     ## the guessing period
eps= 20          ## the standard deviation of period
fixlens=c(4,4,4,4,4)
www = warpfun(kkk,p0,bbb,eps,fixlens)
dtilda= www$dtilda
bbbw = www$bbbw

kkk$ode_par


##### 3rd step + warp
woption='w'
####   warp   3rd
crtype = '3'

lambdaw3= 1e-5
res = third(lambdaw3,kkk,bbbw,crtype,woption,dtilda)

oppar = res$oppar  
tail(oppar[[1]],6)













