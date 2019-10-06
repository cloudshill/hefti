use chrono::prelude::*;
use diesel::{
    pg::PgConnection,
    r2d2::{ConnectionManager, Pool, PooledConnection},
};
use handlebars::{Context, Handlebars, Helper, HelperResult, Output, RenderContext};
use iron::{prelude::*, status, typemap::Key};
use persistent::State;

pub struct DatabasePool;
impl Key for DatabasePool {
    type Value = Pool<ConnectionManager<PgConnection>>;
}

pub type Database = PooledConnection<ConnectionManager<PgConnection>>;

/// returns a Vec with all days of that week
pub fn to_week_days(year: i32, week: u32) -> Vec<NaiveDate> {
    use chrono::Weekday::*;

    trace!("week: {}, year: {}", week, year);

    [Mon, Tue, Wed, Thu, Fri, Sat, Sun]
        .iter()
        .map(|day| NaiveDate::from_isoywd(year, week, *day))
        .collect()
}

/// Gets a database connection from the pool
/// error will 500 HTTP status
pub fn get_db(req: &mut Request) -> IronResult<Database> {
    trace!("Getting new database connection from Pool");
    match req
        .get::<State<DatabasePool>>()
        .unwrap()
        .read()
        .unwrap()
        .get()
    {
        Ok(db) => Ok(db),
        Err(e) => Err(IronError::new(e, status::InternalServerError)),
    }
}

pub fn to_hours(
    h: &Helper,
    _: &Handlebars,
    _: &Context,
    _: &mut RenderContext,
    out: &mut dyn Output,
) -> HelperResult {
    let param = h.param(0).unwrap();

    match param.value().as_i64().unwrap() / 60 {
        x if x == 1 => out.write(format!("{} Stunde", x).as_str()),
        x => out.write(format!("{} Stunden", x).as_str()),
    }
    .unwrap();

    Ok(())
}
