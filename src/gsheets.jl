
"turn off test mode"
function prod()
    global istest = false
    nothing
end

function reload_all()
    update_ej()
    db_refresh_token()
end

function reset_gs!()
    rm(joinpath(ENV["HOME"],".julia","config","google_sheets","google_sheets_token.0.pickle"),force = true)
    rm(joinpath(ENV["HOME"],".julia","config","google_sheets","google_sheets_token.1.pickle"),force = true)
    rm(joinpath(ENV["HOME"],".julia","config","google_sheets","google_sheets_token.10.pickle"),force = true)
end


"update EJ google sheets"
function update_ej()
    d[] = gs_read()
    r[] = get_replicators()
    new_arrivals[] = get_new_arrivals()
    nothing
end

EJ_id() = istest ? "1Uw6uj_yZhsri5fjcjqkgHZRYqyjmWOMnPahARcO4aNY" : "1D7nhTs8ao9yIW-PQ_z4zjYNB3pGMWcLWABtaA4I_WL0"
# Example based upon: # https://developers.google.com/sheets/api/quickstart/python

gs_reader() = sheets_client(AUTH_SCOPE_READONLY)
gs_readwrite() = sheets_client(AUTH_SCOPE_READWRITE)


# EJ spreadsheet row and column constants
ej_ranges() = Dict("maxcol" => "AE", 
               "de_comments" => "N",
               "dropbox_id" => "O",
               "row_number" => "P",
               "maxrow" => 1800,
               )
ej_row_offset() = 900  # do not read first 900 rows

"Dates parsed as strings in this format from gsheet"
gs_dates() = dateformat"d-u-YYYY"

gs_dateformat() = "d-u-YYYY"

function gs_read(;journal = "EJ", range = "List!A$(ej_row_offset()):$(ej_ranges()["maxcol"])$(ej_ranges()["maxrow"])")
    if istest
        println("testing mode")
    else
        @warn "not in test mode!"
    end
    if journal == "EJ"
        sheet = Spreadsheet(EJ_id())
        names = "List!A2:$(ej_ranges()["maxcol"])2"
        range = CellRanges(sheet, [names,range])
    else
        println("not done yet")
    end
    s = get(gs_reader(), range)
    d = @clean_names DataFrame(s[2].values, s[1].values[:])
    # make sure that row_number is correct and sheet is ordered
    nrows = sum(d.ms .!= "")
    rn = d[.!(d.ms .== ""), :row_number]
    @assert all(rn .== string.(Base.range(ej_row_offset(),ej_row_offset() + nrows - 1 )))

    # also that case id is correct whenever last name is given
    transform!(d, [:lastname, :round, :ms] => 
        ((x,y,z) -> case_id.(x,y,z)) => :case_id2
    )
    # return d
    # TODO compute a case id for all missing lastnames as well
    assert_ids = findall(d[.!(d.lastname .== ""), :case_id] .!= d[.!(d.lastname .== ""), :case_id2])
    if length(assert_ids) > 0
        @error "wrong case id" d[.!(d.lastname .== ""),:][assert_ids, [:case_id, :case_id2, :row_number]] 
    end

    mydate(x) = Date(x, "d-u-yyyy")
    mydatemissing(x) = passmissing(mydate) 


    # fix up dates would look like this (not doing this now)
    # transform!(d,
    #     [:arrival_date_package, :arrival_date_ee, :date_assigned, :date_completed] .=> (y -> passmissing.(dateparse.(y))) .=>
    #     [:arrival_date_package, :arrival_date_ee, :date_assigned, :date_completed]
    #     )

    select!(d, Not(:case_id2))
    d
end


"gets new arrivals from the editorial office"
function get_arrivals_new(;journal = "EJ")
    if journal == "EJ"
        sheet = Spreadsheet(EJ_id())
    else
        println("not done yet")
    end
    s = get(gs_reader(), CellRange(sheet, "arrivals"))
    
    o = DataFrame(s.values[2:end,:], s.values[1,:])
    rename!(o, ["arrival_date_de","ms","title","arrival_date_ee","firstname_author","lastname_author","email_author","email_author2","editor","comments"])
    o[!,:arrival_date_de] = Date.(o[!,:arrival_date_de], dateformat"d/m/YYYY H:M:S")
    o[!,:arrival_date_ee] = Date.(o[!,:arrival_date_ee], dateformat"d/m/YYYY")
    transform!(o, 
        [:email_author2, :comments] .=> (x -> replace(x, "" => missing)) .=> [:email_author2, :comments],
        # [:email_author, :email_author2] .=> (x -> replace(x, r"\n|\t" => "")) .=> [:email_author, :email_author2]
        [:firstname_author, :lastname_author] .=> (x -> strip.(x, ['\n','\t',' '])) .=> [:firstname_author, :lastname_author]
        )
    # clean out tabs and linebreaks from entire dataframe
    mapcols!(x -> replace(x, "\t" => "","\t" => ""),o)
    o
end

# join( [join([s.values[i,j] for j in axes(s.values, 2)], '\t') for i in axes(s.values, 1)], '\n')

function get_new_arrivals(;journal = "EJ")
    if journal == "EJ"
        sheet = Spreadsheet(EJ_id())
    else
        println("not done yet")
    end
    s = get(gs_reader(), CellRange(sheet, "New-Arrivals!A2:J30"))
    
    o = if size(s.values)[1] == 1
        DataFrame([k => String[] for k in s.values[1,:]])
    else
        DataFrame(s.values[2:end,:], s.values[1,:])
    end
    @clean_names o
end

function get_replicators()

    sheet = Spreadsheet(EJ_id())
    s = get(gs_reader(), CellRange(sheet, "Replicator-Availability"))
    
    @clean_names DataFrame(s.values[2:end,:], s.values[1,:])

end

# function gs_refresh()


function gs_test()
    client = gs_readwrite()
    # add a sheet
    sheet = Spreadsheet(EJ_id())
    add_sheet!(client, sheet, "test-sheet")
    println()
    show(client, sheet, "test-sheet")

    update!(client, CellRange(sheet,"test-sheet!A1"), fill("hello world",1,1))

    delete_sheet!(client, sheet, "test-sheet")

end


# this needs to write into the main sheet and delete in the arrivals sheet
function fr_write_gsheet(client, sheet, row_number, id)# store fr id somewhere. best on the share google sheet
    update!(client, CellRange(sheet,"List!A$(row_number):D$(row_number)"), ["waiting" id])  # column M holds the id of the file request
    update!(client, CellRange(sheet,"List!$(ej_ranges["de_comments"])$(row_number):$(ej_ranges["dropbox_id"])$(row_number)"), ["waiting" id])  # column M holds the id of the file request
end

