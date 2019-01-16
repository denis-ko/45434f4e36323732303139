#--------------------------------------------------------------------------
# ASCII Art.
# see https://en.wikipedia.org/wiki/ASCII_art
#--------------------------------------------------------------------------

include("Common/io.jl");

using Colors, Images, ImageTransformations
using FileIO, .IO, Match

chars = ['@'; '#'; '%'; '&'; 'o'; ':'; '*'; '.'; ' '];
int(x) = trunc(Int, x);
color2char(c) = (idx = int((length(chars) - 1) * c); chars[idx + 1]);

function resize(img::Matrix{T} where T<:Colorant)
    s(i) = (v = size(img, i); min(1.0, 500.0 / v))
    sc =  min(s(1), s(2))
    imresize(img, int.(size(img) .* sc))
end

function img2ascii(img::Matrix{T} where T<:Colorant)
    gim = Gray.(resize(img)) # Convert to grayscale
    tmp = map(i -> join(color2char.(gray.(gim[i, :]))), 1:size(gim, 1));
    join(tmp, '\n');
end

function get_html(asc::String; fontsize = 3, lineheight = 1)
    v = replace(asc, r"(\n|\s)" => s -> (s == "\n" ?  "<br/>" : "&nbsp;"))
    r(x) = @match x begin
        "{fs}" => string(fontsize)
        "{lh}" => string(lineheight)
        "{aa}" => v
        u => error("Unexpected match '$u'.")
    end

    html = read("Resources/ascii_art.html", String)
    replace(html, r"({fs}|{lh}|{aa})" => r)
end

img = load("Resources/Images/test1.jpg");
asc = img2ascii(img);
html = get_html(asc, lineheight = 0.7);

path = chkdir("Output");
write("$path/ascii_art.html", html);
fopen("$path/ascii_art.html")