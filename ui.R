library(shiny)
library(shinyjs)

kernelChoices = c("rbf"="rbf", "mlp"="mlp")
modelChoices = c("---" = "",
                 "Lotka-Volterra" = "lv",
                 "Fiz hugh nagumo" = "fhg",
                 "Biopathway" = "bp")

shinyUI(fluidPage(
    
    useShinyjs(),
    
    # Application title
    # titlePanel(title=div(img(src="logo.png"), "ODE Inference Tool")),
    titlePanel("ODE Inference Tool"),
    
    fluidRow(

        column(2,
               h4("Define Model"),
               selectInput("selected_model", "Select a predefined model", modelChoices),               
               fileInput("sbml_file", "Or upload an SBML model",
                         accept = c(
                             "application/octet-stream",
                             "binary/hdf5",
                             ".hdf5")
               ),        
               helpText("Uploading SBML instead of selecting a predefined model will use numerical gradients."),
               helpText(a("Download SBML Editor", href="http://www.ebi.ac.uk/compneur-srv/SBMLeditor.html", target="_blank")),
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
                   column(6, numericInput("timePointsMax", "Max", value=6, min=0, max=NA, step=1)),
                   column(6, numericInput("snr", "SNR", value=0.1, min=0, max=NA, step=0.1))
               ),
               # shinyjs::disabled(
               #    numericInput("timePointsStep", "Time Points (Step)", value=0, min=0, max=NA, step=1)
               # ),
               actionButton("generateBtn", "Generate"),               
        style="overflow-x: scroll; overflow-y: scroll"),

        column(10,
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
                        verbatimTextOutput('resultsType'),
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
                        plotOutput('diagnosticPlot'),
                        h5("Console log"),
                        verbatimTextOutput("console")
               )
           )               
        )
        
    ) # end fluidRow
    
))
