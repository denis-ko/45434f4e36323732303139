module Util

using LinearAlgebra

export eye, flatten, maxby, minby

function eye(n)
     Matrix(1.0I, n, n)
end

function flatten(x...)
     collect(Iterators.flatten(x))
end

"""
Returns the greatest element of a collection,
compared by using max on the function result.
"""
function maxby(f, x...)
     maximum(f.(flatten(x...)))
end

"""
Returns the greatest element of a collection,
compared by using min on the function result.
"""
function minby(f, x...)
     minimum(f.(flatten(x...)))
end

end