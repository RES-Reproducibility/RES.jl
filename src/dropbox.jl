

##################################
# copied from Erik Schnetter's https://github.com/eschnett/DropboxSDK.jl


struct DropboxError
    dict::Dict
end




"""
    struct Authorization
        access_token::String
    end

Contains an access token. Almost all Dropbox API functions require
such a token. Access tokens are like passwords and should be treated
with the same care.
"""
struct Authorization
    access_token::String
end

"""
    mapget(fun::Function, dict::Dict, key, def=nothing)

Get an entry from a dictionary, and apply the function `fun` to the
result. If the key `key` is missing from the dictionary, return the
default value `def`.
"""
function mapget(fun::Function, dict::Dict, key, def=nothing)
    value = get(dict, key, nothing)
    if value === nothing return def end
    fun(value)
end


const try_after = Ref(time())
function set_retry_delay(retry_after::Real)
    @assert retry_after >= 0
    next_try = time() + retry_after
    try_after[] = max(try_after[], next_try)
end
function wait_as_requested()
    delay = try_after[] - time()
    if delay > 0
        println("Info: Waiting $(round(delay, digits=1)) seconds...")
        sleep(delay)
    end
end


function post_http(auth::Authorization,
                   url::String,
                   args::Union{Nothing, Dict} = nothing;
                   content = HTTP.nobody,
                   expecting_content::Bool = false,
                   verbose::Int = 0
                   )::Tuple{Dict, Vector{UInt8}}
    headers = ["Authorization" => "Bearer $(auth.access_token)"]
    if args !== nothing
        json_args = JSON.json(args)
    else
        json_args = nothing
    end

    # Are we sending arguments as body or in a header?
    if content === HTTP.nobody && !expecting_content
        # Arguments as body
        if json_args !== nothing
            push!(headers, "Content-Type" => "application/json")
            body = json_args
        else
            body = HTTP.nobody
        end
    else
        # Arguments in header
        if json_args !== nothing
            push!(headers, "Dropbox-API-Arg" => json_args)
        end
        push!(headers, "Content-Type" => "application/octet-stream")
        body = content
    end

    result = nothing
    result_content = HTTP.nobody

    retry_count = 1
    @label retry

    wait_as_requested()

    try

        response = HTTP.request("POST", url, headers, body;
                                canonicalize_headers=true, verbose=verbose)

        # Are we expecting the result in the body or in a header?
        if !expecting_content
            # Result as body
            json_result = response.body
            result_content = HTTP.nobody
        else
            # Result in header
            json_result = Dict(response.headers)["Dropbox-Api-Result"]
            result_content = response.body
        end

        result = JSON.parse(String(json_result); dicttype=Dict, inttype=Int64)
        if result === nothing
            result = Dict()
        end

    catch exception
        if exception isa HTTP.StatusError
            response = exception.response
            result = try
                JSON.parse(String(response.body); dicttype=Dict, inttype=Int64)
            catch
                Dict("error_summary" =>
                     "No JSON result in HTTP error: $response")
            end
            result["http_status"] = string(exception.status)
            error_summary = get(result, "error_summary",
                                "(no error summary in HTTP error): $response")

            # Should we retry?
            retry_after = mapget(s->parse(Float64, s),
                                 Dict(response.headers), "Retry-After")
            if retry_after !== nothing
                println("Info: Warning $(exception.status): $error_summary")
                set_retry_delay(retry_after)
                @goto retry
            end

            # If this is a real error (e.g. a file does not exist),
            # report in right away without retrying
            if (exception.status in (400, 401, 403, 409) &&
                get(result, ".tag", nothing) != "internal_error")

                throw(DropboxError(result))
            end

            # Too many weird things can go wrong. We will thus retry
            # for any error. If the error goes away, we don't really
            # care. If it persists, we'll give up after several
            # retries.
            println("Info: Error $exception")
            if retry_count >= 3
                println("Info: Giving up after attempt #$retry_count.")
                # The error was properly diagnosed and reported by
                # Dropbox
                throw(DropboxError(result))
            end
            retry_count += 1
            println("Info: Retrying, attempt #$retry_count...")
            sleep(1)
            @goto retry
        end

        # Too many weird things can go wrong. We will thus retry for
        # any error. If the error goes away, we don't really care. If
        # it persists, we'll give up after several retries.
        println("Info: Error $exception")
        if retry_count >= 3
            println("Info: Giving up after attempt #$retry_count.")
            # This is probably not an error in Dropbox
            rethrow()
        end
        retry_count += 1
        println("Info: Retrying, attempt #$retry_count...")
        sleep(1)
        @goto retry

        # elseif (exception isa ArgumentError &&
        #         (exception.msg ==
        #          "`unsafe_write` requires `iswritable(::SSLContext)`"))
        #     # I don't understand this error; maybe it is ephemeral? We
        #     # will retry.
        # elseif (exception isa ErrorException &&
        #         startswith(exception.msg,
        #                    "Unexpected end of input\nLine: 0\n"))
        #     # This is a JSON parsing error. Something went wrong with
        #     # Dropbox's response. We will retry.
        # elseif exception isa Base.IOError
        #     # I don't understand this error; maybe it is ephemeral? We
        #     # will retry.
        # elseif exception isa HTTP.IOExtras.IOError
        #     # I don't understand this error; maybe it is ephemeral? We
        #     # will retry.
    end

    # The request worked -- return
    return result, result_content
end
           


"""
    post_rpc(auth::Authorization,
             fun::String,
             args::Union{Nothing, Dict} = nothing
            )::Dict

Post an RPC request to the Dropbox API.
"""
function post_rpc(auth::Authorization,
                  fun::String,
                  args::Union{Nothing, Dict} = nothing)::Dict
    post_http(auth, "https://api.dropboxapi.com/2/$fun", args)[1]
end

# end copied from Erik Schnetter's https://github.com/eschnett/DropboxSDK.jl
##################################





"""
    db_auth()

Get an authorization token. This function looks for an
environment variable `DROPBOXSDK_ACCESS_TOKEN`
"""
function db_auth()
    access_token = nothing
    if access_token === nothing
        access_token = get(ENV, "DROPBOXSDK_ACCESS_TOKEN", nothing)
    end
    
    if access_token === nothing
        error("Could not find access token for Dropbox")
    end
    Authorization(access_token)
end



"""
    db_fr_count(auth::Authorization)

Counts the number of dropbox file requests.
"""
function db_fr_count(auth::Authorization)
    res = post_rpc(auth, "file_requests/count")
    return res["file_request_count"]
end




