module Regress

export ols, iv, tsls, nls, quant, overid

using Distributions, Match, Parameters
using ForwardDiff, LinearAlgebra, SparseArrays
using Convex, ECOS, Optim

@with_kw mutable struct Params
    VarType::Symbol = :Default
    Stats::Bool = true
    IncludeConst::Bool = true
    Alpha::Float64 = 0.05
end

struct Stats
    SSE
    AVar
    SE
    CI
    Resid
end

# Standard normal distribution
snd = Normal();

function add_const(n, x...)
    map(y -> [ones(n) y], x)
end

"""
OLS regression.

# Arguments
- `y::Vector`: dependent variable.
- `x::Matrix`: regressors.
- `params::Params`: various parameters.
"""
function ols(y::Vector, x::Matrix, params)
    n = size(x, 1)

    if n != length(y)
        error("Incompatible data.")
    end

    # Get estimates
    x = !params.IncludeConst ? x : add_const(n, x)[1]
    xx = x' * x
    b_hat = xx \ (x' * y)

    if !params.Stats
        b_hat, nothing
    else
        # Get residuals
        r_hat = y - x * b_hat; sse = r_hat' * r_hat

        # Get asyvar.
        avar = @match params.VarType begin
            :Default => sse * inv(xx) / n
            :HC      => (xr = x .* r_hat; xx \ (xr' * xr) / xx)
            :HAC     => hac_var(xx, x .* r_hat)
            _ => error("Invalid VarType parameter.")
        end

        se = sqrt.(diag(avar))
        ci = norm_ci(b_hat, se, params.Alpha)
        stats = Stats(sse, avar, se, ci, r_hat)
        b_hat, stats
    end
end

"""
IV regression.

# Arguments
- `y::Vector`: dependent variable.
- `x::Matrix`: regressors.
- `z::Matrix`: instruments.
- `params::Params`: various parameters.
"""
function iv(y::Vector, x::Matrix, z::Matrix, params::Params)
    n = size(x, 1)

    if n != length(y) || any(size(x) != size(z))
        error("Incompatible data.")
    end

    # Get estimates
    x, z = !params.IncludeConst ? (x, z) : add_const(n, x, z)
    zx = z' * x
    b_hat = zx \ (z' * y)

    if !params.Stats
        b_hat, nothing
    else
        # Get residuals
        r_hat = y - x * b_hat; sse = r_hat' * r_hat

        # Get asyvar.
        avar = @match params.VarType begin
            :Default => sse * (zx \ (z' * z) / zx') / n
            :HC      => (zr = z .* r_hat; zx \ (zr' * zr) / zx')
            :HAC     => hac_var(zx, z .* r_hat)
            _ => error("Invalid VarType parameter.")
        end

        se = sqrt.(diag(avar))
        ci = norm_ci(b_hat, se, params.Alpha)
        stats = Stats(sse, avar, se, ci, r_hat)
        b_hat, stats
    end
end

"""
TSLS regression.

# Arguments
- `y::Vector`: dependent variable.
- `x::Matrix`: regressors.
- `z::Matrix`: instruments.
- `params::Params`: various parameters.
"""
function tsls(y::Vector, x::Matrix, z::Matrix, params::Params)
    if size(x, 1) != size(z, 1)
        error("Incompatible data.")
    elseif size(x, 2) > size(z, 2)
        error("Insufficient number of instruments.")
    end

    if size(x, 2) == size(z, 2)
        iv(y, x, z, params)
    else
        n = size(z, 1)
        z = !params.IncludeConst ? z : add_const(n, z)[1]
        iv(y, x, z * ((z' * z) \ (z' * x)), params)
    end
end

"""
NLS regression.
...
# Arguments
- `f`: model function y = f(x, β).
- `y::Vector`: dependent variable.
- `x::Matrix`: regressors.
- `b0::Vector`: initial guess.
- `params::Params`: various parameters.
- `optimopts`: optimization options.
"""
function nls(f, y::Vector, x::Matrix, b0::Vector, params::Params;
    optimopts = Optim.Options())
    n = size(x, 1)

    # Objective function
    obj = b -> sum((y - f(x, b)) .^ 2)

    # Get estimates
    td = TwiceDifferentiable(obj, b0; autodiff = :forward)
    o = optimize(td, b0, Newton(), optimopts)

    if !Optim.converged(o)
        error("Minimization failed.")
    end

    b_hat = Optim.minimizer(o)

    if !params.Stats
        b_hat, nothing
    else
        # Get residuals
        r_hat = y - f(x, b_hat); sse = r_hat' * r_hat

        # Get asyvar. (using the exact gradient)
        v = map(i -> ForwardDiff.gradient(z -> f(x[i, :]', z), b_hat), 1:n)
        md = vcat(v'...)

        me = md .* r_hat; mmd = md' * md
        avar = mmd \ (me' * me) / mmd

        se = sqrt.(diag(avar))
        ci = norm_ci(b_hat, se, params.Alpha)
        stats = Stats(sse, avar, se, ci, r_hat)
        b_hat, stats
    end
end

"""
Quantile regression.
...
# Arguments
- `y::Vector`: dependent variable.
- `x::Matrix`: regressors.
- `params::Params`: various parameters.
- `solver`: LP solver.
- `kernel`: kernel function.
"""
function quant(y::Vector, x::Matrix, τ::Float64, params::Params;
    solver = ECOSSolver(verbose = 0), kernel = nothing)
    n, k = size(x)

    if n != length(y)
       error("Incompatible data.")
    elseif !(0 < τ < 1)
       error("τ ∉ (0,1).")
    end

    # Obj. func/constraints
    x = !params.IncludeConst ? x : add_const(n, x)[1]
    v = Variable(2 * n + k)
    c = (o = ones(n); [τ * o; (1 - τ) * o; zeros(k)])
    A = [I -I sparse(x)]

    # Get estimates (LP optimization)
    p = minimize(c' * v)
    p.constraints += [A * v == y; v[1:(2 * n)] >= 0]
    solve!(p, solver)

    if p.status != :Optimal
        error("Optimization failed.")
    end

    b_hat = v.value[(end - k + 1):end]

    if !params.Stats
        b_hat, nothing
    else
        # Get residuals/kernel
        r_hat = y - x * b_hat; sse = r_hat' * r_hat
        h = 1.06 * std(r_hat) * n ^ (-1 / 5)
        k = kernel == nothing ? (abs.(r_hat / h) .< 1) / 2 : kernel(r_hat, h)

        # Get asyvar.
        Ω = τ * (1 - τ) * (x' * x)
        B = ((x .* k)' * x) / h
        avar = B \ Ω / B

        se = sqrt.(diag(avar))
        ci = norm_ci(b_hat, se, params.Alpha)
        stats = Stats(sse, avar, se, ci, r_hat)
        b_hat, stats
    end
end

"""
Overidentification test.

# Arguments
- `s::Stats`: regression output.
- `z::Matrix`: instruments.
- `params::Params`: various parameters.
"""
function overid(s::Stats, z::Matrix, params::Params)
    n = size(z, 1)
    z = !params.IncludeConst ? z : add_const(n, z)[1]
    l, k = size(z, 2), length(s.SE)

    if n != length(s.Resid)
        error("Incompatible data.")
    elseif k >= l
        error("Insufficient number of instruments.")
    end

    zr = z .* s.Resid; t = sum(zr, 1)
    js = @match params.VarType begin
        :Default => t * ((z' * z) \ t') / s.SSE * n
        :HC      => t * ((zr' * zr) \ t')
        _ => error("Invalid VarType parameter.")
    end

    js[1], ccdf(Chisq(l - k), js[1])
end

"""
Newey–West HAC estimator.
"""
function hac_var(zx, zu)
    n = size(zu, 1)
    m = trunc(Int, (n / log(n)) ^ (1 / 4))
    h = zu' * zu

    for j = 1:m
        v = zu[1:(end - j), :]' * zu[(j + 1):end, :]
        h += (1 - j / (m  + 1)) * (v + v')
    end

    zx \ h / zx'
end

function norm_ci(b::Vector, se::Vector, α::Float64)
    if α <= 0 || α >= 0.5
        error("Invalid α parameter.")
    end

    (quantile(snd, α / 2) .* se + b),
    (quantile(snd, 1 - α / 2) .* se + b)
end

end