shiny::shinyUI(fluidPage(

    shinyjs::useShinyjs(),

    # Application title
    # titlePanel(title=div(img(src="logo.png"), "Gradient Matching for ODE Inference")),
    shiny::titlePanel("Gradient Matching for ODE Inference"),

    shiny::fluidRow(

        shiny::column(3,
               shiny::h4("Define Model"),
               shiny::helpText("You can select from the list of predefined models or upload your own model in SBML. Uploading SBML instead of selecting a predefined model will use numerical gradients."),
               shiny::selectInput("selected_model", "Select a predefined model", modelChoices),
               shiny::fileInput("sbml_file", "Or upload an SBML model",
                         accept = c(
                             "application/octet-stream",
                             "binary/hdf5",
                             ".hdf5")
               ),
               shiny::helpText(a("Download SBML Editor", href="http://www.ebi.ac.uk/compneur-srv/SBMLeditor.html", target="_blank")),
               shiny::tags$hr(),
               shiny::h4("Load Data"),
               shiny::helpText(("Data should be in a CSV format with column headers. The first column is header is 'time', while other column headers are the individual states.")),
               shinyjs::disabled(
                   shiny::fileInput("csv_file", "Choose a CSV File",
                             accept = c(
                                 "application/octet-stream",
                                 "binary/hdf5",
                                 ".hdf5")
                   )
               ),
               shiny::h4("Generate Data"),
               shiny::helpText(("Specify the start time, end time and every n-th time points to pick.")),
               shiny::fluidRow(
                   shiny::column(4, numericInput("time_points_min", "Start", value=0, min=0, max=NA, step=1)),
                   shiny::column(4, numericInput("time_points_max", "End", value=10, min=0, max=NA, step=1)),
                   shiny::column(4, numericInput("time_points_pick", "Pick", value=1, min=1, max=NA, step=1))
               ),
               shiny::fluidRow(
                   shiny::column(8, numericInput("noise", "Noise", value=0.1, min=0, max=NA, step=0.1)),
                   shiny::column(4, radioButtons("noise_unit", '', c(
                       "Variance"="var",
                       "dB"="db"
                   ), inline=F))
               ),
               shinyjs::disabled(
                   shiny::actionButton("generateBtn", "Generate")
               ),
        style="overflow-x: scroll; overflow-y: scroll"),

        shiny::column(9,
           shiny::tabsetPanel(id = "inTabset",
               shiny::tabPanel(title="Inference",
                        value="inference",
                        shiny::column(3, offset = 1,
                               shiny::h5("ODE Parameters"),
                               shiny::verbatimTextOutput("odeParameters", placeholder = TRUE),
                               shiny::helpText(("Specify the starting values of parameters.")),
                               shiny::tags$div(id = 'placeholderParams'),
                               shiny::tags$br()
                        ),
                        shiny::column(3, offset = 1,
                               shiny::h5("System States"),
                               shiny::verbatimTextOutput("systemStates", placeholder = TRUE),
                               shiny::tags$div(id = 'placeholderStates'),
                               shiny::selectInput('ktype', "Kernel", kernelChoices),
                               shiny::numericInput('eps', 'Standard deviation of period', value=1, min=0, max=NA, step=0.1),
                               shiny::helpText("If warping is selected, the guess periods and the standard deviation of period will be used.")
                        ),
                        shiny::column(3, offset = 1,
                           shiny::h5("Run Inference"),
                           shiny::radioButtons("ode_reg", "ODE Regularisation", c(
                               "Off"="off",
                               "On"="on"
                           ), inline=F),
                           shiny::radioButtons("warping", "Warping", c(
                               "Off"="off",
                               "On"="on"
                           ), inline=F),
                           shinyjs::disabled(
                               shiny::actionButton("inferBtn", "Infer")
                           )
                        )
               ),
               shiny::tabPanel(title="Results",
                        value="results",
                        shiny::h5("Plots"),
                        shiny::plotOutput('generateDataPlot'),
                        shiny::conditionalPanel(
                            condition = "input.plot_ode == 'initial'",
                            shiny::plotOutput('interpPlotInitial')
                        ),
                        shiny::conditionalPanel(
                            condition = "input.plot_ode == 'inferred'",
                            shiny::plotOutput('interpPlotInferred')
                        ),
                        shinyjs::hidden(
                            radioButtons("plot_ode", "Plot solved ODE using", c(
                                "Initial parameters"="initial",
                                "Inferred parameters"="inferred"
                            ), inline=T)
                        ),
                        shiny::conditionalPanel(
                            condition = "input.plot_ode == 'initial'",
                            shiny::tableOutput('initialParams')
                        ),
                        shiny::conditionalPanel(
                            condition = "input.plot_ode == 'inferred'",
                            shiny::tableOutput('inferredParams')
                        ),
                        shiny::h5("Downloads"),
                        shinyjs::hidden(
                            shiny::downloadButton('downloadDataBtn', 'Download Data')
                        ),
                        shinyjs::hidden(
                            shiny::downloadButton('downloadParamsBtn', 'Download Inferred Parameters')
                        )
               ),
               shiny::tabPanel(title="Diagnostics",
                        value="diagnostics",
                        shiny::h5("Objectives"),
                        shinyjs::hidden(
                            shiny::plotOutput('diagnosticPlot')
                        ),
                        shinyjs::hidden(
                            shiny::conditionalPanel(
                                condition = "input.warping == 'on'",
                                shiny::h5("Warping"),
                                shiny::plotOutput('warpingPlot')
                            )
                        ),
                        shiny::h5("Console log"),
                        shinyjs::hidden(
                            shiny::verbatimTextOutput("console")
                        )
               ),
               shiny::tabPanel(title="Advanced Parameters",
                        value="advanced",
                        shiny::numericInput("seed", "Seed", value=SEED, min=-1, max=NA, step=1)
               )
           )
        )

    ) # end fluidRow

))
