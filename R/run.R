start_shiny_gradmatch <- function(x, ...)
{
  shiny::runApp(appDir = system.file("application", package='shinygradmatch'),
                ...)
}