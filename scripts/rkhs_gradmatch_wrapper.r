source('/Users/joewandy/git/rkhs_gradmatch/kernel1.r')
source('/Users/joewandy/git/rkhs_gradmatch/rkhs1.r')
source('/Users/joewandy/git/rkhs_gradmatch/rk3g1.r')
source('/Users/joewandy/git/rkhs_gradmatch/ode.r')
source('/Users/joewandy/git/rkhs_gradmatch/WarpSin.r')

source('/Users/joewandy/git/rkhs_gradmatch/warpfun.r')
source('/Users/joewandy/git/rkhs_gradmatch/crossv.r')
source('/Users/joewandy/git/rkhs_gradmatch/warpInitLen.r')
source('/Users/joewandy/git/rkhs_gradmatch/third.r')
source('/Users/joewandy/git/rkhs_gradmatch/rkg.r')

## Biopathway
library(R6)
library(deSolve)
library(pracma)
library(mvtnorm)
library(SBMLR)

### define ode 
LV_fun = function(t,x,par_ode){
    alpha=par_ode[1]
    beta=par_ode[2]
    gamma=par_ode[3]
    delta=par_ode[4]
    as.matrix( c( alpha*x[1]-beta*x[2]*x[1] , -gamma*x[2]+delta*x[1]*x[2] ) )
}

LV_grlNODE = function(par,grad_ode,y_p,z_p) { 
    alpha = par[1]; beta= par[2]; gamma = par[3]; delta = par[4]
    dres= c(0)
    dres[1] = sum( -2*( z_p[1,]-grad_ode[1,])*y_p[1,]*alpha ) 
    dres[2] = sum( 2*( z_p[1,]-grad_ode[1,])*y_p[2,]*y_p[1,]*beta)
    dres[3] = sum( 2*( z_p[2,]-grad_ode[2,])*gamma*y_p[2,] )
    dres[4] = sum( -2*( z_p[2,]-grad_ode[2,])*y_p[2,]*y_p[1,]*delta) 
    dres
}

LV_initial_values = function() {
    
    numSpecies = 2
    species = c("X1", "X2")
    speciesInitial = c(0.5, 1.0)
    
    numParams = 4
    params = c("alpha", "beta", "gamma", "delta")
    paramsVals = c(1, 1, 4, 1)
    
    return(list("numSpecies"=numSpecies, "species"=species, "speciesInitial"=speciesInitial, 
                "numParams"=numParams, "params"=params, "paramsVals"=paramsVals))
    
}

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

FN_initial_values = function() {
    
    numSpecies = 2
    species = c("X1", "X2")
    speciesInitial = c(-1,-1)
    
    numParams = 3
    params = c("a", "b", "c")
    paramsVals = c(0.2, 0.2, 3)
    
    return(list("numSpecies"=numSpecies, "species"=species, "speciesInitial"=speciesInitial, 
                "numParams"=numParams, "params"=params, "paramsVals"=paramsVals))
    
}

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

BP_initial_values = function() {
    
    numSpecies = 5
    species = c("X1", "X2", "X3", "X4", "X5")
    speciesInitial = c(1,0,1,0,0)
    
    numParams = 6
    params = c("k1", "k2", "k3", "k4", "k5", "k6")
    paramsVals = c(0.07, 0.6, 0.05, 0.3, 0.017, 0.3)
    
    return(list("numSpecies"=numSpecies, "species"=species, "speciesInitial"=speciesInitial, 
                "numParams"=numParams, "params"=params, "paramsVals"=paramsVals))
    
}

get_initial_values = function(predefined_model) {
    
    if (predefined_model == "lv") {
        res = LV_initial_values()
    } else if (predefined_model == "fhg") {
        res = FN_initial_values()
    } else if (predefined_model == 'bp') {
        res = BP_initial_values()
    } else {
        res = NULL
    }
    res
    
}

generate_data_predefined_models = function(predefined_model, xinit, tinterv, numSpecies, 
                                           paramsVals, noise) {

    npar = length(paramsVals)
    if (predefined_model == "lv") {
        
        kkk0 = ode$new(2, fun=LV_fun, grfun=LV_grlNODE)
        kkk0$solve_ode(paramsVals, xinit, tinterv)
        init_par = rep(c(0.1), npar)
        init_yode = kkk0$y_ode
        init_t = kkk0$t
        kkk = ode$new(1, fun=LV_fun, grfun=LV_grlNODE, t=init_t, ode_par=init_par, y_ode=init_yode)
        
    } else if (predefined_model == "fhg") {
        
        kkk0 = ode$new(numSpecies,fun=FN_fun,grfun=FN_grlNODE)
        kkk0$solve_ode(paramsVals, xinit, tinterv)
        init_par = rep(c(0.1), npar)
        init_yode = kkk0$y_ode
        init_t = kkk0$t
        kkk = ode$new(1, fun=LV_fun, grfun=LV_grlNODE, t=init_t, ode_par=init_par, y_ode=init_yode)
        
    } else if (predefined_model == 'bp') {
        
        kkk0 = ode$new(1, fun=BP_fun, grfun=BP_grlNODE)
        kkk0$solve_ode(paramsVals, xinit, tinterv)
        start = 6
        select = 2
        pick = c( 1:(start-1),seq(start,(length(kkk0$t)-1),select),length(kkk0$t))
        
        init_par = rep(c(0.1), npar)
        init_yode = kkk0$y_ode[,pick]
        init_t = kkk0$t[pick]
        kkk = ode$new(1, fun=BP_fun, grfun=BP_grlNODE, t=init_t, ode_par=init_par, y_ode=init_yode)

    }
    
    n_o = max( dim( kkk$y_ode) )
    y_no =  t(kkk$y_ode) + rmvnorm(n_o, rep(0, numSpecies), noise*diag(numSpecies)) 
    res = list(time=kkk$t, y_no=y_no, kkk=kkk, sbml_data=NULL)
    res

}

add_no_duplicate <- function(v1, v2) {
    for (i in 1:length(names(v2))) {
        name = names(v2)[i]
        if (!is.null(name) && !name %in% names(v1)) {
            v1[name] = v2[name]
        }
    }
    v1
}

# TODO: Fix parsing problem:
# 1. The stochiometry attribute in speciesReference is not used.
# 2. If global parameters are declared but with no corresponding local parameters in the reactions, 
#    then summary() will break ???!!
load_sbml <- function(f) {

    model = SBMLR:::readSBML(f)
    mi = summary(model)

    # collect all the params
    params = mi$globalVec
    for (j in 1:mi$nReactions) {
        mrj = model$reactions[[j]]
        rm = c(mrj$reactants, mrj$modifiers)
        P = mrj$parameters
        params = add_no_duplicate(params, P)
    }

    initial_names = names(params)
    res = list(model=model, mi=mi, params=params, initial_names=initial_names)
    res
    
}

generate_data_from_sbml <- function(f, xinit, tinterv, params, samp, noise) {

    model = SBMLR:::readSBML(f)
    mi = summary(model)
    initial_names = names(params)
    
    ode_fun <- function(t, x, par_ode) {
        
        # print(par_ode)
        if (length(par_ode) > 0) {
            names(par_ode) = initial_names
        }
        v = rep(0, mi$nReactions)
        xp = rep(0, mi$nStates)
        St = mi$S0
        St[mi$BC == FALSE] = x
        
        if (mi$nRules > 0) 
            for (j in 1:mi$nRules) St[model$rules[[j]]$idOutput] = model$rules[[j]]$law(St[model$rule[[j]]$inputs])
        
        for (j in 1:mi$nReactions) {
            mrj = model$reactions[[j]]
            rm = c(mrj$reactants, mrj$modifiers)
            # P is now passed from outside as par_ode
            # P = mrj$parameters
            # v[j] = mrj$law(St[rm], P)
            v[j] = mrj$law(St[rm], par_ode)
        }
        
        xp = mi$incid %*% v
        xp
        
    }
    
    kkk0 = ode$new(samp, fun=ode_fun)
    xinit = as.matrix(mi$S0)
    kkk0$solve_ode(par_ode=params, xinit, tinterv)
    
    init_par = params
    init_yode = kkk0$y_ode
    init_t = kkk0$t
    kkk = ode$new(1, fun=ode_fun, t=init_t, ode_par=init_par, y_ode=init_yode)

    n_o = max( dim( kkk$y_ode) )
    y_no =  t(kkk$y_ode) + rmvnorm(n_o, rep(0, mi$nStates),noise*diag(mi$nStates))
    
    res = list(time=kkk$t, y_no=y_no, kkk=kkk)
    res

}

gradient_match <- function(kkk, y_no, ktype='rbf') {
    
    output = capture.output(rkgres <- rkg(kkk, y_no, ktype))
    bbb = rkgres$bbb ## bbb is a rkhs object which contain all information about interpolation and kernel parameters.
    ode_par = kkk$ode_par
    
    plot_x = list()
    plot_y = list()
    data = list()
    for (i in 1:length(bbb)) { 
        print(bbb[[i]])
        plot_x[[i]] = bbb[[i]]$t 
        plot_y[[i]] = rkgres$intp[i, ]        
        data[[i]] = bbb[[i]]$y
    }

    return(list(ode_par=ode_par, output=output, plot_x=plot_x, plot_y=plot_y, 
                data=data, nst=length(plot_x)))
    
}

gradient_match_third_step <- function(kkk, y_no, ktype='rbf') {

    rkgres = rkg(kkk, y_no, ktype)
    bbb = rkgres$bbb ## bbb is a rkhs object which contain all information about interpolation and kernel parameters.

    crtype='i'  ## two methods fro third step  'i' fast method means iterative and '3' for slow method means 3rd step
    lam=c(1e-4,1e-5)  ## we need to do cross validation for find the weighter parameter
    lamil1 = crossv(lam,kkk,bbb,crtype,y_no)
    lambdai1=lamil1[[1]]
    
    # output = capture.output(res <- third(lambdai1,kkk,bbb,crtype))
    output = ''
    res <- third(lambdai1,kkk,bbb,crtype)
    
    ode_par = res$oppar
    plot_x = list()
    plot_y = list()
    data = list()
    for (i in 1:length(res$rk3$rk)) { 
        plot_x[[i]] = res$rk3$rk[[i]]$t 
        plot_y[[i]] = res$rk3$rk[[i]]$predict()$pred
        data[[i]] = res$rk3$rk[[i]]$y
    }
    
    return(list(ode_par=ode_par, output=output, plot_x=plot_x, plot_y=plot_y, 
                data=data, nst=length(plot_x)))
    
}

warping <- function(kkk, y_no, peod, eps, ktype='rbf') {

    rkgres = rkg(kkk, y_no, ktype)
    bbb = rkgres$bbb ## bbb is a rkhs object which contain all information about interpolation and kernel parameters.
    
    #lens=c(3,4,5) ## user can define the init value of lens for sigmoid function. the default is c(3,4,5)
    fixlens=warpInitLen(peod, eps, rkgres) ## find the start value for the warping basis function.
    
    output = capture.output(www <- warpfun(kkk, p0, bbb, eps, fixlens, kkk$t))
    
    dtilda= www$dtilda
    bbbw = www$bbbw
    resmtest = www$wtime
    wfun=www$wfun
    wkkk = www$wkkk
    
    ode_par = wkkk$ode_par
    plot_x = list()
    plot_y = list()
    for (i in 1:length(bbbw)) { 
        plot_x[[i]] = resmtest[i, ] 
        plot_y[[i]] = bbbw[[i]]$predict()$pred
    }

    return(list(ode_par=ode_par, output=output, plot_x=plot_x, plot_y=plot_y, nst=length(plot_x)))
    
}

third_step_warping <- function(kkk, y_no, peod, eps, ktype='rbf') {
    
    rkgres = rkg(kkk, y_no, ktype)
    bbb = rkgres$bbb ## bbb is a rkhs object which contain all information about interpolation and kernel parameters.
    
    #lens=c(3,4,5) ## user can define the init value of lens for sigmoid function. the default is c(3,4,5)
    fixlens=warpInitLen(peod, eps, rkgres) ## find the start value for the warping basis function.
    
    www = warpfun(kkk, p0, bbb, eps, fixlens, kkk$t)
    
    dtilda= www$dtilda
    bbbw = www$bbbw
    resmtest = www$wtime
    wfun=www$wfun
    wkkk = www$wkkk
    
    ode_par = wkkk$ode_par
    
    ##### 3rd step + warp
    woption='w'
    ####   warp   3rd
    crtype = 'i'
    
    lam=c(1e-4,1e-5)  ## we need to do cross validation for find the weighter parameter
    lamwil= crossv(lam,wkkk,bbbw,crtype,y_no,woption,resmtest,dtilda) 
    lambdawi=lamwil[[1]]
    
    output = capture.output(res <- third(lambdawi,wkkk,bbbw,crtype,woption,dtilda))  ## add third step after warping
    ode_par = res$oppar
    plot_x = list()
    plot_y = list()
    for (i in 1:length(res$rk3$rk)) { 
        plot_x[[i]] = res$rk3$rk[[i]]$t 
        plot_y[[i]] = res$rk3$rk[[i]]$predict()$pred
    }
    
    return(list(ode_par=ode_par, output=output, plot_x=plot_x, plot_y=plot_y, nst=length(plot_x)))
    
}