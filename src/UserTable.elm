module UserTable exposing
    ( EditedUser
    , EditingCell
    , Msg(..)
    , UserChanges
    , UserColumn
    , UserTable
    , UserTableId
    , UsersChangeError(..)
    , applyChanges
    , applyEditingCell
    , errorText
    , hasChanges
    , init
    , update
    , view
    )

{-| An editable table of users, adapted from the one in at-chat's admin page. Edits are kept
locally (changed, new and deleted rows are highlighted) until "Save changes" is pressed.
-}

import Array exposing (Array)
import Effect.Browser.Dom as Dom exposing (HtmlId)
import Effect.Command as Command exposing (Command, FrontendOnly)
import Effect.Task as Task
import EmailAddress
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events
import Id exposing (Id, UserId)
import Json.Decode
import SeqDict exposing (SeqDict)
import SeqSet exposing (SeqSet)
import Style
import Time
import User exposing (User)


type UserTableId
    = ExistingUserId (Id UserId)
    | NewUserId Int


type alias UserTable =
    { changedUsers : SeqDict (Id UserId) EditedUser
    , editingCell : Maybe EditingCell
    , newUsers : Array EditedUser
    , deletedUsers : SeqSet (Id UserId)
    }


type alias EditingCell =
    { userId : UserTableId, column : UserColumn, text : String }


type alias EditedUser =
    { name : String
    , email : String
    }


type UserColumn
    = NameColumn
    | EmailAddressColumn


type alias UserChanges =
    { changedUsers : SeqDict (Id UserId) EditedUser
    , newUsers : Array EditedUser
    , deletedUsers : SeqSet (Id UserId)
    }


type UsersChangeError
    = EmailAddressesAreNotUnique
    | InvalidChangesToUser
    | ChangesAppliedToNonExistentUser
    | CantDeleteYourself
    | InvalidNewUser


type Msg
    = PressedEditCell UserTableId UserColumn
    | TypedEditCell String
    | EditCellLostFocus UserTableId UserColumn
    | EnterKeyInEditCell UserTableId UserColumn
    | TabKeyInEditCell
    | EscapeKeyInEditCell
    | PressedResetUserChanges
    | PressedAddUserRow
    | PressedDeleteUser UserTableId
    | PressedResetUser (Id UserId)
    | FocusedOnEditCell


init : UserTable
init =
    { changedUsers = SeqDict.empty
    , editingCell = Nothing
    , newUsers = Array.empty
    , deletedUsers = SeqSet.empty
    }


hasChanges : UserTable -> Bool
hasChanges userTable =
    not
        (SeqDict.isEmpty userTable.changedUsers
            && Array.isEmpty userTable.newUsers
            && SeqSet.isEmpty userTable.deletedUsers
        )


update : SeqDict (Id UserId) User -> Msg -> UserTable -> ( UserTable, Command FrontendOnly toBackend Msg )
update users msg userTable =
    case msg of
        PressedEditCell userTableId column ->
            let
                userTable2 : UserTable
                userTable2 =
                    applyEditingCell users userTable
            in
            case editedUser userTableId users userTable2 of
                Just user ->
                    ( { userTable2 | editingCell = Just { userId = userTableId, column = column, text = columnText column user } }
                    , Dom.focus editCellTextInputId |> Task.attempt (\_ -> FocusedOnEditCell)
                    )

                Nothing ->
                    ( userTable2, Command.none )

        TypedEditCell text ->
            ( case userTable.editingCell of
                Just editingCell ->
                    { userTable | editingCell = Just { editingCell | text = text } }

                Nothing ->
                    userTable
            , Command.none
            )

        EditCellLostFocus userTableId column ->
            ( applyEditingCellIfAt userTableId column users userTable, Command.none )

        EnterKeyInEditCell userTableId column ->
            ( applyEditingCellIfAt userTableId column users userTable, Command.none )

        TabKeyInEditCell ->
            case userTable.editingCell of
                Just editingCell ->
                    let
                        userTable2 : UserTable
                        userTable2 =
                            applyEditingCell users userTable

                        column : UserColumn
                        column =
                            case editingCell.column of
                                NameColumn ->
                                    EmailAddressColumn

                                EmailAddressColumn ->
                                    NameColumn
                    in
                    case editedUser editingCell.userId users userTable2 of
                        Just user ->
                            ( { userTable2
                                | editingCell = Just { userId = editingCell.userId, column = column, text = columnText column user }
                              }
                            , Dom.focus editCellTextInputId |> Task.attempt (\_ -> FocusedOnEditCell)
                            )

                        Nothing ->
                            ( userTable2, Command.none )

                Nothing ->
                    ( userTable, Command.none )

        EscapeKeyInEditCell ->
            ( { userTable | editingCell = Nothing }, Command.none )

        PressedResetUserChanges ->
            ( init, Command.none )

        PressedAddUserRow ->
            ( { userTable | newUsers = Array.push { name = "", email = "" } userTable.newUsers }
            , Command.none
            )

        PressedDeleteUser userTableId ->
            ( case userTableId of
                ExistingUserId userId ->
                    { userTable
                        | deletedUsers = SeqSet.insert userId userTable.deletedUsers
                        , changedUsers = SeqDict.remove userId userTable.changedUsers
                    }

                NewUserId index ->
                    { userTable
                        | newUsers =
                            Array.append
                                (Array.slice 0 index userTable.newUsers)
                                (Array.slice (index + 1) (Array.length userTable.newUsers) userTable.newUsers)
                    }
            , Command.none
            )

        PressedResetUser userId ->
            ( { userTable
                | changedUsers = SeqDict.remove userId userTable.changedUsers
                , deletedUsers = SeqSet.remove userId userTable.deletedUsers
              }
            , Command.none
            )

        FocusedOnEditCell ->
            ( userTable, Command.none )


applyEditingCellIfAt : UserTableId -> UserColumn -> SeqDict (Id UserId) User -> UserTable -> UserTable
applyEditingCellIfAt userTableId column users userTable =
    case userTable.editingCell of
        Just editingCell ->
            if editingCell.userId == userTableId && editingCell.column == column then
                applyEditingCell users userTable

            else
                userTable

        Nothing ->
            userTable


{-| Keep what's been typed into the cell being edited and stop editing it.
-}
applyEditingCell : SeqDict (Id UserId) User -> UserTable -> UserTable
applyEditingCell users userTable =
    case userTable.editingCell of
        Just editingCell ->
            case editingCell.userId of
                ExistingUserId userId ->
                    case SeqDict.get userId users of
                        Just user ->
                            { userTable
                                | changedUsers =
                                    SeqDict.update
                                        userId
                                        (\maybeChange ->
                                            let
                                                changeA : EditedUser
                                                changeA =
                                                    Maybe.withDefault (userToEditedUser user) maybeChange

                                                changeB : EditedUser
                                                changeB =
                                                    setColumn editingCell.column editingCell.text changeA
                                            in
                                            if changeB == userToEditedUser user then
                                                Nothing

                                            else
                                                Just changeB
                                        )
                                        userTable.changedUsers
                                , editingCell = Nothing
                                , deletedUsers = SeqSet.remove userId userTable.deletedUsers
                            }

                        Nothing ->
                            { userTable | editingCell = Nothing }

                NewUserId index ->
                    { userTable
                        | newUsers =
                            case Array.get index userTable.newUsers of
                                Just newUser ->
                                    Array.set index (setColumn editingCell.column editingCell.text newUser) userTable.newUsers

                                Nothing ->
                                    userTable.newUsers
                        , editingCell = Nothing
                    }

        Nothing ->
            userTable


editedUser : UserTableId -> SeqDict (Id UserId) User -> UserTable -> Maybe EditedUser
editedUser userTableId users userTable =
    case userTableId of
        ExistingUserId userId ->
            case SeqDict.get userId userTable.changedUsers of
                Just change ->
                    Just change

                Nothing ->
                    SeqDict.get userId users |> Maybe.map userToEditedUser

        NewUserId index ->
            Array.get index userTable.newUsers


setColumn : UserColumn -> String -> EditedUser -> EditedUser
setColumn column text user =
    case column of
        NameColumn ->
            { user | name = text }

        EmailAddressColumn ->
            { user | email = text }


columnText : UserColumn -> EditedUser -> String
columnText column user =
    case column of
        NameColumn ->
            user.name

        EmailAddressColumn ->
            user.email


userToEditedUser : User -> EditedUser
userToEditedUser user =
    { name = user.name, email = EmailAddress.toString user.email }


validateEditedUser : EditedUser -> Maybe ( String, EmailAddress.EmailAddress )
validateEditedUser user =
    case ( User.nameFromString user.name, EmailAddress.fromString (String.trim user.email) ) of
        ( Ok name, Just email ) ->
            Just ( name, email )

        _ ->
            Nothing


{-| Used by both the frontend, to show errors before sending, and the backend, to apply the changes.
-}
applyChanges :
    Time.Posix
    -> Id UserId
    -> UserChanges
    -> SeqDict (Id UserId) User
    -> Result UsersChangeError (SeqDict (Id UserId) User)
applyChanges time changedBy { changedUsers, newUsers, deletedUsers } users =
    let
        changed : Result UsersChangeError (SeqDict (Id UserId) User)
        changed =
            SeqDict.foldl
                (\userId change state ->
                    case state of
                        Ok users2 ->
                            case ( SeqDict.get userId users2, validateEditedUser change ) of
                                ( Just user, Just ( name, email ) ) ->
                                    Ok (SeqDict.insert userId { user | name = name, email = email } users2)

                                ( Just _, Nothing ) ->
                                    Err InvalidChangesToUser

                                ( Nothing, _ ) ->
                                    Err ChangesAppliedToNonExistentUser

                        Err _ ->
                            state
                )
                (Ok users)
                changedUsers

        nextId : Int
        nextId =
            SeqDict.keys users |> List.map Id.toInt |> List.maximum |> Maybe.withDefault -1 |> (+) 1

        added : Result UsersChangeError (List ( Id UserId, User ))
        added =
            Array.foldl
                (\newUser state ->
                    case ( state, validateEditedUser newUser ) of
                        ( Ok list, Just ( name, email ) ) ->
                            Ok (( Id.fromInt (nextId + List.length list), { name = name, email = email, createdAt = time } ) :: list)

                        _ ->
                            Err InvalidNewUser
                )
                (Ok [])
                newUsers
    in
    case ( changed, added ) of
        ( Ok changed2, Ok added2 ) ->
            let
                allUsers : SeqDict (Id UserId) User
                allUsers =
                    SeqDict.union
                        (SeqDict.filter (\userId _ -> not (SeqSet.member userId deletedUsers)) changed2)
                        (SeqDict.fromList added2)

                emails : List String
                emails =
                    SeqDict.values allUsers |> List.map (\user -> String.toLower (EmailAddress.toString user.email))
            in
            if SeqSet.member changedBy deletedUsers then
                Err CantDeleteYourself

            else if List.length emails /= SeqSet.size (SeqSet.fromList emails) then
                Err EmailAddressesAreNotUnique

            else
                Ok allUsers

        ( Err error, _ ) ->
            Err error

        ( _, Err error ) ->
            Err error


errorText : UsersChangeError -> String
errorText error =
    case error of
        EmailAddressesAreNotUnique ->
            "Two users have the same email address"

        InvalidChangesToUser ->
            "One or more user rows have invalid fields"

        ChangesAppliedToNonExistentUser ->
            "A user you changed no longer exists. Try reloading the page."

        CantDeleteYourself ->
            "You can't delete yourself"

        InvalidNewUser ->
            "One or more new user rows have invalid fields"


editCellTextInputId : HtmlId
editCellTextInputId =
    Dom.id "userTable_editCell"


validateColumn : UserColumn -> String -> Result String ()
validateColumn column text =
    case column of
        NameColumn ->
            User.nameFromString text |> Result.map (\_ -> ())

        EmailAddressColumn ->
            case EmailAddress.fromString (String.trim text) of
                Just _ ->
                    Ok ()

                Nothing ->
                    Err "Invalid email"


view : Time.Zone -> SeqDict (Id UserId) User -> UserTable -> Html Msg
view zone users userTable =
    let
        rows : List ( UserTableId, EditedUser, Maybe Time.Posix )
        rows =
            List.map
                (\( userId, user ) ->
                    ( ExistingUserId userId
                    , Maybe.withDefault (userToEditedUser user) (SeqDict.get userId userTable.changedUsers)
                    , Just user.createdAt
                    )
                )
                (SeqDict.toList users)
                ++ List.indexedMap (\index user -> ( NewUserId index, user, Nothing )) (Array.toList userTable.newUsers)
    in
    Html.table
        [ Attr.style "border-collapse" "collapse"
        , Attr.style "width" "100%"
        , Attr.style "font-size" "15px"
        ]
        [ Html.thead []
            [ Html.tr []
                (List.map
                    (\title -> Html.th [ Attr.style "text-align" "left", Attr.style "padding" "8px", Attr.style "border-bottom" ("1px solid " ++ Style.borderStrong) ] [ Html.text title ])
                    [ "", "Name", "Email", "Added" ]
                )
            ]
        , Html.tbody []
            (List.map
                (\( userTableId, user, createdAt ) ->
                    Html.tr
                        [ Attr.style "background" (rowColor userTableId userTable)
                        , Attr.style "border-bottom" ("1px solid " ++ Style.border)
                        ]
                        [ Html.td [ Attr.style "padding" "4px 8px", Attr.style "width" "1%" ] [ rowButton userTableId userTable ]
                        , tableCell userTable NameColumn userTableId user
                        , tableCell userTable EmailAddressColumn userTableId user
                        , Html.td
                            [ Attr.style "padding" "8px", Attr.style "color" Style.textFaint, Attr.style "white-space" "nowrap" ]
                            [ case createdAt of
                                Just time ->
                                    Html.text (Style.date zone time)

                                Nothing ->
                                    Html.text "New"
                            ]
                        ]
                )
                rows
            )
        ]


rowColor : UserTableId -> UserTable -> String
rowColor userTableId userTable =
    case userTableId of
        ExistingUserId userId ->
            if SeqSet.member userId userTable.deletedUsers then
                "#F6DADA"

            else if SeqDict.member userId userTable.changedUsers then
                "#F6EDC9"

            else
                "transparent"

        NewUserId _ ->
            "#DCEFE2"


rowButton : UserTableId -> UserTable -> Html Msg
rowButton userTableId userTable =
    let
        resetButton : Id UserId -> Html Msg
        resetButton userId =
            Style.smallButton (PressedResetUser userId) "Undo"
    in
    case userTableId of
        ExistingUserId userId ->
            if SeqDict.member userId userTable.changedUsers || SeqSet.member userId userTable.deletedUsers then
                resetButton userId

            else
                Style.smallButton (PressedDeleteUser userTableId) "Delete"

        NewUserId _ ->
            Style.smallButton (PressedDeleteUser userTableId) "Delete"


tableCell : UserTable -> UserColumn -> UserTableId -> EditedUser -> Html Msg
tableCell userTable column userTableId user =
    let
        editing : Maybe String
        editing =
            case userTable.editingCell of
                Just editingCell ->
                    if editingCell.column == column && editingCell.userId == userTableId then
                        Just editingCell.text

                    else
                        Nothing

                Nothing ->
                    Nothing
    in
    case editing of
        Just text ->
            Html.td [ Attr.style "padding" "2px 4px" ]
                [ Html.input
                    [ Attr.id (Dom.idToString editCellTextInputId)
                    , Attr.type_
                        (case column of
                            NameColumn ->
                                "text"

                            EmailAddressColumn ->
                                "email"
                        )
                    , Attr.value text
                    , Attr.attribute "aria-label" "Edit cell"
                    , Html.Events.onInput TypedEditCell
                    , Html.Events.onBlur (EditCellLostFocus userTableId column)
                    , Html.Events.preventDefaultOn "keydown"
                        (Json.Decode.field "key" Json.Decode.string
                            |> Json.Decode.andThen
                                (\key ->
                                    if key == "Enter" then
                                        Json.Decode.succeed ( EnterKeyInEditCell userTableId column, True )

                                    else if key == "Tab" then
                                        Json.Decode.succeed ( TabKeyInEditCell, True )

                                    else if key == "Escape" then
                                        Json.Decode.succeed ( EscapeKeyInEditCell, True )

                                    else
                                        Json.Decode.fail ""
                                )
                        )
                    , Attr.style "width" "100%"
                    , Attr.style "box-sizing" "border-box"
                    , Attr.style "padding" "6px"
                    , Attr.style "font" "inherit"
                    , Attr.style "border" ("2px solid " ++ Style.accent)
                    , Attr.style "border-radius" "4px"
                    ]
                    []
                ]

        Nothing ->
            let
                text : String
                text =
                    columnText column user
            in
            Html.td
                [ Html.Events.onClick (PressedEditCell userTableId column)
                , Attr.style "padding" "8px"
                , Attr.style "cursor" "text"
                ]
                (case validateColumn column text of
                    Ok () ->
                        [ Html.text text ]

                    Err error ->
                        [ Html.text text
                        , Html.div
                            [ Attr.style "color" Style.error, Attr.style "font-size" "13px" ]
                            [ Html.text error ]
                        ]
                )
