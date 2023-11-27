using RES
using Test

@testset "RES.jl" begin
    @testset "dropbox functions" begin
        a = db_auth()
        @test !isnothing(a)

        c = RES.db_fr_count(a)
        @test c isa Number 

    end
end
