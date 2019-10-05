#[macro_use]
extern crate log;
extern crate env_logger;

#[macro_use]
extern crate diesel;
extern crate dotenv;
#[macro_use]
extern crate serde_derive;
extern crate chrono;
extern crate serde;
#[macro_use]
extern crate serde_json;

extern crate bodyparser;
extern crate handlebars_iron as hbs;
extern crate iron;
extern crate logger;
extern crate mount;
extern crate persistent;
extern crate router;
extern crate staticfile;

use std::{env, path::Path};

use chrono::prelude::*;
use diesel::{
    pg::PgConnection,
    prelude::*,
    r2d2::{Builder, ConnectionManager, Pool, PooledConnection},
};
use dotenv::dotenv;
use serde_json::Map;

use hbs::{DirectorySource, HandlebarsEngine, Template};
use iron::{prelude::*, status, typemap::Key};
use logger::Logger;
use mount::Mount;
use persistent::{Read, State};
use router::Router;
use staticfile::Static;

use self::models::*;

mod models;
mod schema;

const MAX_BODY_LENGTH: usize = 1024 * 1024 * 10;

struct DatabasePool;
impl Key for DatabasePool {
    type Value = Pool<ConnectionManager<PgConnection>>;
}

type Database = PooledConnection<ConnectionManager<PgConnection>>;

fn main() {
    dotenv().ok();
    env_logger::init();

    let database_url = env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    let manager = ConnectionManager::<PgConnection>::new(&database_url);
    let pool = Builder::new()
        .build(manager)
        .expect("Database connection failed");

    let mut hbse = HandlebarsEngine::new();
    hbse.add(Box::new(DirectorySource::new("./templates/", ".hbs")));
    hbse.handlebars_mut().set_strict_mode(true);
    hbse.reload().unwrap();

    let (logger_before, logger_after) = Logger::new(None);

    let mut router = Router::new();
    router.get("/", index, "index");
    router.get("/week/:year/:week", week_handler, "week");
    router.put("/post/:id", update_handler, "update post");
    router.post("/post", add_handler, "add post");
    router.delete("/post/:id", delete_handler, "delete post");

    let mut mount = Mount::new();
    mount
        .mount("/", router)
        .mount("/static/", Static::new(Path::new("static")));

    let mut chain = Chain::new(mount);
    chain.link_before(logger_before);
    chain.link_before(Read::<bodyparser::MaxBodyLength>::one(MAX_BODY_LENGTH));
    chain.link(State::<DatabasePool>::both(pool));
    chain.link_after(logger_after);
    chain.link_after(hbse);

    Iron::new(chain).http("localhost:8000").unwrap();
}

fn index(req: &mut Request) -> IronResult<Response> {
    use self::schema::entries::dsl::*;

    let db = get_db(req)?;
    let mut context = Map::new();

    let result = entries.load::<Entry>(&db).expect("Error loading entries");
    context.insert("entrys".into(), json!(result));

    let mut resp = Response::new();
    resp.set_mut(Template::new("index", context))
        .set_mut(status::Ok);

    Ok(resp)
}

fn week_handler(req: &mut Request) -> IronResult<Response> {
    use self::schema::entries::dsl::*;
    let mut context = Map::new();

    let ref router = req.extensions.get::<Router>().unwrap();

    let week: u32 = router.find("week").unwrap().parse().unwrap();
    let year: i32 = router.find("year").unwrap().parse().unwrap();
    let weekdays = to_week_days(year, week);
    trace!("weekdays {:#?}", weekdays);

    let db = get_db(req)?;
    let entrys = match entries
        .filter(logdate.between(weekdays.first().unwrap(), weekdays.last().unwrap()))
        .order_by(logdate)
        .load::<Entry>(&db)
    {
        Ok(i) => i,
        Err(e) => return Err(IronError::new(e, status::InternalServerError)),
    };

    context.insert("entrys".into(), json!(entrys));

    let mut resp = Response::new();
    resp.set_mut(Template::new("index", context))
        .set_mut(status::Ok);

    Ok(resp)
}

fn update_handler(req: &mut Request) -> IronResult<Response> {
    use self::schema::entries::dsl::*;
    let db = get_db(req)?;

    let ref router = req.extensions.get::<Router>().unwrap();
    let req_id: i32 = router.find("id").unwrap().parse().unwrap();

    match req.get::<bodyparser::Struct<EntryForm>>() {
        Ok(Some(item)) => {
            return diesel::update(entries.filter(id.eq(req_id)))
                .set(&item)
                .execute(&db)
                .map(|_| Response::with(status::Ok))
                .map_err(|e| IronError::new(e, status::InternalServerError))
        }
        Ok(None) => Ok(Response::with(status::Ok)),
        Err(e) => Err(IronError::new(e, status::InternalServerError)),
    }
}

fn add_handler(req: &mut Request) -> IronResult<Response> {
    use self::schema::entries::dsl::*;
    let db = get_db(req)?;

    match req.get::<bodyparser::Struct<EntryForm>>() {
        Ok(Some(item)) => {
            return diesel::insert_into(entries)
                .values(&item)
                .execute(&db)
                .map(|_| Response::with(status::Ok))
                .map_err(|e| IronError::new(e, status::InternalServerError))
        }
        Ok(None) => Ok(Response::with(status::NotFound)),
        Err(e) => Err(IronError::new(e, status::InternalServerError)),
    }
}

fn delete_handler(req: &mut Request) -> IronResult<Response> {
    use self::schema::entries::dsl::*;
    let db = get_db(req)?;

    let ref router = req.extensions.get::<Router>().unwrap();
    let req_id: i32 = router.find("id").unwrap().parse().unwrap();

    diesel::delete(entries.filter(id.eq(req_id)))
        .execute(&db)
        .map(|_| Response::with(status::Ok))
        .map_err(|e| IronError::new(e, status::InternalServerError))
}

/// returns a Vec with all days of that week
fn to_week_days(year: i32, week: u32) -> Vec<NaiveDate> {
    use chrono::Weekday::*;

    trace!("week: {}, year: {}", week, year);

    [Mon, Tue, Wed, Thu, Fri, Sat, Sun]
        .iter()
        .map(|day| NaiveDate::from_isoywd(year, week, *day))
        .collect()
}

/// Gets a database connection from the pool
/// error will 500 HTTP status
fn get_db(req: &mut Request) -> IronResult<Database> {
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
