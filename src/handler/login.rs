use chrono::{Duration, Utc};
use crypto::scrypt::{scrypt_check, ScryptParams};
use diesel::prelude::*;
use iron::{prelude::*, status, typemap::Key};
use jsonwebtoken::{encode, Header};
use lazy_static::lazy_static;
use router::Router;
use serde_derive::{Deserialize, Serialize};
use serde_json::json;

use crate::models::User;
use crate::utils::*;

lazy_static! {
    static ref SCRYPT_PARAMS: ScryptParams = ScryptParams::new(16, 8, 1);
}

pub fn routes() -> Router {
    let mut router = Router::new();
    router.post("/login", login, "login");
    router
}

#[derive(Clone, Deserialize)]
struct LoginData {
    username: String,
    password: String,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct Claims {
    sub: i32,
    name: String,
    exp: i64,
}

impl Key for Claims {
    type Value = Claims;
}

pub fn login(req: &mut Request) -> IronResult<Response> {
    use crate::schema::users::dsl::*;

    let db = get_db(req)?;

    match req.get::<bodyparser::Struct<LoginData>>() {
        Ok(Some(item)) => {
            let user = users
                .filter(name.eq(item.username))
                .get_result::<User>(&db)
                .unwrap();

            let user_claims = Claims {
                sub: user.id,
                name: user.name.clone(),
                exp: (Utc::now() + Duration::weeks(1)).timestamp(),
            };

            if scrypt_check(item.password.as_str(), user.password.as_str()).unwrap() {
                Ok(Response::with(status::Ok)
                    .set(json!({
                        "user": {
                            "username": user.name,
                            "token": encode(&Header::default(), &user_claims, "secret".as_ref()).unwrap(),
                            "image": null
                        }
                    }).to_string()))
            } else {
                Ok(Response::with(status::Unauthorized))
            }
        }
        Ok(None) => Ok(Response::with(status::Unauthorized)),
        Err(e) => Err(IronError::new(e, status::InternalServerError)),
    }
}
