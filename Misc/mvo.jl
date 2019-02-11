#--------------------------------------------------------------------------
# Mean-Variance optimization.
# see https://en.wikipedia.org/wiki/Modern_portfolio_theory
#--------------------------------------------------------------------------

#=
Pkg.add("Convex")
Pkg.add("ECOS")
Pkg.add("LaTeXStrings")
Pkg.add("Plots")
=#

include("Common/findata.jl")
include("Common/io.jl");

#--------------------------------------------------------------------------
# Download data from Yahoo Finance
#--------------------------------------------------------------------------

using .FinData

symbols = [:GOOG, :CSCO, :DVN, :BAC, :BA,
           :AAPL, :MSFT, :PFE, :MMM, :GE,
           :AMZN, :DWDP, :XRX, :IBM, :VZ,
           :NFLX, :ADBE, :WMT, :HPQ, :F ];

p = Yahoo.getprices(symbols, "2015-01-01", "2018-12-31", int = :mo);

#--------------------------------------------------------------------------
# Efficient frontier
#--------------------------------------------------------------------------

using Distributions, Statistics
using DataFrames, FileIO, LaTeXStrings, Plots
using Convex, ECOS

c = unstack(p, :Date, :Symbol, :Close);
sort!(c, [:Date]);

# Calculate returns/stats
cm = convert(Matrix, c[:, 2:end]);
rt = cm[2:end, :] ./ cm[1:end - 1, :] .- 1;
η, Σ = mean(rt, dims = 1)[:], cov(rt);

# Optimization
function minvar(η, Σ; μ = nothing, verbose = false)
    w = Variable(length(η))
    p = minimize(quadform(w, Σ))
    p.constraints += [w >= 0; sum(w) == 1]
    if μ != nothing
        p.constraints += η' * w == μ
    end

    solve!(p, ECOSSolver(verbose = verbose))
    if p.status != :Optimal
        error("Optimization failed.")
    end

    σ = (w.value' * Σ * w.value)[1] |> sqrt
    μ != nothing ? σ : ((η' * w.value)[1], σ)
end

μ = range(minimum(η), stop = maximum(η), length = 50);
σ = map(v -> minvar(η, Σ, μ = v), μ);

# Minimum variance portfolio
μ_mv, σ_mv = minvar(η, Σ);

# Plot the efficient frontier
gr(legend = false);

i = findfirst(μ .> μ_mv);
μ1 = μ[i:end]; μ2 = μ[1:i + 1];
σ1 = σ[i:end]; σ2 = σ[1:i + 1];
sd = sqrt.(diag(Σ));

plot(σ2, μ2,
     xlab = L"\sigma", ylab = L"\mu",
     xlims = [0, maximum(sd) * (1.05)],
     linestyle = :dot,
     linewidth = 3,
     linecolor = :red)

plot!(σ1, μ1,
     linewidth = 3,
     linecolor = :blue)

# Add data points
scatter!(sd, η,
         markersize = 4,
         markerstrokewidth = 0)

lbl = map(s -> text(string(s), 7, :left, :top), names(c));
ann = [(sd[i], η[i], lbl[i + 1]) for i = 1:length(η)];
annotate!(ann)