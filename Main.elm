port module Main exposing (..)


import Dom
import Html exposing (..)
import Html.App as App
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Json
import List.Extra exposing (find, last)
import Task


main : Program (Maybe Model)
main =
  App.programWithFlags
    { init = init
    , view = view
    , update = update
    , subscriptions = \_ -> Sub.none
    }




-- MODEL


type alias Model =
  { content : List Content
  , nodes : List Node
  , viewState : ViewState
  , root : Id
  }

type alias ViewState =
  { active : Uid
  }

type alias Content =
  { id : Id
  , contentType : String
  , content : String
  }

type alias Node =
  { id : Id
  , content : Id
  , children : List Id
  }

type alias Tree = 
  { uid : Uid
  , content : Content
  , children : Children
  }

type Children = Children (List Tree)
type alias Id = String
type alias Uid = Int
type alias Group = List Tree
type alias Column = List (List Tree)


defaultContent : Content
defaultContent =
  { id = "0"
  , contentType = "text/markdown"
  , content = "defaultContent"
  }


defaultModel : Model
defaultModel =
  { content = [defaultContent, { defaultContent | id = "1", content = "2" }]
  , nodes = [Node "0" "0" ["1"], Node "1" "1" []]
  , viewState = ViewState 0
  , root = "0"
  }


init : Maybe Model -> ( Model, Cmd Msg )
init savedModel =
  case savedModel of
    Nothing ->
      defaultModel ! [ ]
    Just data ->
      data ! [ ]




-- UPDATE


type Msg
    = NoOp
    | Activate Uid


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    NoOp ->
      model ! []

    Activate uid ->
      { model | viewState = ViewState uid }
        ! []




-- VIEW


view : Model -> Html Msg
view model =
  viewTree model.viewState (buildStructure model)


viewTree : ViewState -> Tree -> Html Msg
viewTree vs x =
  let
    columns = getColumns([[[x]]])
  in
    div [ id "app" ]
        (List.map (viewColumn vs) columns)


viewTreeContent : ViewState -> Tree -> Html Msg
viewTreeContent vs x =
    div [ id ("card-" ++ (toString x.uid))
        , classList [("card", True), ("active", vs.active == x.uid)]
        , onClick (Activate x.uid)
        ]
        [ text x.content.content ]
    

viewGroup : ViewState -> Group -> Html Msg
viewGroup vs xs =
  div [ class "group" ]
      (List.map (viewTreeContent vs) xs)


viewColumn : ViewState -> Column -> Html Msg
viewColumn vs col =
  div [ class "column" ]
      (List.map (viewGroup vs) col)


-- STRUCTURING


getChildren : Tree -> List Tree
getChildren x =
  case x.children of
    Children c ->
      c


nodeToTree : Model -> Int -> Node -> Tree
nodeToTree model uid a =
  let
    fmFunction id = find (\a -> a.id == id) model.nodes -- (Id -> Maybe Node)
    imFunction = (\idx -> nodeToTree model (idx + uid + 1))
  in
    { uid = uid
    , content = model.content |> find (\c -> c.id == a.content)
                              |> Maybe.withDefault defaultContent
    , children = a.children -- List Id
                  |> List.filterMap fmFunction -- List Node
                  |> List.indexedMap imFunction -- List Tree
                  |> Children
    }


columnHasChildren : Column -> Bool
columnHasChildren col =
  col |> List.concat
      |> List.any (\x -> (getChildren x) /= [])


nextColumn : Column -> Column
nextColumn col =
  (List.map getChildren (List.concat col))


getColumns : List Column -> List Column
getColumns cols =
  let
    col = case (last cols) of
      Nothing -> [[]]
      Just c -> c
    hasChildren = columnHasChildren col
  in
    if hasChildren then
      getColumns(cols ++ [nextColumn(col)])
    else
      cols


buildStructure : Model -> Tree
buildStructure model =
  model.nodes -- List Node
    |> find (\a -> a.id == model.root) -- Maybe Node
    |> Maybe.withDefault (Node "0" "0" []) -- Node
    |> nodeToTree model 0 -- Tree




--HELPERS


onEnter : Msg -> Attribute Msg
onEnter msg =
  let
    tagger code =
      if code == 13 then
        msg
      else NoOp
  in
    on "keydown" (Json.map tagger keyCode)
