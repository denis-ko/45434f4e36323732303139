#--------------------------------------------------------------------------
# Assignment 7
# Monte Carlo for Quantile Regression
#--------------------------------------------------------------------------

include("Common/regress.jl");
include("Common/sim.jl");

using Distributions, .Regress, .Simulation

# Paramaters
β = [0; 0.3255];
γ = [1; 1];

function sim_data(n)
    x = [ones(n) rand(n)]
    u = rand(Regress.snd, n)
    (x * β + (x * γ) .* u), x
end

p = Regress.Params(IncludeConst = false);
b(τ) = β[2] + quantile(Regress.snd, τ) * γ[2];

function sim_step(τ, n)
    y, x = sim_data(n)
    b_hat, stats = quant(y, x, τ, p)
    stats.CI[1][2] <= b(τ) <= stats.CI[2][2]
end

# Run the simulation
out = Simulation.run_avg(_ -> sim_step(0.75, 100), 1000, seed = 135)