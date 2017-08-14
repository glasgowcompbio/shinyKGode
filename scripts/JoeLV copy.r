source('rkhs_gradmatch_wrapper.r')

SEED=19537
set.seed(SEED)

noise = 0.1  ## 10db:34 1 20db:34 0.1  30db:2 0.01   40db:18 0.001
xinit = as.matrix(c(0.5,1))
tinterv = c(0,6)
numSpecies = 2
paramsVals = c(1,1,4,1)
res = generate_data_predefined_models('lv', xinit, tinterv, numSpecies, paramsVals, noise)
print(res$y_no)

kkk = res$kkk
y_no = res$y_no

############################# parameter inference   ############################## 
##### standard gradient matching

res = gradient_match(kkk, y_no)
print(res$ode_par)
for (i in 1:res$nst) {
    plot(res$plot_x[[i]], res$plot_y[[i]], type='l')
}

############# gradient matching + thrid step
res = gradient_match_third_step(kkk, y_no)
print(res$ode_par)
for (i in 1:res$nst) {
    plot(res$plot_x[[i]], res$plot_y[[i]], type='l')
}

########## warp  
peod = c(6,5.3) #8#9.7     ## the guessing period
eps= 1          ## the standard deviation of period
res = warping(kkk, y_no, peod, eps, ktype='rbf')
print(res$ode_par)
for (i in 1:res$nst) {
    plot(res$plot_x[[i]], res$plot_y[[i]], type='l')
}

##### 3rd step + warp
peod = c(6,5.3) #8#9.7     ## the guessing period
eps= 1          ## the standard deviation of period
res = third_step_warping(kkk, y_no, peod, eps, ktype='rbf')
print(res$ode_par)
for (i in 1:res$nst) {
    plot(res$plot_x[[i]], res$plot_y[[i]], type='l')
}