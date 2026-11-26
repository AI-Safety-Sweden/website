module Evergreen.V7.UserTable exposing (..)

import Array
import Evergreen.V7.Id
import SeqDict
import SeqSet


type alias EditedUser =
    { name : String
    , email : String
    }


type UserTableId
    = ExistingUserId (Evergreen.V7.Id.Id Evergreen.V7.Id.UserId)
    | NewUserId Int


type UserColumn
    = NameColumn
    | EmailAddressColumn


type alias EditingCell =
    { userId : UserTableId
    , column : UserColumn
    , text : String
    }


type alias UserTable =
    { changedUsers : SeqDict.SeqDict (Evergreen.V7.Id.Id Evergreen.V7.Id.UserId) EditedUser
    , editingCell : Maybe EditingCell
    , newUsers : Array.Array EditedUser
    , deletedUsers : SeqSet.SeqSet (Evergreen.V7.Id.Id Evergreen.V7.Id.UserId)
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
    | PressedResetUser (Evergreen.V7.Id.Id Evergreen.V7.Id.UserId)
    | FocusedOnEditCell


type alias UserChanges =
    { changedUsers : SeqDict.SeqDict (Evergreen.V7.Id.Id Evergreen.V7.Id.UserId) EditedUser
    , newUsers : Array.Array EditedUser
    , deletedUsers : SeqSet.SeqSet (Evergreen.V7.Id.Id Evergreen.V7.Id.UserId)
    }
