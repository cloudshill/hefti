use diesel::prelude::*;
use iron::{headers::ContentType, prelude::*, status};
use router::Router;

use crate::models::{Entry, EntryForm};
use crate::utils::*;

// all routes are prefixed with /entry
pub fn routes() -> Router {
    let mut router = Router::new();
    router.get("/", get_entries, "get entries");
    router.put("/:id", update_handler, "update entry");
    router.post("/", add_handler, "add entry");
    router.delete("/:id", delete_handler, "delete entry");
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
                .returning(id)
                .get_result::<i32>(&db)
                .map(|i| Response::with(json!(i).to_string()).set(status::Ok))
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

fn get_entries(req: &mut Request) -> IronResult<Response> {
    use crate::schema::entries::dsl::*;

    let db = get_db(req)?;

    let result = entries.load::<Entry>(&db).expect("Error loading entries");

    let mut resp = Response::new();
    resp.set_mut(json!(result).to_string()).set_mut(status::Ok);
    resp.headers.set(ContentType::json());

    Ok(resp)
}

fn week_handler(req: &mut Request) -> IronResult<Response> {
    use crate::schema::entries::dsl::*;

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

    // context.insert("entrys".into(), json!(entrys));

    let mut resp = Response::new();
    resp.set_mut(json!(entrys).to_string()).set_mut(status::Ok);
    resp.headers.set(ContentType::json());

    Ok(resp)
}
