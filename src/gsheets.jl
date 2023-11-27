


EJ_id() = "1D7nhTs8ao9yIW-PQ_z4zjYNB3pGMWcLWABtaA4I_WL0"
# Example based upon: # https://developers.google.com/sheets/api/quickstart/python

gs_reader() = sheets_client(AUTH_SCOPE_READONLY)

function gs_read(; journal = "EJ")
    if journal == "EJ"
        sheet = Spreadsheet(EJ_id())
        range = CellRange(sheet, "A2:M1054")
    else
        println("not done yet")
    end
    result = get(gs_reader(), range)
    return result
end


# if isnothing(result.values)
#     println("No data found.")
# else
#     for row in eachrow(result.values)
#         println("ROW: $row")
#     end

#     println("")
#     println("Name, Major:")
#     for row in eachrow(result.values)
#         # Print columns A and E, which correspond to indices 1 and 5.
#         println("ROW: $(row[1]), $(row[5])")
#     end
# end