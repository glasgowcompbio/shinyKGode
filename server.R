library(shiny)
library(gridExtra)
library(ggplot2)
library(pspline)
library(libSBML)
library(reshape2)

source('rkhs_gradMatch/ode.r')
source('rkhs_gradMatch/kernel1.r')
source('rkhs_gradMatch/rkhs1.r')
source('rkhs_gradMatch/WarpSin.r')
source('rkhs_gradMatch/rk3g1.r')

# true parameters
kernelChoices = c("kernel1"="kernel1", "kernel2"="kernel2", "kernel3"="kernel3")
constraintChoices = c("---"="---", "Gaussian"="gaussian", "Gamma"="gamma")

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

### generate data by solving odes

shinyServer(function(input, output, session) {
   
    observeEvent(input$process, {
        insertUI(
            selector = "#add",
            where = "afterEnd",
            ui = textInput(paste0("txt", input$add),
                           "Insert some text")
        )
    })    
    
    parseSBML = reactive({
        
        inFile = input$sbml_file
        d = readSBML(inFile);
        
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
        
    })
    
    resetModel = function(input, output) {
        removeUI(selector = '#placeholderParams *', multiple=TRUE)
    }
    
    loadModel = function(input, output, 
                         numSpecies, species, speciesInitial,
                         numParams, params, paramsVals) {

        removeUI(selector = '#placeholderParams *', multiple=TRUE)
        removeUI(selector = '#placeholderStates *', multiple=TRUE)
        
        output$odeParameters = renderText({ paste(params, collapse=", " ) })        
        for (i in 1:numParams) {
            paramLabel = params[i]
            paramId = paste0("param", i)
            paramValId = paste0('param_val', i)
            paramValLabel = "Starting Value"
            insertUI(
                selector = '#placeholderParams',
                ui = fluidRow(
                    column(6, selectInput(paramId, paramLabel, constraintChoices)),
                    column(6, numericInput(paramValId, paramValLabel, value=paramsVals[i], min=0, max=NA, step=1))
                )                    
            )
        }
        
        labels = c()
        for (i in 1:numSpecies) {
            stateLabel = species[i]
            stateId = paste0("state", i)
            initCondId = paste0('initial_cond', i)
            initCondLabel = "Initial Cond."
            guessId = paste0('p0_', i)
            guessLabel = 'Guess Period'
            insertUI(
                selector = '#placeholderStates',
                ui = fluidRow(
                    column(4, selectInput(stateId, stateLabel, kernelChoices)),
                    column(4, numericInput(initCondId, initCondLabel, value=speciesInitial[i], min=0, max=NA, step=0.1)),
                    column(4, numericInput(guessId, guessLabel, value=6, min=0, max=NA, step=0.1))
                )                    
            )
            labels = c(labels, stateLabel)
        }
        output$systemStates = renderText({ paste(labels, collapse=", " ) })
        
    }
    
    observeEvent(input$predefined_model, {
        
        if (input$predefined_model == "lv") {

            numSpecies = 2
            species = c("X1", "X2")
            speciesInitial = c(0.5, 1.0)
            
            numParams = 4
            params = c("alpha", "beta", "gamma", "delta")
            paramsVals = c(1, 1, 4, 1)

            loadModel(input, output, numSpecies, species, speciesInitial, numParams, params, paramsVals)
                                    
        } else if (input$predefined_model == "fhg") {

            numSpecies = 2
            species = c("X1", "X2")
            speciesInitial = c(-1,-1)
            
            numParams = 3
            params = c("a", "b", "c")
            paramsVals = c(0.2, 0.2, 3)

            loadModel(input, output, numSpecies, species, speciesInitial, numParams, params, paramsVals)
                        
        } else if (input$predefined_model == 'bp') {
            
            numSpecies = 5
            species = c("X1", "X2", "X3", "X4", "X5")
            speciesInitial = c(1,0,1,0,0)
            
            numParams = 6
            params = c("k1", "k2", "k3", "k4", "k5", "k6")
            paramsVals = c(0.07, 0.6, 0.05, 0.3, 0.017, 0.3)
            
            loadModel(input, output, numSpecies, species, speciesInitial, numParams, params, paramsVals)
            
        } else {
            
            # reset
            resetModel(input, output)
            
        }
        
        
    })
    
    observeEvent(input$sbml_file, {

        sbml = parseSBML()
        
        numSpecies = sbml$numSpecies
        species = sbml$species
        speciesInitial = sbml$speciesInitial
        
        numParams = sbml$numParams
        params = sbml$params
        paramsVals = sbml$paramsVals
        
        print(numSpecies)
        print(species)
        print(speciesInitial)
        print(numParams)
        print(params)
        print(paramsVals)
        
        loadModel(input, output, numSpecies, species, speciesInitial, numParams, params, paramsVals)
        
    })    

    generateData = reactive({

        sbml = parseSBML()
        xinit = as.matrix(sbml$speciesInitial)
        tinterv = c(input$timePointsMin, input$timePointsMax)

        kkk = ode$new(sbml$numSpecies,fun=LV_fun,grfun=LV_grlNODE)
        kkk$solve_ode(sbml$paramsVals, xinit, tinterv)
        
        ## add noise to the true solution    y_no is the noisy data
        set.seed(19573)
        n_o = max( dim( kkk$y_ode) )
        noise = input$snr  ## TODO: change from variance to SNR 
        y_no =  t(kkk$y_ode) + rmvnorm(n_o,c(0,0),noise*diag(sbml$numSpecies)) 
        time = kkk$t
        return(list("time="=time, "n_o"=n_o, "y_no"=y_no))
        
    })
    
    observeEvent(input$generateBtn, {

        if (input$predefined_model == "lv") {

            # generate data for models from SBML file
            
            
        } else {
            
            
        }
        
        
        
        # generate data for preset models
        
        res = generateData()
        
        
        
        time = res$time
        y_no = res$y_no
        updateTabsetPanel(session, "inTabset", selected="results")
        output$resultsType = renderText({ "Generated data:" })
        output$resultsPlot = renderPlot({
            df = data.frame(y_no)
            df$time = time
            df_plot = melt(df, id.vars='time', variable.name='states')
            ggplot(aes(y=value, x=time, colour=states), data=df_plot) + geom_point(size=2) + 
                theme_bw() +
                theme(text = element_text(size=20))
        })    
        shinyjs::enable("inferBtn")
        
        shinyjs::show("downloadDataBtn")
        updateActionButton(session, "inferBtn", label = "Infer on generated data")    
        output$downloadDataBtn <- downloadHandler(
            filename = function() { 'data.csv' },
            content = function(file) {
                write.csv(df, file)
            }
        )    
        
    })    
    
    observeEvent(input$inferBtn, {
        updateTabsetPanel(session, "inTabset", selected="results")        
        output$resultsType = renderText({ "Parameter estimations:" })
        res = generateData()
        y_no = res$y_no
        n_o = res$n_o
        sbml = parseSBML()
        numSpecies = sbml$numSpecies
        withProgress(message='Inferring', value=0, {
            
            sbml = parseSBML()
            xinit = as.matrix(sbml$speciesInitial)
            tinterv = c(input$timePointsMin, input$timePointsMax)
            
            if (input$method == "gm") {
            
                kkk = ode$new(sbml$numSpecies,fun=LV_fun,grfun=LV_grlNODE)
                kkk$solve_ode(sbml$paramsVals, xinit, tinterv)
                    
                bbb=c()
                intp= c()
                grad= c()
                for (st in 1:numSpecies)
                {
                    incProgress(st/numSpecies, detail=paste("System State", st))
                    ann1 = RBF$new(1)
                    bbb1 = rkhs$new(t(y_no)[st,],kkk$t,rep(1,n_o),1,ann1)
                    bbb1$skcross(c(5) ) 
                    bbb=c(bbb,bbb1)
                    intp = rbind(intp,bbb[[st]]$predict()$pred)
                    grad = rbind(grad,bbb[[st]]$predict()$grad)
                }
                
                ## parameter estimation 
                kkk$optim_par( sbml$paramsVals, intp, grad )
                x = kkk$ode_par
                
            } else if (input$method == "3rd") {
                
                kkk = ode$new(sbml$numSpecies,fun=LV_fun,grfun=LV_grlNODE)
                kkk$solve_ode(sbml$paramsVals, xinit, tinterv)
                
                bbb=c()
                intp= c()
                grad= c()
                for (st in 1:numSpecies)
                {
                    incProgress(st/numSpecies, detail=paste("System State", st))
                    ann1 = RBF$new(1)
                    bbb1 = rkhs$new(t(y_no)[st,],kkk$t,rep(1,n_o),1,ann1)
                    bbb1$skcross(c(5) ) 
                    bbb=c(bbb,bbb1)
                    intp = rbind(intp,bbb[[st]]$predict()$pred)
                    grad = rbind(grad,bbb[[st]]$predict()$grad)
                }
                
                ## parameter estimation 
                kkk$optim_par( sbml$paramsVals, intp, grad )

                ############################ 3rd step  Method ###################
                ## iterative + full loss 3rd step 
                ode_m = kkk$clone()
                iterp = rkg3$new()
                iterp$odem=ode_m
                for( st in 1:numSpecies)
                {
                    rk1 = bbb[[st]]$clone()
                    iterp$add(rk1)
                }
                
                incProgress(1, detail="3rd Step Iteration")
                lambda = 1e-1
                iterp$iterate(20,3,lambda)
                oppar=iterp$opfull( lambda )
                x = tail(oppar[[1]],4)
                
            } else if (input$method == "all") {
                
                kkk = ode$new(sbml$numSpecies,fun=LV_fun,grfun=LV_grlNODE)
                kkk$solve_ode(sbml$paramsVals, xinit, tinterv)
                
                bbb=c()
                intp= c()
                grad= c()
                for (st in 1:numSpecies)
                {
                    incProgress(st/numSpecies, detail=paste("System State", st))
                    ann1 = RBF$new(1)
                    bbb1 = rkhs$new(t(y_no)[st,],kkk$t,rep(1,n_o),1,ann1)
                    bbb1$skcross(c(5) ) 
                    bbb=c(bbb,bbb1)
                    intp = rbind(intp,bbb[[st]]$predict()$pred)
                    grad = rbind(grad,bbb[[st]]$predict()$grad)
                }
                
                ## parameter estimation 
                kkk$optim_par( sbml$paramsVals, intp, grad )
                
                ############################ 3rd step  Method ###################
                ## iterative + full loss 3rd step 
                ode_m = kkk$clone()
                iterp = rkg3$new()
                iterp$odem=ode_m
                for( st in 1:numSpecies)
                {
                    rk1 = bbb[[st]]$clone()
                    iterp$add(rk1)
                }
                
                incProgress(1, detail="3rd Step Iteration")
                lambda = 1e-1
                iterp$iterate(20,3,lambda)
                oppar=iterp$opfull( lambda )
                x = tail(oppar[[1]],4)
                
                ################################ warp  ###############################
            
                peod=c(6,5.3)
                
                bbbw = c()
                dtilda = c()
                intp = c()
                grad = c()
                fixlens=c(2.9,3)
                
                incProgress(1, detail="Warping")
                for( st in 1:numSpecies)
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
                x = kkk$ode_par
                
            }
            df = data.frame(parameters=x)
            sbml = parseSBML()
            rownames(df) = sbml$params

        })
        
        output$resultsPlot = renderPlot({

            # plots = list()
            # data = data.frame(t=kkk$t, resb1=resb1$pred, resb2=resb2$pred)
            # plots[[1]] = ggplot(data=data,aes(x=t, y=resb1)) + geom_line()
            # plots[[2]] = ggplot(data=data,aes(x=t, y=resb2)) + geom_line()
            # do.call(grid.arrange, plots)
            
            # y = c(resb1$pred, resb2$pred)
            # plot_df = data.frame(t(intp))
            # plot_df$time = kkk$t 
            # plot_df = melt(plot_df, id.vars='time', variable.name='states')
            # ggplot(aes(y=value, x=time, colour=states), data=plot_df) + geom_line() + 
            #     theme_bw() +
            #     theme(text = element_text(size=20))

            plots = list()
            un = unique(plot_df[['states']])
            for (i in 1:length(un)) {
                sub_df = plot_df[plot_df$states == un[i], ]
                plots[[i]] = ggplot(aes(y=value, x=time, colour=states), data=sub_df) + geom_line(size=1) + 
                    theme_bw() +
                    theme(text = element_text(size=20))
            }
            do.call(grid.arrange, plots)

        })    
        
        output$resultsTable = renderTable({
            df  
        }, rownames=T)
    
        shinyjs::show("downloadParamsBtn")
        
        output$downloadParamsBtn <- downloadHandler(
            filename = function() { 'params.csv' },
            content = function(file) {
                write.csv(df, file)
            }
        )    
        
    })
    
    output$cond = renderText({
        paste0("State1=", input$Sample, ", State2=",input$Sample1)
    })
    
    # observeEvent(input$helpLink, {
    #     showModal(modalDialog(
    #         title = "Parameter Constraint Syntax",
    #         "You can specify 
    #         (1) equality constraint, 
    #         (2) Parameter drawn from Gaussian with given mean and variance,
    #         (3) Parameter drawn from Gamma with given shape and scale,
    #         (4) Parameter drawn from Uniform with given bounds.",
    #         easyClose = TRUE,
    #         footer = NULL
    #     ))
    # })    

    output$table1 = renderTable(iris)
    
    output$table2 = renderTable(iris)
    
})
