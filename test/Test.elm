module Test exposing (main)

import Browser
import Html exposing (Html, button, div, h4, pre, text)
import Html.Events exposing (onClick)
import Http
import Ipfs exposing (Hash, Path, hash, toHash)
import Task
import Url


type alias Flags =
    ()


main : Program Flags Model Msg
main =
    Browser.element
        { init =
            \flags ->
                ( init
                , Task.attempt UpdateReadme <|
                    case originalReadme of
                        Nothing ->
                            Task.fail (Http.BadBody "no file")

                        Just readme ->
                            Ipfs.cat init.client readme
                )
        , subscriptions = \model -> Sub.none
        , view = view
        , update = update
        }


type alias Model =
    { client : String
    , readme : Result Http.Error String
    , readmeFile : Result Http.Error Path
    }


init : Model
init =
    { client = "http://127.0.0.1:5001"
    , readme = Err (Http.BadBody "empty")
    , readmeFile = Err (Http.BadBody "No file")
    }


type Msg
    = CycleReadme
    | UpdateReadme (Result Http.Error String)
    | UpdateReadmeFile (Result Http.Error Path)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        CycleReadme ->
            case model.readmeFile of
                Ok path ->
                    ( { init | client = model.client }
                    , Task.attempt UpdateReadme <|
                        Ipfs.cat model.client <|
                            toHash path
                    )

                _ ->
                    ( model, Cmd.none )

        UpdateReadme resultReadme ->
            ( { model | readme = resultReadme }
            , case resultReadme of
                Ok readme ->
                    Task.attempt UpdateReadmeFile <| Ipfs.add model.client ("copy\u{000D}\n" ++ readme)

                _ ->
                    Cmd.none
            )

        UpdateReadmeFile resultReadmeFile ->
            ( { model | readmeFile = resultReadmeFile }, Cmd.none )


view : Model -> Html Msg
view model =
    div []
        [ button [ onClick CycleReadme ] [ text "Cycle" ]
        , h4 [] [ text "Readme" ]
        , pre [] [ text <| Result.withDefault "Error" model.readme ]
        , h4 [] [ text "File" ]
        , pre [] [ text <| Debug.toString model.readmeFile ]
        ]


originalReadme : Maybe Hash
originalReadme =
    hash
        "QmS4ustL54uo8FzR9455qaxZwuMiUhyvMcX9Ba8nUH4uVv/readme"
