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
