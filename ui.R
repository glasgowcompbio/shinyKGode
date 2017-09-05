library(shiny)
library(shinyjs)

kernelChoices = c("rbf"="rbf", "mlp"="mlp")
modelChoices = c("---" = "",
                 "Lotka-Volterra" = "lv",
                 "Fiz hugh Nagumo" = "fhg",
                 "Biopathway" = "bp")

shinyUI(fluidPage(
    
    useShinyjs(),
    
    # Application title
    # titlePanel(title=div(img(src="logo.png"), "Gradient Matching for ODE Inference")),
    titlePanel("Gradient Matching for ODE Inference"),
    
    fluidRow(

        column(3,
               h4("Define Model"),
               helpText("You can select from the list of predefined models or upload your own model in SBML. Uploading SBML instead of selecting a predefined model will use numerical gradients."),
               selectInput("selected_model", "Select a predefined model", modelChoices),               
               fileInput("sbml_file", "Or upload an SBML model",
                         accept = c(
                             "application/octet-stream",
                             "binary/hdf5",
                             ".hdf5")
               ),        
               helpText(a("Download SBML Editor", href="http://www.ebi.ac.uk/compneur-srv/SBMLeditor.html", target="_blank")),
               tags$hr(),
               h4("Load Data"),
               helpText(("Data should be in a CSV format with column headers. The first column is header is 'time', while other column headers are the individual states.")),
               shinyjs::disabled(
                   fileInput("csv_file", "Choose a CSV File",
                             accept = c(
                                 "application/octet-stream",
                                 "binary/hdf5",
                                 ".hdf5")
                   )
               ),
               h4("Generate Data"),
               helpText(("Specify the start time, end time and every n-th time points to pick.")),
               fluidRow(
                   column(4, numericInput("timePointsMin", "Start", value=0, min=0, max=NA, step=1)),
                   column(4, numericInput("timePointsMax", "End", value=10, min=0, max=NA, step=1)),
                   column(4, numericInput("timePointsPick", "Pick", value=1, min=1, max=NA, step=1))
               ),
               fluidRow(
                   column(6, numericInput("noise", "Noise", value=0.1, min=0, max=NA, step=0.1)),
                   column(6, radioButtons("noise_unit", '', c(
                       "Variance"="var",
                       "dB"="db"
                   ), inline=F))
               ),
               shinyjs::disabled(
                   actionButton("generateBtn", "Generate")
               ),
        style="overflow-x: scroll; overflow-y: scroll"),

        column(9,
           tabsetPanel(id = "inTabset",
               tabPanel(title="Inference",
                        value="inference",
                        column(3, offset = 1,
                               h5("ODE Parameters"),
                               verbatimTextOutput("odeParameters", placeholder = TRUE),
                               helpText(("Specify the starting values of parameters.")),
                               tags$div(id = 'placeholderParams'),
                               tags$br()
                        ),
                        column(3, offset = 1,
                               h5("System States"),
                               verbatimTextOutput("systemStates", placeholder = TRUE),
                               tags$div(id = 'placeholderStates'),
                               selectInput('ktype', "Kernel", kernelChoices),                               
                               numericInput('eps', 'Standard deviation of period', value=1, min=0, max=NA, step=0.1),
                               helpText("If warping is selected, the guess periods and the standard deviation of period will be used.")
                        ),
                        column(3, offset = 1,
                           h5("Run Inference"),
                           radioButtons("ode_reg", "ODE Regularisation", c(
                               "Off"="off",
                               "On"="on"
                           ), inline=F),
                           radioButtons("warping", "Warping", c(
                               "Off"="off",
                               "On"="on"
                           ), inline=F),
                           shinyjs::disabled(
                               actionButton("inferBtn", "Infer")
                           )
                        )
               ),
               tabPanel(title="Results",
                        value="results",
                        h5("Plots"),
                        # verbatimTextOutput('resultsType'),
                        plotOutput('generateDataPlot'),
                        conditionalPanel(
                            condition = "input.plot_ode == 'initial'",  
                            plotOutput('interpPlotInitial')
                        ),
                        conditionalPanel(
                            condition = "input.plot_ode == 'inferred'",  
                            plotOutput('interpPlotInferred')
                        ),
                        shinyjs::hidden(
                            radioButtons("plot_ode", "Plot solved ODE using", c(
                                "Initial parameters"="initial",
                                "Inferred parameters"="inferred"
                            ), inline=T)
                        ),
                        conditionalPanel(
                            condition = "input.plot_ode == 'initial'",  
                            tableOutput('initialParams')
                        ),
                        conditionalPanel(
                            condition = "input.plot_ode == 'inferred'",  
                            tableOutput('inferredParams')
                        ),
                        h5("Downloads"),
                        shinyjs::hidden(
                            downloadButton('downloadDataBtn', 'Download Data')
                        ),
                        shinyjs::hidden(
                            downloadButton('downloadParamsBtn', 'Download Inferred Parameters')
                        )
               ),
               tabPanel(title="Diagnostics",
                        value="diagnostics",
                        h5("Objectives"),
                        plotOutput('diagnosticPlot'),
                        conditionalPanel(
                            condition = "input.warping == 'on'",  
                            h5("Warping"),
                            plotOutput('warpingPlot')
                        ),
                        h5("Console log"),
                        verbatimTextOutput("console")
               ),
               tabPanel(title="Advanced Parameters",
                        value="advanced",
                        numericInput("seed", "Seed", value=19537, min=-1, max=NA, step=1)
               )
           )               
        )
        
    ) # end fluidRow
    
))
