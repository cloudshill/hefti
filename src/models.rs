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
    #[serde(with = "naive_date_converter")]
    pub logdate: NaiveDate,
    pub entry_type: String,
}

#[derive(AsChangeset, Insertable, Clone, Debug, Serialize, Deserialize)]
#[table_name = "entries"]
pub struct EntryForm {
    pub title: String,
    pub description: Option<String>,
    pub spend_time: i32,
    #[serde(with = "naive_date_converter")]
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

mod naive_date_converter {
    use chrono::{Duration, NaiveDate};
    use serde::{de, ser};
    use std::fmt;

    struct NaiveDateVisitor;

    pub fn serialize<S>(nd: &NaiveDate, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: ser::Serializer,
    {
        let duration = *nd - NaiveDate::from_yo(1970, 1);
        serializer.serialize_i64(duration.num_seconds())
    }

    impl<'de> de::Visitor<'de> for NaiveDateVisitor {
        type Value = NaiveDate;

        fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
            write!(
                formatter,
                "a i64 represents chrono::NaiveDate as a Posix timestamp"
            )
        }

        fn visit_i64<E>(self, s: i64) -> Result<Self::Value, E>
        where
            E: de::Error,
        {
            Ok(NaiveDate::from_yo(1970, 1) + Duration::milliseconds(s))
        }

        fn visit_u64<E>(self, s: u64) -> Result<Self::Value, E>
        where
            E: de::Error,
        {
            Ok(NaiveDate::from_yo(1970, 1) + Duration::milliseconds(s as i64))
        }
    }

    pub fn deserialize<'de, D>(d: D) -> Result<NaiveDate, D::Error>
    where
        D: de::Deserializer<'de>,
    {
        Ok(d.deserialize_i64(NaiveDateVisitor)?)
    }
}
