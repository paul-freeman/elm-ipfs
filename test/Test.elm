module Test exposing (main)

import Browser
import Html
import Ipfs
import Task


type Msg
    = SavePrimes (Result Ipfs.Error Ipfs.Link)


showReadme : Cmd Msg
showReadme =
    Task.attempt SavePrimes <|
        case Ipfs.node "http://127.0.0.1:5001" of
            Just node ->
                Ipfs.add node "primes.txt" "2, 3, 5, 7, 11, 13, 17"

            Nothing ->
                Task.fail <| Ipfs.IpfsError "invalid node or hash"


main : Program () String Msg
main =
    Browser.element
        { init = always ( "testing", showReadme )
        , view = Html.text >> List.singleton >> Html.pre []
        , subscriptions = always Sub.none
        , update =
            \(SavePrimes result) _ ->
                case result of
                    Ok x ->
                        ( Debug.toString x, Cmd.none )

                    Err x ->
                        ( Ipfs.errorToString x, Cmd.none )
        }
