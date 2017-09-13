library(ggplot2)
source('../rkhs_gradmatch_functions.r')

SEED = 19537
set.seed(SEED)

## try Lotka-Volterra model
f = '../SBML/LotkaVolterra.xml';
noise = 0.1  ## 10db:34 1 20db:34 0.1  30db:2 0.01   40db:18 0.001
noise_unit = 'var'
xinit = as.matrix(c(0.5,1))
tinterv = c(0,6)
params = c(alpha=1,beta=1,gamma=4,delta=1)
pick = 2
res = generate_data_from_sbml(f, xinit, tinterv, params, noise, noise_unit, pick)

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
peod = c(6,5.3) #8#9.7     ## the guessing period
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

## try Fitz-Hugh Nagumo model

f = '../SBML/FHN.xml';
noise = 0.01  ##   10db0.1    20db 0.01   30db0.001    40db 0.0001
samp = 2
xinit = as.matrix(c(-1,-1))
tinterv = c(0,10)
params = c(a=0.2, b=0.2, c=3)
res = generate_data_from_sbml(f, xinit, tinterv, params, noise, noise_unit, pick)

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

# 'f =' followed by any number of spaces, followed by a decimal number
pattern = 'f =\\s+[0-9]*\\.?[0-9]*'
m = gregexpr(pattern, res$output)
regm = regmatches(res$output, m)
costs = numeric()
for (i in 1:length(regm)) {
    match = regm[[i]]
    if (length(match) > 0) {
        x = unlist(strsplit(match, '='))
        my_cost = as.numeric(trimws(x[2]))
        costs = c(my_cost, costs)
    }
}
costs = rev(costs)
df = as.data.frame(costs)
iterations = seq_along(costs)-1
ggplot(data=df, aes(y=costs, x=iterations)) +
    geom_line() +
    geom_point() +
    ggtitle('Optimisation Results') +
    xlab("Iteration") +
    ylab("f") +
    theme_bw() + theme(text = element_text(size=20)) +
    expand_limits(x = 0) + scale_x_continuous(expand = c(0, 0))
