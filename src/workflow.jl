
case_id(lastname,round,ms) = string(split(lastname)[1],"-",ms,"-R",round)


# macros

"""
    list [n]

list the current list of papers. optionally only the n most recent ones.
"""
macro list(n...)
    if isempty(n)
        return :(d[])
    else
        quote
            @chain d[] begin
                subset(:ms =>ByRow(x -> x != ""))
                last($(n[1]))
            end
        end
    end
end

"""
    ln

list new papers.
"""
macro ln()
        :(new_arrivals[])
end


"""
List Replicator Availability
"""
function ar()
    @chain r[] begin
        transform("remaining_(de_only)" => (x -> parse.(Int,x)) => "remaining")
        subset("remaining" => ByRow( >(0) ) )
        select(:replicator,:name,:surname,"remaining")
    end
end


"""
Package Good To Go Message

1. get case id of package
2. send email to author and ej editorial office
"""
function g2g(caseid)

    # get full record
    i = subset(d[], :case_id => ByRow( ==(caseid)))

    R"RESr:::ej_g2g($(strip(i.firstname)),$(i.lastname),$(i.email),$(i.ms),$(i.round))"
   
    # update corresponding row in google sheet
    # prepare the gsheet writer API
    sheet = Spreadsheet(EJ_id())
    client = gs_readwrite()

    #update row
    i.date_processed .= string(Dates.today())
    i.date_resub .= string(Dates.today())
    i.decision .= "A"
    i.decision_comment .= "accept"
    i.status .= "AP"
    update!(client, CellRange(sheet,"List!A$(i.row_number[1]):$(ej_cols()["max"])$(i.row_number[1])"), Array(i))

    @info "$(caseid) good to go draft created."
end



"""
Assign Replicator to paper

1. get availability of replicators
2. pick one
3. assign replicator to paper: write email of replicator into google sheet, write date of assignment
4. send email to replicator, containing dropbox link to package
"""
function assign(caseid, repl_email; back = false)

    # get full record
    i = subset(d[], :case_id => ByRow( ==(caseid)))

    # get full replicator record
    row = subset(r[], :replicator => ByRow( ==(repl_email)))

    # send email via R
    if back
        R"RESr:::ej_replicator_assignment($(row.name),$(row.replicator),$(split(i.lastname[1])[1]),$(i.ms),$(i.round),back = TRUE)"
    else
        R"RESr:::ej_replicator_assignment($(row.name),$(row.replicator),$(split(i.lastname[1])[1]),$(i.ms),$(i.round),back = FALSE)"
    end

    # update corresponding row in google sheet
    # prepare the gsheet writer API
    sheet = Spreadsheet(EJ_id())
    client = gs_readwrite()

    #update row
    i.date_assigned .= string(Dates.today())
    i.checker1 .= row.replicator
    i.status .= "A"
    update!(client, CellRange(sheet,"List!A$(i.row_number[1]):$(ej_cols()["max"])$(i.row_number[1])"), Array(i))

    @info "$(caseid) assigned to $(row.replicator[1])"
end


"poll waiting packages"
function pw(; write = false)

    # prepare the gsheet writer API
    sheet = Spreadsheet(EJ_id())
    client = gs_readwrite()

    cands = @chain d[] begin
        subset(:status => ByRow(x -> x == ""), :dropbox_id => ByRow(x -> x != ""))
    end
    
    o = Dict(:arrived => String[], :waiting => String[])
    # check each candidate for file requests which have arrived or not
    for i in eachrow(cands)
        if db_fr_hasfile(db_au, i.dropbox_id)
            # update google sheet
            i.arrival_date_package = string(Dates.today())
            if write update!(client, CellRange(sheet,"List!A$(i.row_number):$(ej_cols()["max"])$(i.row_number)"), reshape(collect(i), 1, :)) end
            push!(o[:arrived], i.case_id)
        else
            push!(o[:waiting], i.case_id)
        end
    end
    o
end


function get_case(lastname,round)
    @chain d[] begin
        subset(:lastname => ByRow(x -> x == lastname), :round => ByRow(x -> x == round))
    end
end
function get_case_fr_id(lastname,round)
    @chain d[] begin
        subset(:lastname => ByRow(x -> x == lastname), :round => ByRow(x -> x == round))
        select(:lastname,:round,:dropbox_id)
    end
end
function check_fr_case(lastname,round)
    db_fr_hasfile(db_au, get_case_fr_id(lastname,round).dropbox_id[1])
end

"""
DE has received reports and sends out emails for RNR to authors:

    1. get relevant rows from google sheet
    2. create file paths to pdf reports
    3. create file requests for next round
    4. send emails to authors including url of new file request
"""
function flow_rnrs()

    # get the rows where we need to send dropbox link for first package
    which_package = filter([:ms, :status] => (x,y) -> x != "" && y == "B" , d[])
    
    # prompt user: what do you want to do with those?


    # googlesheets.jl API
    # -------------------
    # prepare the gsheet writer API for julia
    sheet = Spreadsheet(EJ_id())
    client = gs_readwrite()
    # current cursor in spreadsheet (first row which is empty)
    cursor = findfirst(d[].ms .== "")

    # Dropbox API
    # -------------------
    # create file requests
    # append new row to google sheet with correct round number and file request id
    fr_dict = Dict()

    for i in eachrow(which_package)
        j = deepcopy(i) # on this row we have to set status to "R" once we are done and set the date of processing


        # update the row in the spreadsheet for the new round
        i.round = string(parse(Int,i.round) + 1)
        i.row_number = string(cursor + ej_row_offset() - 1)
        i.arrival_date_ee = ""
        i.arrival_date_package = ""
        i.de_comments = "waiting"
        i.status = ""
        i.checker1 = "" 
        i.checker2 = ""
        i.date_assigned = ""
        i.date_completed = ""
        i.hours_checker1 = ""
        i.hours_checker2 = ""
        i.successful = ""
        i.software = ""
        i.data_statement = ""
        i.comments = ""


        # new file request
        fname = case_id(i.lastname,i[:round],i[:ms])
        fr_dict[fname] = db_fr_create(db_au, string("EJ Replication Package: ",fname), joinpath("/EJ/EJ-2-submitted-replication-packages",fname))

        i.dropbox_id = fr_dict[fname]["id"]

        # update the first empty row in the spreadshee with the new entry for this paper
        update!(client, CellRange(sheet,"List!A$(i.row_number):$(ej_cols()["max"])$(i.row_number)"), reshape(collect(i), 1, :))

        tmp_url = fr_dict[fname]["url"]

        # send email via R
        R"RESr:::ej_randr($(i.firstname),$(split(i.lastname)[1]),$(i.email),$(i[:ms]),$(i.title),$(tmp_url),$(j.round))"


        # modify current round and write on spreadsheet. index j!
        j.status = "R"
        j.date_processed = string(Dates.today())
        j.decision = "R"
        j.decision_comment = "resubmit"

        update!(client, CellRange(sheet,"List!A$(j.row_number):$(ej_cols()["max"])$(j.row_number)"), reshape(collect(j), 1, :))



        # update cursor
        cursor = cursor + 1
    end
    @info "Rnr's sent"

    fr_dict
end


# this to be changed: grab new entries from specific sheet, send fr link and then copy over to main sheet.
function flow_file_requests()

    # get the rows where we need to send dropbox link for first package
    ask_package = new_arrivals[]

    # prepare the gsheet writer API for julia
    sheet = Spreadsheet(EJ_id())
    client = gs_readwrite()


    cursor = findfirst(d[].ms .== "")

    row_number = cursor + ej_row_offset() - 1


    # create file requests
    # and log fr id in google sheet
    fr_dict = Dict()

    new_packages_row = 2 # first rows are headers

    for i in eachrow(ask_package)
        new_packages_row += 1
        fname = case_id(i.lastname,i[:round],i[:ms])
        fr_dict[fname] = db_fr_create(db_au, string("EJ Replication Package: ",fname), joinpath("/EJ/EJ-2-submitted-replication-packages",fname))
        fr_dict[fname]["firstname"] = i[:firstname]

        # now write into main sheet
        update!(client, CellRange(sheet,"List!A$(row_number):D$(row_number)"), reshape(strip.(collect(i[[:ms,:round,:firstname,:lastname]])), 1, :))
        update!(client, CellRange(sheet,"List!F$(row_number):J$(row_number)"), reshape(strip.(collect(i[5:end])), 1, :))
        update!(client, CellRange(sheet,"List!M$(row_number):N$(row_number)"), ["waiting" fr_dict[fname]["id"]])

        tmp_url = fr_dict[fname]["url"]

        # send email via R
        R"RESr:::ej_filerequest($(i[:firstname]),$(i[:email]),$(i[:ms]),$(tmp_url),draft = FALSE)"

        # clear this row in new-arrivals
        clear!(client, CellRange(sheet, "New-Arrivals!A$(new_packages_row):I$(new_packages_row)"))
        row_number += 1
    end
    @info "File requests created and emails sent"

    fr_dict
end

function db_fr_single_create(last,round,ms)
    fname = case_id(last,round,ms)
    d = Dict()
    d[fname] = db_fr_create(db_au, string("EJ Replication Package: ",fname), joinpath("/EJ/EJ-2-submitted-replication-packages",fname))
    d
end
