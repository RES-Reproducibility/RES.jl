module RES


using DataFrames
using RCall
using HTTP
using JSON
using GoogleSheets
using Infiltrator

include("dropbox.jl")
include("gsheets.jl")
include("workflow.jl")

# upon package load, download spreadsheet

# update the sheet via R
d = rcopy(R"RESr::read_list(refresh = TRUE)")

# exports
export db_auth, Authorization, DropboxError


end
