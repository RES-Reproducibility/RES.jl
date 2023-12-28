


EJ_id() = "1D7nhTs8ao9yIW-PQ_z4zjYNB3pGMWcLWABtaA4I_WL0"
# Example based upon: # https://developers.google.com/sheets/api/quickstart/python

gs_reader() = sheets_client(AUTH_SCOPE_READONLY)
gs_readwrite() = sheets_client(AUTH_SCOPE_READWRITE)

function gs_read(; journal = "EJ")
    if journal == "EJ"
        sheet = Spreadsheet(EJ_id())
        range = CellRange(sheet, "A2:M1054")
    else
        println("not done yet")
    end
    result = get(gs_reader(), range)
    return DataFrame(result)
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
    update!(client, CellRange(sheet,"List!M$(row_number)"), fill(id,1,1))  # column M holds the id of the file request
end

