#' Start ShinyGradmatch
#' @title This function will start ShinyGradmatch
#' @return Nothing
#' @description An interactive Shiny application for running gradient matching to approximate ODEs.
#' @details This starts the ShinyGradmatch application on the users local computer. 
#' @keywords ShinyGradmatch
#' @examples
#' \dontrun{
#' startShinyGradmatch()
#' }
#' @export
startShinyGradmatch <- function() {
  shiny::runApp(appDir = system.file("application", package='shinygradmatch'))
}