function readlist(journal)
    sheet = Spreadsheet(EJ_id())
    names = "List!A2:$(ej_ranges()["maxcol"])2"
    # range = CellRanges(sheet, [names,range])
    range = "List!A3:$(ej_ranges()["maxcol"])2000"
    range = CellRanges(sheet, [names,range])
    s = get(gs_reader(), range)
    d = @clean_names DataFrame(s[2].values, s[1].values[:]) 

    @chain d begin
        subset(:ms => ByRow(!=("")))
    end

end

function fix_readlist(x::DataFrame)
    d = copy(x)
    # names
    v = @view d[d.lastname .== "", :]
    n = split.(v.firstname)
    v.lastname = last.(n)
    v.firstname = [ join(i[1:(end-1)], " ") for i in n]
    v.case_id = case_id.(v.lastname,v.round,v.ms)


    rename!(d , :arrival_date_ee => :date_arrival_ee, :arrival_date_package => :date_arrival_package)

    # fix commas in numbers
    d.hours_checker1 = replace.(d.hours_checker1, "," => ".")
    d.hours_checker2 = replace.(d.hours_checker2, "," => ".")

    # datatypes
    d.round = parse.(Int,d.round)
    d.date_arrival_ee      = dateparse.(d.date_arrival_ee)
    d.date_arrival_package = dateparse.(d.date_arrival_package)
    d.date_assigned  = dateparse.(d.date_assigned)
    d.date_completed = dateparse.(d.date_completed)
    d.date_processed = dateparse.(d.date_processed)
    d.date_resub = dateparse.(d.date_resub)
    d.hours_checker1 = missparse.(d.hours_checker1 , Float64)
    d.hours_checker2 = missparse.(d.hours_checker2 , Float64)

    # now create a papers and an iterations register each
    # papers register should have latest status as `status`
    iterations = @chain d begin
        groupby(:ms)
        transform(
            ["date_arrival_ee", "date_arrival_package","date_assigned"] =>
            ByRow((x,y,z) -> begin
                if ismissing(x) && ismissing(y)
                    return z
                elseif ismissing(x) && !ismissing(y)
                    return y
                elseif !ismissing(x) && ismissing(y)
                    return x
                else
                    return x
                end
            end) => :date_arrival_cleaned
        )
        # https://discourse.julialang.org/t/row-wise-median-for-julia-dataframes/106922/2
        transform(AsTable([:date_arrival_cleaned, :date_arrival_ee]) => ByRow(t -> emptymissing(minimum)(skipmissing(t))) => :firstdate)        
    end
    papers = @chain iterations begin
        groupby(:ms)
        transform(:firstdate => (x -> maximum(skipmissing(Dates.today() .- x))) => :first_contact_de, ungroup = false)
        subset(:round => x -> x .== maximum(x))  # take final round
    end
    Dict(:iterations => iterations, :papers => papers)

end
