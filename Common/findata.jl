module FinData

export Yahoo

module Yahoo

export getprices

using CSV, Dates, HTTP, Match, Parameters

const Option{T} = Union{Nothing, T}

@with_kw mutable struct AuthData
    Cookie::Option{HTTP.Cookies.Cookie} = nothing
    Crumb::Option{String} = nothing
end

qurl = "https://query1.finance.yahoo.com/v7/finance/download/";
authdata = AuthData();

function findcookie(r::HTTP.Messages.Response, name)
    x = filter(v -> v[1] == "set-cookie", r.headers)
    c = HTTP.Cookies.readsetcookies("", map(v -> v[2], x))
    i = findfirst(v -> v.name == name, c)
    i == 0 ? nothing : c[i]
end

function get_authdata()
    url = "https://finance.yahoo.com/quote/%5EDJI?p=^DJI"
    rsp = HTTP.get(url)
    c = findcookie(rsp, "B")
    if c == nothing
        error("Could not find necessary cookies.")
    else
        rgx = r"\"CrumbStore\":{\"crumb\":\"(?<crumb>.+?)\"}"
        c, match(rgx, rsp.body |> String)[:crumb]
    end
end

function check_auth()
    c = authdata.Cookie
    if c == nothing || c.expires < now()
        c, crumb = get_authdata()
        global authdata = AuthData(c, crumb)
    end
end

function query(sdate, edate, int)
    yint = @match int begin
        :d  => "1d"
        :wk => "1wk"
        :mo => "1mo"
        v => error("Invalid interval '$v'.")
    end
    ut(v) = Dates.datetime2unix(DateTime(v)) |> Int
    Dict("period1" => ut(sdate),
         "period2" => ut(edate),
         "interval" => yint,
         "events" => "history",
         "crumb" => authdata.Crumb)
end

function getprices(symbols, sdate, edate; int = :d)
    check_auth()
    q = query(sdate, edate, int)
    c = authdata.Cookie |> String

    handle_symbol(s) = begin
        @info "Downloading data for '$s'."
        rsp = HTTP.get("$qurl$s", ["Cookie" => c]; query = q)
        df = CSV.read(IOBuffer(rsp.body))
        df[:Symbol] = s; df
    end

    vcat(map(handle_symbol, symbols)...)
end

end

end