
noise = 0.1  ## 10db:34 1 20db:34 0.1  30db:2 0.01   40db:18 0.001
SEED = 19537
set.seed(SEED)

### define ode 
    LV_fun = function(t,x,par_ode){
        alpha=par_ode[1]
        beta=par_ode[2]
        gamma=par_ode[3]
        delta=par_ode[4]
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
    
##################  generate data  #################################### 
kkk0 = ode$new(2,fun=LV_fun,grfun=LV_grlNODE)
xinit = as.matrix(c(0.5,1))
tinterv = c(0,6)
kkk0$solve_ode(c(1,1,4,1),xinit,tinterv) 


##################################################################
init_par = rep(c(0.1),4)
init_yode = kkk0$y_ode
init_t = kkk0$t

kkk = ode$new(1,fun=LV_fun,grfun=LV_grlNODE,t= init_t,ode_par= init_par, y_ode=init_yode )

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
lamil1 = crossv(lam,kkk,bbb,crtype,y_no)
lambdai1=lamil1[[1]]

res = third(lambdai1,kkk,bbb,crtype)
oppar = res$oppar

###### warp state
peod = c(6,5.3) #8#9.7     ## the guessing period
eps= 1          ## the standard deviation of period

fixlens=warpInitLen(peod,eps,rkgres)

kkkrkg = kkk$clone()
www = warpfun(kkkrkg,p0,bbb,eps,fixlens,kkkrkg$t)

dtilda= www$dtilda
bbbw = www$bbbw
resmtest = www$wtime
wfun=www$wfun
wkkk = www$wkkk

wkkk$ode_par

##### 3rd step + warp
woption='w'
####   warp   3rd
crtype = 'i'

lamwil= crossv(lam,kkkrkg,bbb,crtype,y_no,woption,resmtest,dtilda) 
lambdawi=lamwil[[1]]

res = third(lambdawi,kkk,bbbw,crtype,woption,dtilda)
oppar = res$oppar  



















