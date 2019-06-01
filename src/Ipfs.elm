module Ipfs exposing
    ( cat, add
    , Node, node
    , Link, Hash(..), hash, toLink, toLinks
    , Error(..), errorToString, version
    )

{-| This module provides access to file storage via [IPFS](https://ipfs.io/).

Many of the concepts and language have been adopted from [this Medium
post](https://medium.com/textileio/whats-really-happening-when-you-add-a-file-to-ipfs-ae3b8b5e4b0f).


# Reading/Writing from IPFS

@docs cat, add


# IPFS Nodes

@docs Node, node


# IPFS Links and Hashes

@docs Link, Hash, hash, toLink, toLinks


# Helpers

@docs postGeneric, getGeneric, generic

-}

import BigInt exposing (BigInt)
import Http
import Json.Decode as D exposing (Decoder, decodeString, errorToString)
import Result exposing (mapError)
import Task exposing (Task)
import Url exposing (Url)
import Url.Builder exposing (crossOrigin, string)


{-| Get string data from IPFS.

Most of the time, this is how you retrieve data from IPFS. You provide the node
and the hash (or hash + path) of the file. This function will traverse the
graph and gather up all the data for the file.

    showReadme : Cmd Msg
    showReadme =
        Task.attempt ShowReadme <|
            case
                Maybe.map2 Tuple.pair
                    (Ipfs.node "http://127.0.0.1:5001")
                    (Ipfs.hash <|
                        "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"
                            ++ "/readme"
                    )
            of
                Just ( node, hash ) ->
                    Ipfs.cat node hash

                Nothing ->
                    Task.fail <| Ipfs.IpfsError "invalid node or hash"

In this example, we are passing a hash _plus_ a path. IPFS will go to the object
pointed to by the hash and look for a link named "readme". If found, it will
follow this link and return the results.

You could also do this same process manually calling [Ipfs.tolink](Ipfs#toLink)
on the hash and "readme". Then you could call this function on the hash in the
resulting link.

-}
cat : Node -> Hash -> Task Error String
cat (Node url) (Hash h) =
    getGeneric
        { url =
            crossOrigin (removeSlash url)
                [ "api", "v0", "cat" ]
                [ string "arg" ("/ipfs/" ++ h) ]
        , goodBodyResolver = Ok
        }


{-| Store string data to IPFS.

This stores data to IPFS, gives it a name, and wraps it in a directory. The link
returned is a link to the directory, which will contain a link to the files. The
link will have metadata containing the file name, hash, and size.

-}
add : Node -> String -> String -> Task Error Link
add (Node url) filename dataString =
    postGeneric
        { url =
            crossOrigin (removeSlash url)
                [ "api", "v0", "add" ]
                [ string "wrap-with-directory" "true"
                , string "stdin-name" filename
                , string "silent" "true"
                ]
        , body = Http.multipartBody [ Http.stringPart filename dataString ]
        , goodBodyResolver = decodeString decodeLink >> mapError DecodeFailure
        }


{-| An IPFS node. Through a node you will have access to any data on it, and its
connected peers.

A `Node` is essentially just the root URL to be used with the [IPFS HTTP
API](https://docs.ipfs.io/reference/api/http/).

-}
type Node
    = Node String


{-| Create a `Node` type.

Creating a `Node` will not fail, but the value is not validated to
ensure it points to a valid IPFS node.

    myIpfs : Node
    myIpfs = node "http://127.0.0.1:5001"

-}
node : String -> Maybe Node
node string =
    Url.fromString string
        |> Maybe.map
            ((\url ->
                { url | query = Nothing, fragment = Nothing }
             )
                >> Url.toString
                >> Node
            )


{-| An IPFS link is a data structure which points to content-addressable
(immutable) files on IPFS.

A link is often just the tip of the iceberg, and may contain many more links,
each containing many more links, and so on. Because of this, not all links
represent a file on IPFS. Some links represent directories of files and some
links represent part of the data within a single files. IPFS reconstructs your
file by starting with a file link and following all the links to their
endpoints.

One way to create a `Link` object is to add a file to IPFS with
[Ipfs.add](Ipfs#add). Another way is get the link from an existing hash using
[Ipfs.toLink](Ipfs#toLink).

Constructing a `Link` object yourself is also possible, but will fail if
the link does not point to a file.

-}
type alias Link =
    { name : String
    , hash : Hash
    , size : BigInt
    }


{-| A hash of some content on IPFS.

Identical content will always generate the same hash. And changing the content
will always generate a new hash.

It is important to note that files will have multiple hashes associated with
them. Even short text files will usually have one hash that points to the link
to the file, and one hash (the one in the link) that points to the content of
the file.

Currently this is only a `String` wrapper. However, the complexities of hashes
implies that it should be considered its own type.

-}
type Hash
    = Hash String


{-| Turn a string into the suitable type for retrieving data from IPFS.

This will not accept empty strings, but anything else is considered a valid
hash.

    readmeHash : Maybe Hash
    readmeHash = Ipfs.hash "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"

-}
hash : String -> Maybe Hash
hash string =
    if String.isEmpty string then
        Nothing

    else
        Just <| Hash string


{-| Get a link with a specific name out of an IPFS hash.

Most of the time, you will probably be working with hashes that point to
objects on IPFS containing a link to your file. This task will retrieve the
object at the given hash, look for a link with the given name, and return
that link to you.

    case
        Maybe.map2
            Tuple.pair
            (Ifps.node "http://127.0.0.1:5001")
            (Ipfs.hash "QmW2WQi7j6c7UgJTarActp7tDNikE4B2qXtFCfLPdsgaTQ")
    of
        Just (node, hash) ->
            Ipfs.toLink node hash "readme"

        Nothing ->
            Task.fail <| Ipfs.IpfsError "invalid node or hash"

**Note:** This does not get the file, but only gets the first object related to
the file. In practice, this is what you want to use to convert a `Hash` into a
`Link`

Internally, this uses the [Ipfs.Object.get](Ipfs-Object#get) task to retrieve
link information from IPFS.

-}
toLink : Node -> Hash -> String -> Task Error (Maybe Link)
toLink n h name =
    toLinks n h
        |> Task.map
            (List.filter (.name >> (==) name)
                >> List.head
            )


{-| The same as <Ipfs#toLink> but returns the complete list of
links. This is useful if you need to look through the list yourself.
-}
toLinks : Node -> Hash -> Task Error (List Link)
toLinks (Node n) (Hash h) =
    objectGet n h
        |> Task.andThen
            (\string ->
                case decodeString decodeLinksFromGet string of
                    Ok link ->
                        Task.succeed link

                    Err err ->
                        Task.fail <| DecodeFailure err
            )


type Error
    = HttpError (Http.Response String)
    | DecodeFailure D.Error
    | IpfsError String


errorToString : Error -> String
errorToString err =
    case err of
        HttpError httpError ->
            case httpError of
                Http.BadUrl_ e ->
                    "Bad Url: " ++ e

                Http.Timeout_ ->
                    "Timeout"

                Http.NetworkError_ ->
                    "Network Error"

                Http.BadStatus_ m _ ->
                    "Bad Status Code: " ++ String.fromInt m.statusCode

                Http.GoodStatus_ m b ->
                    "Good Status error: should not happen and is likely a bug"

        DecodeFailure e ->
            "JSON decode error: " ++ D.errorToString e

        IpfsError e ->
            "IPFS error: " ++ e


{-| Retrieve the version information for the IPFS node.
-}
version : String -> Task Error String
version url =
    getGeneric
        { url =
            crossOrigin (removeSlash url)
                [ "api", "v0", "version" ]
                [ string "number" "true" ]
        , goodBodyResolver = Ok
        }


objectGet : String -> String -> Task Error String
objectGet url hashString =
    getGeneric
        { url =
            crossOrigin (removeSlash url)
                [ "api", "v0", "object", "get" ]
                [ string "arg" ("/ipfs/" ++ hashString) ]
        , goodBodyResolver = Ok
        }


decodeLinksFromGet : Decoder (List Link)
decodeLinksFromGet =
    D.field "Links" (D.list decodeLink)


decodeLink : Decoder Link
decodeLink =
    D.field "Name" D.string
        |> D.andThen
            (\name ->
                D.field "Hash" (D.map hash D.string)
                    |> D.andThen
                        (\maybeHash ->
                            case maybeHash of
                                Just h ->
                                    D.field "Size"
                                        (D.oneOf
                                            [ D.map BigInt.fromIntString D.string
                                            , D.map (Just << BigInt.fromInt) D.int
                                            ]
                                        )
                                        |> D.andThen
                                            (\maybeSize ->
                                                case maybeSize of
                                                    Just size ->
                                                        D.succeed <|
                                                            { name = name
                                                            , hash = h
                                                            , size = size
                                                            }

                                                    Nothing ->
                                                        D.fail "invalid size"
                                            )

                                Nothing ->
                                    D.fail "invalid hash"
                        )
            )


postGeneric :
    { url : String
    , body : Http.Body
    , goodBodyResolver : String -> Result Error a
    }
    -> Task Error a
postGeneric { url, body, goodBodyResolver } =
    generic
        { method = "POST"
        , url = url
        , body = body
        , goodBodyResolver = goodBodyResolver
        }


getGeneric :
    { url : String
    , goodBodyResolver : String -> Result Error a
    }
    -> Task Error a
getGeneric { url, goodBodyResolver } =
    generic
        { method = "GET"
        , url = url
        , body = Http.emptyBody
        , goodBodyResolver = goodBodyResolver
        }


generic :
    { method : String
    , url : String
    , body : Http.Body
    , goodBodyResolver : String -> Result Error a
    }
    -> Task Error a
generic { method, url, body, goodBodyResolver } =
    Http.task
        { method = method
        , headers = []
        , url = url
        , body = body
        , resolver =
            Http.stringResolver
                (\result ->
                    case result of
                        Http.GoodStatus_ m b ->
                            goodBodyResolver b

                        e ->
                            Err (HttpError e)
                )
        , timeout = Nothing
        }


removeSlash : String -> String
removeSlash string =
    if String.endsWith "/" string then
        String.dropRight 1 string

    else
        string
