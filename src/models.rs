use super::schema::*;
use chrono::prelude::*;

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
