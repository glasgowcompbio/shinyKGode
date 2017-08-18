source('rkhs_gradmatch_wrapper.r')

SEED = 19537
set.seed(SEED)

## try Lotka-Volterra model

f = '../SBML/LotkaVolterra.xml';
noise = 0.1  ## 10db:34 1 20db:34 0.1  30db:2 0.01   40db:18 0.001
samp = 2
xinit = as.matrix(c(0.5,1))
tinterv = c(0,6)
params = c(alpha=1,beta=1,gamma=4,delta=1)
res = generate_data_from_sbml(f, xinit, tinterv, params, samp, noise)

kkk = res$kkk
y_no = res$y_no
sbml_data = res$sbml_data

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
res = third_step_warping(kkk, y_no, peod, eps)
print(res$ode_par)

## try Fitz-Hugh Nagumo model

f = '../SBML/FHN.xml';
noise = 0.01  ##   10db0.1    20db 0.01   30db0.001    40db 0.0001
samp = 2
xinit = as.matrix(c(-1,-1))
tinterv = c(0,10)
params = c(a=0.2, b=0.2, c=3)
res = generate_data_from_sbml(f, xinit, tinterv, params, samp, noise)

kkk = res$kkk
y_no = res$y_no
sbml_data = res$sbml_data

# sink('fhn_parsed.txt')
res = gradient_match(kkk, y_no)
print(res$ode_par)
# sink()

attach(sbml_data)
res = gradient_match_third_step(kkk, y_no)
detach(sbml_data)
print(res$ode_par)