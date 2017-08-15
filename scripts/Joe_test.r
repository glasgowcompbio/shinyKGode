source('rkhs_gradmatch_wrapper.r')

SEED = 19537
set.seed(SEED)

## try Lotka-Volterra model

f = '../SBML/LotkaVolterra.xml';
noise = 0.1  ## 10db:34 1 20db:34 0.1  30db:2 0.01   40db:18 0.001
samp = 2

sbml_data = load_sbml(f)

res = generate_data_from_sbml(sbml_data, c(0,6), samp, noise)
kkk = res$kkk
y_no = res$y_no

# gradient matching
res = gradient_match(kkk, y_no)
print(res$ode_par)
for (i in 1:res$nst) {
    plot(res$plot_x[[i]], res$plot_y[[i]], type='l')
}

# gradient matching + 3rd step
attach(sbml_data)
res = gradient_match_third_step(kkk, y_no)
detach(sbml_data)
print(res$ode_par)

# warp
peod = c(6,5.3) ## the guessing period
eps= 1          ## the standard deviation of period
fixlens=c(3,3)
res = warping(kkk, y_no, peod, eps, ktype='rbf')
print(res$ode_par)

# 3rd step + warp
res = third_step_warping(sbml_data$mi$nStates, length(sbml_data$params), kkk, y_no, peod, eps, fixlens)
print(res$ode_par)

## try Fitz-Hugh Nagumo model

f = '../SBML/FHN.xml';
noise = 0.01  ##   10db0.1    20db 0.01   30db0.001    40db 0.0001
samp = 2

sbml_data = load_sbml(f)
res = generate_data_from_sbml(sbml_data, ode_fun, c(0,10), samp, noise)
kkk = res$kkk
y_no = res$y_no

sink('fhn_parsed.txt')
res = gradient_match(sbml_data$mi$nStates, length(sbml_data$params), kkk, y_no)
print(res$ode_par)
sink()

res = gradient_match_third_step(sbml_data$mi$nStates, length(sbml_data$params), sbml_data, kkk, y_no)
print(res$ode_par)
