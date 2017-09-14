source('../R/rkhs_gradmatch_functions.r')

SEED=19537
set.seed(SEED)

noise = 0.01  ##   10db0.1    20db 0.01   30db0.001    40db 0.0001
noise_unit = 'var'
xinit = as.matrix(c(-1,-1))
tinterv = c(0,10)
numSpecies = 2
paramsVals = c(0.2,0.2,3)
pick = 2
res = generate_data_selected_model('fhg', xinit, tinterv, numSpecies, paramsVals, 
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
peod = c(8,8.5) #8#9.7     ## the guessing period
eps= 1          ## the standard deviation of period
res = warping(kkk, tinterv, y_no, peod, eps, ktype, progress)
print(res$ode_par)
for (i in 1:res$nst) {
    plot(res$intp_x[[i]], res$intp_y[[i]], type='l')
}

##### 3rd step + warp
peod = c(6,5.3) #8#9.7     ## the guessing period
eps= 1          ## the standard deviation of period
res = third_step_warping(kkk, tinterv, y_no, peod, eps, ktype, progress)
print(res$ode_par)
for (i in 1:res$nst) {
    plot(res$intp_x[[i]], res$intp_y[[i]], type='l')
}
