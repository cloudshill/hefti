use crypto::scrypt::{scrypt_check, ScryptParams};
use diesel::prelude::*;
use iron::{prelude::*, status};
use urlencoded::UrlEncodedBody;

use crate::utils::*;

lazy_static! {
    static ref SCRYPT_PARAMS: ScryptParams = ScryptParams::new(16, 8, 1);
}

// pub fn routes() -> Router {
//     let mut router = Router::new();
//     router.post("/login", login, "login");
//     router
// }

pub fn login(req: &mut Request) -> IronResult<Response> {
    use crate::schema::users::dsl::*;

    let db = get_db(req)?;

    let post_params = match req.get_ref::<UrlEncodedBody>() {
        Ok(hashmap) => hashmap,
        Err(e) => return Err(IronError::new(e, status::NotFound)),
    };

    let post_username = post_params.get("username").unwrap().first().unwrap();
    let post_password = post_params.get("password").unwrap().first().unwrap();

    let storage_hash = users
        .select(password)
        .filter(name.eq(post_username))
        .load::<String>(&db)
        .unwrap();

    if scrypt_check(post_password, storage_hash.first().unwrap()).unwrap() {}

    Ok(Response::with(status::Ok))
}
