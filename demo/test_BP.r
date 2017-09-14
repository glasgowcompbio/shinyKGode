source('../rkhs_gradmatch_functions.r')

SEED=19537
set.seed(SEED)

noise = 0.017^2 #0.0018^2 #0.052^2
noise_unit = 'var'
xinit = as.matrix(c(1,0,1,0,0))
tinterv = c(0,100)
numSpecies = 5
paramsVals = c(0.07,0.6,0.05,0.3,0.017,0.3)
res = generate_data_selected_model('bp', xinit, tinterv, numSpecies, paramsVals, 
                                   noise, noise_unit, pick)
print(res$y_no)

kkk = res$kkk
y_no = res$y_no

############################# parameter inference   ############################## 
##### standard gradient matching

progress = NULL
ktype = 'rbf'
res = gradient_match(kkk, tinterv, y_no, ktype, progress)
print(res$ode_par)
for (i in 1:res$nst) {
    plot(res$intp_x[[i]], res$intp_y[[i]], type='l')
}

############# gradient matching + thrid step
res = gradient_match_third_step(kkk, tinterv, y_no, ktype, progress)
print(res$ode_par)
for (i in 1:res$nst) {
    plot(res$intp_x[[i]], res$intp_y[[i]], type='l')
}

########## warp  
peod = c(200,200,200,200,200)   ## the guessing period for each state  user defined
eps= 20          ## the standard deviation of period  user defined
res = warping(kkk, tinterv, y_no, peod, eps, ktype, progress)
print(res$ode_par)
for (i in 1:res$nst) {
    plot(res$intp_x[[i]], res$intp_y[[i]], type='l')
}

##### 3rd step + warp
peod = c(200,200,200,200,200)   ## the guessing period for each state  user defined
eps= 20          ## the standard deviation of period  user defined
res = third_step_warping(kkk, tinterv, y_no, peod, eps, ktype, progress)
print(res$ode_par)
for (i in 1:res$nst) {
    plot(res$intp_x[[i]], res$intp_y[[i]], type='l')
}