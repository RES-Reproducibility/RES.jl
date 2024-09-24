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
using Term.Prompts
import Pkg.generate
using Humanize
using CSV

include("dropbox.jl")
include("gsheets.jl")
include("workflow.jl")
include("snippets.jl")


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
    @info "First tell us which journal you are handling in this session."

    a = ask(DefaultPrompt(["EJ", "EctJ"], 1, "Which Journal are you working on?"))
    if a == "EJ"
        global journal = "EJ"
    elseif a == "EctJ"
        global journal = "EctJ"
    else
        error("has to be either EJ or EctJ")
    end

    @info "Setting up email"
    R"RESr:::auth($journal)"

    if !haskey(ENV, "RES_PROD")
        @info "Running in test mode"
        global istest = true
    else
        @info "Running in production mode"
        global istest = false
    end

    try
        update_ej()    
        db_refresh_token()
    catch
        reset_gs!()
        update_ej()
        db_refresh_token()
    end

end 

# exports
export db_auth, Authorization, DropboxError
export @list, @ln, assign, update_ej, pw, ar, reload_all, g2g, md5
export @lb, @handler, @find, @lw


end
