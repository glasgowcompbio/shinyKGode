shiny::shinyUI(fluidPage(
    shinyjs::useShinyjs(),
    
    # Application title
    # titlePanel(title=div(img(src="logo.png"), "Gradient Matching for ODE Inference")),
    shiny::titlePanel("Gradient Matching for ODE Inference"),
    
    shiny::fluidRow(shiny::column(
        12,
        shiny::tabsetPanel(
            id = "inTabset",
            shiny::tabPanel(
                title = "Model",
                value = "model",
                shiny::column(
                    3,
                    shiny::h3("Define Model"),
                    shiny::helpText(
                        "You can select from the list of predefined models or upload your own model in SBML. Uploading SBML instead of selecting a predefined model will use numerical gradients."
                    ),
                    shiny::selectInput("selected_model", "Select a predefined model", modelChoices),
                    shiny::fileInput(
                        "sbml_file",
                        "Or upload an SBML model",
                        accept = c("application/octet-stream",
                                   "binary/hdf5",
                                   ".hdf5")
                    ),
                    shiny::helpText(
                        a("Download SBML Editor", href = "http://www.ebi.ac.uk/compneur-srv/SBMLeditor.html", target =
                              "_blank")
                    ),
                    shiny::hr(),
                    shiny::h3("Load Data"),
                    shiny::helpText((
                        "Data should be in a CSV format with column headers. The first column header is 'time', while other column headers are the individual states."
                    )
                    ),
                    shinyjs::disabled(shiny::fileInput(
                        "csv_file",
                        "Choose a CSV File",
                        accept = c("application/octet-stream",
                                   "binary/hdf5",
                                   ".hdf5")
                    ))
                ),
                shiny::column(
                    3,
                    shiny::h3("Generate Data"),
                    shiny::helpText(
                        "Specify the start & end times, the n-th time points to pick and the noise level when generated data."
                    ),
                    shiny::fluidRow(
                        shiny::column(
                            4,
                            numericInput(
                                "time_points_min",
                                "Start",
                                value = 0,
                                min = 0,
                                max = NA,
                                step = 1
                            )
                        ),
                        shiny::column(
                            4,
                            numericInput(
                                "time_points_max",
                                "End",
                                value = 10,
                                min = 0,
                                max = NA,
                                step = 1
                            )
                        ),
                        shiny::column(
                            4,
                            numericInput(
                                "time_points_pick",
                                "Pick",
                                value = 1,
                                min = 1,
                                max = NA,
                                step = 1
                            )
                        )
                    ),
                    shiny::fluidRow(
                        shiny::column(
                            8,
                            numericInput(
                                "noise",
                                "Noise",
                                value = 0.1,
                                min = 0,
                                max = NA,
                                step = 0.1
                            )
                        ),
                        shiny::column(4, radioButtons(
                            "noise_unit", '', c("Variance" = "var",
                                                "dB" = "db"), inline = F
                        ))
                    ),
                    shiny::hr(),
                    shiny::h5("ODE Parameters"),
                    shiny::helpText(
                        "Specify the parameter values when generating data."
                    ),
                    # shiny::verbatimTextOutput("generateParamsTextOutput", placeholder = TRUE),
                    shiny::tags$div(id = 'generateParams'),
                    shiny::hr(),
                    shiny::h5("System States"),
                    shiny::helpText(
                        "Specify the initial system states when generating data."
                    ),
                    # shiny::verbatimTextOutput("generateStatesTextOutput", placeholder = TRUE),
                    shiny::tags$div(id = 'generateStates'),
                    shiny::hr(),
                    shinyjs::disabled(shiny::actionButton("generateBtn", "Generate"))
                ),
                shiny::column(
                    6,
                    shiny::h3("Loaded/Generated Data"),
                    shiny::plotOutput('generateDataPlot', height='auto'),
                    shinyjs::hidden(shiny::downloadButton('downloadDataBtn', 'Download Data'))
                )
            ),
            shiny::tabPanel(
                title = "Inference",
                value = "inference",
                shiny::column(
                    3,
                    shiny::h3("Inference Parameters"),
                    shiny::helpText(
                        "Specify the kernel, the random seed, 
                        the number of bootstrap replicates (to estimate parameter uncertainty),
                        whether to use ODE regularisation, and the initial parameters for optimisation during inference."
                    ),
                    shiny::selectInput('ktype', "Kernel", kernelChoices),
                    shiny::numericInput(
                        "seed",
                        "Random Seed",
                        value = SEED,
                        min = -1,
                        max = NA,
                        step = 1
                    ),
                    shiny::numericInput(
                        "K",
                        "No. of Bootstrap Replicates",
                        value = 0,
                        min = 0,
                        max = NA,
                        step = 1
                    ),
                    shiny::radioButtons(
                        "ode_reg",
                        "ODE Regularisation",
                        c("Off" = "off",
                          "On" = "on"),
                        inline = T
                    ),
                    shiny::br(),
                    shiny::h5('Initial Parameters for Optimisation'),
                    # shiny::verbatimTextOutput("optimisationParamsTextOutput", placeholder = TRUE),
                    shiny::tags$div(id = 'optimisationParams')
                ),
                shiny::column(
                    3,
                    shiny::h3("Warping Options"),
                    shiny::helpText(
                        "If warping is turned on, the guessing periods and the standard deviation of period will be used."
                    ),
                    shiny::radioButtons("warping", "Warping", c("Off" =
                                                                    "off",
                                                                "On" = "on"), inline = T),
                    shiny::h5('Guessing periods for warping'),
                    # shiny::verbatimTextOutput("warpingPeriodsTextOutput", placeholder = TRUE),
                    shiny::tags$div(id = 'warpingPeriods'),
                    shiny::br(),
                    shiny::numericInput(
                        'eps',
                        'Standard deviation of period',
                        value = 1,
                        min = 0,
                        max = NA,
                        step = 0.1
                    ),
                    shiny::hr(),
                    shinyjs::disabled(shiny::actionButton("inferBtn", "Infer"))
                ),
                shiny::column(
                    6,
                    shiny::h3("Results"),
                    shiny::verbatimTextOutput("methodTextOutput"),
                    # show the initial parameter plot
                    shiny::conditionalPanel(condition = "input.plot_ode_initial && !input.plot_ode_inferred",
                                            shiny::plotOutput('interpPlotInitial', height='auto')),
                    # show the inferred parameter plot
                    shiny::conditionalPanel(condition = "!input.plot_ode_initial && input.plot_ode_inferred",
                                            shiny::plotOutput('interpPlotInferred', height='auto')),
                    # show the combined plot
                    shiny::conditionalPanel(condition = "input.plot_ode_initial && input.plot_ode_inferred",
                                            shiny::plotOutput('interpPlotInitialInferred', height='auto')),
                    shinyjs::hidden(
                        shiny::tags$div(id="plot_ode",
                            shiny::h5('Plot solved ODE using'),
                            shiny::checkboxInput(
                               "plot_ode_inferred", 
                               "Inferred parameters", 
                               TRUE
                            ),
                            shiny::checkboxInput(
                               "plot_ode_initial", 
                               "True parameters", 
                               FALSE
                            )
                        )
                    ),
                    shiny::hr(),
                    shiny::h5('ODE parameters'),
                    shiny::conditionalPanel(condition = "input.plot_ode_initial && !input.plot_ode_inferred",
                                            shiny::tableOutput('initialParams')
                    ),
                    shiny::conditionalPanel(condition = "!input.plot_ode_initial && input.plot_ode_inferred",
                                            shiny::tableOutput('inferredParams')
                    ),
                    shiny::conditionalPanel(condition = "input.plot_ode_initial && input.plot_ode_inferred",
                                            shiny::tableOutput('initialInferredParams')
                    ),
                    shiny::conditionalPanel(condition = "input.plot_ode_inferred",
                                            shiny::downloadButton('downloadParamsBtn', 'Download Inferred Parameters')
                    )                    
                )
            ),
            shiny::tabPanel(
                title = "Diagnostics",
                value = "diagnostics",
                shiny::h5("Objectives"),
                shinyjs::hidden(shiny::plotOutput('diagnosticPlot')),
                shiny::conditionalPanel(
                    condition = "input.warping == 'on'",
                    shiny::h5("Warping"),
                    shiny::plotOutput('warpingPlot', height='auto')
                ),
                shiny::h5("Console log"),
                shinyjs::hidden(shiny::verbatimTextOutput("console"))
            )
        )
    )) # end fluidRow
    
))
