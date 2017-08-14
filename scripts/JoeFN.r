
noise = 0.01  ##   10db0.1    20db 0.01   30db0.001    40db 0.0001
SEED = 19537

### define ode 
    FN_fun = function(t,x,par_ode){
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

##############################################################
source('kernel1.r')
source('rkhs1.r')
source('rk3g1.r')
source('ode.r')
source('WarpSin.r')

source('warpfun.r')
source('crossvr')
source('warpInitLen.r')
source('third.r')
source('rkg.r')

##################  generate data  #################################### 
kkk0 = ode$new(2,fun=FN_fun,grfun=FN_grlNODE)
xinit = as.matrix(c(-1,-1))
tinterv = c(0,10)
kkk0$solve_ode(c(0.2,0.2,3),xinit,tinterv)

##################################################################
init_par = rep(c(0.1),3)
init_yode = kkk0$y_ode
init_t = kkk0$t

kkk = ode$new(1,fun=FN_fun,grfun=FN_grlNODE,t= init_t,ode_par= init_par, y_ode=init_yode )

n_o = max( dim( kkk$y_ode) )
y_no =  t(kkk$y_ode) + rmvnorm(n_o,c(0,0),noise*diag(2))


############################# parameter inference   ############################## 
##### standard gradient matching
ktype='rbf'
rkgres = rkg(kkk,y_no,ktype)
bbb = rkgres$bbb

kkk$ode_par

############# gradient matching + thrid step
crtype='i'

lam=c(1e-4,1e-5)
lamil1 = crossv1(lam,kkk,bbb,crtype,y_no)
lambdai1=lamil1[[1]]

res = third(lambdai1,kkk,bbb,crtype)
oppar = res$oppar


###### warp state
peod = c(8,8.5) #8#9.7     ## the guessing period
eps= 1          ## the standard deviation of period

lens=c(4,5)
fixlens=warpInitLen(peod,eps,rkgres,lens)

kkkrkg = kkk$clone()
www = warpfun(kkkrkg,p0,bbb,eps,fixlens,kkkrkg$t)

dtilda= www$dtilda
bbbw = www$bbbw
resmtest = www$wtime

kkkrkg$ode_par

##### 3rd step + warp
woption='w'
####   warp   3rd
crtype = 'i'

lamwil= crossv1(lam,kkkrkg,bbb,crtype,y_no,woption,resmtest,dtilda) 
lambdawi=lamwil[[1]]

res = third(lambdawi,kkk,bbbw,crtype,woption,dtilda)
oppar = res$oppar  




















