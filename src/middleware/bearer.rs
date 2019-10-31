use diesel::prelude::*;
use iron::{headers, prelude::*, status, AroundMiddleware, Handler};

use crate::utils::*;

pub struct Bearer;

impl AroundMiddleware for Bearer {
    fn around(self, handler: Box<dyn Handler>) -> Box<Handler> {
        use crate::schema::sessions::dsl::*;

        Box::new(move |req: &mut Request| -> IronResult<Response> {
            let db = get_db(req)?;

            match req.headers.get::<headers::Authorization<headers::Bearer>>() {
                Some(baerer) => {
                    if sessions
                        .select(diesel::dsl::count_star())
                        .filter(key.eq(&baerer.token))
                        .first(&db)
                        .and_then(|n: i64| Ok(n >= 1))
                        .unwrap_or(false)
                    {
                        return handler.handle(req);
                    }
                }
                _ => {}
            };
            Ok(Response::with(status::Unauthorized))
        })
    }
}
