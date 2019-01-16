module Util

export flatten, maxby, minby

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