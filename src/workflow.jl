
function case_id(lastname,round,ms)
    if lastname == ""
        ""
    else
        ln = split(strip(lastname))[1]
        string(ln,"-",strip(ms),"-R",strip(round))
    end
end


function count_published_ej()
    @chain RES.d[] begin
       subset(:status => ByRow(∈(["NT","P","p"])), :date_assigned => ByRow(!=("")))
       transform(:date_assigned => (x -> year.(Date.(x, "d-u-yyyy"))) => :year_assigned)
       groupby(:year_assigned)
       combine(nrow)
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
            select(:case_id,:round,:status,:checker1,:email,:email_2)
        end
    end
end

"""
    find active relicator jobs

lists ongoing packages (i.e not published)
"""
macro findar(n)
    quote
        @chain d[] begin
            subset(:checker1 => ByRow( contains($n) ), :status => ByRow(∈(["A","B","R"])))
            transform(:date_assigned => (x -> Dates.today() .- Dates.Date.(x,gs_dates())) => :days_since_assigned)
            select(:days_since_assigned,:case_id,:round,:status,:checker1,:checker2,)
            sort(:days_since_assigned)
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
        select(:case_id,:round,:status,:arrival_date_package,:email,:email_2)
    end
end

intparse(x::String) = x == "" ? missing : parse(Int,x) 
function dateparse(x::String) 
    if x == ""
        missing
    else
        try
            Dates.Date(x,gs_dates())
        catch
            try
                Dates.Date(x,dateformat"yyyy-mm-dd")
            catch
                println(x)
                missing
            end            
        end
    end
end


"""
filter published papers
"""
filter_published(x::DataFrame) = subset(x, :status => ByRow(x -> x .∈ Ref(["AP","NT","nt", "P", "p"])))

"""
list unpublished packages which have more than `rounds` rounds
"""
function packages_round(rounds::Int)
    published = @chain d[] begin
        filter_published(_)
        Array(select(_,:ms))
        unique(_)
    end
        # fix missing arrival date field
        # x[, arrival_date := as.Date(max(arrival_date_ee, arrival_date_package,na.rm = TRUE)), by = .(ms, round)]
        # x[(!is.finite(arrival_date)) | is.na(arrival_date) , arrival_date := date_assigned]


    
    # return published
    @chain d[] begin
        transform(
        [:arrival_date_package, :arrival_date_ee, :date_assigned, :date_completed] .=> (y -> dateparse.(y)) .=>
        [:arrival_date_package, :arrival_date_ee, :date_assigned, :date_completed]
        )
        subset(:ms => ByRow(x -> x ∉ published))
        subset(:round => ByRow(x -> x != ""))
        transform(:round => ByRow(intparse) => :round)
        groupby([:ms,:round])
        transform(AsTable([:arrival_date_ee, :arrival_date_package, :date_assigned]) .=> ByRow(x -> maximum(skipmissing(x),init = missing)) => :arrival_date)
        groupby(:ms)
        transform( :arrival_date => ( x -> x .== minimum(x)) => :first_arrival)
        groupby(:ms)

        subset(:round => (x -> x .== maximum((x))))
        subset(:round => ByRow(>(rounds)))
        transform(:first_arrival => (x -> Dates.today() .- x) => :days_with_de)
        # select(:case_id,:round,:status,:arrival_date_ee, :arrival_date_package, :date_assigned,:arrival_date)
        select(:case_id,:round,:email,:ms,:editor)
        unique(_)
    end
end

function lw(;r = nothing)
    if isnothing(r)
        x = @chain d[] begin
            subset(:de_comments =>ByRow(==("waiting")))
            select(:case_id,:round,:status,:arrival_date_package,:email,:ms,:editor)
        end
        mss = unique(Array(select(subset(x,:round => ByRow(x -> parse(Int,x) > 1)), :ms)))
        @chain RES.d[] begin
            transform(:round => (x -> intparse.(x)) => :round)
            subset(:ms => ByRow(∈(mss)))
            groupby(:ms)
            # subset(:round => x -> x .== maximum(x)-1)
            combine([:round,:date_processed] => ((x,y) -> Dates.today() .- Dates.Date.(y[x .== (maximum(x)-1)], gs_dates())) => :days_waiting)
            outerjoin(x, on = :ms)
            select(:days_waiting,:case_id,:round,:email,:ms, :editor)
            sort!(:days_waiting)
            @aside @chain _ begin
                dropmissing()
                CSV.write(joinpath(@__DIR__,"..","waiting_packages.csv"),_)
            end
        end
    else
            @chain d[] begin
                subset(:de_comments => ByRow(==("waiting")), :round => ByRow(==(r)))
                select(:case_id,:round,:status,:arrival_date_package,:email)
            end
    end        
end


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

"""
1. send email about zenodo good to go and 
2. log DOI in spreadsheet
3. move all reports into archive
4. list all previous round packages to be deleted from dropbox
"""
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

    R"RESr:::ej_zg2g($(strip(i.firstname[1])),$(i.lastname),$(i.email),$(i.email_2),$(i.ms),$(i.round))"
    @info "$(caseid) zenodo good to go email sent."


    cleanup!(caseid)

    @info "cleanup done for $caseid"

end

function cleanup!(caseid; op = mv)
    i = subset(d[], :case_id => ByRow( ==(caseid)))
    spath = joinpath(ENV["JL_DB_EJ"], "EJ-2-submitted-replication-packages")
    dirs = readdir(spath)
    dd = dirs[contains.(dirs,i.ms)]

    # check that latest version exists as copy in 6-EJ-good-to-go
    # and move there
    if ispath(joinpath(ENV["JL_DB_EJ"], "EJ-6-good-to-go", caseid))
        for id in dd
            op(joinpath(spath,id),joinpath(spath,"archive",id))
        end
        @info "moved folders to archive" dd
    else
        @warn "no copy for $caseid found in $(joinpath(ENV["JL_DB_EJ"], "EJ-6-good-to-go"))"
    end

    # also move reports to archive
    rpath = joinpath(ENV["JL_DB_EJ"], "EJ-3-replication-reports","DE-processed")
    rapath = joinpath(ENV["JL_DB_EJ"], "EJ-3-replication-reports","DE-processed-archive")
    reps = readdir(rpath)
    dr = reps[contains.(reps,i.ms)]
    for id in dr
        op(joinpath(rpath,id),joinpath(rapath,id))
    end
    @info "moved reports to archive" dr
end

"set case id status in spreadsheet"
function set(caseid,status)
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

"recursively traverse a directory and compute total file size"
function dirsize(dirpath)
    total = 0
    for (root,dirs,files) in walkdir(dirpath)
        total += filesize(root)
        for f in files
            file = joinpath(root,f)
            size = filesize(file)
            total += size
        end
    end
    total
end


"""
Package Good To Go Message

1. get case id of package
2. send email to author and ej editorial office
"""
function g2g(caseid; copy = true, draft = false)

    # get full record
    i = subset(d[], :case_id => ByRow( ==(caseid)))

    fsize = dirsize(joinpath(ENV["JL_DB_EJ"], "EJ-2-submitted-replication-packages", caseid))
    if fsize < 3000000
        @warn "$caseid package has less than $(Humanize.datasize(fsize)) hence is probably online only in dropbox ATM"
        a = ask(DefaultPrompt(["y", "no"], 1, "Do you want to go ahead and send the good-to-go email anyway?"))
    
        if a == "y"
            
        else
            error("first copy that package to good-to-go folder!")
        end

    end

    # update corresponding row in google sheet
    # prepare the gsheet writer API
    sheet = Spreadsheet(EJ_id())
    client = gs_readwrite()

    #update row
    i.date_processed .= Dates.format(Dates.today(), gs_dateformat())
    i.date_resub .= Dates.format(Dates.today(), gs_dateformat())
    i.decision .= "A"
    i.decision_comment .= "accept"
    i.de_comments .= ""
    i.status .= "AP"
    update!(client, CellRange(sheet,"List!A$(i.row_number[1]):$(ej_ranges()["maxcol"])$(i.row_number[1])"), Array(i))

    # copy package to good-to-go folder
    if copy cp(joinpath(ENV["JL_DB_EJ"], "EJ-2-submitted-replication-packages", caseid), joinpath(ENV["JL_DB_EJ"], "EJ-6-good-to-go", caseid), force = true) end


    R"RESr:::ej_g2g($(strip(i.firstname[1])),$(i.lastname),$(i.email),$(i.email_2),$(i.ms),$(i.round), draft = $(draft))"


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
    i.date_assigned .= Dates.format(Dates.today(), gs_dateformat())
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
            i.arrival_date_package = Dates.format(Dates.today(), gs_dateformat())
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
        R"RESr:::ej_randr($(strip(i.firstname)),$(split(i.lastname)[1]),$(i.email),$(i.email_2),$(i[:ms]),$(i.title),$(tmp_url),$(j.round))"


        # modify current round and write on spreadsheet. index j!
        j.status = "R"
        j.case_id = case_id(j.lastname,j.round,j.ms)
        j.date_processed = Dates.format(Dates.today(), gs_dateformat())
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
        R"RESr:::ej_randr($(strip(i.firstname)),$(split(i.lastname)[1]),$(i.email),$(i.email_2),$(i[:ms]),$(i.title),$(tmp_url),$(j.round), attachment = FALSE)"


        # modify current round and write on spreadsheet. index j!
        j.status = "R"
        j.case_id = case_id(j.lastname,j.round,j.ms)
        j.date_processed = Dates.format(Dates.today(), gs_dateformat())
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

        i.round = "1"
        i.lastname = strip(i.lastname, ['\n','\t',' '])
        fname = case_id(i.lastname,i.round,i.ms)
        fr_dict[fname] = db_fr_create(db_au, string("EJ Replication Package: ",fname), joinpath("/EJ/EJ-2-submitted-replication-packages",fname))
        fr_dict[fname]["firstname"] = i[:firstname]

        # clean email field
        i.email = replace(i.email, r"\n|\t" => "")
        i.email_2 = replace(i.email_2, r"\n|\t" => "")

        # compute caseid
        i.cid = case_id(i.lastname,i.round,i.ms)

        # now write into main sheet
        # clean up this data first 
        invec = collect(i[[:ms,:round,:firstname,:lastname,:cid,:title, :email,:email_2, :editor, :data_policy, :arrival_date_ee,]])
        iinvec = replace(invec, "\t" => "", "\n" => "")
        update!(client, CellRange(sheet,"List!A$(row_number):K$(row_number)"), reshape(strip.(iinvec), 1, :))
        update!(client, CellRange(sheet,"List!N$(row_number):O$(row_number)"), ["waiting" fr_dict[fname]["id"]])

        tmp_url = fr_dict[fname]["url"]

        # send email via R
        R"RESr:::ej_filerequest($(i[:firstname]),$(i[:email]),$(i[:email_2]),$(i[:ms]),$(tmp_url),draft = FALSE)"

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
