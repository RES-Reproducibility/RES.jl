
function create_example_package(; name = "Oswald-123456-R1")

    # setup folder structure

    haskey(ENV, "EJ_DB") || error("EJ_DB env var not set")

    ej = ENV["EJ_DB"]

    # paths
    root = joinpath(ej, "EJ-2-submitted-replication-packages", name)
    pkg = joinpath(root,"3-replication-package")
    cpkg = joinpath(root,"4-confidential-data-not-for-publication")

    @info "creating example package at $root"

    mkpath(joinpath(root,"1-paper"))
    mkpath(joinpath(root,"2-appendices"))

    mkpath(pkg)
    mkpath(cpkg)

    mkpath(joinpath(pkg,"data"))
    mkpath(joinpath(pkg,"code"))
    mkpath(joinpath(pkg,"output"))
    

    # create data content
    ipath = joinpath(pkgdir(DataFrames), "docs", "src", "assets", "iris.csv")
    cp(ipath, joinpath(pkg,"data","iris.csv"), force = true)
    cp(ipath, joinpath(cpkg,"iris.csv"), force = true)

    # create code content
    generate(joinpath(pkg,"code","Oswald.jl"))

    # create a readme
    open(joinpath(pkg,"README.md"), "w") do io
        println(io, "# $name Replication Package")
        println(io, "\nIn this package you will find code, data and output for the $name package. Have fun! ✌️")
        println(io, "\nAs you can see, there is a lot of important info missing. Checkout [our readme](https://www.templatereadme.org) generator and our dedicated [website](https://ejdataeditor.github.io/package.html) for more info.")
    end

    # zip up
    cd(root)
    run(`zip -r 3-replication-package.zip 3-replication-package -q`)
    run(`zip -r 4-confidential-data-not-for-publication.zip 4-confidential-data-not-for-publication -q`)

    # cleanup
    rm(pkg, force = true, recursive = true)
    rm(cpkg, force = true, recursive = true)

    # zip entire package
    run(`zip -r full-package.zip . -q`)

    # remove all but root.zip
    rm(joinpath(root,"1-paper"), force = true, recursive = true)
    rm(joinpath(root,"2-appendices"), force = true, recursive = true)
    rm("$(pkg).zip", force = true, recursive = true)
    rm("$(cpkg).zip", force = true, recursive = true)

    @info "done."

end