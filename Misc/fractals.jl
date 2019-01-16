#--------------------------------------------------------------------------
# Visualization of various fractals, e.g. the Mandelbrot and Julia sets.
# see https://en.wikipedia.org/wiki/Julia_set,
#     https://en.wikipedia.org/wiki/Mandelbrot_set
#--------------------------------------------------------------------------

#=
import Pkg
Pkg.add("ColorSchemes")
Pkg.add("GR")
Pkg.add("Plots")
Pkg.add("ProgressMeter")
=#

include("Common/colormaps.jl");
include("Common/io.jl");
include("Common/util.jl");

using Plots, ProgressMeter
using .ColorMaps, .IO, .Util

ColorMaps.register_gradients()
gr(size = (450, 450), ratio = 1,
   colorbar = false,
   axis = true, ticks = true);

ge(x, y) = isnan(x) || x > y;
id(x) = x;

function julia(f, c, x, y, maxn; r = 2.0)
    r = max(abs(c), abs(r))
    aux(z, k) =
        (ge(abs(z), r) ? 0.0 : (k > maxn ? z : aux(f(z) + c, k + 1)))

    [(v = a + b * im; aux(v, 0)) for a in x, b in y]
end

function mandelbrot(x, y, maxn)
    aux(c, z, k) =
        (ge(abs(z), 2.0) || k > maxn ? k : aux(c, z ^ 2 + c, k + 1))

    [(c = a + b * im; aux(c, c, 0)) for a in x, b in y]
end

draw_julia(f, c, x, y, maxn; scalef = id, color = :jet) = begin
    r = maxby(abs, extrema(x), extrema(y))
    z = julia(f, c, x, y, maxn, r = r)
    heatmap(x, y, scalef.(abs.(z')), color = color)
end

draw_mandelbrot(x, y, maxn; color = :jet) = begin
    k = mandelbrot(x, y, maxn)
    scalef(v) = v ^ (2.5 / log(maxn))
    heatmap(x, y, scalef.(k'), color = color)
end

# Some examples
x = -1.5:0.003:1.5;
draw_julia(z -> z ^ 2, -0.75, x, x, 25,
           color = :colorcube2)

x = -1.5:0.01:1.5;
draw_julia(z -> z ^ 2, -0.4+0.6im, x, x, 50)

x, y = -4:0.01:1, -3:0.01:3;
draw_julia(z -> (z ^ 2 + z) / log(z), 0.268+0.06im,
           x, y, 25,
           scalef = v -> exp(-v),
           color = :colorcube1)

x, y = -2.0:0.005:1.0, -1.5:0.005:1.5;
draw_mandelbrot(x, y, 500)

x, y = -0.5:0.002:0.5, 0.5:0.002:1.2;
draw_mandelbrot(x, y, 500)

x, y = -1.42:0.0001:-1.38, -0.02:0.0001:0.02;
draw_mandelbrot(x, y, 500)

# Animated Julia set
animate_julia(niter; size = (300, 300), fps = 20) = begin
    p = Progress(niter, 1)
    x = -1.5:0.01:1.5
    ca = [v[1] + v[2] * im for
          v = (zip(range(-0.1, stop = 0.2, length = niter),
                   range(0.6, stop = 0.7, length = niter)))]

    gr(size = size, ratio = 1,
       colorbar = false, axis = false,
       border = false, ticks = false)

    anim = @animate for c in ca
        draw_julia(z -> z ^ 2, c, x, x, 25)
        next!(p)
    end

    path = chkdir("Output")
    gif(anim, "$path/julia.gif", fps = fps, variable_palette = true)
    fopen("$path/julia.gif")
end

animate_julia(100)