use crate::schema::*;
use chrono::prelude::*;
use serde_derive::{Deserialize, Serialize};

#[derive(Insertable, Identifiable, Queryable, AsChangeset, Clone, Debug, Serialize, Deserialize)]
#[table_name = "entries"]
pub struct Entry {
    pub id: i32,
    pub title: String,
    pub description: Option<String>,
    pub spend_time: i32,
    pub logdate: NaiveDate,
    pub entry_type: String,
}

#[derive(AsChangeset, Insertable, Clone, Debug, Serialize, Deserialize)]
#[table_name = "entries"]
pub struct EntryForm {
    pub title: String,
    pub description: Option<String>,
    pub spend_time: i32,
    pub logdate: NaiveDate,
    pub entry_type: String,
}

#[derive(Insertable, Identifiable, Queryable, AsChangeset, Clone, Debug, Serialize, Deserialize)]
pub struct User {
    pub id: i32,
    pub name: String,
    pub password: String,
}

#[derive(Insertable, Identifiable, Queryable, AsChangeset, Clone, Debug, Serialize, Deserialize)]
pub struct Session {
    pub id: i32,
    pub user_id: i32,
    pub key: String,
}
