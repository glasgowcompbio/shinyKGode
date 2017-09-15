startShinyGradmatch <- function(x, ...)
{
  shiny::runApp(appDir = system.file("application", package='shinygradmatch'),
                ...)
}