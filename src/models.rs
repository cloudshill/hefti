use chrono::prelude::*;

#[derive(Queryable, Debug, Serialize)]
pub struct Entry {
    pub id: i32,
    pub title: String,
    pub description: Option<String>,
    pub spend_time: i32,
    pub logdate: NaiveDate,
    pub entry_type: String,
}
