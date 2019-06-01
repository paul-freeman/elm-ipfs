# Interact with files on IPFS

There are very few file storage options available for Elm which can easily be
incorporated into packages. This package attempts to fix part of this problem by
building file storage on top of the [IPFS HTTP
API](https://docs.ipfs.io/reference/api/http/).

# Using the IPFS API

All of the API calls to IPFS are implemented via
[Http.task](/packages/elm/http/latest/Http#task). By doing this, you are able to
supply callbacks into the IPFS code easily.

## Task example

Here is a minimal complete example showing how to view the 'readme' file on an
IPFS node. It mirrors the example in the [Getting
Started](https://docs.ipfs.io/introduction/usage/) section of the IPFS
documentation.

    import Browser
    import Html
    import Ipfs
    import Task


    type Msg
        = ShowReadme (Result Ipfs.Error String)


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


    main : Program () String Msg
    main =
        Browser.element
            { init = always ( "testing", showReadme )
            , view = Html.text >> List.singleton >> Html.pre []
            , subscriptions = always Sub.none
            , update =
                \(ShowReadme result) _ ->
                    case result of
                        Ok x ->
                            ( x, Cmd.none )

                        Err x ->
                            ( Ipfs.errorToString x, Cmd.none )
            }

You can read more about tasks in the [Task
module](/packages/elm/core/latest/Task).

# Future

I have plans to add more to this - likely mutable files, and encrypted files.
Stay tuned!