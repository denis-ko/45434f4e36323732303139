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

end