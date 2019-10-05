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

use diesel::{
    pg::PgConnection,
    prelude::*,
    r2d2::{Builder, ConnectionManager},
};
use dotenv::dotenv;
use serde_json::Map;

use hbs::{DirectorySource, HandlebarsEngine, Template};
use iron::{prelude::*, status};
use logger::Logger;
use mount::Mount;
use persistent::{Read, State};
use router::Router;
use staticfile::Static;

use self::models::*;
use self::utils::*;

mod models;
mod schema;
mod utils;

const MAX_BODY_LENGTH: usize = 1024 * 1024 * 10;

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
    router.put("/entry/:id", update_handler, "update entry");
    router.post("/entry", add_handler, "add entry");
    router.delete("/entry/:id", delete_handler, "delete entry");

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
