library(shiny)
library(shinyjs)

kernelChoices <- c("kernel1"="kernel1", "kernel2"="kernel2", "kernel3"="kernel3")

shinyUI(fluidPage(
    
    useShinyjs(),
    
    # Application title
    # titlePanel(title=div(img(src="logo.png"), "ODE Inference Tool")),
    titlePanel("ODE Inference Tool"),
    
    fluidRow(

        column(2,
               h4("Define Model"),
               selectInput("selected_model", "Select predefined models",
                           c("---" = "",
                               "Lotka-Volterra" = "lv",
                               "Fiz hugh nagumo" = "fhg",
                               "Biopathway" = "bp")),               
               fileInput("sbml_file", "Or you can upload your own model in SBML format",
                         accept = c(
                             "application/octet-stream",
                             "binary/hdf5",
                             ".hdf5")
               ),        
               tags$hr(),
               h4("Load Data"),
               fileInput("csv_file", "Choose a CSV File",
                         accept = c(
                             "application/octet-stream",
                             "binary/hdf5",
                             ".hdf5")
               ),
               tags$hr(),
               h4("Generate Data"),
               helpText(("Time Points.")),
               fluidRow(
                   column(6, numericInput("timePointsMin", "Min", value=0, min=0, max=NA, step=1)),
                   column(6, numericInput("timePointsMax", "Max", value=6, min=0, max=NA, step=1))
               ),
               fluidRow(
                   column(6, numericInput("noOfSamples", "Num. Replicates", value=1, min=0, max=NA, step=1)),
                   column(6, numericInput("snr", "SNR", value=0.1, min=0, max=NA, step=0.1))
               ),
               # shinyjs::disabled(
               #    numericInput("timePointsStep", "Time Points (Step)", value=0, min=0, max=NA, step=1)
               # ),
               actionButton("generateBtn", "Generate"),               
        style="overflow-x: scroll; overflow-y: scroll"),

        column(8,
           tabsetPanel(id = "inTabset",
               tabPanel(title="Inference",
                        value="inference",
                        column(4, offset = 1,
                               h5("ODE Parameters"),
                               verbatimTextOutput("odeParameters", placeholder = TRUE),
                               helpText(("Specify the starting values of parameters.")),
                               tags$div(id = 'placeholderParams'),
                               tags$br(),
                               radioButtons("method", "Method", c(
                                   "Gradient Matching"="gm", 
                                   "Gradient Matching + 3rd Step"="gm+3rd",
                                   "Warping"="warping",
                                   "3rd Step + Warping"="3rd+warping"
                               ), inline=F),
                               shinyjs::disabled(
                                   actionButton("inferBtn", "Infer")
                               )
                        ),
                        column(5, offset = 1,
                               h5("System States"),
                               verbatimTextOutput("systemStates", placeholder = TRUE),
                               helpText(("Specify the same kernel for all system states.")),
                               selectInput('statesAll', "Kernel", kernelChoices),                               
                               helpText(("Or specify different kernels for individual system states.")),
                               tags$div(id = 'placeholderStates'),
                               numericInput('eps', 'Standard deviation of period', value=1, min=0, max=NA, step=0.1),
                               helpText("If warping is enabled, the guessing periods and the standard deviation of period will be used.")
                        )
               ),
               tabPanel(title="Results",
                        value="results",
                        verbatimTextOutput("resultsType"),
                        plotOutput('resultsPlot'),
                        tableOutput('resultsTable'),
                        shinyjs::hidden(
                            downloadButton('downloadDataBtn', 'Download Generated Data')
                        ),
                        shinyjs::hidden(
                            downloadButton('downloadParamsBtn', 'Download Inferred Parameters')
                        )
               ),
               tabPanel(title="Diagnostics",
                        value="diagnostics",
                        tableOutput('table3')
               )
           )               
        )
        
    ) # end fluidRow
    
))
