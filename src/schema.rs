table! {
    entries (id) {
        id -> Int4,
        title -> Varchar,
        description -> Nullable<Text>,
        spend_time -> Int4,
        logdate -> Date,
        entry_type -> crate::models::types::EntryKindType,
    }
}

table! {
    sessions (id) {
        id -> Int4,
        user_id -> Int4,
        key -> Text,
    }
}

table! {
    users (id) {
        id -> Int4,
        name -> Text,
        password -> Text,
    }
}

joinable!(sessions -> users (user_id));

allow_tables_to_appear_in_same_query!(entries, sessions, users,);
