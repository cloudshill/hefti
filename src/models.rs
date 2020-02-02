use crate::schema::*;
use chrono::prelude::*;
use serde_derive::{Deserialize, Serialize};
use types::*;

#[derive(Insertable, Identifiable, Queryable, AsChangeset, Clone, Debug, Serialize, Deserialize)]
#[table_name = "entries"]
pub struct Entry {
    pub id: i32,
    pub title: String,
    pub description: Option<String>,
    pub spend_time: i32,
    #[serde(with = "naive_date_converter")]
    pub logdate: NaiveDate,
    pub entry_type: EntryKind,
}

#[derive(AsChangeset, Insertable, Clone, Debug, Serialize, Deserialize)]
#[table_name = "entries"]
pub struct EntryForm {
    pub title: String,
    pub description: Option<String>,
    pub spend_time: i32,
    #[serde(with = "naive_date_converter")]
    pub logdate: NaiveDate,
    pub entry_type: EntryKind,
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

pub mod types {
    use diesel::{
        deserialize,
        deserialize::FromSql,
        pg::Pg,
        serialize,
        serialize::{IsNull, Output, ToSql},
    };
    use serde_derive::{Deserialize, Serialize};
    use std::io::Write;

    #[derive(SqlType, QueryId)]
    #[postgres(type_name = "EntryType")]
    pub struct EntryKindType;

    #[derive(Debug, PartialEq, Copy, Clone, AsExpression, FromSqlRow, Serialize, Deserialize)]
    #[sql_type = "EntryKindType"]
    pub enum EntryKind {
        Work,
        Training,
        School,
    }

    impl ToSql<EntryKindType, Pg> for EntryKind {
        fn to_sql<W: Write>(&self, out: &mut Output<W, Pg>) -> serialize::Result {
            match *self {
                EntryKind::Work => out.write_all(b"work")?,
                EntryKind::Training => out.write_all(b"training")?,
                EntryKind::School => out.write_all(b"school")?,
            }
            Ok(IsNull::No)
        }
    }
    impl FromSql<EntryKindType, Pg> for EntryKind {
        fn from_sql(bytes: Option<&[u8]>) -> deserialize::Result<Self> {
            match not_none!(bytes) {
                b"work" => Ok(EntryKind::Work),
                b"school" => Ok(EntryKind::School),
                b"training" => Ok(EntryKind::Training),
                _ => Err(format!("Unrecognized enum variant").into()),
            }
        }
    }
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
