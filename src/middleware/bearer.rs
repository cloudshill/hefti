use iron::{headers, prelude::*, status, AroundMiddleware, Handler};
use jsonwebtoken::{decode, Algorithm, Validation};

use crate::handler::login::Claims;

// if the path matches one of these, no token valid token will be needed
const NO_AUTH_REQUIRED: [&'static str; 2] = ["/", "api/auth/login"];

pub struct Bearer;

impl AroundMiddleware for Bearer {
    fn around(self, handler: Box<dyn Handler>) -> Box<Handler> {
        Box::new(move |req: &mut Request| -> IronResult<Response> {
            let mut path = String::from("/");
            path.push_str(req.url.path().join("/").as_str());

            if NO_AUTH_REQUIRED.iter().any(|p| path.starts_with(p)) {
                return handler.handle(req);
            }

            match req.headers.get::<headers::Authorization<headers::Bearer>>() {
                Some(bearer) => {
                    dbg!(&bearer);
                    match decode::<Claims>(
                        bearer.token.as_ref(),
                        "secret".as_ref(),
                        &Validation::new(Algorithm::HS256),
                    ) {
                        Ok(token) => {
                            req.extensions.insert::<Claims>(token.claims);
                            return handler.handle(req);
                        }
                        Err(e) => {
                            println!("{}", e);
                        }
                    };
                }
                _ => {}
            };
            Ok(Response::with(status::Unauthorized))
        })
    }
}
