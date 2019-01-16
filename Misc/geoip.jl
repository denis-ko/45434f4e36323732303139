#--------------------------------------------------------------------------
# Visualization of the GeoIP data.
# see https://dev.maxmind.com/geoip/
#--------------------------------------------------------------------------

#=
Pkg.add("HTTP")
Pkg.add("GZip")
Pkg.add("Query")
Pkg.add("ZipFile")
=#

include("Common/geodata.jl");
include("Common/io.jl");

using DataFrames, Plots, Query
using .GeoData, .IO

geoip = @from x in GeoData.geoip(4) begin
    @let lt = trunc(x.latitude.value, digits = 1)
    @let ln = trunc(x.longitude.value, digits = 1)
    @group x by (lt, ln) into g
    @select {lt = key(g)[1], ln = key(g)[2], count = length(g)}
    @collect DataFrame
end;

cline = GeoData.coastline();

gr(dpi = 600, legend = false,
   axis = false, ticks = false);

plot(cline[:, 1], cline[:, 2],
     color  = :grey,
     linewidth = 0.2,
     bg = :black)

scatter!(geoip[:ln], geoip[:lt],
        markersize = 0.3,
        markerstrokewidth = 0,
        markercolor = :lime)

path = chkdir("Output")
savefig("$path/geoip.png")