run_app <- function(x, ...)
{
  shiny::runApp(appDir = system.file("application", package='shinygradmatch'),
                ...)
}