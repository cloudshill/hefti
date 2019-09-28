#[macro_use]
extern crate diesel;
extern crate dotenv;
extern crate env_logger;
extern crate handlebars_iron as hbs;
extern crate iron;
extern crate logger;
extern crate mount;
extern crate persistent;
extern crate router;
#[macro_use]
extern crate serde_derive;
extern crate chrono;
extern crate serde;
#[macro_use]
extern crate serde_json;
extern crate staticfile;

use diesel::{
    pg::PgConnection,
    prelude::*,
    r2d2::{Builder, ConnectionManager, Pool},
};
use dotenv::dotenv;
use hbs::{DirectorySource, HandlebarsEngine, Template};
use iron::{prelude::*, status, typemap::Key};
use logger::Logger;
use mount::Mount;
use persistent::State;
use router::Router;
use serde_json::Map;
use staticfile::Static;
use std::{env, path::Path};

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
