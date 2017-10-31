#' Start ShinyKGode
#' @title This function will start ShinyKGode
#' @return Nothing
#' @description An interactive Shiny application for running gradient matching to approximate ODEs.
#' @details This starts the ShinyKGode application on the users local computer.
#' @keywords ShinyKGode
#' @examples
#' \dontrun{
#' startShinyKGode()
#' }
#' @export
#' @import pracma pspline
startShinyKGode <- function() {
  shiny::runApp(appDir = system.file("application", package='shinyKGode'))
}