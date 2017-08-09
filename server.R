library(shiny)
library(gridExtra)
library(ggplot2)
library(reshape2)
library(libSBML)

source('scripts/rkhs_gradmatch_wrapper.r')

SEED = 19537
set.seed(SEED)

# true parameters
kernelChoices = c("kernel1"="kernel1", "kernel2"="kernel2", "kernel3"="kernel3")
constraintChoices = c("---"="---", "Gaussian"="gaussian", "Gamma"="gamma")

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
        
        if (is.null(input$sbml_file)) { # no SBML input, return pre-defined model
            
            res = get_initial_values(input$predefined_model)
            return(res)
                        
        } else { # extract from the SBML file

            inFile = input$sbml_file
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
        
        res = get_initial_values(input$predefined_model)
        if (!is.null(res)) { # load one of the three pre-defined models
            loadModel(input, output, 
                      res$numSpecies, res$species, res$speciesInitial, 
                      res$numParams, res$params, res$paramsVals)
        } else { # no predefined model is selected
            resetModel(input, output)
        }
        
    })
    
    observeEvent(input$sbml_file, {
        
        sbml = parseSBML()
        loadModel(input, output, 
                  sbml$numSpecies, sbml$species, sbml$speciesInitial, 
                  sbml$numParams, sbml$params, sbml$paramsVals)

    })    

    generateData = reactive({

        noise = input$snr  ## TODO: change from variance to SNR 
        tinterv = c(input$timePointsMin, input$timePointsMax)
        
        if (is.null(input$sbml_file)) { # no SBML input, generate data using predefined models

            predefined_model = input$predefined_model
                        
            sbml = parseSBML()
            xinit = as.matrix(sbml$speciesInitial)
            numSpecies = sbml$numSpecies
            paramsVals = sbml$paramsVals
            
            res = generate_data_predefined_models(predefined_model, xinit, tinterv, numSpecies, paramsVals, noise)
            
        } else { # extract from the SBML file
         
            samp = 2
            sbml_data = load_sbml(input$sbml_file$datapath)
            res = generate_data_from_sbml(sbml_data, tinterv, samp, noise)

        }
        
        res
        
    })
    
    observeEvent(input$generateBtn, {

        res = generateData()
        sbml = parseSBML()
        
        t = res$time
        y_no = res$y_no
        updateTabsetPanel(session, "inTabset", selected="results")
        output$resultsType = renderText({ "Generated data:" })
        output$resultsPlot = renderPlot({
            
            plot_df = data.frame(y_no)
            plot_df$time = t
            plot_df = melt(plot_df, id.vars='time', variable.name='state')
            
            pp = list()
            for (i in 1:ncol(y_no)) {
                
                species = sbml$species[i]
                title = paste('State', species, sep=' ')
                pp[[i]] = ggplot(data=plot_df, aes(x=time, y=value)) + 
                    geom_point(data=subset(plot_df, state==species), color="red") + 
                    ggtitle(title) + 
                    theme_bw() + theme(text = element_text(size=20))

            }
            do.call(grid.arrange, pp)
            
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
        kkk = res$kkk
        y_no = res$y_no
        
        sbml = parseSBML()
        nst = sbml$numSpecies
        npar = sbml$numParams
        xinit = as.matrix(sbml$speciesInitial)
        tinterv = c(input$timePointsMin, input$timePointsMax)
        
        # for (st in 1:numSpecies)
        # {
        #     incProgress(st/numSpecies, detail=paste("System State", st))
        # }
        # incProgress(1, detail="3rd Step Iteration")
        
        withProgress(message='Inferring', value=0, {
            
            if (input$method == "gm") {
                infer_res = gradient_match(nst, npar, kkk, y_no, ktype='rbf')
            } else if (input$method == "gm+3rd") {
                infer_res = gradient_match_third_step(nst, npar, kkk, y_no, ktype='rbf')
            } else if (input$method == "warping") {
                # TODO
            } else if (input$method == "3rd+warping") {
                # TODO
            }
            
            x = infer_res$ode_par
            df = data.frame(parameters=x)
            sbml = parseSBML()
            rownames(df) = sbml$params

        })
        
        output$resultsPlot = renderPlot({

            # plot them together -- THIS ISN'T WHAT WE WANT
            # y = c(resb1$pred, resb2$pred)
            # plot_df = data.frame(t(intp))
            # plot_df$time = kkk$t 
            # plot_df = melt(plot_df, id.vars='time', variable.name='states')
            # ggplot(aes(y=value, x=time, colour=states), data=plot_df) + geom_line() + 
            #     theme_bw() +
            #     theme(text = element_text(size=20))

            res = infer_res$res
            pp = list()
            for (i in 1:length(res$bbb)) {
                
                time = res$bbb[[i]]$t
                y = res$bbb[[i]]$y
                intp = res$intp[i, ]
                    
                plot_df = data.frame(time)
                plot_df$data = y
                plot_df$interpolated = intp
                plot_df = melt(plot_df, id.vars='time', variable.name='type')
                
                title = paste('State', sbml$species[i], sep=' ')
                pp[[i]] = ggplot(data=plot_df, aes(x=time, y=value)) + 
                    geom_point(data=subset(plot_df, type=='data'), aes(color='data')) + 
                    geom_line(data=subset(plot_df, type=='interpolated'), aes(color='interpolated')) +
                    ggtitle(title) + 
                    theme_bw() + theme(text = element_text(size=20)) + 
                    scale_colour_manual(name="Legend", values=c(data="red", interpolated="blue"))                    
            
            }
            do.call(grid.arrange, pp)

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
