#--------------------------------------------------------------------------
# Econometric Applications.
#
# Reference: Bruce Hansen's textbook available at
# http://www.ssc.wisc.edu/~bhansen/econometrics/Econometrics.pdf
#--------------------------------------------------------------------------

#=
import Pkg
Pkg.add("GR")
Pkg.add("Plots")
Pkg.add("PlotlyJS")
Pkg.add("UnicodePlots")
Pkg.add("LaTeXStrings")
Pkg.add("Convex")
Pkg.add("Optim")
Pkg.add("CSV")
Pkg.add("Distributions")
Pkg.add("DataFrames")
Pkg.add("ForwardDiff")
Pkg.add("ReverseDiff")
Pkg.add("Match")
Pkg.add("Parameters")
=#

include("Common/io.jl");
include("Common/regress.jl");
include("Common/sim.jl");

using Distributions, Random
using .IO, .Regress, .Simulation

#--------------------------------------------------------------------------
# 1. Instrumental Variables (Ch. 11, p. 302)
#--------------------------------------------------------------------------

# Generate data
n = 10000;
β = [1; 1]; ρ = 0.5;

Random.seed!(153); # Reseed the RNG
mnd = MvNormal([0; 0], [1 ρ; ρ 1]);
z = rand(n, 1);
e = rand(mnd, n)';
x = z .+ e[:, 1];
y = β[1] .+ x * β[2...] + e[:, 2];

# Estimate the model using OLS
p = Regress.Params(Stats = false);
b_hat1, = ols(y[:], x, p);

# Estimate the model using IV
b_hat2, = iv(y[:], x, z, p);

# Plot the estimated regression functions
using Plots
plotlyjs();

scatter(x[:], y[:],
        markersize = 0.8,
        markerstrokewidth = 0,
        xlabel = "x",
        ylabel = "y",
        label = "Data")

xp = range(-4, stop = 8)
y_hat1 = b_hat1[1] .+ xp * b_hat1[2...];
y_hat2 = b_hat2[1] .+ xp * b_hat2[2...];

plot!(xp, y_hat1[:],
      linestyle = :dot,
      linecolor = :red,
      label = "OLS")

plot!(xp, y_hat2[:],
      linecolor = :black,
      label = "IV")

#--------------------------------------------------------------------------
# 2. Nonlinear Least Squares (Ch. 20, p. 486)
#--------------------------------------------------------------------------

# Generate data
n = 10000;
β = [1; -1];
m_fn(x, b) = (1 .+ exp.(-x * b)) .^ -1; # Logistic link function

Random.seed!(153); # Reseed the RNG
snd = Normal();
x = 2 * rand(snd, n, length(β));
u = rand(snd, n);
y = m_fn(x, β) + u;

# Estimate the model
p = Regress.Params(Stats = true);
b0 = zeros(length(β));
b_hat, stats = nls(m_fn, y, x, b0, p);

# Plot the estimated function
scatter3d(x[:, 1], x[:, 2], y,
          markersize = 0.5,
          markerstrokewidth = 0,
          xlabel = "x1",
          ylabel = "x2",
          zlabel = "y")

xp =  range(-7, stop = 7, length = 100);
y_hat = [m_fn([xp[j] xp[i]], b_hat)[1]
         for i = 1:length(xp), j = 1:length(xp)];

surface!(xp, xp, y_hat,
         α = 0.9,
         fill_z = -log.(y_hat),
         colorbar = false,
         color = :plasma)

# Write the results to a CSV file
using CSV, DataFrames

out = DataFrame(b_hat = b_hat, se = stats.SE,
    t = b_hat ./ stats.SE,
    ci_lb = stats.CI[1],
    ci_ub = stats.CI[2])

path = chkdir("Output")
CSV.write("$path/results.csv", out);

#--------------------------------------------------------------------------
# 3. Nonparametric Bootstrap (CI for the mean)
#--------------------------------------------------------------------------

gm = Gamma(1, 2);
θ = mean(gm);

bootstrap(x::Vector; b::Int64 = 499, α = 0.05) = begin
      n, m = length(x), mean(x)
      t = map(i -> mean(x[rand(1:n, n)] .- m), 1:b)
      l, u = quantile(t, α / 2), quantile(t, 1 - α / 2)
      (m - u, m - l), var(t)
end

stepf(n) = begin
      # Draw an i.i.d. sample from the Γ distribution
      x = rand(gm, n)
      # Get confidence interval, boot. variance
      ci, v = bootstrap(x)
      ci[1] <= θ <= ci[2], ci[2] - ci[1], v
end

# Simulated coverage pr., avg length of the boot. CI,
# and the avg. bootstrap variance
Simulation.run_avg(i -> stepf(500), 1000, seed = 153)