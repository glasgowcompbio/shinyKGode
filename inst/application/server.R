shiny::shinyServer(function(input, output, session) {
    values <- shiny::reactiveValues(
        model_from = NULL,
        data_from = NULL,
        infer_res = NULL,
        df = NULL,
        kkk0 = NULL
    )
    
    getModelParameters = shiny::reactive({
        if (is.null(values$model_from)) {
            res = NULL
        } else if (values$model_from == 'uploaded') {
            res = get_initial_values_sbml(input$sbml_file)
        } else if (values$model_from == 'selected') {
            res = get_initial_values_selected(input$selected_model)
        }
        return(res)
        
    })
    
    resetScreen = function(input, output) {
        shiny::removeUI(selector = '#generateParams *', multiple = TRUE)
        shiny::removeUI(selector = '#generateStates *', multiple = TRUE)
        shiny::removeUI(selector = '#optimisationParams *', multiple = TRUE)
        shiny::removeUI(selector = '#warpingPeriods *', multiple = TRUE)
    }
    
    showModel = function(input, output, res) {
        shinyjs::enable('csv_file')
        shinyjs::enable('generateBtn')
        shiny::removeUI(selector = '#generateParams *', multiple = TRUE)
        shiny::removeUI(selector = '#generateStates *', multiple = TRUE)
        shiny::removeUI(selector = '#optimisationParams *', multiple = TRUE)
        shiny::removeUI(selector = '#warpingPeriods *', multiple = TRUE)
        
        output$generateParamsTextOutput = shiny::renderText({
            paste(res$params, collapse = ", ")
        })
        output$optimisationParamsTextOutput = shiny::renderText({
            paste(res$params, collapse = ", ")
        })
        for (i in 1:res$num_params) {
            param_val_id = paste0('param_val', i)
            opt_val_id = paste0('opt_val', i)
            param_val_label = res$params[i]
            insertUI(
                selector = '#generateParams',
                ui = numericInput(
                    param_val_id,
                    param_val_label,
                    value = res$params_vals[i],
                    min = 0,
                    max = NA,
                    step = 0.1
                )
            )
            insertUI(
                selector = '#optimisationParams',
                ui = numericInput(
                    opt_val_id,
                    param_val_label,
                    value = 0.1,
                    min = 0,
                    max = NA,
                    step = 0.1
                )
            )
        }
        
        labels = c()
        for (i in 1:res$num_species) {
            init_cond_id = paste0('initial_cond', i)
            init_cond_label = paste0(res$species[i], " Initial Cond.")
            guess_id = paste0('p0_', i)
            guess_label = paste0(res$species[i], " Guessing Period")
            shiny::insertUI(
                selector = '#generateStates',
                ui = shiny::numericInput(
                    init_cond_id,
                    init_cond_label,
                    value = res$species_initial[i],
                    min = 0,
                    max = NA,
                    step = 0.1
                )
            )
            shiny::insertUI(
                selector = '#warpingPeriods',
                ui = shiny::numericInput(
                    guess_id,
                    guess_label,
                    value = res$peod[i],
                    min = 0,
                    max = NA,
                    step = 0.1
                )
            )
            labels = c(labels, res$species[i])
        }
        output$generateStatesTextOutput = shiny::renderText({
            paste(labels, collapse = ", ")
        })
        output$warpingPeriodsTextOutput = shiny::renderText({
            paste(labels, collapse = ", ")
        })
        
        shiny::updateNumericInput(session, "time_points_min", value = res$tinterv[1])
        shiny::updateNumericInput(session, "time_points_max", value = res$tinterv[2])
        shiny::updateNumericInput(session, "time_points_pick", value = res$pick)
        shiny::updateNumericInput(session, "noise", value = res$noise)
        shiny::updateRadioButtons(session, "noise_unit", selected = "var")
        shiny::updateNumericInput(session, "eps", value = res$eps)
        
    }
    
    shiny::observeEvent(input$selected_model, {
        values$model_from <- 'selected'
        res = getModelParameters()
        
        if (!is.null(res)) {
            # load one of the three pre-defined models, null otherwise
            showModel(input, output, res)
        } else {
            # no predefined model is selected
            resetScreen(input, output)
        }
        
    })
    
    shiny::observeEvent(input$sbml_file, {
        values$model_from <- 'uploaded'
        sbml = getModelParameters()
        showModel(input, output, sbml)
        
    })
    
    getValues = function(input, id, n, param_names) {
        vals = numeric(0)
        for (i in 1:n) {
            vals = c(vals, input[[paste0(id, i)]])
        }
        names(vals) = param_names
        return(vals)
    }
    
    getData = shiny::reactive({
        SEED = input$seed
        # print(paste('Get data seed is', SEED))
        set.seed(SEED)
        
        model = getModelParameters()
        params = getValues(input, 'param_val', model$num_params, model$params)
        opt_params = getValues(input, 'opt_val', model$num_params, model$params)
        
        if (is.null(values$data_from)) {
            # should never happen
            
            res = NULL
            
        } else if (values$data_from == 'uploaded') {
            # for data uploaded by the user
            
            res = get_data_from_csv(
                input$csv_file$datapath,
                input$sbml_file$datapath,
                params,
                opt_params,
                values$model_from,
                input$selected_model
            )
            
        } else if (values$data_from == 'generated') {
            # for data generated by the user
            
            xinit = as.matrix(getValues(
                input,
                'initial_cond',
                model$num_species,
                model$species
            ))
            tinterv = c(input$time_points_min, input$time_points_max)
            pick = input$time_points_pick
            res = generate_data(
                values$model_from,
                input$sbml_file$datapath,
                input$selected_model,
                xinit,
                tinterv,
                input$noise,
                input$noise_unit,
                model$num_species,
                params,
                opt_params,
                pick
            )
            
        }
        
        values$kkk0 = res$kkk0
        return(res)
        
    })
    
    showData = function(input, output, session, t, y_no) {
        model = getModelParameters()
        
        # shiny::updateTabsetPanel(session, "inTabset", selected="results")
        output$generateDataPlot = shiny::renderPlot({
            plot_df = data.frame(y_no)
            plot_df$time = t
            plot_df = reshape2::melt(plot_df,
                                     id.vars = 'time',
                                     variable.name = 'state')
            
            pp = list()
            for (i in 1:ncol(y_no)) {
                species = model$species[i]
                title = paste('State', species, sep = ' ')
                pp[[i]] = ggplot2::ggplot(data = plot_df, ggplot2::aes(x =
                                                                           time, y = value)) +
                    ggplot2::geom_point(data = subset(plot_df, state == species),
                                        color = "red") +
                    ggplot2::ggtitle(title) +
                    ggplot2::xlab("Time") +
                    ggplot2::ylab("Value") +
                    ggplot2::theme_bw() + ggplot2::theme(text = ggplot2::element_text(size =
                                                                                          20)) +
                    ggplot2::expand_limits(x = 0) + ggplot2::scale_x_continuous(expand = c(0, 0))
                
            }
            gridExtra::grid.arrange(grobs=pp, ncol=1)
            
        }, height=function() {
            200 * model$num_species
        })
        
        shinyjs::enable("inferBtn")
        if (values$data_from == 'generated') {
            shiny::updateActionButton(session, "inferBtn", label = "Infer on generated data")
            shinyjs::show("downloadDataBtn")
        } else if (values$data_from == 'uploaded') {
            shiny::updateActionButton(session, "inferBtn", label = "Infer on loaded data")
        }
        
        output$downloadDataBtn <- shiny::downloadHandler(
            filename = function() {
                'data.csv'
            },
            content = function(file) {
                df1 = as.data.frame(t)
                df2 = as.data.frame(y_no)
                names(df1) = 'time'
                names(df2) = model$species
                df = cbind(df1, df2)
                write.csv(df, file, row.names = FALSE)
            }
        )
        
        shinyjs::show('generateDataPlot')
        shinyjs::hide('interpPlotInitial')
        shinyjs::hide('interpPlotInferred')
        shinyjs::hide('plot_ode')
        shinyjs::hide('downloadParamsBtn')
        shinyjs::hide('initialParams')
        shinyjs::hide('inferredParams')
        shinyjs::hide('diagnosticPlot')
        shinyjs::hide('warpingPlot')
        shinyjs::hide('console')
        shinyjs::hide('methodTextOutput')
        
    }
    
    shiny::observeEvent(input$generateBtn, {
        values$data_from <- 'generated'
        res = getData()
        showData(input, output, session, res$time, res$y_no)
    })
    
    shiny::observeEvent(input$csv_file, {
        values$data_from <- 'uploaded'
        res = getData()
        showData(input, output, session, res$time, res$y_no)
    })
    
    shiny::observeEvent(input$inferBtn, {
        SEED = input$seed
        # print(paste('Infer seed is', SEED))
        set.seed(SEED)
        
        shinyjs::disable('inferBtn')
        shiny::updateTabsetPanel(session, "inTabset", selected = "results")
        
        res = getData()
        kkk = res$kkk
        y_no = res$y_no
        tinterv = res$tinterv
        
        model = getModelParameters()
        nst = model$num_species
        
        progress <- shiny::Progress$new()
        on.exit(progress$close())
        
        if (input$ode_reg == 'on' && input$warping == 'on') {
            method = '3rd+warping'
        } else {
            if (input$ode_reg == 'on') {
                method = 'gm+3rd'
            } else if (input$warping == 'on') {
                method = 'warping'
            } else {
                method = 'gm'
            }
        }
        # print(paste('method =', method))
        
        if (method == "gm") {
            output$methodTextOutput = shiny::renderText("Method: gradient matching")
            infer_res = gradient_match(kkk, tinterv, y_no, input$ktype, progress)
        } else if (method == "gm+3rd") {
            output$methodTextOutput = shiny::renderText("Method: gradient matching + ODE regularisation")
            infer_res = gradient_match_third_step(kkk, tinterv, y_no, input$ktype, progress)
        } else if (method == "warping") {
            output$methodTextOutput = shiny::renderText("Method: gradient matching + warping")
            peod = getValues(input, 'p0_', nst, model$species)
            eps = input$eps
            infer_res = warping(kkk, tinterv, y_no, peod, eps, input$ktype, progress)
        } else if (method == "3rd+warping") {
            output$methodTextOutput = shiny::renderText("Method: gradient matching + warping + ODE regularisation")
            peod = getValues(input, 'p0_', nst, model$species)
            eps = input$eps
            infer_res = third_step_warping(kkk, tinterv, y_no, peod, eps, input$ktype, progress)
        }
        values$infer_res = infer_res
        
        initial_params = getValues(input, 'param_val', model$num_params, model$params)
        inferred_params = infer_res$ode_par
        names(inferred_params) = names(initial_params)
        
        xinit = as.matrix(getValues(
            input,
            'initial_cond',
            model$num_species,
            model$species
        ))
        solved_initial = solve_ode(values$kkk0, initial_params, xinit, tinterv)
        solved_inferred = solve_ode(values$kkk0, inferred_params, xinit, tinterv)
        
        initial_df = data.frame(parameters = initial_params)
        inferred_df = data.frame(parameters = inferred_params)
        # rownames(inferred_df) = model$params
        values$initial_df = initial_df
        values$inferred_df = inferred_df
        
        ### plot the interpolation fit ###
        output$interpPlotInitial = get_interpolation_plot(values$infer_res, time, solved_initial, model$species)
        output$interpPlotInferred = get_interpolation_plot(values$infer_res,
                                                           time,
                                                           solved_inferred,
                                                           model$species)
        
        ### show the tables of initial & inferred parameters ###
        output$initialParams = shiny::renderTable({
            values$initial_df
        }, rownames = T, digits = 6)
        output$inferredParams = shiny::renderTable({
            values$inferred_df
        }, rownames = T, digits = 6)
        
        # set the download handler for the inferred parameters
        output$downloadParamsBtn <- shiny::downloadHandler(
            filename = function() {
                'params.csv'
            },
            content = function(file) {
                write.csv(values$inferred_df, file)
            }
        )
        
        ### plot the objective function for diagnostics
        output$diagnosticPlot = getDiagnosticPlot(values$infer_res)
        
        ### plot the warping functions for each state ###
        # if (!is.null(res$warpfun_x[[1]])) {
        output$warpingPlot = getWarpingPlot(values$infer_res, model$species)
        # }
        
        ### print diagnostic output
        outputMsg = paste(values$infer_res$output, collapse='\n')
        output$console = shiny::renderText({
            outputMsg
        })
        
        shinyjs::show('interpPlotInitial')
        shinyjs::show('interpPlotInferred')
        shinyjs::show('plot_ode')
        shinyjs::show('downloadParamsBtn')
        shinyjs::show('initialParams')
        shinyjs::show('inferredParams')
        shinyjs::show('diagnosticPlot')
        shinyjs::show('warpingPlot')
        shinyjs::show('console')
        shinyjs::show('methodTextOutput')
        shinyjs::show("downloadParamsBtn")
        shinyjs::enable("inferBtn")
        
    })
    
    get_interpolation_plot = function(res, time, solved, species) {
        return(shiny::renderPlot({
            solved_yode = solved$y_ode
            solved_t = solved$t
            pp = list()
            for (i in 1:res$nst) {
                intp_x = res$intp_x[[i]]
                intp_y = res$intp_y[[i]]
                data_x = res$data_x[[i]]
                data_y = res$data_y[[i]]
                solved_y = solved_yode[i, ]
                solved_x = solved_t
                
                time = intp_x
                plot_df1 = data.frame(time)
                plot_df1$interpolated = intp_y
                plot_df1 = reshape2::melt(plot_df1,
                                          id.vars = 'time',
                                          variable.name = 'type')
                
                time = data_x
                plot_df2 = data.frame(time)
                plot_df2$observed = data_y
                plot_df2 = reshape2::melt(plot_df2,
                                          id.vars = 'time',
                                          variable.name = 'type')
                
                time = solved_x
                plot_df3 = data.frame(time)
                plot_df3$solved = solved_y
                plot_df3 = reshape2::melt(plot_df3,
                                          id.vars = 'time',
                                          variable.name = 'type')
                
                plot_df = rbind(plot_df1, plot_df2, plot_df3)
                temp2 = subset(plot_df, type == 'observed')
                temp1 = subset(plot_df, type == 'interpolated')
                temp3 = subset(plot_df, type == 'solved')
                
                title = paste('State', species[i], sep = ' ')
                g = ggplot2::ggplot() +
                    ggplot2::geom_point(data = temp2,
                                        ggplot2::aes(
                                            x = time,
                                            y = value,
                                            colour = 'c1'
                                        )) +
                    ggplot2::geom_line(
                        data = temp1,
                        ggplot2::aes(
                            x = time,
                            y = value,
                            colour = 'c2'
                        ),
                        size = 1
                    ) +
                    ggplot2::geom_line(
                        data = temp3,
                        ggplot2::aes(
                            x = time,
                            y = value,
                            colour = 'c3'
                        ),
                        size = 1,
                        linetype = "dashed"
                    ) +
                    ggplot2::ggtitle(title) +
                    ggplot2::theme_bw() + ggplot2::theme(text = ggplot2::element_text(size =
                                                                                          20)) +
                    ggplot2::scale_colour_manual(
                        name = "Legend",
                        values = c(
                            c1 = "red",
                            c2 = "blue",
                            c3 = "grey"
                        ),
                        labels = c(
                            c1 = "Observed",
                            c2 = "Interpolated",
                            c3 = "Solved"
                        )
                    ) +
                    ggplot2::expand_limits(x = 0) + ggplot2::scale_x_continuous(expand = c(0, 0))
                
                pp[[i]] = g
                
            }
            gridExtra::grid.arrange(grobs=pp, ncol=1)
            
        }, height=function() {
            200 * length(species)
        })
        
    )}
    
    getDiagnosticPlot = function(res) {
        return(renderPlot({
            objectives = res$objectives
            
            # plot the objective function for gradient matching
            df = as.data.frame(objectives)
            iterations = seq_along(objectives) - 1
            g = ggplot2::ggplot(data = df, ggplot2::aes(y = objectives, x =
                                                            iterations)) +
                ggplot2::geom_line(size = 1, colour = 'blue') +
                ggplot2::geom_point() +
                ggplot2::ggtitle('Optimisation Results') +
                ggplot2::xlab("Iteration") +
                ggplot2::ylab("Objective (f)") +
                ggplot2::theme_bw() + ggplot2::theme(text = ggplot2::element_text(size =
                                                                                      20)) +
                ggplot2::expand_limits(x = 0) + ggplot2::scale_x_continuous(expand = c(0, 0))
            return(g)
            
        }))
        
    }
    
    getWarpingPlot = function(res, species) {
        return(renderPlot({
            pp = list()
            for (i in 1:res$nst) {
                warpfun_x = res$warpfun_x[[i]]
                warpfun_y = res$warpfun_y[[i]]
                warpfun_pred = res$warpfun_pred[[i]]
                
                title = 'Original Plot'
                warp_df = as.data.frame(warpfun_x)
                warp_df$intp = warpfun_pred
                g1 = ggplot2::ggplot() +
                    ggplot2::geom_line(
                        data = warp_df,
                        ggplot2::aes(x = warpfun_x, y = intp),
                        size = 1
                    ) +
                    ggplot2::ggtitle(title) +
                    ggplot2::xlab("Original time") +
                    ggplot2::ylab("Value") +
                    ggplot2::theme_bw() + ggplot2::theme(text = ggplot2::element_text(size =
                                                                                          20)) +
                    ggplot2::expand_limits(x = 0) + ggplot2::scale_x_continuous(expand = c(0, 0)) +
                    ggplot2::theme(plot.margin = ggplot2::unit(c(0.5, 0.5, 0.5, 0.5), "cm"))
                
                title = paste('State', species[i], ' - Warping function', sep =
                                  ' ')
                warp_df = as.data.frame(warpfun_x)
                warp_df$warpfun_y = warpfun_y
                g2 = ggplot2::ggplot() +
                    ggplot2::geom_line(
                        data = warp_df,
                        ggplot2::aes(x = warpfun_x, y = warpfun_y),
                        size = 1
                    ) +
                    ggplot2::ggtitle(title) +
                    ggplot2::xlab("Original time") +
                    ggplot2::ylab("Warped time") +
                    ggplot2::theme_bw() + ggplot2::theme(text = ggplot2::element_text(size =
                                                                                          20)) +
                    ggplot2::expand_limits(x = 0) + ggplot2::scale_x_continuous(expand = c(0, 0)) +
                    ggplot2::theme(plot.margin = ggplot2::unit(c(0.5, 0.5, 0.5, 0.5), "cm"))
                
                title = 'Warped Plot'
                warp_df = as.data.frame(warpfun_y)
                warp_df$intp = warpfun_pred
                g3 = ggplot2::ggplot() +
                    ggplot2::geom_line(
                        data = warp_df,
                        ggplot2::aes(x = warpfun_y, y = intp),
                        size = 1
                    ) +
                    ggplot2::ggtitle(title) +
                    ggplot2::xlab("Warped time") +
                    ggplot2::ylab("Value") +
                    ggplot2::theme_bw() + ggplot2::theme(text = ggplot2::element_text(size =
                                                                                          20)) +
                    ggplot2::expand_limits(x = 0) + ggplot2::scale_x_continuous(expand = c(0, 0)) +
                    ggplot2::theme(plot.margin = ggplot2::unit(c(0.5, 0.5, 0.5, 0.5), "cm"))
                
                pp[[i]] = gridExtra::grid.arrange(g1, g2, g3, ncol = 3)
                
            }
            
            gridExtra::grid.arrange(grobs=pp, ncol=1)
            
        }, height=function() {
            200 * length(species)
        })
        
    )}
    
})

### define ode
LV_fun = function(t, x, par_ode) {
    alpha = par_ode[1]
    beta = par_ode[2]
    gamma = par_ode[3]
    delta = par_ode[4]
    # incid = matrix(c(1, 0, -1, 0, 0, -1, 0, 1), nrow=2, ncol=4)
    # v = c(alpha*x[1], beta*x[2]*x[1], gamma*x[2], delta*x[1]*x[2])
    # incid %*% v
    as.matrix(c(alpha * x[1] - beta * x[2] * x[1] , -gamma * x[2] + delta *
                    x[1] * x[2]))
}

LV_grlNODE = function(par, grad_ode, y_p, z_p) {
    alpha = par[1]
    beta = par[2]
    gamma = par[3]
    delta = par[4]
    dres = c(0)
    dres[1] = sum(-2 * (z_p[1,] - grad_ode[1,]) * y_p[1,] * alpha)
    dres[2] = sum(2 * (z_p[1,] - grad_ode[1,]) * y_p[2,] * y_p[1,] *
                      beta)
    dres[3] = sum(2 * (z_p[2,] - grad_ode[2,]) * gamma * y_p[2,])
    dres[4] = sum(-2 * (z_p[2,] - grad_ode[2,]) * y_p[2,] * y_p[1,] *
                      delta)
    dres
}

LV_initial_values = function() {
    num_species = 2
    species = c("X1", "X2")
    species_initial = c(1.0, 2.0)
    
    num_params = 4
    params = c("alpha", "beta", "gamma", "delta")
    params_vals = c(0.2, 0.35, 0.7, 0.4)
    
    tinterv = c(0, 30)
    pick = 2
    noise_var = 0.000625
    
    peod = c(17, 17) #8#9.7     ## the guessing period
    eps = 2          ## the standard deviation of period
    
    return(
        list(
            num_species = num_species,
            species = species,
            species_initial = species_initial,
            num_params = num_params,
            params = params,
            params_vals = params_vals,
            tinterv = tinterv,
            pick = pick,
            noise_var = noise_var,
            peod = peod,
            eps = eps
        )
    )
    
}

FN_fun = function(t, x, par_ode) {
    a = par_ode[1]
    b = par_ode[2]
    c = par_ode[3]
    as.matrix(c(c * (x[1] - x[1] ^ 3 / 3 + x[2]),-1 / c * (x[1] - a + b *
                                                               x[2])))
}

FN_grlNODE = function(par, grad_ode, y_p, z_p) {
    a = par[1]
    b = par[2]
    c = par[3]
    dres = c(0)
    dres[1] = sum(-2 * (z_p[2,] - grad_ode[2,]) * a / c)
    dres[2] = sum(2 * (z_p[2,] - grad_ode[2,]) * b * y_p[2,] / c)
    dres[3] = sum(-2 * (z_p[1,] - grad_ode[1,]) * grad_ode[1,]) + sum(2 *
                                                                          (z_p[2,] - grad_ode[2,]) * grad_ode[2,])
    dres
}

FN_initial_values = function() {
    num_species = 2
    species = c("X1", "X2")
    species_initial = c(-1,-1)
    
    num_params = 3
    params = c("a", "b", "c")
    params_vals = c(0.2, 0.2, 3)
    
    tinterv = c(0, 10)
    pick = 2
    noise_var = 0.01
    
    peod = c(8, 8.5) #8#9.7     ## the guessing period
    eps = 1          ## the standard deviation of period
    
    return(
        list(
            num_species = num_species,
            species = species,
            species_initial = species_initial,
            num_params = num_params,
            params = params,
            params_vals = params_vals,
            tinterv = tinterv,
            pick = pick,
            noise_var = noise_var,
            peod = peod,
            eps = eps
        )
    )
    
}

BP_fun = function(t, x, par_ode) {
    k1 = par_ode[1]
    k2 = par_ode[2]
    k3 = par_ode[3]
    k4 = par_ode[4]
    k5 = par_ode[5]
    k6 = par_ode[6]
    as.matrix(
        c(
            -k1 * x[1] - k2 * x[1] * x[3] + k3 * x[4],
            k1 * x[1],-k2 * x[1] * x[3] + k3 * x[4] + k5 * x[5] / (k6 + x[5]),
            k2 * x[1] * x[3] - k3 * x[4] - k4 * x[4],
            k4 * x[4] - k5 * x[5] / (k6 + x[5])
        )
    )
}

BP_grlNODE = function(par_ode, grad_ode, y_p, z_p) {
    k1 = par_ode[1]
    k2 = par_ode[2]
    k3 = par_ode[3]
    k4 = par_ode[4]
    v = par_ode[5]
    km = par_ode[6]
    lm = max(dim(y_p))
    dz1 = grad_ode[1,]
    dz2 = grad_ode[2,]
    dz3 = grad_ode[3,]
    dz4 = grad_ode[4,]
    dz5 = grad_ode[5,]
    
    z1 = y_p[1,]
    z2 = y_p[2,]
    z3 = y_p[3,]
    z4 = y_p[4,]
    z5 = y_p[5,]
    
    dres = c(0)
    dres[1] = sum(-2 * (z_p[1, 1:lm] - dz1) * (-z1 * k1) - 2 * (z_p[2, 1:lm] -
                                                                    dz2) * z1 * k1)
    dres[2] = sum(-2 * (z_p[1, 1:lm] - dz1) * (-z1 * z3 * k2) + 2 * (z_p[3, 1:lm] -
                                                                         dz3) * z1 * z3 * k2 - 2 * (z_p[4, 1:lm] - dz4) * z1 * z3 * k2)
    dres[3] = sum(2 * (z_p[1, 1:lm] - dz1) * (-z4 * k3) - 2 * (z_p[3, 1:lm] -
                                                                   dz3) * z4 * k3 + 2 * (z_p[4, 1:lm] - dz4) * z4 * k3)
    dres[4] = sum(2 * (z_p[4, 1:lm] - dz4) * z4 * k4 - 2 * (z_p[5, 1:lm] -
                                                                dz5) * z4 * k4)
    dres[5] = sum(-2 * (z_p[3, 1:lm] - dz3) * z5 * v / (km + z5) +  2 *
                      (z_p[5, 1:lm] - dz5) * z5 * v / (km + z5))
    dres[6] = sum(2 * (z_p[3, 1:lm] - dz3) * v * z5 / (km + z5) ^ 2 * km - 2 *
                      (z_p[5, 1:lm] - dz5) * v * z5 / (km + z5) ^ 2 * km)
    dres
}

BP_initial_values = function() {
    num_species = 5
    species = c("X1", "X2", "X3", "X4", "X5")
    species_initial = c(1, 0, 1, 0, 0)
    
    num_params = 6
    params = c("k1", "k2", "k3", "k4", "k5", "k6")
    params_vals = c(0.07, 0.6, 0.05, 0.3, 0.017, 0.3)
    
    tinterv = c(0, 100)
    pick = 2
    noise_var = 0.000289 # 0.017^2
    
    peod = c(200, 200, 200, 200, 200)   ## the guessing period for each state  user defined
    eps = 20          ## the standard deviation of period  user defined
    
    return(
        list(
            num_species = num_species,
            species = species,
            species_initial = species_initial,
            num_params = num_params,
            params = params,
            params_vals = params_vals,
            tinterv = tinterv,
            pick = pick,
            noise_var = noise_var,
            peod = peod,
            eps = eps
        )
    )
    
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
    return(res)
    
}

get_initial_values_sbml = function(inFile) {
    print(inFile)
    res = load_sbml(inFile$datapath)
    
    num_species = res$mi$nSpecies
    species = res$mi$sIDs
    species_initial = unname(res$mi$y0)
    
    num_params = length(res$params)
    params = names(res$params)
    params_vals = unname(res$params)
    
    # just some randomly selected default values
    tinterv = c(0, 10)
    pick = 1
    noise_var = 0.1
    peod = rep(1, num_params)
    eps = 1
    
    return(
        list(
            num_species = num_species,
            species = species,
            species_initial = species_initial,
            num_params = num_params,
            params = params,
            params_vals = params_vals,
            tinterv = tinterv,
            pick = pick,
            noise_var = noise_var,
            peod = peod,
            eps = eps
        )
    )
    
}

test = function(std) {
    rnorm(length(std), mean = 0, sd = std)
}

add_noise <- function(x, snr_db) {
    denom = 10 ^ (snr_db / 10)
    std = t(x) / denom
    noise = numeric()
    for (i in 1:ncol(std)) {
        temp = sapply(std[, i], test)
        noise = cbind(noise, temp)
    }
    res = t(x) + noise
    return(res)
}

generate_data_selected_model = function(selected_model,
                                        xinit,
                                        tinterv,
                                        num_species,
                                        params_vals,
                                        opt_params,
                                        noise,
                                        noise_unit,
                                        pick) {
    if (selected_model == "lv") {
        selected_fun = LV_fun
        selected_grfun = LV_grlNODE
    } else if (selected_model == "fhg") {
        selected_fun = FN_fun
        selected_grfun = FN_grlNODE
    } else if (selected_model == 'bp') {
        selected_fun = BP_fun
        selected_grfun = BP_grlNODE
    }
    kkk0 = KGode::ode$new(pick, fun=selected_fun, grfun=selected_grfun)
    kkk0$solve_ode(params_vals, xinit, tinterv)
    # npar = length(params_vals)
    # init_par = rep(c(0.1), npar)
    init_par = opt_params
    init_yode = kkk0$y_ode
    init_t = kkk0$t
    kkk = KGode::ode$new(
        1,
        fun = selected_fun,
        grfun = selected_grfun,
        t = init_t,
        ode_par = init_par,
        y_ode = init_yode
    )
    
    if (noise_unit == 'var') {
        n_o = max(dim(kkk$y_ode))
        y_no =  t(kkk$y_ode) + mvtnorm::rmvnorm(n_o, rep(0, num_species), noise *
                                                    diag(num_species))
    } else if (noise_unit == 'db') {
        y_no =  add_noise(kkk$y_ode, noise)
    }
    
    # print("Data is")
    # print(y_no)
    
    res = list(
        time = kkk$t,
        y_no = y_no,
        kkk = kkk,
        sbml_data = NULL,
        tinterv = tinterv,
        kkk0 = kkk0
    )
    return(res)
    
}

# https://stackoverflow.com/questions/26057400/r-how-do-you-merge-combine-two-environments
appendEnv = function(e1, e2) {
    e1name = deparse(substitute(e1))
    e2name = deparse(substitute(e2))
    listE1 = ls(e1)
    listE2 = ls(e2)
    for (v in listE2) {
        # if(v %in% listE1) warning(sprintf("Variable %s is in e1, too!", v))
        e1[[v]] = e2[[v]]
    }
}

generate_data_from_sbml <-
    function(f,
             xinit,
             tinterv,
             params,
             opt_params,
             noise,
             noise_unit,
             pick) {
        res = get_ode_fun(f, params)
        model = res$model
        mi = res$mi
        initial_names = names(params)
        
        ode_fun = res$ode_fun
        work_env = environment(ode_fun)
        param_env = list2env(model$globalParameters)
        appendEnv(work_env, param_env) # appends global parameters into work_env
        work_env$initial_names = initial_names
        
        kkk0 = KGode::ode$new(pick, fun = ode_fun)
        xinit = as.matrix(mi$S0)
        kkk0$solve_ode(par_ode = params, xinit, tinterv)
        
        init_par = opt_params
        init_yode = kkk0$y_ode
        init_t = kkk0$t
        kkk = KGode::ode$new(
            1,
            fun = ode_fun,
            t = init_t,
            ode_par = init_par,
            y_ode = init_yode
        )
        
        if (noise_unit == 'var') {
            n_o = max(dim(kkk$y_ode))
            y_no =  t(kkk$y_ode) + mvtnorm::rmvnorm(n_o, rep(0, mi$nStates), noise *
                                                        diag(mi$nStates))
        } else if (noise_unit == 'db') {
            y_no =  add_noise(kkk$y_ode, noise)
        }
        
        sbml_data = list(model = model,
                         mi = mi,
                         initial_names = initial_names)
        res = list(
            time = kkk$t,
            y_no = y_no,
            kkk = kkk,
            sbml_data = sbml_data,
            tinterv = tinterv,
            kkk0 = kkk0
        )
        return(res)
        
    }

generate_data <-
    function(model_from,
             sbml_file,
             selected_model,
             xinit,
             tinterv,
             noise,
             noise_unit,
             num_species,
             params,
             opt_params,
             pick) {
        if (model_from == 'uploaded') {
            # generate data using the model from an SBML file
            res = generate_data_from_sbml(sbml_file,
                                          xinit,
                                          tinterv,
                                          params,
                                          opt_params,
                                          noise,
                                          noise_unit,
                                          pick)
        } else if (model_from == 'selected') {
            # generate data using predefined models
            res = generate_data_selected_model(
                selected_model,
                xinit,
                tinterv,
                num_species,
                params,
                opt_params,
                noise,
                noise_unit,
                pick
            )
        }
        return(res)
        
    }

add_no_duplicate <- function(v1, v2) {
    for (i in 1:length(names(v2))) {
        name = names(v2)[i]
        if (!is.null(name) && !name %in% names(v1)) {
            v1[name] = v2[name]
        }
    }
    return(v1)
}

load_sbml <- function(f) {
    model = readSBML(f)
    mi = summary.SBMLR(model)
    
    # collect all the params
    params = mi$globalVec
    for (j in 1:mi$nReactions) {
        mrj = model$reactions[[j]]
        rm = c(mrj$reactants, mrj$modifiers)
        P = mrj$parameters
        params = add_no_duplicate(params, P)
    }
    
    initial_names = names(params)
    res = list(
        model = model,
        mi = mi,
        params = params,
        initial_names = initial_names
    )
    return(res)
    
}

get_data_from_csv <-
    function(csv_file,
             sbml_file,
             params,
             opt_params,
             model_from,
             selected_model) {
        ext = tools::file_ext(csv_file)
        if (ext == 'csv') {
            df <- read.csv(file = csv_file,
                           header = TRUE,
                           sep = ",")
        } else if (ext == 'rds') {
            df = readRDS(csv_file)
        }
        x = as.matrix(df)
        
        init_time = x[, 1]
        y_no = x[, 2:ncol(x)]
        # init_par = rep(c(0.1), length(params))
        init_par = opt_params
        
        if (model_from == 'uploaded') {
            # extract from the SBML file
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
        kkk = KGode::ode$new(
            1,
            fun = ode_fun,
            t = init_time,
            ode_par = init_par,
            y_ode = t(y_no)
        )
        res = list(
            time = init_time,
            y_no = y_no,
            kkk = kkk,
            sbml_data = NULL,
            tinterv = tinterv,
            kkk0 = kkk
        )
        return(res)
        
    }

get_ode_fun <- function(f, params) {
    model = readSBML(f)
    mi = summary.SBMLR(model)
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
            for (j in 1:mi$nRules)
                St[model$rules[[j]]$idOutput] = model$rules[[j]]$law(St[model$rule[[j]]$inputs])
        
        # par_ode should contain both the local AND global parameters from the SBML
        param_env = list2env(as.list(par_ode))
        for (j in 1:mi$nReactions) {
            mrj = model$reactions[[j]]
            rm = c(mrj$reactants, mrj$modifiers)
            
            # P is now passed from outside as par_ode
            # P = mrj$parameters
            # v[j] = mrj$law(St[rm], P)
            
            f = mrj$law
            work_env = environment(f)
            appendEnv(work_env, param_env) # appends global parameters into work_env
            v[j] = mrj$law(St[rm], par_ode)
            
        }
        
        xp = mi$incid %*% v
        xp
        
    }
    
    return(list(
        model = model,
        mi = mi,
        ode_fun = ode_fun
    ))
    
}

get_grid <- function(tinterv, n) {
    # https://stackoverflow.com/questions/19689397/extracting-breakpoints-with-intervals-closed-on-the-left
    labs <- levels(cut(tinterv, n))
    x = cbind(lower = as.numeric(sub("\\((.+),.*", "\\1", labs)), upper = as.numeric(sub("[^,]*,([^]]*)\\]", "\\1", labs)))
    grids = x[, 2]
    return(grids)
    
}

update_status <- function(progress, msg, msg_type, val) {
    if (!is.null(progress)) {
        if (msg_type == 'start') {
            progress$set(message = msg, value = val)
        } else if (msg_type == 'inc') {
            progress$inc(val, detail = msg)
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
    output1 = capture.output(rkgres <- KGode::rkg(kkk, y_no, ktype))
    update_status(progress, 'Completed', 'inc', 1)
    bbb = rkgres$bbb ## bbb is a rkhs object which contain all information about interpolation and kernel parameters.
    ode_par = kkk$ode_par
    
    grids = get_grid(tinterv, 2000)
    intp_x = list()
    intp_y = list()
    data_x = list()
    data_y = list()
    for (i in 1:length(bbb)) {
        # print(bbb[[i]])
        intp_x[[i]] = grids
        intp_y[[i]] = bbb[[i]]$predictT(grids)$pred
        data_x[[i]] = bbb[[i]]$t
        data_y[[i]] = bbb[[i]]$y
    }
    
    objectives = parse_objectives(output1)
    return(
        list(
            ode_par = ode_par,
            output = output1,
            objectives = objectives,
            intp_x = intp_x,
            intp_y = intp_y,
            data_x = data_x,
            data_y = data_y,
            warpfun_x = NULL,
            warpfun_y = NULL,
            warpfun_pred = NULL,
            nst = length(intp_x)
        )
    )
    
}

gradient_match_third_step <-
    function(kkk, tinterv, y_no, ktype, progress) {
        update_status(progress, 'Gradient matching', 'start', 0)
        output1 = capture.output(rkgres <-
                                     KGode::rkg(kkk, y_no, ktype))
        bbb = rkgres$bbb ## bbb is a rkhs object which contain all information about interpolation and kernel parameters.
        
        update_status(progress, 'Cross-validating', 'inc', 0.3)
        crtype = 'i'  ## two methods fro third step  'i' fast method means iterative and '3' for slow method means 3rd step
        # lam = c(1e-4, 1e-5)  ## we need to do cross validation for find the weighter parameter
        lam = c(10, 1, 1e-1, 1e-2, 1e-4)
        lamil1 = KGode::crossv(lam, kkk, bbb, crtype, y_no)
        lambdai1 = lamil1[[1]]
        
        update_status(progress, 'Third-step', 'inc', 0.6)
        output2 = capture.output(res <-
                                     KGode::third(lambdai1, kkk, bbb, crtype))
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
        return(
            list(
                ode_par = ode_par,
                output = output,
                objectives = objectives,
                intp_x = intp_x,
                intp_y = intp_y,
                data_x = data_x,
                data_y = data_y,
                warpfun_x = NULL,
                warpfun_y = NULL,
                warpfun_pred = NULL,
                nst = length(intp_x)
            )
        )
        
    }

warping <-
    function(kkk,
             tinterv,
             y_no,
             peod,
             eps,
             ktype,
             progress) {
        update_status(progress, 'Gradient matching', 'start', 0)
        output1 = capture.output(rkgres <-
                                     KGode::rkg(kkk, y_no, ktype))
        bbb = rkgres$bbb ## bbb is a rkhs object which contain all information about interpolation and kernel parameters.
        
        update_status(progress, 'Initialise warping', 'inc', 0.25)
        output2 = capture.output(fixlens <-
                                     KGode::warpInitLen(peod, eps, rkgres)) ## find the start value for the warping basis function.
        
        update_status(progress, 'Warping', 'inc', 0.5)
        kkkrkg = kkk$clone()
        output3 = capture.output(www <-
                                     KGode::warpfun(kkkrkg, bbb, peod, eps, fixlens, y_no, kkkrkg$t))
        update_status(progress, 'Completed', 'inc', 1)
        
        dtilda = www$dtilda
        bbbw = www$bbbw
        resmtest = www$wtime
        wfun = www$wfun
        wkkk = www$wkkk
        ode_par = wkkk$ode_par
        
        plot(kkk$t, resmtest[1,], type = 'l')   ## plotting function
        
        grids = get_grid(tinterv, 2000)
        intp_x = list()
        intp_y = list()
        data_x = list()
        data_y = list()
        warpfun_x = list()
        warpfun_y = list()
        warpfun_pred = list()
        for (i in 1:length(bbbw)) {
            wgrids = wfun[[i]]$predictT(grids)$pred ## denser grid in warped domain
            intp_x[[i]] = grids
            intp_y[[i]] = bbbw[[i]]$predictT(wgrids)$pred
            data_x[[i]] = bbb[[i]]$t
            data_y[[i]] = bbb[[i]]$y
            warpfun_x[[i]] = kkk$t
            warpfun_y[[i]] = resmtest[i, ]
            warpfun_pred[[i]] = bbbw[[i]]$predict()$pred
        }
        
        output = c(output1, output2, output3)
        objectives = parse_objectives(output1)
        return(
            list(
                ode_par = ode_par,
                output = output,
                objectives = objectives,
                intp_x = intp_x,
                intp_y = intp_y,
                data_x = data_x,
                data_y = data_y,
                warpfun_x = warpfun_x,
                warpfun_y = warpfun_y,
                warpfun_pred = warpfun_pred,
                nst = length(intp_x)
            )
        )
        
        
    }

third_step_warping <-
    function(kkk,
             tinterv,
             y_no,
             peod,
             eps,
             ktype,
             progress) {
        update_status(progress, 'Gradient matching', 'start', 0)
        output1 = capture.output(rkgres <-
                                     KGode::rkg(kkk, y_no, ktype))
        bbb = rkgres$bbb ## bbb is a rkhs object which contain all information about interpolation and kernel parameters.
        
        update_status(progress, 'Initialise warping', 'inc', 0.25)
        output2 = capture.output(fixlens <-
                                     KGode::warpInitLen(peod, eps, rkgres)) ## find the start value for the warping basis function.
        
        update_status(progress, 'Warping', 'inc', 0.50)
        kkkrkg = kkk$clone()
        output3 = capture.output(www <-
                                     KGode::warpfun(kkkrkg, bbb, peod, eps, fixlens, y_no, kkk$t))
        
        dtilda = www$dtilda
        bbbw = www$bbbw
        resmtest = www$wtime
        wfun = www$wfun
        wkkk = www$wkkk
        
        ##### 3rd step + warp
        woption = 'w'
        ####   warp   3rd
        crtype = 'i'
        # lam = c(1e-4, 1e-5)  ## we need to do cross validation for find the weighter parameter
        lam = c(10, 1, 1e-1, 1e-2, 1e-4)
        
        update_status(progress, 'Cross-validating', 'inc', 0.75)
        output4 = capture.output(lamwil <-
                                     KGode::crossv(lam, wkkk, bbbw, crtype, y_no, woption, resmtest, dtilda))
        
        update_status(progress, 'Third-step', 'inc', 0.90)
        lambdawi = lamwil[[1]]
        output5 = capture.output(res <-
                                     KGode::third(lambdawi, wkkk, bbbw, crtype, woption, dtilda))  ## add third step after warping
        progress$inc(1, detail = "Completed")
        ode_par = res$oppar
        
        grids = get_grid(tinterv, 2000)
        intp_x = list()
        intp_y = list()
        data_x = list()
        data_y = list()
        warpfun_x = list()
        warpfun_y = list()
        warpfun_pred = list()
        for (i in 1:length(res$rk3$rk)) {
            wgrid = wfun[[i]]$predictT(grids)$pred
            intp_x[[i]] = grids
            intp_y[[i]] = res$rk3$rk[[i]]$predictT(wgrid)$pred
            data_x[[i]] = bbb[[i]]$t
            data_y[[i]] = bbb[[i]]$y
            warpfun_x[[i]] = kkk$t
            warpfun_y[[i]] = resmtest[i, ]
            warpfun_pred[[i]] = bbbw[[i]]$predict()$pred
        }
        
        output = c(output1, output2, output3, output4, output5)
        objectives = parse_objectives(output1)
        return(
            list(
                ode_par = ode_par,
                output = output,
                objectives = objectives,
                intp_x = intp_x,
                intp_y = intp_y,
                data_x = data_x,
                data_y = data_y,
                warpfun_x = warpfun_x,
                warpfun_y = warpfun_y,
                warpfun_pred = warpfun_pred,
                nst = length(intp_x)
            )
        )
        
        
    }

solve_ode = function(kkk, params, xinit, tinterv) {
    solved = kkk$solve_ode(par_ode = params, xinit, tinterv)
    return(list(y_ode = kkk$y_ode, t = kkk$t))
}

readSBML = function(filename) {
    # takes SBML in filename.xml and maps it to a SBML class model
    # using both Sax and DOM (for mathml) based parsing.
    
    sbmlHandler <- function ()
    {
        # first block here sets up the parent environment used by all handler functions
        sbml <- "x"     # "x" is just a starting string value
        modelid <- "x"  				#storing model id
        lnotes <- NULL
        compartments <- list()
        reactLaws <- list()
        species <- list()
        rules <- list()
        reactions <- list()
        globalParameters = list()
        reactants = NULL
        products = NULL
        modifiers = NULL
        currRxnID = NULL
        parameters = NULL   # local to rate law
        parameterIDs = NULL   # local to rate law
        globalParameterIDs = NULL
        
        notes = FALSE
        reactant = FALSE
        product = FALSE
        law = FALSE
        parameter = FALSE
        math = FALSE
        
        .startElement <- function(name, atts, ...) {
            #   cat("Start: Name =",name," ",paste(names(atts),atts,sep=" = "),"\n")
            if (name == "sbml")
                sbml <<- atts
            if (name == "annotation")
                print("skipping annotation")
            
            if (name == "model")  {
                modelid <<- atts[["id"]]
            }
            
            if (name == "compartment")
                if ("id" %in% names(atts))
                    compartments[[atts["id"]]] <<- atts
                
                if (name == "species")
                    if ("id" %in% names(atts))
                        species[[atts["id"]]] <<- atts
                    if (name == "assignmentRule")
                        rules[[atts["variable"]]]$idOutput <<- atts[["variable"]]
                    if (name == "reaction")
                    {
                        lstnames <- names(atts)
                        numitems <- length(lstnames)
                        nameslist <- list()
                        id <- "x"
                        reverse <- FALSE
                        name <- "x"
                        count <- 1
                        while (count <= numitems)
                        {
                            switch(
                                lstnames[[count]],
                                "id" = {
                                    id = atts[[count]]
                                    nameslist[[length(nameslist) + 1]] <- "id"
                                },
                                "reversible" = {
                                    reverse = as.logical(atts[[count]])
                                    nameslist[[length(nameslist) + 1]] <- "reversible"
                                },
                                "name" = {
                                    name = as.character(atts[[count]])
                                    nameslist[[length(nameslist) + 1]] <- "name"
                                }
                            )
                            count <- count + 1
                        }
                        reactions[[atts["id"]]]$id <<- id
                        reactions[[atts["id"]]]$reversible <<- reverse
                        currRxnID <<- atts["id"]
                    }
                    
                    
                    if (name == "listOfReactants")
                        reactant <<- TRUE
                    if (name == "listOfProducts")
                        product <<- TRUE
                    if (name == "kineticLaw")
                        law <<- TRUE
                    if (name == "math")
                        math <<- TRUE
                    if ((name == "speciesReference") & reactant) {
                        reactants <<- addSpecies(reactants, atts)
                    }
                    if ((name == "speciesReference") & product) {
                        products <<- addSpecies(products, atts)
                    }
                    if (name == "modifierSpeciesReference") {
                        modifiers <<- addSpecies(modifiers, atts)
                    }
                    
                    if ((name == "parameter") & law) {
                        parameterIDs <<- c(parameterIDs, atts[["id"]])
                        parameters <<- c(parameters, atts[["value"]])
                    }
                    
                    if ((name == "parameter") & (!law)) {
                        globalParameterIDs <<- c(globalParameterIDs, atts[["id"]])
                        globalParameters <<-
                            c(globalParameters, as.numeric(atts[["value"]]))
                    }
                    
        } # end .startElement()
        
        .endElement <- function(name) {
            if (name == "listOfReactants")
                reactant <<- FALSE
            if (name == "listOfProducts")
                product <<- FALSE
            if (name == "kineticLaw")
                law <<- FALSE
            if (name == "math")
                math <<- FALSE
            if ((name == "listOfParameters") &
                (!law))
                names(globalParameters) <<- globalParameterIDs
            if (name == "reaction")  {
                names(reactants) <<- NULL
                names(modifiers) <<- NULL
                names(products) <<- NULL
                reactions[[currRxnID]]$reactants <<- reactants
                reactions[[currRxnID]]$modifiers <<- modifiers
                reactions[[currRxnID]]$products <<- products
                parameters <<- as.numeric(parameters)
                names(parameters) <<- parameterIDs
                reactions[[currRxnID]]$parameters <<- parameters
                reactants <<- NULL
                products <<- NULL
                modifiers <<- NULL
                parameters <<- NULL
                parameterIDs <<- NULL
            }
        }
        
        .text <- function(x, ...) {
            if (!math)
                lnotes <<- c(lnotes, x)
            #  cat("Txt:", x,"\n")
        }
        
        addSpecies <- function(my_list, atts) {
            species = atts['species']
            if ('stoichiometry' %in% names(atts)) {
                stoich = atts['stoichiometry']
                my_list = c(my_list, rep(species, stoich))
                names(my_list) = rep('species', length(my_list))
                return(my_list)
            } else {
                return(c(my_list, species))
            }
        }
        
        getModel <- function()
        {
            #  VV replaces fixComps with the following:
            fixComps = function(x)
            {
                lstnames <- names(x)
                count <- 1
                numit <- length(lstnames)
                id <- "x"
                size <- 0
                name <- "x"
                nameslist <- list()
                while (count <= numit)
                {
                    switch(
                        lstnames[[count]],
                        "id" = {
                            id = x[[count]]
                            nameslist[[length(nameslist) + 1]] <- "id"
                        },
                        "size" = {
                            size = as.numeric(x[[count]])
                            nameslist[[length(nameslist) + 1]] <- "size"
                        },
                        "name" = {
                            name = as.character(x[[count]])
                            nameslist[[length(nameslist) + 1]] <- "name"
                        }
                    )
                    count = count + 1
                }
                
                if (numit == 2)
                    # only 2 attributes present. We need to find them.
                {
                    if (id == "x")
                        #id not set but name and size are.
                        id <- "default"
                    else if (name == "x")
                        #name not set, we copy the id.
                        name <- id
                    else if (size == "0")
                        #size not set
                        size <- 1 	#arbitrary setting as 1
                    lst = list(id, size, name)
                    names(lst) <- c("id", "size", "name")
                    lst
                } else if (numit == 3)
                    # 3 attributes/items present.
                {
                    lst = list(id, size, name)
                    names(lst) <- c("id", "size", "name")
                    lst
                }
            }
            
            #  VV replaces fixSpecies with the following
            fixSpecies = function(x)
            {
                #cat (names(x), "\n")
                #cat(toString(x) , "\n")
                numitems <- length(x)
                lstnames <- names(x)
                count <- 1
                id <- "x"			#species Id
                ic <- 0				#species initial concentration
                compart <- "def"		#species compartment
                bc <- FALSE			#species boundary condition
                name <- "def"
                nameslist <- list()
                while (count <= numitems)
                {
                    switch(
                        lstnames[[count]],
                        "id" = {
                            id <- x[[count]]
                            nameslist[[length(nameslist) + 1]] <- "id"
                        },
                        "name" = {
                            name <- x[[count]]
                            nameslist[[length(nameslist) + 1]] <- "name"
                        },
                        "initialConcentration" = {
                            ic <-
                                as.numeric(x[[count]])
                            nameslist[[length(nameslist) + 1]] <- "ic"
                        },
                        "compartment" = {
                            compart <-
                                as.character(x[[count]])
                            nameslist[[length(nameslist) + 1]] <- "compartment"
                        },
                        "boundaryCondition" = {
                            bc <-
                                as.logical(x[[count]])
                            nameslist[[length(nameslist) + 1]] <- "bc"
                        }
                    )
                    count = count + 1
                }
                #lst = list(id,ic,compart,bc, name)
                lst = list(id, as.numeric(ic), compart, as.logical(bc))
                names(lst) <- c("id", "ic", "compartment", "bc")
                #names(lst)<-c("id","ic","compartment","bc", "name");
                lst
            }
            
            # and VV adds in fixParams
            fixParams = function(x)
            {
                numitems <- length(x)
                lstnames <- names(x)
                count <- 1
                id <- "x"			#Parameter Id
                value <- 0			#Parameter value
                name <- "def"
                constant <- FALSE
                nameslist <- list()
                while (count <= numitems)
                {
                    switch(
                        lstnames[[count]],
                        "id" = {
                            id <- x[[count]]
                            nameslist[[length(nameslist) + 1]] <- "id"
                        },
                        "name" = {
                            name <- x[[count]]
                            nameslist[[length(nameslist) + 1]] <- "name"
                        },
                        "value" = {
                            value <-
                                as.numeric(x[[count]])
                            nameslist[[length(nameslist) + 1]] <- "value"
                        },
                        "constant" = {
                            constant <-
                                as.logical(x[[count]])
                            nameslist[[length(nameslist) + 1]] <- "constant"
                        }
                    )
                    count = count + 1
                }
                
                lst = list(id, as.numeric(value))
                names(lst) <- c("id", "value")
                lst
            }
            
            compartments = sapply(compartments, fixComps, simplify = FALSE)
            species = sapply(species, fixSpecies, simplify = FALSE)     # this keeps the better looks in the SBMLR model definition file
            
            list(
                sbml = sbml,
                id = modelid[[1]],
                notes = lnotes,
                compartments = compartments,
                # TR may revert to this??
                species = species,
                globalParameters = globalParameters,
                rules = rules,
                reactions = reactions
            ) # returns values accrued in parent env
        }
        
        list(
            .startElement = .startElement,
            .endElement = .endElement,
            .text = .text,
            # , dom = function() {con}
            getModel = getModel
        ) # function returns a list of functions, each with a common parent environment = stuff before function definitions
    }
    
    #  END handler definition
    
    # *********************************************************************************
    # The next block of three functions converts mathML XMLnode objects into R expression objects
    # This approach is better than the old read.SBML approach in that the parenthesis overkill is avoided!
    mathml2R <- function(node)  {
        UseMethod("mathml2R", node)
    }
    
    mathml2R.XMLDocument <-
        function(doc) {
            return(mathml2R(doc$doc$children))
        }
    
    mathml2R.default <- function(children)
    {
        expr <-
            expression()  # this gets used when a "list" of children nodes are sent in
        n = length(children)
        for (i in 1:n)
            expr = c(expr, mathml2R(children[[i]]))
        if (n > 3) {
            #print("n>3")  # this fixes libsbml problem that times is not binary
            if (expr[[1]] == "*")
                expr[[1]] = as.name("prod") # in R, prod takes arb # of args
            if (expr[[1]] == "+")
                expr[[1]] = as.name("sum")  # similary for sum
        }
        return(expr)
    }
    
    mathml2R.XMLNode <- function(node) {
        nm <- xmlName(node)
        if (nm == "power" ||
            nm == "divide" || nm == "times" || nm == "plus" || nm == "minus") {
            op <- switch(
                nm,
                power = "^",
                divide = "/",
                times = "*",
                plus = "+",
                minus = "-"
            )
            val <- as.name(op)
        } else if ((nm == "ci") | (nm == "cn")) {
            if (nm == "ci")
                val <- as.name(node$children[[1]]$value)
            if (nm == "cn")
                val <- as.numeric(node$children[[1]]$value)
        }  else if (nm == "apply") {
            val <- mathml2R(node$children)
            mode(val) <- "call"
        } else  {
            cat("error: nm =", nm, " not in set!\n")
        }
        return(as.expression(val))
    }
    # ********** END the mathML2R block of method based on node type codes  *************************
    
    if (!require(XML))
        print(
            "Error in Read.SBML(): First Install the XML package http://www.omegahat.org/RSXML"
        )
    
    edoc <-
        xmlEventParse(filename, handlers = sbmlHandler(), ignoreBlanks = TRUE)
    model = edoc$getModel() # SAX approach using the handler. Output of getModel() in edoc list is what we want.
    doc <-
        xmlTreeParse(filename, ignoreBlanks = TRUE)  # use DOM just for rules and reactions
    model$htmlNotes = doc$doc$children$sbml[["model"]][["notes"]]
    rules = doc$doc$children$sbml[["model"]][["listOfRules"]]
    reactions = doc$doc$children$sbml[["model"]][["listOfReactions"]]
    
    globalParameters = names(model$globalParameters)
    
    nRules = length(rules)
    if (nRules > 0) {
        for (i in 1:nRules)
            #  for( i in 1:(nRules-1))   # VV stops 1 shy of end????
        {
            # assume they are assignment rules
            mathml <- rules[[i]][["math"]][[1]]
            model$rules[[i]]$mathmlLaw = mathml
            e <- mathml2R(mathml)
            model$rules[[i]]$exprLaw <- e[[1]]
            model$rules[[i]]$strLaw <- gsub(" ", "", toString(e[1]))
            leaves <- getRuleLeaves(mathml)
            r <-
                model$rules[[i]]$inputs <-
                setdiff(leaves, globalParameters) # must deduce inputs by substracting global params
            model$rules[[i]]$law = makeLaw(r, NULL, model$rules[[i]]$exprLaw)
        }
    }
    
    nReactions = length(reactions)
    if (nReactions > 0) {
        #    rIDs=NULL;
        for (i in 1:nReactions)
        {
            model$reactions[[i]]$mathmlLaw = reactions[[i]][["kineticLaw"]][["math"]][[1]]
            e = mathml2R(reactions[[i]][["kineticLaw"]][["math"]][[1]])
            model$reactions[[i]]$exprLaw = e[[1]]
            model$reactions[[i]]$strLaw = gsub(" ", "", toString(e[1]))
            r = model$reactions[[i]]$reactants
            p = names(model$reactions[[i]]$parameters)
            m = model$reactions[[i]]$modifiers
            e = model$reactions[[i]]$exprLaw
            model$reactions[[i]]$law = makeLaw(c(r, m), p, e)
        }
    }
    
    class(model) <- "SBMLR"
    model
}

# the following is called by both readSBML and readSBMLR so it outside where both can reach it.
# Note that keeing it here instead of in a separate file => no need to document it
"makeLaw" <- function(r, p, e) {
    # takes reactant list r, parameter list p and rate law R expression e
    # and makes a reaction rate law function out of them.
    lawTempl = function(r, p = NULL) {
        
    }
    i = 2
    for (j in seq(along = p)) {
        body(lawTempl)[[i]] <-
            call("=", as.name(p[j]), call("[", as.name("p"), p[j]))
        i = i + 1
    }
    for (j in seq(along = r)) {
        body(lawTempl)[[i]] <-
            call("=", as.name(r[j]), call("[", as.name("r"), r[j]))
        i = i + 1
    }
    body(lawTempl)[[i]] <- e
    lawTempl
}

# The next two functions are used by rules and were taken straight from read.SBML
# The idea is that SBML doesn't provide a list of atoms/leaves with rules, so we have to create them
# to place them in their model slots, and to use them to create the R function definition for the rule
# using makeLaw with a null for parameters, since they are passed global for rules.
ML2R <- function(type)
    # map MathML operator symbols into R symbols
    switch(
        type,
        "times" = "*",
        "divide" = "/",
        "plus" = "+",
        "minus" = "-",
        "power" = "^",
        "exp" = "exp",
        "ln" = "log",
        "not found"
    ) # end definition of ML2R


getRuleLeaves <- function(math)
{
    n = length(math)
    S = c(NULL)
    op = ML2R(xmlName(math[[1]]))
    for (j in 2:n)
        if ((xmlName(math[[j]]) == "ci") |
            (xmlName(math[[j]]) == "cn"))
            S = c(S, as.character(xmlValue(math[[j]])))
    else
        S = c(S, Recall(math[[j]]))
    S
}

"summary.SBMLR" <- function(object, ...)
{
    model = object
    sIDs = names(model$species)
    rIDs = names(model$reactions)
    ruleIDs = names(model$rules)
    nReactions = length(model$reactions)
    nSpecies = length(model$species)
    nRules = length(model$rules)
    
    # Species
    S0 = NULL
    BC = NULL # initialize
    for (i in 1:nSpecies) {
        BC[i] = model$species[[i]]$bc
        
        S0[i] = model$species[[i]]$ic
    }
    names(S0) <- sIDs
    names(BC) <- sIDs
    y0 = S0[BC == FALSE]
    nStates = length(y0)
    globals = model$globalParameters
    
    param_env = list2env(model$globalParameters)
    
    # Reactions
    rLaws = NULL
    V0 = NULL # initialize
    for (j in 1:nReactions) {
        rLaws[j] <-
            model$reactions[[j]]$strLaw  	#this gives you null which is wrong
        r = S0[c(
            model$reactions[[j]]$reactants,
            model$reactions[[j]]$modifiers,
            model$reactions[[j]]$products
        )]
        p = model$reactions[[j]]$parameters
        f = model$reactions[[j]]$law
        work_env = environment(f)
        appendEnv(work_env, param_env) # appends global parameters into work_env
        V0[j] = f(r, p)
    }
    names(rLaws) <- rIDs
    names(V0) <- rIDs
    
    # Incidence Matrix
    incid = matrix(rep(0, nStates * nReactions), nrow = nStates)
    indx = (1:nSpecies)[BC == FALSE]
    for (i in 1:nStates)
        for (j in 1:nReactions)
        {
            if (is.element(model$species[[indx[i]]]$id, model$reactions[[j]]$products))
                incid[i, j] = summary(factor(model$reactions[[j]]$products))[[model$species[[indx[i]]]$id]]
            if (is.element(model$species[[indx[i]]]$id, model$reactions[[j]]$reactants))
                incid[i, j] = incid[i, j] - summary(factor(model$reactions[[j]]$reactants))[[model$species[[indx[i]]]$id]]
        }
    rownames(incid) <- names(y0)
    
    # return a list of model information
    options(stringsAsFactors = FALSE)
    DFs = data.frame(
        index = 1:nSpecies,
        initialConcentrations = S0,
        boundaryConditions = BC
    )
    row.names(DFs) <- sIDs
    DFr = data.frame(
        index = 1:nReactions,
        Laws = rLaws,
        initialFluxes = V0
    )
    row.names(DFr) <- rIDs
    list(
        nSpecies = nSpecies,
        sIDs = sIDs,
        S0 = S0,
        BC = BC,
        nStates = nStates,
        y0 = y0,
        nReactions = nReactions,
        rIDs = rIDs,
        rLaws = rLaws,
        V0 = V0,
        globalVec = unlist(globals),
        # P0, VP,
        incid = incid,
        nRules = nRules,
        ruleIDs = ruleIDs,
        species = DFs,
        reactions = DFr
    )
}

# https://stackoverflow.com/questions/26057400/r-how-do-you-merge-combine-two-environments
appendEnv = function(e1, e2) {
    e1name = deparse(substitute(e1))
    e2name = deparse(substitute(e2))
    listE1 = ls(e1)
    listE2 = ls(e2)
    for (v in listE2) {
        # if(v %in% listE1) warning(sprintf("Variable %s is in e1, too!", v))
        e1[[v]] = e2[[v]]
    }
}