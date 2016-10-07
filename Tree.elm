module Tree exposing (..)

import Array exposing (Array)
import String
import List.Extra as ListExtra
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Lazy exposing (lazy)
import Json.Decode as Json
import Markdown

import Types exposing (..)
import TreeUtils exposing (..)
import TreeSort exposing (..)




-- MODEL

default : Tree
default =
  { uid = "0"
  , content = Content "" "" "" |> withContentId
  , parentId = Nothing
  , children = Children [] 
  , next = Nothing
  , prev = Nothing 
  , visible = True 
  }

blankTree : String -> Tree
blankTree uid =
  { default | uid = uid }




-- UPDATE

type Msg
  = NoOp
  | Activate String
  | UpdateCard String String
  | DeleteCard String
  | OpenCard String String
  | CancelCard
  | InsertBelow String
  | InsertChild String
  | Insert (Maybe String) (Maybe String) (Maybe String)
  | UpdateField String


update : Msg -> Tree -> Tree
update msg tree =
  let
    children =
      case tree.children of
        Children trees -> trees

  in
  case msg of
    NoOp -> tree

    UpdateCard uid str ->
      if tree.uid == uid then
        { tree | content = Content "" "" str |> withContentId }
      else
        { tree | children = Children (List.map (update (UpdateCard uid str)) children) }

    DeleteCard uid ->
      if tree.uid == uid then
        { tree | visible = False }
      else
        { tree | children = Children (List.map (update (DeleteCard uid)) children) }

    Insert parentId prevId_ nextId_ ->
      if Just tree.uid == parentId then
        let
          newTree =
            { uid = newUid parentId prevId_ nextId_
            , parentId = parentId
            , prev = prevId_
            , next = nextId_
            , content = (Content "" "" "" |> withContentId)
            , visible = True
            , children = Children []
            }

          sortedChildren = Children (sortTrees (children ++ [newTree]))
        in
          { tree
            | children = sortedChildren
          }
      else
          { tree | children = Children (List.map (update msg) children) }
    
    InsertChild uid ->
      let
        parentId = Just uid
        prevId_ = getLastChild tree uid
        nextId_ = Nothing
      in
        update (Insert parentId prevId_ nextId_ ) tree

    _ ->
      tree


applyOperations : Array Operation -> Tree -> Tree
applyOperations ops tree =
  Array.foldl applyOp tree ops


applyOp : Operation -> Tree -> Tree
applyOp {opType, params} tree =
  case (Debug.log "opType" opType) of
    "Insert" -> 
      let
        parId = ListExtra.getAt 0 params |> Maybe.withDefault (Nothing)
        prevId = ListExtra.getAt 1 params |> Maybe.withDefault (Nothing)
        nextId = ListExtra.getAt 2 params |> Maybe.withDefault (Nothing)
      in
        update (Insert parId prevId nextId) tree

    "Update" -> 
      let
        uid = 
          ListExtra.getAt 0 params 
            |> Maybe.withDefault (Nothing) 
            |> Maybe.withDefault ""
        str =
          ListExtra.getAt 1 params 
            |> Maybe.withDefault (Nothing) 
            |> Maybe.withDefault "empty"
      in
        update (UpdateCard uid str) tree

    "Delete" -> 
      let
        uid = 
          ListExtra.getAt 0 params 
            |> Maybe.withDefault (Nothing) 
            |> Maybe.withDefault ""
      in
        update (DeleteCard uid) tree

    _ ->
      tree




-- VIEW

viewColumn : ViewState -> Column -> Html Msg
viewColumn vstate col =
  div
    [ class "column" ]
    [ div
        [ class "buffer" ][]
    , div [](List.map (lazy (viewGroup vstate)) col)
    , div
        [ class "buffer" ][]
    ]


viewGroup : ViewState -> Group -> Html Msg
viewGroup vstate xs =
  let
    firstChild = 
      xs
        |> List.head
        |> Maybe.withDefault default
        |> .uid

    isActiveDescendant =
      vstate.descendants
        |> List.member firstChild
  in
    div [ classList [ ("group", True)
                    , ("active-descendant", isActiveDescendant)
                    ]
        ]
        (List.map (lazy (viewCard vstate)) xs)


viewCard : ViewState -> Tree -> Html Msg
viewCard vstate tree =
  let
    hasChildren =
      case tree.children of
        Children [] -> False
        _ -> True
  in
    div [ id ("card-" ++ tree.uid)
        , classList [ ("card", True)
                    , ("active", vstate.active == tree.uid)
                    , ("editing", vstate.editing == Just tree.uid)
                    , ("has-children", hasChildren)
                    ]
        ]
        [ div  [ class "view" 
                , onClick (Activate tree.uid)
                , onDoubleClick (OpenCard tree.uid tree.content.content)
                ] [ Markdown.toHtml [] tree.content.content ]
        , textarea
            [ id ( "card-edit-" ++ tree.uid )
            , classList [ ("edit", True)
                        , ("mousetrap", True)
                        ]
            , value vstate.field
            , onBlur CancelCard
            , onInput UpdateField
            ]
            []
        ]




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