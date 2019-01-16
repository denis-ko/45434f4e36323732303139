module IO

export chkdir, fopen

function chkdir(path)
    if !isdir(path); mkdir(path) end
    path
end

function fopen(filename)
    if Sys.iswindows()
        run(`$(ENV["COMSPEC"]) /c start $(filename)`)
    elseif Sys.isapple()
        run(`open $(filename)`)
    elseif Sys.islinux() || Sys.isbsd()
        run(`xdg-open $(filename)`)
    else
        error("Unsupported platform.")
    end
end

end