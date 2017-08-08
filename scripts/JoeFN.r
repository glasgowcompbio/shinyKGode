

noise = 0.01  ##   10db0.1    20db 0.01   30db0.001    40db 0.0001
SEED = 19537


library(pspline)
### define ode 
    FN_fun = function(t,x,par_ode){
        print(par_ode)
	    a=par_ode[1]
	    b=par_ode[2]
	    c=par_ode[3]
	    as.matrix( c( c*(x[1]-x[1]^3/3 + x[2]),-1/c*(x[1]-a+b*x[2]) ) )
    }

    FN_grlNODE= function(par,grad_ode,y_p,z_p) { 
    a = par[1]; b= par[2]; c = par[3]
	dres= c(0)
    dres[1] = sum(-2*( z_p[2,]-grad_ode[2,])*a/c)
    dres[2] = sum( 2*( z_p[2,]-grad_ode[2,])*b*y_p[2,]/c )
    dres[3] = sum(-2*( z_p[1,]-grad_ode[1,])*grad_ode[1,])+sum(2*(z_p[2,]-grad_ode[2,])*grad_ode[2,] )
    dres
    }	
    
    M1 <- function(t,inix,par_ode){
 	with( as.list(c(inix,par_ode)),{
    dx1 =  par_ode[3]*(x1-x1^3/3 + x2)
    dx2 =  -1/par_ode[3]*( x1 - par_ode[1] + par_ode[2]*x2)
    list(c(dx1,dx2))
   })
   }

### generate data
source('rkhs_gradmatch/ode.r')
kkk = ode$new(2,fun=FN_fun,grfun=FN_grlNODE)
kkk = ode$new(2,fun=FN_fun)
xinit = as.matrix(c(-1,-1))
tinterv = c(0,10)
kkk$solve_ode(c(0.2,0.2,3),xinit,tinterv)
n_o = max( dim( kkk$y_ode) )

set.seed(SEED)
y_no =  t(kkk$y_ode) + rmvnorm(n_o,c(0,0),noise*diag(2))
nst = 2
npar = 3
################################ standard gradient matching ############
source('rkhs_gradmatch/kernel1.r')
source('rkhs_gradmatch/rkhs1.r')
source('rkhs_gradmatch/intfun.r')
source('rkhs_gradmatch/rk3g1.r')

############################  standard gradient matching
sink('fhn_fixed.txt')
ktype='rbf'
rkgres = rkg(kkk,nst,npar,y_no,ktype)
bbb = rkgres$bbb

kkk$ode_par
sink()


############# gradient matching + thrid step
crtype = '3'
lambda3 = 1e-1
res = third(lambda3,kkk,bbb,crtype)

oppar = res$oppar
tail(oppar[[1]],npar)

########## warp    rkgw 194.683 seconds   rkg  8.849 seconds
source('WarpSin.r')
###### warp state
peod = c(8,8.5) #8#9.7     ## the guessing period
eps= 1          ## the standard deviation of period
fixlens=c(4.5,4.5)
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
tail(oppar[[1]],npar)










