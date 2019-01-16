module GeoData

export data_path

using CSV, DataFrames, DelimitedFiles, GZip

data_path = "Resources/Geodata"

module GeoIP

using HTTP, GZip, ZipFile
using Main.GeoData

url_md5 = "http://geolite.maxmind.com/download/geoip/database/GeoLite2-City-CSV.zip.md5"
url_csv = "http://geolite.maxmind.com/download/geoip/database/GeoLite2-City-CSV.zip"
fname_md5 = "$data_path/geoip.md5"
fname_csv(v) = "$data_path/geoip$v.csv.gz"

function local_md5()
    try
        open(fname_md5) do f
            strip(readline(f))
        end
    catch nothing
    end
end

function update()
    md5 = HTTP.get(url_md5).body |> String

    if md5 != local_md5()
        @info "Downloading data..."
        rsp = HTTP.get(url_csv)
        zip = ZipFile.Reader(IOBuffer(rsp.body))

        @info "Extracting zipped files..."
        get_idx(f) = findfirst(v -> occursin(f, string(v)), zip.files)

        gzopen(fname_csv(4), "w") do f
            i = get_idx("GeoLite2-City-Blocks-IPv4.csv")
            write(f, read(zip.files[i]))
        end

        gzopen(fname_csv(6), "w") do f
            i = get_idx("GeoLite2-City-Blocks-IPv6.csv")
            write(f, read(zip.files[i]))
        end

        write(fname_md5, md5)
    end
end

function get_file(ipv::Int)
    if !(ipv in (4, 6))
        error("Invalid IP version.")
    end

    update(); fname_csv(ipv)
end

end

function coastline()
    gzopen("$data_path/coastline.txt.gz", "r") do f
        readdlm(f)
    end
end

function geoip(ipv::Int; rows::Int = -1)
    df = gzopen(GeoIP.get_file(ipv)) do f
        CSV.read(f, rows = rows)
    end

    deletecols!(df, collect(3:7))
end

end