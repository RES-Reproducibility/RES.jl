
get_replicators() = rcopy(R"RESr::read_replicators(refresh = TRUE)")


function flow_file_requests(d::DataFrame)

    # get the rows where we need to send dropbox link for first package
    ask_package = filter([:ms, :status, :de_comments] => (x,y,z) -> !ismissing(x) && ismissing(y) && ismissing(z) , d)    

    # prepare the gsheet writer API for julia
    sheet = Spreadsheet(EJ_id())
    client = gs_readwrite()

    # create file requests
    # and log fr id in google sheet
    au = db_auth()
    fr_dict = Dict()

    # authenticate gmail
    R"gmailr::gm_auth_configure()"
    R"gmailr::gm_auth()"


    for i in eachrow(ask_package)
        fname = string(i[:lastname],"-",i[:ms],"-R",i[:round])
        fr_dict[fname] = db_fr_create(au, string("EJ Replication Package: ",fname), joinpath("/EJ/EJ-2-submitted-replication-packages",fname))
        fr_dict[fname]["firstname"] = i[:firstname]
        fr_write_gsheet(client, sheet, i[:row_number], fr_dict[fname]["id"])
        tmp_url = fr_dict[fname]["url"]

        # send email via R
        R"RESr:::ej_filerequest($(i[:firstname]),$(i[:email]),$(i[:ms]),$(tmp_url),draft = TRUE)"
    end
    @info "File requests and email drafts created"

    fr_dict
end

function flow()

    # use R to get the sheet updated
    

    # update the sheet via R
    d = rcopy(R"RESr::read_list(refresh = TRUE)")

    # get the rows where we need to send dropbox link for first package
    ask_package = filter([:ms, :status, :de_comments] => (x,y,z) -> !ismissing(x) && ismissing(y) && ismissing(z) , d)    

    # prepare the gsheet writer API for julia
    sheet = Spreadsheet(EJ_id())
    client = gs_readwrite()
@infiltrate
    # create file requests
    # and log fr id in google sheet
    au = db_auth()
    fr_dict = Dict()
    for i in 1:nrow(ask_package)
        fname = string(ask_package[i,:lastname],"-",ask_package[i,:ms],"-R",ask_package[i,:round])
        fr_dict[fname] = db_fr_create(au, string("EJ Replication Package: ",fname), joinpath("/EJ/EJ-2-submitted-replication-packages",fname))
        fr_write_gsheet(client, sheet, ask_package[i,:row_number], fr_dict[fname]["id"])
    end
    

    # came back to DE
    back_DE = filter([:ms, :status] => (x,y) -> !ismissing(x) && y == "B" , x)    


    # or needs work if package has not yet arrived -> send email with dropbox link to authors

    # study readme of package

    # look at available replicators

    # assign to replicators : pick one from list

    # enter replicator into google sheet in correct column, together with date assigned

    # send email to replicator

end