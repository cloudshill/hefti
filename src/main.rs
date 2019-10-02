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

extern crate handlebars_iron as hbs;
extern crate iron;
extern crate logger;
extern crate mount;
extern crate params;
extern crate persistent;
extern crate router;
extern crate staticfile;

use std::{env, path::Path};

use chrono::prelude::*;
use diesel::{
    pg::PgConnection,
    prelude::*,
    r2d2::{Builder, ConnectionManager, Pool},
};
use dotenv::dotenv;
use serde_json::Map;

use hbs::{DirectorySource, HandlebarsEngine, Template};
use iron::{prelude::*, status, typemap::Key};
use logger::Logger;
use mount::Mount;
use persistent::State;
use router::Router;
use staticfile::Static;

use self::models::*;

mod models;
mod schema;

struct Database;
impl Key for Database {
    type Value = Pool<ConnectionManager<PgConnection>>;
}

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

    if let Err(r) = hbse.reload() {
        panic! {"{}", r};
    }

    let (logger_before, logger_after) = Logger::new(None);

    let mut router = Router::new();
    router.get("/", index, "index");
    router.get("/week/:year/:week", week_handler, "week");

    let mut mount = Mount::new();
    mount
        .mount("/", router)
        .mount("/static/", Static::new(Path::new("static")));

    let mut chain = Chain::new(mount);
    chain.link_before(logger_before);
    chain.link(State::<Database>::both(pool));
    chain.link_after(logger_after);
    chain.link_after(hbse);

    Iron::new(chain).http("localhost:8000").unwrap();
}

fn index(req: &mut Request) -> IronResult<Response> {
    use self::schema::entry::dsl::*;

    let db = req
        .get::<State<Database>>()
        .unwrap()
        .read()
        .unwrap()
        .get()
        .unwrap();
    let mut context = Map::new();

    let entrys = entry.load::<Entry>(&db).expect("Error loading entries");
    context.insert("entrys".into(), json!(entrys));

    let mut resp = Response::new();
    resp.set_mut(Template::new("index", context))
        .set_mut(status::Ok);

    Ok(resp)
}

fn week_handler(req: &mut Request) -> IronResult<Response> {
    let ref router = req.extensions.get::<Router>().unwrap();

    let week: u32 = router.find("week").unwrap().parse().unwrap();
    let year: i32 = router.find("year").unwrap().parse().unwrap();
    dbg!(to_week_days(year, week));

    Ok(Response::with(status::Ok))
}

fn to_week_days(year: i32, week: u32) -> Vec<NaiveDate> {
    use chrono::Weekday::*;

    let weekdays = [Mon, Tue, Wed, Thu, Fri, Sat, Sun].iter();

    weekdays
        .map(|day| NaiveDate::from_isoywd(year, week, *day))
        .collect()
}
