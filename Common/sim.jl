module Simulation

using ProgressMeter, Random

function init(stepf, niter, seed)
    if seed != nothing; Random.seed!(seed) end
    p = Progress(niter)
    i -> (ProgressMeter.next!(p); stepf(i))
end

function run(stepf, niter; seed = nothing)
    f = init(stepf, niter, seed)
    map(f, 1:niter)
end

function run_avg(stepf, niter; seed = nothing)
    f = init(stepf, niter, seed)
    mapreduce(f, (a, b) -> a .+ b, 1:niter) ./ niter
end

function try_run_avg(stepf, niter; seed = nothing, maxiter = 10)
    aux(i, j) = begin
        if j > maxiter
            error("Max number of iterations exceeded.")
        end
        try stepf(i) catch _ aux(i, j + 1) end
    end

    run_avg(i -> aux(i, 0), niter; seed = seed)
end

end