use chrono::naive::NaiveDate;
use diesel::prelude::*;
use hbs::Template;
use iron::{prelude::*, status};
use router::Router;
use serde_json::Map;

use crate::{models::Entry, utils::*};

pub fn routes() -> Router {
    let mut router = Router::new();
    router.get(":year/:week", print_handler, "print");
    router
}

fn print_handler(req: &mut Request) -> IronResult<Response> {
    use crate::schema::entries::dsl::*;
    let mut context = Map::new();

    let ref router = req.extensions.get::<Router>().unwrap();

    let week: u32 = router.find("week").unwrap().parse().unwrap();
    let year: i32 = router.find("year").unwrap().parse().unwrap();
    let weekdays = to_week_days(year, week);

    let db = get_db(req)?;
    let betrieb = match entries
        .filter(entry_type.eq("Betriebliche Tätigkeit"))
        .filter(logdate.between(weekdays.first().unwrap(), weekdays.last().unwrap()))
        .order_by(logdate)
        .load::<Entry>(&db)
    {
        Ok(i) => i,
        Err(e) => return Err(IronError::new(e, status::InternalServerError)),
    };

    let schulungen = match entries
        .filter(entry_type.eq("Schulung"))
        .filter(logdate.between(weekdays.first().unwrap(), weekdays.last().unwrap()))
        .order_by(logdate)
        .load::<Entry>(&db)
    {
        Ok(i) => i,
        Err(e) => return Err(IronError::new(e, status::InternalServerError)),
    };

    let schule = match entries
        .filter(entry_type.eq("Berufsschule"))
        .filter(logdate.between(weekdays.first().unwrap(), weekdays.last().unwrap()))
        .order_by(logdate)
        .load::<Entry>(&db)
    {
        Ok(i) => i,
        Err(e) => return Err(IronError::new(e, status::InternalServerError)),
    };

    let number = *weekdays.first().unwrap() - NaiveDate::from_ymd(2019, 09, 02);

    context.insert("betrieb".into(), json!(betrieb));
    context.insert("schulung".into(), json!(schulungen));
    context.insert("schule".into(), json!(schule));
    context.insert("number".into(), json!(number.num_weeks() + 1));
    context.insert("year".into(), json!(number.num_weeks() / 52 + 1));
    context.insert("date-start".into(), json!(weekdays.first().unwrap()));
    context.insert("date-end".into(), json!(weekdays.last().unwrap()));

    let mut resp = Response::new();
    resp.set_mut(Template::new("print", context))
        .set_mut(status::Ok);

    Ok(resp)
}
