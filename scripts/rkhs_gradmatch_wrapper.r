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

get_initial_values_selected = function(selected_model) {
    
    if (selected_model == "lv") {
        res = LV_initial_values()
    } else if (selected_model == "fhg") {
        res = FN_initial_values()
    } else if (selected_model == 'bp') {
        res = BP_initial_values()
    } else {
        res = NULL
    }
    res
    
}

get_initial_values_sbml = function(inFile) {
    
    print(inFile)
    d = libSBML:::readSBML(inFile$datapath);
    
    errors   = SBMLDocument_getNumErrors(d);
    SBMLDocument_printErrors(d);
    m = SBMLDocument_getModel(d);
    
    params = character(0);
    paramsVals = vector();
    for(i in seq_len(Model_getNumParameters( m ))) {
        sp = Model_getParameter( m, i-1);
        params = c(params, Parameter_getId(sp));
        paramsVals = c(paramsVals, Parameter_getValue(sp));
    }
    
    species = character(0);
    speciesInitial = vector()
    for(i in seq_len(Model_getNumSpecies(m))) {
        sp = Model_getSpecies(m, i-1);
        species = c(species, Species_getId(sp));
        speciesInitial = c(speciesInitial, Species_getInitialConcentration(sp));
    }
    
    numSpecies = Model_getNumSpecies(m)
    numParams = Model_getNumParameters(m)
    
    return(list("numSpecies"=numSpecies, "species"=species, "speciesInitial"=speciesInitial, 
                "numParams"=numParams, "params"=params, "paramsVals"=paramsVals))
    
}

generate_data_selected_model = function(selected_model, xinit, tinterv, numSpecies, 
                                           paramsVals, noise) {

    npar = length(paramsVals)
    if (selected_model == "lv") {
        
        kkk0 = ode$new(2, fun=LV_fun, grfun=LV_grlNODE)
        kkk0$solve_ode(paramsVals, xinit, tinterv)
        init_par = rep(c(0.1), npar)
        init_yode = kkk0$y_ode
        init_t = kkk0$t
        kkk = ode$new(1, fun=LV_fun, grfun=LV_grlNODE, t=init_t, ode_par=init_par, y_ode=init_yode)
        
    } else if (selected_model == "fhg") {
        
        kkk0 = ode$new(numSpecies,fun=FN_fun,grfun=FN_grlNODE)
        kkk0$solve_ode(paramsVals, xinit, tinterv)
        init_par = rep(c(0.1), npar)
        init_yode = kkk0$y_ode
        init_t = kkk0$t
        kkk = ode$new(1, fun=LV_fun, grfun=LV_grlNODE, t=init_t, ode_par=init_par, y_ode=init_yode)
        
    } else if (selected_model == 'bp') {
        
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
    res = list(time=kkk$t, y_no=y_no, kkk=kkk, sbml_data=NULL, tinterv=tinterv)
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

get_data_from_csv <- function(csv_file, sbml_file, params, model_from, selected_model) {

    df <- read.csv(file=csv_file, header=TRUE, sep=",")
    x = as.matrix(df)

    init_time = x[, 1]
    y_no = x[, 2:ncol(x)]
    init_par = rep(c(0.1), length(params))

    if (model_from == 'uploaded') { # extract from the SBML file
        res = get_ode_fun(sbml_file, params)
        ode_fun = res$ode_fun
    } else if (model_from == 'selected') {
        if (selected_model == "lv") {
            ode_fun = LV_fun
        } else if (selected_model == "fhg") {
            ode_fun = FN_fun
        } else if (selected_model == 'bp') {
            ode_fun = BP_fun
        } else {
            ode_fun = NULL
        }
    }
    
    tinterv = c(min(init_time), max(init_time))
    print(ode_fun)
    print(tinterv)
    kkk = ode$new(1, fun=ode_fun, t=init_time, ode_par=init_par, y_ode=t(y_no))
    res = list(time=init_time, y_no=y_no, kkk=kkk, sbml_data=NULL, tinterv=tinterv)
    res
    
}

get_ode_fun <- function(f, params) {
    
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

    return(list(model=model, mi=mi, ode_fun=ode_fun))    
    
}

generate_data_from_sbml <- function(f, xinit, tinterv, params, pick, noise) {

    res = get_ode_fun(f, params)
    model = res$model
    mi = res$mi
    ode_fun = res$ode_fun
    initial_names = names(params)
    
    kkk0 = ode$new(pick, fun=ode_fun)
    xinit = as.matrix(mi$S0)
    kkk0$solve_ode(par_ode=params, xinit, tinterv)
    
    init_par = params
    init_yode = kkk0$y_ode
    init_t = kkk0$t
    kkk = ode$new(1, fun=ode_fun, t=init_t, ode_par=init_par, y_ode=init_yode)

    n_o = max( dim( kkk$y_ode) )
    y_no =  t(kkk$y_ode) + rmvnorm(n_o, rep(0, mi$nStates), noise*diag(mi$nStates))
    
    sbml_data = list(model=model, mi=mi, initial_names=initial_names)
    res = list(time=kkk$t, y_no=y_no, kkk=kkk, sbml_data=sbml_data, tinterv=tinterv)
    res

}

get_grid <- function(tinterv, n) {

    # https://stackoverflow.com/questions/19689397/extracting-breakpoints-with-intervals-closed-on-the-left    
    labs <- levels(cut(tinterv, n))
    x = cbind(lower = as.numeric( sub("\\((.+),.*", "\\1", labs) ), upper = as.numeric( sub("[^,]*,([^]]*)\\]", "\\1", labs) ))
    grids = x[, 2]
    return(grids)
    
}

update_status <- function(progress, msg, msg_type, val) {
    if (!is.null(progress)) { 
        if (msg_type == 'start') {
            progress$set(message=msg, value=val)
        } else if (msg_type == 'inc') {
            progress$inc(val, detail=msg)
        }
    } else {
        print(msg)
    }
}

parse_objectives <- function(output) {
    
    # 'f =' followed by any number of spaces, followed by a decimal number
    pattern = 'f =\\s+[0-9]*\\.?[0-9]*'
    m = gregexpr(pattern, output)
    regm = regmatches(output, m)
    objectives = numeric()
    for (i in 1:length(regm)) {
        match = regm[[i]]
        if (length(match) > 0) {
            x = unlist(strsplit(match, '='))
            my_obj = as.numeric(trimws(x[2]))
            objectives = c(my_obj, objectives)
        }
    }
    objectives = rev(objectives)
    return(objectives)
    
}

gradient_match <- function(kkk, tinterv, y_no, ktype, progress) {

    update_status(progress, 'Gradient matching', 'start', 0)    
    output1 = capture.output(rkgres <- rkg(kkk, y_no, ktype))
    update_status(progress, 'Completed', 'inc', 1)
    bbb = rkgres$bbb ## bbb is a rkhs object which contain all information about interpolation and kernel parameters.
    ode_par = kkk$ode_par
    
    grids = get_grid(tinterv, 2000)
    intp_x = list()
    intp_y = list()
    data_x = list()
    data_y = list()
    for (i in 1:length(bbb)) { 
        print(bbb[[i]])
        intp_x[[i]] = grids
        intp_y[[i]] = bbb[[i]]$predictT(grids)$pred
        data_x[[i]] = bbb[[i]]$t 
        data_y[[i]] = bbb[[i]]$y
    }

    objectives = parse_objectives(output1)
    return(list(ode_par=ode_par, output=output1, objectives=objectives,
                intp_x=intp_x, intp_y=intp_y, data_x=data_x, data_y=data_y,
                warpfun_x=NULL, warpfun_y=NULL,
                nst=length(intp_x)))
    
}

gradient_match_third_step <- function(kkk, tinterv, y_no, ktype, progress) {

    update_status(progress, 'Gradient matching', 'start', 0)    
    output1 = capture.output(rkgres <- rkg(kkk, y_no, ktype))
    bbb = rkgres$bbb ## bbb is a rkhs object which contain all information about interpolation and kernel parameters.

    update_status(progress, 'Cross-validating', 'inc', 0.3)
    crtype='i'  ## two methods fro third step  'i' fast method means iterative and '3' for slow method means 3rd step
    lam=c(1e-4,1e-5)  ## we need to do cross validation for find the weighter parameter
    lamil1 = crossv(lam,kkk,bbb,crtype,y_no)
    lambdai1=lamil1[[1]]

    update_status(progress, 'Third-step', 'inc', 0.6)
    output2 = capture.output(res <- third(lambdai1,kkk,bbb,crtype))
    update_status(progress, 'Completed', 'inc', 1)
    ode_par = res$oppar
    
    grids = get_grid(tinterv, 2000)
    intp_x = list()
    intp_y = list()
    data_x = list()
    data_y = list()
    for (i in 1:length(res$rk3$rk)) { 
        intp_x[[i]] = grids
        intp_y[[i]] = res$rk3$rk[[i]]$predictT(grids)$pred
        data_y[[i]] = res$rk3$rk[[i]]$y
        data_x[[i]] = res$rk3$rk[[i]]$t
    }

    output = c(output1, output2)
    objectives = parse_objectives(output1)
    return(list(ode_par=ode_par, output=output, objectives=objectives,
                intp_x=intp_x, intp_y=intp_y, data_x=data_x, data_y=data_y,
                warpfun_x=NULL, warpfun_y=NULL,
                nst=length(intp_x)))
    
}

warping <- function(kkk, tinterv, y_no, peod, eps, ktype, progress) {

    update_status(progress, 'Gradient matching', 'start', 0)    
    output1 = capture.output(rkgres <- rkg(kkk, y_no, ktype))
    bbb = rkgres$bbb ## bbb is a rkhs object which contain all information about interpolation and kernel parameters.

    update_status(progress, 'Initialise warping', 'inc', 0.25)
    output2 = capture.output(fixlens <- warpInitLen(peod, eps, rkgres)) ## find the start value for the warping basis function.

    update_status(progress, 'Warping', 'inc', 0.5)
    output3 = capture.output(www <- warpfun(kkk, bbb, peod, eps, fixlens, y_no, kkk$t))
    update_status(progress, 'Completed', 'inc', 1)
    
    dtilda= www$dtilda
    bbbw = www$bbbw
    resmtest = www$wtime
    wfun=www$wfun
    wkkk = www$wkkk
    ode_par = wkkk$ode_par
    
    plot(kkk$t,resmtest[1,],type='l')   ## plotting function
    
    grids = get_grid(tinterv, 2000)
    intp_x = list()
    intp_y = list()
    data_x = list()
    data_y = list()
    warpfun_x = list()
    warpfun_y = list()
    for (i in 1:length(bbbw)) { 
        wgrids = wfun[[i]]$predictT(grids)$pred ## denser grid in warped domain
        intp_x[[i]] = grids
        intp_y[[i]] = bbbw[[i]]$predictT(wgrids)$pred
        data_x[[i]] = bbb[[i]]$t
        data_y[[i]] = bbb[[i]]$y
        warpfun_x[[i]] = kkk$t
        warpfun_y[[i]] = resmtest[i, ]
    }

    output = c(output1, output2, output3)
    objectives = parse_objectives(output1)
    return(list(ode_par=ode_par, output=output, objectives=objectives,
                intp_x=intp_x, intp_y=intp_y, data_x=data_x, data_y=data_y, 
                warpfun_x=warpfun_x, warpfun_y=warpfun_y,
                nst=length(intp_x)))
    
    
}

third_step_warping <- function(kkk, tinterv, y_no, peod, eps, ktype, progress) {

    update_status(progress, 'Gradient matching', 'start', 0)    
    output1 = capture.output(rkgres <- rkg(kkk, y_no, ktype))
    bbb = rkgres$bbb ## bbb is a rkhs object which contain all information about interpolation and kernel parameters.

    update_status(progress, 'Initialise warping', 'inc', 0.25)    
    output2 = capture.output(fixlens <- warpInitLen(peod, eps, rkgres)) ## find the start value for the warping basis function.
    
    update_status(progress, 'Warping', 'inc', 0.50)    
    kkkrkg = kkk$clone()
    output3 = capture.output(www <- warpfun(kkkrkg, bbb, peod, eps, fixlens, y_no,kkk$t))
    
    dtilda= www$dtilda
    bbbw = www$bbbw
    resmtest = www$wtime
    wfun=www$wfun
    wkkk = www$wkkk
    
    ##### 3rd step + warp
    woption='w'
    ####   warp   3rd
    crtype = 'i'
    lam=c(1e-4,1e-5)  ## we need to do cross validation for find the weighter parameter

    update_status(progress, 'Cross-validating', 'inc', 0.75)    
    output4 = capture.output(lamwil <- crossv(lam,kkkrkg,bbb,crtype,y_no,woption,resmtest,dtilda)) 
    
    update_status(progress, 'Third-step', 'inc', 0.90)    
    lambdawi=lamwil[[1]]
    output5 = capture.output(res <- third(lambdawi,wkkk,bbbw,crtype,woption,dtilda))  ## add third step after warping
    progress$inc(1, detail = "Completed")
    ode_par = res$oppar
    
    grids = get_grid(tinterv, 2000)
    intp_x = list()
    intp_y = list()
    data_x = list()
    data_y = list()
    for (i in 1:length(res$rk3$rk)) { 
        wgrid = wfun[[i]]$predictT(grids)$pred
        intp_x[[i]] = grids
        intp_y[[i]] = res$rk3$rk[[i]]$predictT(wgrid)$pred
        data_x[[i]] = bbb[[i]]$t
        data_y[[i]] = bbb[[i]]$y
    }
    
    output = c(output1, output2, output3, output4, output5)
    objectives = parse_objectives(output1)
    return(list(ode_par=ode_par, output=output, objectives=objectives,
                intp_x=intp_x, intp_y=intp_y, data_x=data_x, data_y=data_y,
                warpfun_x=NULL, warpfun_y=NULL,
                nst=length(intp_x)))
    
    
}