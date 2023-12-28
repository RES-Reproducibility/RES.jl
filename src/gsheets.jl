


EJ_id(; test = true) = test ? "1Uw6uj_yZhsri5fjcjqkgHZRYqyjmWOMnPahARcO4aNY" : "1D7nhTs8ao9yIW-PQ_z4zjYNB3pGMWcLWABtaA4I_WL0"
# Example based upon: # https://developers.google.com/sheets/api/quickstart/python

gs_reader() = sheets_client(AUTH_SCOPE_READONLY)
gs_readwrite() = sheets_client(AUTH_SCOPE_READWRITE)

ej_row_offset() = 900
ej_cols() = "AB"

function gs_read(;test = true, journal = "EJ", range = "A$(ej_row_offset()):$(ej_cols())1300")
    if journal == "EJ"
        sheet = Spreadsheet(EJ_id(test = test))
        names = "A2:$(ej_cols())2"
        range = CellRanges(sheet, [names,range])
    else
        println("not done yet")
    end
    s = get(gs_reader(), range)
    @clean_names DataFrame(s[2].values, s[1].values[:])
end


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

