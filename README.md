# ShinyKGode

Many processes in science and engineering can be described by dynamical systems based on nonlinear ordinary differential equations (ODEs). Often ODE parameters are unknown and not directly measurable. Since nonlinear ODEs typically have no closed form solution, standard iterative inference procedures  require a computationally expensive numerical integration of the ODEs every time the parameters are adapted, which in practice restricts statistical inference to very small systems. To overcome this computational bottleneck, approximate methods based on gradient matching have recently gained much attention.

In this package, we develop an easy-to-use application in Shiny to perform parameter inference on ODEs using gradient matching. The application, called `shinyKGode`, is built upon the [KGode](https://CRAN.R-project.org/package=KGode) package, which implements the kernel ridge regression and the gradient matching algorithm proposed in [Niu et al. (2016)](http://jmlr.org/proceedings/papers/v48/niu16.html) and the warping algorithm proposed in [Niu et al. (2017)](https://link.springer.com/article/10.1007%2Fs00180-017-0753-z) for parameter inference in differential equations. Advanced features such as ODE regularisation and warping can also be easily used for inference in the `shinyKGode` application.

`shinyKGode` has built-in support for the following three models described in [Niu et al. (2017)](https://link.springer.com/article/10.1007%2Fs00180-017-0753-z):
- [Lotka-Volterra](https://en.wikipedia.org/wiki/Lotka%E2%80%93Volterra_equations), which describes the dynamics of ecological
systems with predator-prey interactions.
-  [FitzHugh–Nagumo](https://en.wikipedia.org/wiki/FitzHugh%E2%80%93Nagumo_model)), which is a two-dimensional dynamical system used for modelling spike generation in axons.
- The Biopathway model described in [y Vyshemirsky and Girolami (2008)](https://academic.oup.com/bioinformatics/article/24/6/833/192524), which is a model for the interactions of five protein isoforms.

On top of that, `shinyKGode` also accepts user-defined models in SBML v2 format. This allows user-defined models specified in the [SBML](https://en.wikipedia.org/wiki/SBML) format to be loaded into the application.

## Providing your own models

For loading of SBML, `shinyKGode` relies on [a modified version of SBMLR](https://github.com/joewandy/sbmlr) (with some bugfixes), so a limited range of SBML level v2 model files that can be parsed by [SBMLR](https://bioconductor.org/packages/release/bioc/html/SBMLR.html) is supported and can be loaded into the application. Notably, this means only SBML v2 specifications is supported and not v3 yet.

Models exported from Copasi can be loaded into the application after some adjustments. These Copasi-generated SBML files often contain [user-defined functions](http://sbml.org/Special/specifications/sbml-level-2/version-1/html/sbml-level-2.html#SECTION00043000000000000000), which are also not supported by the SBMLR parser that `shinyKGode` uses. In this case, we suggest removing user-defined functions from the SBML file (generated by Copasi) and encoding their kinetic laws directly in the reaction sections of the SBML file.

Below are the links to some example SBML files that you can load into `shinyKGode`.
- [The Lotka-Volterra model](https://github.com/joewandy/shinyKGode/raw/master/inst/extdata/LotkaVolterra.xml)
- [The FitzHugh–Nagumo model](https://raw.githubusercontent.com/joewandy/shinyKGode/master/inst/extdata/FHN.xml)

The example SBML files above can be used as the starting point to encoding your own models. Note that SBML files are text-based markup languages, which can be edited in either [text editors](https://atom.io/) or specialised [SBML editors](https://www.ebi.ac.uk/compneur-srv/SBMLeditor.html).

## Installation

The latest version of the `shinyKGode` package can be installed from this github repository using `devtools`:

```R
library(devtools)
install_github('joewandy/shinyKGode')
```

While the stable R package can be installed from CRAN via `install.packages('shinyKGode')`.

## Running shinyKGode

Once installed, the application can be run by:

```R
library(shinyKGode)
startShinyKGode()
```

## Tutorial Videos

### ODE Regularisation

The following video demonstrates the benefits of using ODE regularisation when inferring parameters using gradient matching in the `shinyKGode` package.

<iframe width="560" height="315" src="https://www.youtube.com/watch?v=PnkukIqlh9s" frameborder="0" gesture="media" allow="encrypted-media" allowfullscreen></iframe>