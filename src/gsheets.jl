


EJ_id() = istest ? "1Uw6uj_yZhsri5fjcjqkgHZRYqyjmWOMnPahARcO4aNY" : "1D7nhTs8ao9yIW-PQ_z4zjYNB3pGMWcLWABtaA4I_WL0"
# Example based upon: # https://developers.google.com/sheets/api/quickstart/python

gs_reader() = sheets_client(AUTH_SCOPE_READONLY)
gs_readwrite() = sheets_client(AUTH_SCOPE_READWRITE)

ej_row_offset() = 900
ej_cols() = "AB"

function gs_read(;journal = "EJ", range = "List!A$(ej_row_offset()):$(ej_cols())1300")
    println("istest is $istest")
    if journal == "EJ"
        sheet = Spreadsheet(EJ_id())
        names = "List!A2:$(ej_cols())2"
        range = CellRanges(sheet, [names,range])
    else
        println("not done yet")
    end
    s = get(gs_reader(), range)
    @clean_names DataFrame(s[2].values, s[1].values[:])
end

function get_new_arrivals(;journal = "EJ")
    if journal == "EJ"
        sheet = Spreadsheet(EJ_id())
    else
        println("not done yet")
    end
    s = get(gs_reader(), CellRange(sheet, "New-Arrivals!A2:I30"))
    
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

function fr_write_gsheet(client, sheet, row_number, id)# store fr id somewhere. best on the share google sheet
    update!(client, CellRange(sheet,"List!L$(row_number):M$(row_number)"), ["waiting" id])  # column M holds the id of the file request
end

