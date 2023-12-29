module RES


using DataFrames
using RCall
using HTTP
using JSON
using GoogleSheets
using Infiltrator
using TidierData: @clean_names
using Chain
using Dates

include("dropbox.jl")
include("gsheets.jl")
include("workflow.jl")


# package-wide variables
istest = false
new_arrivals = Ref(DataFrame())   # newly arrived papers
d = Ref(DataFrame())   # main data: current list of papers to be processed
r = Ref(DataFrame())   # replicators
db_au = Authorization("")



function istester()
    println(istest)
end

function __init__()

    @info "Welcome to RES.jl"

    @info "type 2 to reload ejdataeditor@gmail.com credentials, 1 to get new ones"
    R"gmailr::gm_auth_configure()"
    R"gmailr::gm_auth()"

    if !haskey(ENV, "RES_PROD")
        @info "Running in test mode"
        global istest = true
    else
        @info "Running in production mode"
        global istest = false
    end

    d[] = gs_read()
    r[] = get_replicators()
    new_arrivals[] = get_new_arrivals()

    # dropbox auth
    # @info "Refreshing Dropbox token"
    nt = db_refresh_token()
    global db_au = db_auth(nt["access_token"])

end 

# exports
export db_auth, Authorization, DropboxError


end
