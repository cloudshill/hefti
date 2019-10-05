use diesel::prelude::*;
use iron::{prelude::*, status};
use router::Router;

use crate::models::EntryForm;
use crate::utils::*;

// all routes are prefixed with /entry
pub fn routes() -> Router {
    let mut router = Router::new();
    router.put("/entry/:id", update_handler, "update entry");
    router.post("/entry", add_handler, "add entry");
    router.delete("/entry/:id", delete_handler, "delete entry");
    router
}

fn update_handler(req: &mut Request) -> IronResult<Response> {
    use crate::schema::entries::dsl::*;
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
        Ok(None) => Ok(Response::with(status::NotFound)),
        Err(e) => Err(IronError::new(e, status::InternalServerError)),
    }
}

fn add_handler(req: &mut Request) -> IronResult<Response> {
    use crate::schema::entries::dsl::*;
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
    use crate::schema::entries::dsl::*;
    let db = get_db(req)?;

    let ref router = req.extensions.get::<Router>().unwrap();
    let req_id: i32 = router.find("id").unwrap().parse().unwrap();

    diesel::delete(entries.filter(id.eq(req_id)))
        .execute(&db)
        .map(|_| Response::with(status::Ok))
        .map_err(|e| IronError::new(e, status::InternalServerError))
}
