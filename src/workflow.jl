
function case_id(lastname,round,ms)
    if lastname == ""
        ""
    else
        ln = split(strip(lastname))[1]
        string(ln,"-",ms,"-R",round)
    end
end


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
                select(:case_id,:round,:status,:checker1)
                last($(n[1]))
            end
        end
    end
end

"""
    find lastname

list rows with lastname
"""
macro find(n)
        quote
            @chain d[] begin
                subset(:case_id => ByRow( contains($n)) )
                select(:case_id,:round,:status,:checker1,:email)
            end
        end
end

macro findn(n::Symbol)
    ex = quote
        @chain d[] begin
            subset(:case_id => ByRow( contains($n)) )
            select(:case_id,:round,:status,:checker1)
        end
    end
    esc(ex)
end

"""
    ln

list new papers.
"""
macro ln()
        :(new_arrivals[])
end

"""
    lb

list back papers.
"""
macro lb()
    quote
        @chain d[] begin
            subset(:status =>ByRow(x -> x == "B"))
            select(:case_id,:round,:status,:arrival_date_package)
        end
    end
end


"""
    lw

list waiting papers.
"""
function lw1()
    @chain d[] begin
        subset(:de_comments => ByRow(==("waiting")), :round => ByRow(==("1")))
        select(:case_id,:round,:status,:arrival_date_package,:email)
    end
end

macro lw(r...)
    if isempty(r)
        quote 
            @chain d[] begin
                subset(:de_comments =>ByRow(==("waiting")))
                select(:case_id,:round,:status,:arrival_date_package,:email)
            end
        end
    else
        quote
            @chain d[] begin
                subset(:de_comments => ByRow(==("waiting")), :round => ByRow(==($(r[1]))))
                select(:case_id,:round,:status,:arrival_date_package,:email)
            end
        end
    end        
end

gs_dates

"""
List Replicator Ongoing time
How long has each replicator had their current package
"""
function rwait()
    @chain d[] begin
        subset(:date_assigned => ByRow(!=("")), :date_completed => ByRow(==("")))
        select(:case_id, :checker1,:date_assigned,:status)
        transform(:date_assigned => (x -> Dates.today() .- Dates.Date.(x,gs_dates())) => :days_in_progress)
        sort(:days_in_progress)
    end

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

macro handler(caseid)
    quote
        ms = split($caseid,"-")[2]
        @chain d[] begin
            subset(:ms => ByRow(x -> x == ms))
            select(:case_id,:checker1)
        end
    end
end


"""
    md5 [caseid]

compute the md5 sum of the replication package with the system call md5sum

TODO get zenodo API to return md5 sum of package and DOI
"""
function md5(caseid)
    dir = joinpath(ENV["JL_DB_EJ"], "EJ-6-good-to-go", caseid)
    # find zip files 
    zips = filter(x -> endswith(x, ".zip"), readdir(dir)) 

    # what if 3-replication-package.zip is in root already?!
    if isempty(zips)
        @info "No zip file found in $(dir)"
        for (root, dirs, files) in walkdir(dir)
            for f in files
                if contains(f, r"replication|package")
                    println("md5sum of replication package $caseid: ")
                    cd(root)
                    println(read(`md5sum $f`,String))
                end
            end
        end
    else
        for z in zips
            np = mkpath(joinpath(dir,"unzipped"))
            osx = joinpath(np,"__MACOSX")
            run(`unzip -o -qq $(joinpath(dir,z)) -d $np`)
            run(`rm -rf $osx`)
        end
        iter = walkdir(joinpath(dir,"unzipped"))
        while !isempty(iter)
            (root, di, files) = first(iter)
            println(files)
            println(di)
            # for d in di
            #     println("current dir is $(joinpath(dir,root,d))")
                for f in files
                    println("current file is $f")
                    if contains(f, r"replication|package")
                        println("md5sum of replication package $caseid: ")
                        println(read(`md5sum $(joinpath(root,f))`,String))
                        return 0
                    end
                end
            # end
        end
        error("no package found")
    end
end

"send email about zenodo good to go and log DOI in spreadsheet"
function zg2g(caseid,DOI)
    # get full record
    i = subset(d[], :case_id => ByRow( ==(caseid)))

    # update corresponding row in google sheet
    # prepare the gsheet writer API
    sheet = Spreadsheet(EJ_id())
    client = gs_readwrite()

    #update row
    i.doi_zenodo .= DOI
    update!(client, CellRange(sheet,"List!A$(i.row_number[1]):$(ej_ranges()["maxcol"])$(i.row_number[1])"), Array(i))

    R"RESr:::ej_zg2g($(strip(i.firstname[1])),$(i.lastname),$(i.email),$(i.ms),$(i.round))"

    @info "$(caseid) zenodo good to go email sent."
end



"""
Package Good To Go Message

1. get case id of package
2. send email to author and ej editorial office
"""
function g2g(caseid; copy = true)

    # get full record
    i = subset(d[], :case_id => ByRow( ==(caseid)))

   
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
    update!(client, CellRange(sheet,"List!A$(i.row_number[1]):$(ej_ranges()["maxcol"])$(i.row_number[1])"), Array(i))

    # copy package to good-to-go folder
    if copy cp(joinpath(ENV["JL_DB_EJ"], "EJ-2-submitted-replication-packages", caseid), joinpath(ENV["JL_DB_EJ"], "EJ-6-good-to-go", caseid), force = true) end


    R"RESr:::ej_g2g($(strip(i.firstname[1])),$(i.lastname),$(i.email),$(i.ms),$(i.round))"


    @info "$(caseid) good to go email sent."
end


"""
Re-Assign Package to previous replicator

"""
function reassign(name)
    f = @findn name
    ci = last(f.case_id)
    re = last(f.checker1[f.checker1 .!= ""])

    a = ask(DefaultPrompt(["y", "no"], 1, "Reassign $ci to replicator $re?"))
    
    if a == "y"
        assign(ci,re,back = true)
    else
        @info "choose another replicator!"
    end
end


"""
Assign Replicator to paper

1. get availability of replicators
2. pick one
3. assign replicator to paper: write email of replicator into google sheet, write date of assignment
4. send email to replicator, containing dropbox link to package
"""
function assign(caseid, repl_email; back = false, draft = false)

    # get full record
    i = subset(d[], :case_id => ByRow( ==(caseid)))

    # get full replicator record
    row = subset(r[], :replicator => ByRow( ==(repl_email)))

    # send email via R
    R"RESr:::ej_replicator_assignment($(row.name),$(row.replicator),$(split(i.lastname[1])[1]),$(i.ms),$(i.round),back = $back, draft = $draft)"
   

    # update corresponding row in google sheet
    # prepare the gsheet writer API
    sheet = Spreadsheet(EJ_id())
    client = gs_readwrite()

    #update row
    i.date_assigned .= string(Dates.today())
    i.checker1 .= row.replicator
    i.de_comments .= ""
    i.status .= "A"
    update!(client, CellRange(sheet,"List!A$(i.row_number[1]):$(ej_ranges()["maxcol"])$(i.row_number[1])"), Array(i))


    @info "$(caseid) assigned to $(row.replicator[1])"
end


function set_status(caseid, status)

    # get full record
    i = subset(d[], :case_id => ByRow( ==(caseid)))

    # update corresponding row in google sheet
    # prepare the gsheet writer API
    sheet = Spreadsheet(EJ_id())
    client = gs_readwrite()

    #update row
    i.status .= status
    update!(client, CellRange(sheet,"List!A$(i.row_number[1]):$(ej_ranges()["maxcol"])$(i.row_number[1])"), Array(i))
end


"poll waiting packages"
function pw()

    # prepare the gsheet writer API
    sheet = Spreadsheet(EJ_id())
    client = gs_readwrite()

    update_ej()

    cands = @chain d[] begin
        subset(:status => ByRow(x -> x == ""), :dropbox_id => ByRow(x -> x != ""))
    end
    
    o = Dict(:arrived => String[], :waiting => String[])
    # check each candidate for file requests which have arrived or not
    for i in eachrow(cands)
        if db_fr_hasfile(db_au, i.dropbox_id)
            # update google sheet
            i.arrival_date_package = string(Dates.today())
            i.de_comments = ""
            update!(client, CellRange(sheet,"List!A$(i.row_number):$(ej_ranges()["maxcol"])$(i.row_number)"), reshape(collect(i), 1, :))
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
        i.case_id = case_id(i.lastname,i.round,i.ms)
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
        update!(client, CellRange(sheet,"List!A$(i.row_number):$(ej_ranges()["maxcol"])$(i.row_number)"), reshape(collect(i), 1, :))

        tmp_url = fr_dict[fname]["url"]

        # send email via R
        R"RESr:::ej_randr($(strip(i.firstname)),$(split(i.lastname)[1]),$(i.email),$(i[:ms]),$(i.title),$(tmp_url),$(j.round))"


        # modify current round and write on spreadsheet. index j!
        j.status = "R"
        j.case_id = case_id(j.lastname,j.round,j.ms)
        j.date_processed = string(Dates.today())
        j.decision = "R"
        j.decision_comment = "resubmit"

        update!(client, CellRange(sheet,"List!A$(j.row_number):$(ej_ranges()["maxcol"])$(j.row_number)"), reshape(collect(j), 1, :))



        # update cursor
        cursor = cursor + 1
    end
    @info "Rnr's sent"

    fr_dict
end


"""
RnR without report: request new submission for caseid
"""
function quick_rnr(caseid::Vector{String})

    # get the rows where we need to send dropbox link for first package
    which_package = subset(d[], :case_id => ByRow(∈(caseid)))
    
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
        i.case_id = case_id(i.lastname,i.round,i.ms)
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
        update!(client, CellRange(sheet,"List!A$(i.row_number):$(ej_ranges()["maxcol"])$(i.row_number)"), reshape(collect(i), 1, :))

        tmp_url = fr_dict[fname]["url"]

        # send email via R
        R"RESr:::ej_randr($(strip(i.firstname)),$(split(i.lastname)[1]),$(i.email),$(i[:ms]),$(i.title),$(tmp_url),$(j.round), attachment = FALSE)"


        # modify current round and write on spreadsheet. index j!
        j.status = "R"
        j.case_id = case_id(j.lastname,j.round,j.ms)
        j.date_processed = string(Dates.today())
        j.decision = "R"
        j.decision_comment = "resubmit"

        update!(client, CellRange(sheet,"List!A$(j.row_number):$(ej_ranges()["maxcol"])$(j.row_number)"), reshape(collect(j), 1, :))



        # update cursor
        cursor = cursor + 1
    end
    @info "Rnr's sent"

    fr_dict
end


# this to be changed: grab new entries from specific sheet, send fr link and then copy over to main sheet.
function flow_file_requests()

    update_ej()

    # get the rows where we need to send dropbox link for first package
    ask_package = new_arrivals[]
    ask_package.cid .= ""  # empty case id

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
        fname = case_id(i.lastname,i.round,i.ms)
        fr_dict[fname] = db_fr_create(db_au, string("EJ Replication Package: ",fname), joinpath("/EJ/EJ-2-submitted-replication-packages",fname))
        fr_dict[fname]["firstname"] = i[:firstname]

        # clean email field
        i.email = replace(i.email, r"\n" => "")

        i.round = "1"
        # compute caseid
        i.cid = case_id(i.lastname,i.round,i.ms)

        # now write into main sheet
        update!(client, CellRange(sheet,"List!A$(row_number):J$(row_number)"), reshape(strip.(collect(i[[:ms,:round,:firstname,:lastname,:cid,:title, :email, :editor, :data_policy, :arrival_date_ee,]])), 1, :))
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
