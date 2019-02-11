#--------------------------------------------------------------------------
# Assignment 3, Question 2
# Efficient IVs
#--------------------------------------------------------------------------

include("Common/regress.jl");
include("Common/sim.jl");

using Distributions, DataFrames
using .Regress, .Simulation

# Simulation parameters
β = 0.15; ρ = 0.9;
α = [0.1; 0.05; 0.01];

mnd = MvNormal([0.0; 0.0], [1 ρ; ρ 1]);
ci_fn(b, se) =
    quantile.(Regress.snd, [α / 2 (1 .- α / 2)]) * se .+ b;

function sim_data(n)
    # Generate z, x, y
    w = rand(n, 1)
    e = rand(mnd, n)' # [e V]
    z = -0.5 .* (w .< 0.2) - 0.1 .* (0.2 .<= w .< 0.4) +
         0.1 .* (0.4 .<= w .< 0.6) + (w .>= 0.6)
    u = (1 .+ z) .* e[:, 1]
    x = 4 * z .^ 2 + e[:, 2]
    y = x * β + u

    # Generate dummies
    d = map(v -> z .== v, unique(z))
    y[:], x, z, float(hcat(d...))
end

p1 = Regress.Params(Stats = false, IncludeConst = false);
p2 = Regress.Params(Stats = true,  IncludeConst = false, VarType = :HC);

function sim_step(n)
    y, x, z, d = sim_data(n)

    # Usual IV
    b_iv, stats_iv = iv(y, x, z, p2)
    u_iv = stats_iv.Resid

    # Generate efficient instruments
    gi = 4 * z .^ 2 ./ (ρ * (1 .+ z) .^ 2)
    gf = d * (ols(x[:], d, p1)[1] ./ ols(u_iv .^ 2, d, p1)[1])

    # Efficient IV
    eiv(g) = (iv(y, x, gi[:, :], p1)[1], 1 / sqrt((g' * x)[1]))
    b_iiv, se_iiv = eiv(gi)
    b_fiv, se_fiv = eiv(gf)

    ci = cat(ci_fn(b_iv[1], stats_iv.SE[1]),
             ci_fn(b_iiv[1], se_iiv),
             ci_fn(b_fiv[1], se_fiv), dims = 3)

    ci[:, 1, :] .<= β .<= ci[:, 2, :],
    ci[:, 2, :] - ci[:, 1, :],
    .!(ci[:, 1, :] .<= 0 .<= ci[:, 2, :])
end

# Run the simulation
out = Simulation.run_avg(_ -> sim_step(100), 10000, seed = 135);

a = DataFrame(α = α);
set_cols(df) = (names!(df, [:α; :IV; :Eff_IIV; :Eff_FIV]); df);
cov_prob = set_cols([a convert(DataFrame, out[1])])
ci_len   = set_cols([a convert(DataFrame, out[2])])
sig_prob = set_cols([a convert(DataFrame, out[3])])