using RES
using Test
using UUIDs
using Dates


# Avoid colons in the timestamp
timestamp = Dates.format(now(UTC), dateformat"yyyymmdd-HHMMSS.sss")
uuid = UUIDs.uuid4()
folder = "/RES.jl-tests/test-$timestamp-$uuid"
@info "Using folder \"$folder\" for testing"

@testset "RES.jl" begin
    @testset "dropbox functions" begin
        a = db_auth()
        @test !isnothing(a)

        
        @testset "file requests" begin
            c = RES.db_fr_count(a)
            @test c isa Number 

            l = RES.db_fr_list(a)
            @test length(l) > 0
            @test l isa Dict

            dest = folder
            n = RES.db_fr_create(a, "test-freq", dest)
            @test n isa Dict 
            @test n["destination"] == dest
            @test n["url"] == "https://www.dropbox.com/request/$(n["id"])"
            @test n["is_open"]
            @test n["file_count"] == 0

            @test RES.db_fr_count(a) == c + 1
            @test length(RES.db_fr_list(a)["file_requests"]) == c + 1

            RES.db_fr_update(a, n["id"], n["title"], false)  # false: closed

            dn = RES.db_fr_delete(a, [n["id"]])
            @test dn isa Dict
            @test dn["file_requests"][1]["id"] == n["id"]

            @test RES.db_fr_count(a) == c
            @test length(RES.db_fr_list(a)["file_requests"]) == c

        end

    end
end