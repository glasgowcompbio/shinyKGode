
##   user need to provide the differential equations. If they want to generate simulation data 
##   by solving the ode, they also need to provide the true value of ode parameters,
##   initial value of system states and the time span of the simulation.
##
##   ode model :  dx/dt = f(x, theta)  x is system state  theta is ode parameter.
##   example:  lotka volterra model : 2 system states and 4 ode parameters
##          dx1/dt =  alpha * x1 - beta * x2 * x1
##          dx2/dt = -gamma * x2 + delta * x1*x2 
##
##   true value of ode paraemter alpha = 1  beta =1 gamma =4  delta =1
##   initial states are  x1 = 0.5  x2 = 1
##   time span of simulation  c(0,6)


## if user do not want to use simulation data, they need to provdie observations for each system
## states, the time points for each observation and the ode equations.


## the current setting also require user provide a function df(x,theta)/dtheta  which is 
##  LV_grlNODE in the example.


library(pspline)
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
		dres[1] = sum( -2*( z_p[1,]-grad_ode[1,])*y_p[1,]*alpha ) 
		dres[2] = sum( 2*( z_p[1,]-grad_ode[1,])*y_p[2,]*y_p[1,]*beta)
		dres[3] = sum( 2*( z_p[2,]-grad_ode[2,])*gamma*y_p[2,] )
		dres[4] = sum( -2*( z_p[2,]-grad_ode[2,])*y_p[2,]*y_p[1,]*delta) 
		dres
	}

	M1 = function(t,inix,par_ode){
     with( as.list(c(inix,par_ode)),{
    dx1 =  par_ode[1]*x1-par_ode[2]*x2*x1 
    dx2 =  -par_ode[3]*x2+par_ode[4]*x1*x2
    list(c(dx1,dx2))
      })
	}


### generate data by solving odes
source('ode.r')
kkk = ode$new(2,fun=LV_fun,grfun=LV_grlNODE)
xinit = as.matrix(c(0.5,1))
tinterv = c(0,6)
kkk$solve_ode(c(1,1,4,1),xinit,tinterv)

## add noise to the true solution    y_no is the noisy data
set.seed(19573)
n_o = max( dim( kkk$y_ode) )
noise = 0.1  ## variance of noise 
y_no =  t(kkk$y_ode) + rmvnorm(n_o,c(0,0),noise*diag(2))


################################ standard gradient matching ############
source('kernel1.r')
source('rkhs1.r')

bbb=c()
intp= c()
grad= c()
for (st in 1:2)
{
ann1 = RBF$new(1)
bbb1 = rkhs$new(t(y_no)[st,],kkk$t,rep(1,n_o),1,ann1)
bbb1$skcross(c(5) ) 
bbb=c(bbb,bbb1)
intp = rbind(intp,bbb[[st]]$predict()$pred)
grad = rbind(grad,bbb[[st]]$predict()$grad)
}

## parameter estimation 
kkk$optim_par( c(1,1,4,1), intp, grad )

## calculate functional error comparing to true solution
state = c(x1=0.5,x2=1)
RKG =c(kkk$ode_par,kkk$rmsfun(kkk$ode_par,state,M1,c(1,1,4,1)) )

plot(kkk$t,bbb[[1]]$pred)  ## 1st state



############################ 3rd step iterative   ###################
source('rk3g1.r')

 ode_m = kkk$clone()
 iterp = rkg3$new()
 iterp$odem=ode_m
for( st in 1:2)
{
  rk1 = bbb[[st]]$clone()
  iterp$add(rk1)
}

lambda = 1e-1
iterp$iterate(20,3,lambda)

## parameter estimation 
iopar = iterp$odem$ode_par

## calculate functional error comparing to true solution
RKGi3 =c( iopar,kkk$rmsfun(iopar,state,M1,c(1,1,4,1)) )



################################ warp  ###############################
source('WarpSin.r')

peod=c(6,5.3)

bbbw = c()
dtilda = c()
intp = c()
grad = c()
fixlen=c(2.9,3)

for( st in 1:2)
{
###### warp st_th state
p0=peod[st]            ## a guess of the period of warped signal
eps= 1          ## the standard deviation of period
lambda_t= 50    ## the weight of fixing the end of interval 
y_c = bbb[[st]]$predict()$pred ##y_use[1,]

#### fix len
fixlen = fixlens[st]

wsigm = Sigmoid$new(1)
bbbs = Warp$new( y_c,kkk$t,rep(1,n_o),lambda_t,wsigm)
ppp = bbbs$warpSin( fixlen, 10 )   ## 3.9 70db

### learnign warping function using mlp
t_me= bbbs$tw #- mean(bbbs$tw)
ben = MLP$new(c(5,5)) 
rkben = rkhs$new(t(t_me),kkk$t,rep(1,n_o),1,ben)
rkben$mkcross(c(5,5))
resm = rkben$predict()

### learn interpolates in warped time domain
ann1w = RBF$new(1)
bbb1w = rkhs$new(t(y_no)[st,],resm$pred,rep(1,n_o),1,ann1w)
bbb1w$skcross(5)

dtilda =rbind(dtilda,resm$grad)
bbbw=c(bbbw,bbb1w)
intp = rbind(intp,bbbw[[st]]$predict()$pred)
grad = rbind(grad,bbbw[[st]]$predict()$grad*resm$grad)
}

## gradient Matching for warped signal
kkk$optim_par( c(0.1,0.1,0.1,0.1), intp, grad )
RKGW= c( kkk$ode_par, kkk$rmsfun(kkk$ode_par,state,M1,c(1,1,4,1))  )







