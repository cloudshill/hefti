table! {
    entries (id) {
        id -> Int4,
        title -> Varchar,
        description -> Nullable<Text>,
        spend_time -> Int4,
        logdate -> Date,
        entry_type -> Text,
    }
}

table! {
    users (id) {
        id -> Int4,
        name -> Text,
        password -> Text,
    }
}

allow_tables_to_appear_in_same_query!(
    entries,
    users,
);
