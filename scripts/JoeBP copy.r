source('rkhs_gradmatch_wrapper.r')

SEED=19537

noise = 0.017^2 #0.0018^2 #0.052^2
xinit = as.matrix(c(1,0,1,0,0))
tinterv = c(0,100)
numSpecies = 5
paramsVals = c(0.07,0.6,0.05,0.3,0.017,0.3)
res = generate_data_predefined_models('bp', xinit, tinterv, numSpecies, paramsVals, noise, seed=SEED)
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
peod = c(200,200,200,200,200)   ## the guessing period for each state  user defined
eps= 20          ## the standard deviation of period  user defined
res = warping(kkk, y_no, peod, eps, ktype='rbf')
print(res$ode_par)
for (i in 1:res$nst) {
    plot(res$plot_x[[i]], res$plot_y[[i]], type='l')
}

##### 3rd step + warp
peod = c(200,200,200,200,200)   ## the guessing period for each state  user defined
eps= 20          ## the standard deviation of period  user defined
res = third_step_warping(kkk, y_no, peod, eps, ktype='rbf')
print(res$ode_par)
for (i in 1:res$nst) {
    plot(res$plot_x[[i]], res$plot_y[[i]], type='l')
}