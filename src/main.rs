#[macro_use]
extern crate log;
extern crate env_logger;

#[macro_use]
extern crate lazy_static;

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
extern crate cookie;
extern crate handlebars;
extern crate handlebars_iron as hbs;
extern crate iron;
extern crate logger;
extern crate mount;
extern crate persistent;
extern crate router;
extern crate staticfile;
extern crate urlencoded;

use std::{env, path::Path};

use diesel::{
    pg::PgConnection,
    prelude::*,
    r2d2::{Builder, ConnectionManager},
};
use dotenv::dotenv;

use handlebars::Handlebars;
use hbs::{DirectorySource, HandlebarsEngine};
use iron::{headers::ContentType, prelude::*, status};
use logger::Logger;
use mount::Mount;
use persistent::{Read, State};
use router::Router;
use staticfile::Static;

use self::middleware::bearer::Bearer;
use self::models::*;
use self::utils::*;

mod handler;
mod middleware;
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

    let mut hbsr = Handlebars::new();
    hbsr.register_helper("to_hours", Box::new(to_hours));
    let mut hbse = HandlebarsEngine::from(hbsr);
    hbse.add(Box::new(DirectorySource::new("./templates/", ".hbs")));
    hbse.handlebars_mut().set_strict_mode(true);
    hbse.reload().unwrap();

    let (logger_before, logger_after) = Logger::new(None);

    let mut router = Router::new();
    router.post("/login", handler::login::login, "login");

    let mut mount = Mount::new();
    mount
        .mount("/", Static::new(Path::new("static/index.html")))
        .mount("/api/entry", handler::entry::routes())
        .mount("/print", handler::print::routes())
        .mount("/static", Static::new(Path::new("static")));

    let mut chain = Chain::new(mount);
    chain.link_before(logger_before);
    chain.link_before(Read::<bodyparser::MaxBodyLength>::one(MAX_BODY_LENGTH));
    // chain.link_around(Bearer {});
    chain.link(State::<DatabasePool>::both(pool));
    chain.link_after(logger_after);
    chain.link_after(hbse);

    Iron::new(chain).http("localhost:8000").unwrap();
}
