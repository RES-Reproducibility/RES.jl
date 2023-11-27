module RES

using HTTP
using JSON
using GoogleSheets
using SMTPClient

include("dropbox.jl")
include("gsheets.jl")
include("gmail.jl")


# exports
export db_auth, Authorization, DropboxError


end
