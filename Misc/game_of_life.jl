#--------------------------------------------------------------------------
# Visualization of Conway's Game of Life.
# see https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life
#--------------------------------------------------------------------------

#=
import Pkg
Pkg.add("GR")
Pkg.add("Images")
Pkg.add("ImageView")
Pkg.add("Plots")
Pkg.add("ProgressMeter")
=#

include("Common/io.jl");

using Images, ImageView, .IO, LinearAlgebra
using Plots, ProgressMeter

const Scene = Matrix{Bool};

nb_offset = [(k, l) for k in -1:1, l in -1:1 if (k != 0 || l != 0)];

function next_gen(s::Scene)
    n, m = size(s)
    if min(n, m) < 3
        error("The scene is too small.")
    end

    cell_state = (i, j) -> begin
        v = mapreduce(o -> s[mod1(o[1] + i, n), mod1(o[2] + j, m)],
                      +, nb_offset)
        (s[i, j] && v >= 2 && v <= 3) || (v == 3)
    end

    [cell_state(i, j) for i = 1:n, j = 1:m]
end

function get_img(s::Scene)
    clr_a = colorant"#ADFF2F"
    clr_d = colorant"#000000"
    map(v ->  v ? clr_a : clr_d, s)
end

function set_win(img, w::Int, h::Int)
    gd = imshow(img, name = "Game of Life");
    resize!(gd["gui"]["window"], w, h)
    sleep(1)
    gd["gui"]["canvas"]
end

int(x) = trunc(Int, x);

run_gif(seed::Scene; width::Int = 200, ngen = 100) = begin
    s = seed; (n, m) = size(s)
    p = Progress(ngen, 1)

    gr(size = (width, int(width * n / m)),
       dpi = 300, ratio = 1, colorbar = false,
       border = false, ticks = false)

    anim = @animate for i = 1:ngen
        s = next_gen(s)
        heatmap(s); next!(p)
    end

    path = chkdir("Output")
    gif(anim, "$path/gol.gif", fps = 15)
    fopen("$path/gol.gif")
end

run(seed::Scene; zoom = 1, ngen = 100, tmout = 0.05) = begin
    s = seed; (n, m) = size(s)
    cn = set_win(get_img(s), int(zoom * m), int(zoom * n))

    for i = 1:ngen
        s = next_gen(s)
        imshow(cn, get_img(s))
        sleep(tmout)
    end
end

# Random seed
seed1 = rand(Bool, 200, 200);
seed1[60:140, 60:140] .= false;

# Regular pattern 1
seed2 = zeros(Bool, 200, 200);
seed2[60:140, 60:140] .= true;

# Regular pattern 2
seed3 = ones(Bool, 200, 200);
seed3[1:200, 97:103] .= false;
seed3[97:103, 1:200] .= false;

# Gosper glider gun
seed4 = zeros(Bool, 100, 200);
idx = [(5, 1); (5, 2); (6, 1); (6, 2); (5, 11); (6, 11); (7, 11); (4, 12);
       (3, 13); (3, 14); (8, 12); (9, 13); (9, 14); (6, 15); (4, 16);
       (5, 17); (6, 17); (7, 17); (6, 18); (8, 16); (3, 21); (4, 21);
       (5, 21); (3, 22); (4, 22); (5, 22); (2, 23); (6, 23); (1, 25);
       (2, 25); (6, 25); (7, 25); (3, 35); (4, 35); (3, 36); (4, 36)];

for i in idx
    seed4[i[1] + 10, i[2] + 10] = true
    seed4[i[1] + 10, 200 - i[2] - 10] = true
end

run_gif(seed1);

run(seed4, zoom = 5, ngen = 500);