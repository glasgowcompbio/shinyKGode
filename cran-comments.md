## Resubmission
This is a resubmission. In this version I have:

- Corrected the grammar issue in the DESCRIPTION file, as suggested below:
> Thanks, do you mean 'users can also load their own models' or perhaps 'user can also load own models'?

- Make sure that interactive examples can be run, following the suggestion below:
> Your examples are wrapped in \dontrun{}, hence nothing gets tested. Please unwrap the examples if that is feasible and if they can be executed in < 5 sec for each Rd file or create additionally small toy examples. For interactive examples, please use if(interactive()){...}.

## Test environments
* local OS X install, R 3.4.2
* win-builder (devel and release)

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## Reverse dependencies

This is a new release, so there are no reverse dependencies.

---