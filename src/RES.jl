module RES

using HTTP
using JSON
using GoogleSheets

include("dropbox.jl")
include("gsheets.jl")


# exports
export db_auth, Authorization, DropboxError


end
