library(shiny)
library(gridExtra)
library(ggplot2)
library(reshape2)
library(libSBML)

source('scripts/rkhs_gradmatch_wrapper.r')

SEED = 19537
set.seed(SEED)
modelChoices = c("---" = "",
                 "Lotka-Volterra" = "lv",
                 "Fiz hugh nagumo" = "fhg",
                 "Biopathway" = "bp")

shinyServer(function(input, output, session) {
   
    observeEvent(input$process, {
        insertUI(
            selector = "#add",
            where = "afterEnd",
            ui = textInput(paste0("txt", input$add),
                           "Insert some text")
        )
    })    

    values <- reactiveValues(
        upload_state = NULL,
        infer_res = NULL,
        df = NULL
    )    
        
    getModel = reactive({

        if (is.null(values$upload_state)) {
            res = NULL
        } else if (values$upload_state == 'uploaded') {
            res = get_initial_values_sbml(input$sbml_file)
        } else if (values$upload_state == 'selected') {
            res = get_initial_values_selected(input$selected_model)
        }
        return(res)

    })
    
    resetScreen = function(input, output) {
        removeUI(selector = '#placeholderParams *', multiple=TRUE)
    }
    
    showModel = function(input, output, 
                         numSpecies, species, speciesInitial,
                         numParams, params, paramsVals) {

        removeUI(selector = '#placeholderParams *', multiple=TRUE)
        removeUI(selector = '#placeholderStates *', multiple=TRUE)
        
        output$odeParameters = renderText({ paste(params, collapse=", " ) })        
        for (i in 1:numParams) {
            paramValId = paste0('param_val', i)
            paramValLabel = params[i]
            insertUI(
                selector = '#placeholderParams',
                ui = fluidRow(
                    column(12, numericInput(paramValId, paramValLabel, value=paramsVals[i], min=0, max=NA, step=1))
                )                    
            )
        }
        
        labels = c()
        for (i in 1:numSpecies) {
            initCondId = paste0('initial_cond', i)
            initCondLabel = paste0(species[i], " Initial Cond.")
            guessId = paste0('p0_', i)
            guessLabel = 'Guess Period'
            insertUI(
                selector = '#placeholderStates',
                ui = fluidRow(
                    column(6, numericInput(initCondId, initCondLabel, value=speciesInitial[i], min=0, max=NA, step=0.1)),
                    column(6, numericInput(guessId, guessLabel, value=6, min=0, max=NA, step=0.1))
                )                    
            )
            labels = c(labels, species[i])
        }
        output$systemStates = renderText({ paste(labels, collapse=", " ) })
        
    }
    
    observeEvent(input$selected_model, {

        values$upload_state <- 'selected'
        res = getModel()
        
        if (!is.null(res)) { # load one of the three pre-defined models, null otherwise
            showModel(input, output, 
                      res$numSpecies, res$species, res$speciesInitial, 
                      res$numParams, res$params, res$paramsVals)
        } else { # no predefined model is selected
            resetScreen(input, output)
        }
        
    })
    
    observeEvent(input$sbml_file, {

        # updateSelectInput(session, "selected_model", 
        #                   label = "Select predefined models",
        #                   choices = modelChoices,
        #                   selected = head(modelChoices, 1))               

        values$upload_state <- 'uploaded'
        sbml = getModel()
        showModel(input, output, 
                  sbml$numSpecies, sbml$species, sbml$speciesInitial, 
                  sbml$numParams, sbml$params, sbml$paramsVals)

    })    

    get_values = function(input, id, n, param_names) {
        vals = numeric(0)
        for (i in 1:n) {
            vals = c(vals, input[[paste0(id, i)]])
        }
        names(vals) = param_names
        return(vals)
    }
    
    generateData = reactive({

        noise = input$snr  ## TODO: change from variance to SNR 
        tinterv = c(input$timePointsMin, input$timePointsMax)
        
        model = getModel()
        xinit = as.matrix(get_values(input, 'initial_cond', model$numSpecies, model$species))
        params = get_values(input, 'param_val', model$numParams, model$params)
        
        if (is.null(input$sbml_file)) { # no SBML input, generate data using predefined models

            selected_model = input$selected_model
            res = generate_data_selected_model(selected_model, xinit, tinterv, 
                                                  model$numSpecies, params, noise)
            
        } else { # extract from the SBML file
         
            samp = 2
            f = input$sbml_file$datapath
            res = generate_data_from_sbml(f, xinit, tinterv, params, samp, noise)

        }
        
        res
        
    })
    
    observeEvent(input$generateBtn, {

        model = getModel()
        
        res = generateData()
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
                
                species = model$species[i]
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

        res = generateData()
        kkk = res$kkk
        y_no = res$y_no
        
        model = getModel()
        nst = model$numSpecies

        # for (st in 1:numSpecies)
        # {
        #     incProgress(st/numSpecies, detail=paste("System State", st))
        # }
        # incProgress(1, detail="3rd Step Iteration")
        
        withProgress(message='Inferring', value=0, {
            
            if (!is.null(res$sbml_data)) {
                attach(res$sbml_data)
            }
            
            if (input$method == "gm") {
                infer_res = gradient_match(kkk, y_no, ktype=input$ktype)
            } else if (input$method == "gm+3rd") {
                infer_res = gradient_match_third_step(kkk, y_no, ktype=input$ktype)
            } else if (input$method == "warping") {
                peod = get_values(input, 'p0_', nst, model$species)
                eps = input$eps
                infer_res = warping(kkk, y_no, peod, eps, ktype=input$ktype)                
            } else if (input$method == "3rd+warping") {
                peod = get_values(input, 'p0_', nst, model$species)
                eps = input$eps
                infer_res = third_step_warping(kkk, y_no, peod, eps, ktype=input$ktype)                
            }
            
            df = data.frame(parameters=infer_res$ode_par)
            rownames(df) = model$params

            values$infer_res = infer_res
            values$df = df
                        
            if (!is.null(res$sbml_data)) {
                detach(res$sbml_data)
            }
            
        })
        
        output$diagnosticPlot = renderPlot({

            res = values$infer_res
                        
            # 'f =' followed by any number of spaces, followed by a decimal number
            pattern = 'f =\\s+[0-9]*\\.?[0-9]*'
            m = gregexpr(pattern, res$output)
            regm = regmatches(res$output, m)
            costs = numeric()
            for (i in 1:length(regm)) {
                match = regm[[i]]
                if (length(match) > 0) {
                    x = unlist(strsplit(match, '='))
                    my_cost = as.numeric(trimws(x[2]))
                    costs = c(my_cost, costs)
                }
            }
            costs = rev(costs)
            
            df = as.data.frame(costs)
            iterations = seq_along(costs)-1
            ggplot(data=df, aes(y=costs, x=iterations)) +
                geom_line() +
                geom_point() +
                ggtitle('Optimisation Results') +
                xlab("Iteration") +
                ylab("f") +
                theme_bw() + theme(text = element_text(size=20)) +
                expand_limits(x = 0) + scale_x_continuous(expand = c(0, 0))
            
        })
        
        output$console = renderPrint({
            return(print(values$infer_res$output))
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

            res = values$infer_res
            pp = list()
            for (i in 1:infer_res$nst) {
                
                time = res$plot_x[[i]]
                y = res$data[[i]]
                intp = res$plot_y[[i]]
                    
                plot_df = data.frame(time)
                plot_df$data = y
                plot_df$interpolated = intp
                plot_df = melt(plot_df, id.vars='time', variable.name='type')
                
                title = paste('State', model$species[i], sep=' ')
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
            values$df
        }, rownames=T)
    
        shinyjs::show("downloadParamsBtn")
        
        output$downloadParamsBtn <- downloadHandler(
            filename = function() { 'params.csv' },
            content = function(file) {
                write.csv(values$df, file)
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
