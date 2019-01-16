#--------------------------------------------------------------------------
# Visualization of the Collatz conjecture.
# see https://en.wikipedia.org/wiki/Collatz_conjecture
#--------------------------------------------------------------------------

#=
import Pkg
Pkg.add("GR")
Pkg.add("Plots")
Pkg.add("UnicodePlots")
=#

"""
Calculates the Collatz sequence for a given number.
"""
function collatz_seq(n::BigInt)
    v = Array{BigInt, 1}()

    function aux(m, s)
        push!(v, m)
        if m == 1; s
        elseif m % 2 == 0
            aux(m >>> 1, s + 1)
        else
            aux(3 * m + 1, s + 1)
        end
    end

    aux(n, 0), v
end

"""
Calculates the total stopping time of a given number
and the highest number reached during the chain to 1.
"""
function collatz()
    cache = Dict{BigInt,Tuple{Int,BigInt}}()

    function aux(m, s, mx)
        if m == 1; s, mx
        elseif haskey(cache, m)
            x, y = cache[m]
            x + s, max(y, mx)
        elseif m % 2 == 0
            aux(m >>> 1, s + 1, mx)
        else
            z = 3 * m + 1
            aux(z, s + 1, max(z, mx))
        end
    end

    n -> get!(() -> aux(n, 0, n), cache, n)
end

# Example
reduce((x, y) -> "$x → $y", collatz_seq(BigInt(27))[2])

# Check performance
clz = collatz();
@time map(clz ∘ BigInt, 1:1000000);

# Generate plots
using Plots, UnicodePlots
gr();

fst(x::Tuple) = x[1];
x = 1:100000;
y = map(fst ∘ clz ∘ BigInt, x);
scatterplot(x, y)

x = 1:10000;
y = [(clz ∘ BigInt)(n)[c] for n in x, c in 1:2];

scatter(x, y, layout = (1, 2),
        title = ["Stopping Time" "Highest Value"],
        titlefont = Plots.font(9),
        ylim = [nothing (0, 100000)],
        markersize = [1 1.5],
        markerstrokewidth = 0,
        markercolor = [:red :dodgerblue],
        legend = false)