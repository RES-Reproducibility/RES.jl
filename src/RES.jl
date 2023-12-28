module RES


using DataFrames
using RCall
using HTTP
using JSON
using GoogleSheets
using Infiltrator
using Tidier: @clean_names
using Chain
using Dates

include("dropbox.jl")
include("gsheets.jl")
include("workflow.jl")

function __init__()
    @info "RES module loaded"
    @info "type 2 to reload ejdataeditor@gmail.com credentials, 1 to get new ones"
    R"gmailr::gm_auth_configure()"
    R"gmailr::gm_auth()"
end

# exports
export db_auth, Authorization, DropboxError


end
