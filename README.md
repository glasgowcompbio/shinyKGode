# ShinyKGode

Many processes in science and engineering can be described by dynamical systems based on nonlinear ordinary differential equations (ODEs). Often ODE parameters are unknown and not directly measurable. Since nonlinear ODEs typically have no closed form solution, standard iterative inference procedures  require a computationally expensive numerical integration of the ODEs every time the parameters are adapted, which in practice restricts statistical inference to very small systems. To overcome this computational bottleneck, approximate methods based on gradient matching have recently gained much attention.

In this package, we develop an easy-to-use application in Shiny to perform parameter inference on ODEs using gradient matching. The application, called `shinyKGode`, is built upon the [KGode](https://CRAN.R-project.org/package=KGode) package, which implements the kernel ridge regression and the gradient matching algorithm proposed in [Niu et al. (2016)](http://jmlr.org/proceedings/papers/v48/niu16.html) and the warping algorithm proposed in [Niu et al. (2017)](https://link.springer.com/article/10.1007%2Fs00180-017-0753-z) for parameter inference in differential equations. Advanced features such as ODE regularisation and warping can also be easily used for inference in the `shinyKGode` application.

`shinyKGode` has built-in support for the following three models described in [Niu et al. (2017)](https://link.springer.com/article/10.1007%2Fs00180-017-0753-z):
- [Lotka-Volterra](https://en.wikipedia.org/wiki/Lotka%E2%80%93Volterra_equations), which describes the dynamics of ecological
systems with predator-prey interactions.
-  [FitzHugh–Nagumo](https://en.wikipedia.org/wiki/FitzHugh%E2%80%93Nagumo_model)), which is a two-dimensional dynamical system used for modelling spike generation in axons.
- The Biopathway model described in [y Vyshemirsky and Girolami (2008)](https://academic.oup.com/bioinformatics/article/24/6/833/192524), which is a model for the interactions of five protein isoforms.

## Installation

The latest version of the `shinyKGode` package can be installed from this github repository using `devtools`:

```R
library(devtools)
install_github('joewandy/shinyKGode')
```

While the stable R package (under submission) can be installed from CRAN via `install.packages('shinyKGode')`.

## Running shinyKGode

Once installed, the application can be run by:

```R
library(shinyKGode)
startShinyKGode()
```

## Providing your own models

`shinyKGode` accepts user-defined models in SBML v2 format, allowing user-defined models specified in the [SBML](https://en.wikipedia.org/wiki/SBML) format to be loaded into the application. For loading of SBML, `shinyKGode` relies on [a modified version of SBMLR](https://github.com/joewandy/sbmlr) (with some bugfixes), so a limited range of SBML level v2 model files that can be parsed by [SBMLR](https://bioconductor.org/packages/release/bioc/html/SBMLR.html) is supported and can be loaded into the application. Notably, this means only SBML v2 specifications is supported and not v3 yet. Also, models exported from Copasi contains user-defined functions, which are also not supported by the parser. In this case, we suggest removing user-defined functions from the SBML file and putting them directly in the reaction section.

Example SBML files for:
- [The Lotka-Volterra model](inst/extdata/LotkaVolterra.xml)
- [The FitzHugh–Nagumo model](inst/extdata/FHN.xml)