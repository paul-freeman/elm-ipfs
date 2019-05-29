module Ipfs exposing
    ( add
    , File, Hash, hash, getHash
    , cat, version
    , postGeneric, getGeneric, generic
    )

{-|


# Writing to IPFS

@docs add


# Ipfs files and hashes

@docs File, Hash, hash, getHash


# Reading from IPFS

@docs cat, version


# Helpers

@docs postGeneric, getGeneric, generic

-}

import Http exposing (Body, Error, emptyBody, multipartBody, stringPart, stringResolver)
import Json.Decode as D exposing (Decoder, decodeString, errorToString)
import Result exposing (mapError)
import Task exposing (Task)
import Url exposing (Url)
import Url.Builder exposing (crossOrigin, string)



-- IPFS files


{-| Represents a content-addressable (immutable) file, stored on IPFS.
-}
type File
    = File
        { name : String
        , hash : Hash
        , size : String
        }


{-| Store a string as a content-addressable file on IPFS.
-}
add : String -> String -> Task Error File
add prePath dataString =
    postGeneric
        { url = crossOrigin prePath [ "api", "v0", "add" ] []
        , body = multipartBody [ stringPart "file" dataString ]
        , resolver = decodeString decodeFile >> mapError errorToString
        }


{-| A hash value representing the address of a file on IPFS.
-}
type Hash
    = Hash String


{-| Turn an IPFS hash string into the suitable type for retrieving a file.
-}
hash : String -> Maybe Hash
hash =
    Just << Hash


{-| Get the hash value from a File data structure.
-}
getHash : File -> Hash
getHash (File p) =
    p.hash


{-| Retrieve a string from a content-addressable file on IPFS.
-}
cat : String -> Hash -> Task Error String
cat prePath (Hash h) =
    getGeneric
        { url =
            crossOrigin prePath
                [ "api", "v0", "cat" ]
                [ string "arg" ("/ipfs/" ++ h) ]
        , resolver = Ok
        }


{-| Retrieve the version information for the IPFS node.
-}
version : String -> Task Error String
version prePath =
    getGeneric
        { url =
            crossOrigin prePath
                [ "api", "v0", "version" ]
                [ string "number" "true" ]
        , resolver = Ok
        }


{-| A general method for posting information to IPFS.
-}
postGeneric :
    { url : String
    , body : Body
    , resolver : String -> Result String a
    }
    -> Task Error a
postGeneric { url, body, resolver } =
    generic { method = "POST", url = url, body = body, resolver = resolver }


{-| A general method for getting information from IPFS.
-}
getGeneric :
    { url : String
    , resolver : String -> Result String a
    }
    -> Task Error a
getGeneric { url, resolver } =
    generic { method = "GET", url = url, body = emptyBody, resolver = resolver }


{-| If you want to implement your own custom IPFS calls, this might get you
started.
-}
generic :
    { method : String
    , url : String
    , body : Body
    , resolver : String -> Result String a
    }
    -> Task Error a
generic { method, url, body, resolver } =
    Http.task
        { method = method
        , headers = []
        , url = url
        , body = body
        , resolver =
            stringResolver
                (\result ->
                    case result of
                        Http.BadUrl_ e ->
                            Err (Http.BadUrl e)

                        Http.Timeout_ ->
                            Err Http.Timeout

                        Http.NetworkError_ ->
                            Err Http.NetworkError

                        Http.BadStatus_ m b ->
                            Err (Http.BadStatus m.statusCode)

                        Http.GoodStatus_ m b ->
                            resolver b
                                |> Result.mapError Http.BadBody
                )
        , timeout = Nothing
        }


decodeFile : Decoder File
decodeFile =
    D.field "Name" D.string
        |> D.andThen
            (\name ->
                D.field "Hash" D.string
                    |> D.andThen
                        (\h ->
                            D.field "Size" D.string
                                |> D.andThen
                                    (\size ->
                                        D.succeed <|
                                            File
                                                { name = name
                                                , hash = Hash h
                                                , size = size
                                                }
                                    )
                        )
            )
