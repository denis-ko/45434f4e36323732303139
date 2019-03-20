#--------------------------------------------------------------------------
# Assignment 6, Question 1
# GMM
#--------------------------------------------------------------------------

include("Common/sim.jl");
include("Common/util.jl");

using Distributions, LinearAlgebra, Optim, .Simulation, .Util

# Paramaters
Λ(v) = 1 / (1 + exp(-v));
ρ = 0.9; α = 0.05;
θ = [1.0; -1.0];
π = [0.3; -1.0; 0.6];

snd = Normal();
ci_fn(b, se) =
    quantile.(snd, [α / 2 (1 - α / 2)]) * se .+ b;

mvnz = MvNormal([0; 0], eye(2));
mvnu = MvNormal([0; 0], [1 ρ; ρ 1]);

function sim_data(n)
    o = ones(n, 1); u = rand(mvnu, n)'
    z = [o rand(mvnz, n)']
    x = [o (z * π + u[:, 2])]
    Λ.(x * θ) + u[:, 1], x, z
end

function ivnlreg(y, x, z, w, b)
    m = z' * (y - Λ.(x * b))
    (m' * w * m)[1, 1]
end

function ivnlreg_cue(y, x, z, b)
    m = z .* (y - Λ.(x * b))
    w = m' * m; m = sum(m, dims = 1)
    ((m / w) * m')[1, 1]
end

function calc_se(y, x, z, w, b, typ)
    n, xb = length(y), x * b

    # Estimate V_0 = E[m × m']
    m = z .* (y .- Λ.(xb))
    v = m' * m / n

    # Estimate Γ_0 = E[dm/dθ]
    Γ = (z .* Λ.(xb) .* Λ.(-xb))' * x / n

    avar = if typ
        Ω = Γ' * w * v * w * Γ
        B = Γ' * w * Γ; B \ Ω / B
    else
        inv((Γ' / v) * Γ)
    end

    if any(diag(avar) .<= 0)
        error("Invalid asy-var matrix.")
    end

    sqrt.(diag(avar) / n), v
end

w0, b0 = eye(3), [0.0; 0.0];
len(ci) = ci[2] - ci[1];

function sim_step(n)
    y, x, z = sim_data(n)

    minimize(Q, b0) = begin
        o = optimize(Q, b0, Newton())

        if !Optim.converged(o)
            error("Optimization failed.")
        end

        Optim.minimizer(o)
    end

    # 2 step GMM / Step 1
    θ_hat1 = minimize(b -> ivnlreg(y, x, z, w0, b), b0)
    se1, v1 = calc_se(y, x, z, w0, θ_hat1, true)
    ci1 = ci_fn(θ_hat1[2], se1[2])

    # 2 step GMM / Step 2
    θ_hat2 = minimize(b -> ivnlreg(y, x, z, inv(v1), b), θ_hat1)
    se2, = calc_se(y, x, z, [], θ_hat2, false)
    ci2 = ci_fn(θ_hat2[2], se2[2])

    # CUE GMM
    θ_hat3 = minimize(b -> ivnlreg_cue(y, x, z, b), θ_hat2)
    se3, = calc_se(y, x, z, [], θ_hat3, false)
    ci3 = ci_fn(θ_hat3[2], se3[2])

    [ci1[1] <= θ[2] <= ci1[2];
     ci2[1] <= θ[2] <= ci2[2];
     ci3[1] <= θ[2] <= ci3[2]],
    len(ci2) < len(ci1), 
    len(ci3) < len(ci1)
end

# Run the simulation
out = Simulation.try_run_avg(_ -> sim_step(100), 10000, seed = 153)