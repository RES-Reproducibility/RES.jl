# `RES.jl`

This helper package implements the RES workflow:

1. EOL logs new papers into google spreadsheet of corresponding journal (EJ and EctJ)
2. `RES.jl` downloads data for each journal once per day.
3. `RES.jl` creates a dropbox file request for each paper
4. `RES.jl` sends an email to main author of paper with instructions and file request link


## dependencies

1. GoogleSheets.jl
2. HTTP.jl


## Requirements, Access tokens

1. google developer API token to access google sheet
2. dropbox API to access full personal dropbox of data editor

